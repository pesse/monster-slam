extends GdUnitTestSuite
## Cloud-Backend des Schreib-Bosses (ADR 0023): Anfrage-Bau und Antwort-Auswertung — ohne
## Netz. Kein Test spricht mit Anthropic; geprüft werden die statischen Teile und der
## Fall ohne Schlüssel, der gar nicht erst sendet.

const KEY := "sk-ant-zz-test-key-1234"
const TEST_KEYS := "user://zz-cloud-backend-keys.cfg"

## Eine erfundene Aufgabe — kein Lehrbuchtext.
const TASK := {
	"id": "writing.zz.summary_01",
	"kind": "summary",
	"title": "The Silent Lighthouse",
	"author": "Zara Zed",
	"genre": "short story",
	"text": "Mila lives on an island.\n\nOne night the lighthouse goes dark.",
	"target_words": [80, 140],
	"key_points": [
		{"id": "kp1", "text": "Mila lives on an island.", "required": true},
		{"id": "kp2", "text": "The lighthouse goes dark.", "required": false},
	],
}

const STUDENT := "In the story The Silent Lighthouse by Zara Zed, a girl lived on an island."

const RESULT := {
	"key_points": [
		{"id": "kp1", "covered": true, "quote": "a girl lived on an island"},
		{"id": "kp2", "covered": false, "quote": ""},
	],
	"present_tense": false,
	"tense_quotes": ["lived"],
	"errors": [
		{"quote": "lived", "category": "tense", "severity": "major",
				"hint": "In einer Summary steht das Simple Present."},
	],
}


func before_test() -> void:
	ApiKeys.path = TEST_KEYS


func after_test() -> void:
	if FileAccess.file_exists(TEST_KEYS):
		DirAccess.remove_absolute(TEST_KEYS)
	ApiKeys.path = ApiKeys.DEFAULT_PATH


func _envelope(content: Array, stop := "end_turn", model := "claude-opus-5-5") -> String:
	return JSON.stringify({
		"id": "msg_zz", "type": "message", "role": "assistant", "model": model,
		"content": content, "stop_reason": stop,
		"usage": {"input_tokens": 1234, "output_tokens": 456,
				"cache_read_input_tokens": 10, "cache_creation_input_tokens": 20},
	})


# --- Anfrage -------------------------------------------------------------------

func test_headers_carry_key_version_and_fallback_beta() -> void:
	var headers := CloudModelBackend.request_headers(KEY)
	assert_bool(headers.has("x-api-key: %s" % KEY)).is_true()
	assert_bool(headers.has("anthropic-version: 2023-06-01")).is_true()
	assert_bool(headers.has("anthropic-beta: %s" % CloudModelBackend.FALLBACK_BETA)).is_true()
	assert_bool(CloudModelBackend.request_headers(KEY, false).has(
			"anthropic-beta: %s" % CloudModelBackend.FALLBACK_BETA)).is_false()


func test_body_uses_the_model_schema_and_no_forced_tool() -> void:
	var body := CloudModelBackend.request_body(TASK, STUDENT)
	assert_str(str(body["model"])).is_equal("claude-opus-5-5")
	assert_str(str(body["system"])).is_equal(WritingPrompts.SUMMARY_SYSTEM)
	var format: Dictionary = body["output_config"]["format"]
	assert_str(str(format["type"])).is_equal("json_schema")
	assert_dict(format["schema"]).is_equal(WritingPrompts.SUMMARY_SCHEMA)
	# Opus 5.5 lehnt erzwungene Werkzeuge, ausgeschaltetes Denken und temperature ab.
	for field in ["tool_choice", "tools", "thinking", "temperature"]:
		assert_bool(body.has(field)).append_failure_message(field).is_false()
	assert_str(str(body["fallbacks"])).is_equal("default")


func test_body_carries_task_and_text_but_no_key() -> void:
	var flat := JSON.stringify(CloudModelBackend.request_body(TASK, STUDENT))
	assert_bool(flat.contains("The Silent Lighthouse")).is_true()
	assert_bool(flat.contains("Zara Zed")).is_true()
	assert_bool(flat.contains("kp2 (optional)")).is_true()
	assert_bool(flat.contains("a girl lived on an island")).is_true()
	assert_bool(flat.contains("sk-ant")).is_false()


func test_schema_closes_every_object() -> void:
	var open := _open_objects(WritingPrompts.SUMMARY_SCHEMA, "$")
	assert_array(open).append_failure_message(str(open)).is_empty()


func _open_objects(node: Variant, where: String) -> Array:
	var out: Array = []
	if node is Dictionary:
		var d: Dictionary = node
		if str(d.get("type", "")) == "object":
			if d.get("additionalProperties", true) != false:
				out.append(where)
			var props: Dictionary = d.get("properties", {})
			if Array(d.get("required", [])).size() != props.size():
				out.append(where + " (required)")
		for key in d:
			out.append_array(_open_objects(d[key], "%s.%s" % [where, key]))
	elif node is Array:
		for item in node:
			out.append_array(_open_objects(item, where + "[]"))
	return out


# --- Antwort -------------------------------------------------------------------

func test_success_from_a_text_block() -> void:
	var text := _envelope([
		{"type": "thinking", "thinking": "", "signature": "x"},
		{"type": "text", "text": JSON.stringify(RESULT)},
	])
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 6.234)
	assert_str(str(reply["note"])).is_empty()
	assert_dict(reply["result"]).is_equal(RESULT)
	var usage: Dictionary = reply["usage"]
	assert_str(str(usage["model"])).is_equal("claude-opus-5-5")
	assert_int(int(usage["input_tokens"])).is_equal(1234)
	assert_int(int(usage["output_tokens"])).is_equal(456)
	assert_int(int(usage["cache_read_input_tokens"])).is_equal(10)
	assert_int(int(usage["cache_creation_input_tokens"])).is_equal(20)
	assert_float(float(usage["seconds"])).is_equal_approx(6.23, 0.001)


func test_success_from_a_tool_block() -> void:
	var text := _envelope([{"type": "tool_use", "id": "t1", "name": "report", "input": RESULT}],
			"tool_use")
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0)
	assert_dict(reply["result"]).is_equal(RESULT)


func test_fallback_model_goes_into_usage() -> void:
	var text := _envelope([{"type": "text", "text": JSON.stringify(RESULT)}], "end_turn",
			"claude-opus-5")
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0)
	assert_str(str(reply["usage"]["model"])).is_equal("claude-opus-5")


func test_missing_result_block_gives_no_verdict_but_keeps_usage() -> void:
	var text := _envelope([{"type": "thinking", "thinking": "", "signature": "x"}])
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0)
	assert_dict(reply["result"]).is_empty()
	assert_str(str(reply["note"])).is_not_empty()
	# Bezahlt ist trotzdem — der Verbrauch geht mit.
	assert_int(int(reply["usage"]["input_tokens"])).is_equal(1234)


func test_wrong_shape_gives_no_verdict() -> void:
	var text := _envelope([{"type": "text", "text": "{\"key_points\": []}"}])
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0)
	assert_dict(reply["result"]).is_empty()
	assert_str(str(reply["note"])).is_not_empty()


func test_refusal_and_truncation_give_no_verdict() -> void:
	for stop in ["refusal", "max_tokens"]:
		var text := _envelope([{"type": "text", "text": JSON.stringify(RESULT)}], stop)
		var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0)
		assert_dict(reply["result"]).append_failure_message(stop).is_empty()
		assert_str(str(reply["note"])).is_not_empty()


func test_http_errors_explain_themselves() -> void:
	var body := JSON.stringify({"type": "error",
			"error": {"type": "invalid_request_error", "message": "credit balance is too low"}})
	var bad_key := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 401, body, 0.5)
	assert_dict(bad_key["result"]).is_empty()
	assert_str(str(bad_key["note"])).contains("Schlüssel")
	var bad_request := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 400, body, 0.5)
	assert_str(str(bad_request["note"])).contains("credit balance")
	assert_int(int(bad_request["usage"]["input_tokens"])).is_equal(0)


func test_no_network_gives_a_note() -> void:
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_CANT_CONNECT, 0, "", 0.0)
	assert_dict(reply["result"]).is_empty()
	assert_str(str(reply["note"])).contains("Internet")
	assert_str(str(reply["usage"]["model"])).is_equal(CloudModelBackend.MODEL)


func test_broken_entries_are_dropped_not_the_answer() -> void:
	var raw := RESULT.duplicate(true)
	raw["key_points"].append("kaputt")
	raw["key_points"].append({"id": "", "covered": true, "quote": "x"})
	raw["errors"].append({"quote": "", "category": "grammar", "severity": "major", "hint": ""})
	raw["errors"].append({"quote": "goed", "category": "nonsense", "severity": "huge", "hint": "h"})
	var result := CloudModelBackend.parse_result(raw)
	assert_int((result["key_points"] as Array).size()).is_equal(2)
	assert_int((result["errors"] as Array).size()).is_equal(2)
	var odd: Dictionary = result["errors"][1]
	assert_str(str(odd["category"])).is_equal("grammar")
	assert_str(str(odd["severity"])).is_equal("minor")


func test_an_uncovered_point_carries_no_quote() -> void:
	var raw := RESULT.duplicate(true)
	raw["key_points"][1]["quote"] = "erfunden"
	var result := CloudModelBackend.parse_result(raw)
	assert_str(str(result["key_points"][1]["quote"])).is_empty()


# --- Ablauf ohne Netz ----------------------------------------------------------

func test_without_key_nothing_is_sent() -> void:
	var backend: CloudModelBackend = auto_free(CloudModelBackend.new())
	add_child(backend)
	var got := [{}]
	backend.judge_summary(TASK, STUDENT, func(reply): got[0] = reply)
	assert_str(str(got[0]["note"])).is_equal(CloudModelBackend.NO_KEY_NOTE)
	assert_dict(got[0]["result"]).is_empty()
	assert_bool(backend.busy()).is_false()
	var checked := ["?"]
	backend.check_key(func(note): checked[0] = note)
	assert_str(str(checked[0])).is_equal(CloudModelBackend.NO_KEY_NOTE)
