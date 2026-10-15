extends GdUnitTestSuite
## Stufe 1 des Satzmeisters in der Cloud (ADR 0025): Auftrag, Anfrage und Antwort — ohne
## Netz. Kein Test spricht mit Anthropic.

const TEST_KEYS := "user://zz-cloud-sentence-keys.cfg"

## Ein erfundener Satz — kein Lehrbuchsatz.
const SENTENCE := {
	"id": "sen.zz.lighthouse",
	"source_text": "Gestern war der Leuchtturm dunkel. Niemand wusste warum.",
	"reference_translation": "Yesterday the lighthouse was dark. Nobody knew why.",
	"accepted": ["The lighthouse was dark yesterday. Nobody knew why."],
	"grammar_tags": ["past_simple"],
}

const ANSWER := "Yesterday the lighthouse is dark. Nobody knew why."


func before_test() -> void:
	ApiKeys.path = TEST_KEYS


func after_test() -> void:
	if FileAccess.file_exists(TEST_KEYS):
		DirAccess.remove_absolute(TEST_KEYS)
	ApiKeys.path = ApiKeys.DEFAULT_PATH


func _envelope(result: Variant, stop := "end_turn") -> String:
	return JSON.stringify({
		"id": "msg_zz", "type": "message", "role": "assistant", "model": "claude-sonnet-5-5",
		"content": [{"type": "text", "text": JSON.stringify(result)}], "stop_reason": stop,
		"usage": {"input_tokens": 1400, "output_tokens": 300,
				"cache_read_input_tokens": 0, "cache_creation_input_tokens": 0},
	})


# --- Auftrag -------------------------------------------------------------------

func test_the_german_text_is_numbered_by_sentence() -> void:
	assert_str(StageOnePrompts.numbered("Ich gehe. Kommst du? Ja!")) \
			.is_equal("1. Ich gehe.\n2. Kommst du?\n3. Ja!")
	assert_str(StageOnePrompts.numbered("  Ein Satz ohne Punkt ")).is_equal("1. Ein Satz ohne Punkt")


func test_the_user_part_fills_every_placeholder() -> void:
	var user := StageOnePrompts.cloud_user(SENTENCE, "  " + ANSWER + " ")
	assert_str(user).not_contains("{{")
	assert_str(user).contains("1. Gestern war der Leuchtturm dunkel.\n2. Niemand wusste warum.")
	assert_str(user).contains("Model translation: Yesterday the lighthouse was dark.")
	assert_str(user).contains("Other accepted translations: The lighthouse was dark yesterday.")
	assert_str(user).contains(GrammarRules.focus(SENTENCE))
	assert_str(user).ends_with("Student translation:\n" + ANSWER)


func test_an_empty_key_field_reads_as_none() -> void:
	var bare := SENTENCE.duplicate()
	bare["accepted"] = []
	assert_str(StageOnePrompts.cloud_user(bare, ANSWER)) \
			.contains("Other accepted translations: %s" % StageOnePrompts.NONE)


func test_the_prompt_lets_alternatives_stand() -> void:
	# Der Kern von satz-v2/v3: eine andere richtige Form ist kein Fehler.
	assert_str(StageOnePrompts.CLOUD_SYSTEM).contains("every one of them is correct")
	assert_str(StageOnePrompts.CLOUD_SYSTEM).contains("not how closely it follows the German words")
	assert_str(StageOnePrompts.CLOUD_SYSTEM) \
			.contains("Do not present one correct form as the only one")


# --- Anfrage -------------------------------------------------------------------

func test_body_uses_sonnet_the_sentence_schema_and_no_key() -> void:
	var body := CloudModelBackend.sentence_body(SENTENCE, ANSWER)
	assert_str(str(body["model"])).is_equal(CloudModelBackend.SENTENCE_MODEL)
	assert_str(str(body["system"])).is_equal(StageOnePrompts.CLOUD_SYSTEM)
	var config: Dictionary = body["output_config"]
	assert_str(str(config["effort"])).is_equal(CloudModelBackend.EFFORT)
	assert_dict(config["format"]["schema"]).is_equal(StageOnePrompts.CLOUD_SCHEMA)
	assert_bool(body.has("tool_choice")).is_false()
	assert_str(JSON.stringify(body)).not_contains("sk-ant")


func test_schema_closes_every_object() -> void:
	var open := _open_objects(StageOnePrompts.CLOUD_SCHEMA, "$")
	assert_array(open).append_failure_message(str(open)).is_empty()


func _open_objects(node: Variant, where: String) -> Array:
	var out: Array = []
	if node is Dictionary:
		var d: Dictionary = node
		if str(d.get("type", "")) == "object":
			if d.get("additionalProperties", true) != false:
				out.append(where)
			if Array(d.get("required", [])).size() != (d.get("properties", {}) as Dictionary).size():
				out.append(where + " (required)")
		for key in d:
			out.append_array(_open_objects(d[key], "%s.%s" % [where, key]))
	elif node is Array:
		for item in node:
			out.append_array(_open_objects(item, where + "[]"))
	return out


# --- Antwort -------------------------------------------------------------------

func test_a_mistake_comes_with_its_explanation() -> void:
	var text := _envelope({"parts": [{"n": 1, "student": "Yesterday the lighthouse is dark."}],
			"mistake": true, "explanation": " Satz 1: Mit ‚yesterday‘ steht das Simple Past: ‚was‘. "})
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 4.2,
			CloudModelBackend.SENTENCE_MODEL, "sentence")
	assert_str(str(reply["note"])).is_empty()
	assert_dict(reply["result"]).is_equal({"mistake": true,
			"explanation": "Satz 1: Mit ‚yesterday‘ steht das Simple Past: ‚was‘."})
	assert_int(int(reply["usage"]["input_tokens"])).is_equal(1400)


func test_no_mistake_means_no_explanation() -> void:
	var text := _envelope({"parts": [], "mistake": false, "explanation": "Alles gut."})
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0,
			CloudModelBackend.SENTENCE_MODEL, "sentence")
	assert_dict(reply["result"]).is_equal({"mistake": false, "explanation": ""})


func test_without_a_verdict_there_is_none() -> void:
	var text := _envelope({"parts": [], "explanation": "Satz 1: …"})
	var reply := CloudModelBackend.reply_from(HTTPRequest.RESULT_SUCCESS, 200, text, 1.0,
			CloudModelBackend.SENTENCE_MODEL, "sentence")
	assert_dict(reply["result"]).is_empty()
	assert_str(str(reply["note"])).is_not_empty()


func test_a_missing_model_names_the_sentence_model() -> void:
	var note := CloudModelBackend.error_note(404, {}, "", CloudModelBackend.SENTENCE_MODEL)
	assert_str(note).contains(CloudModelBackend.SENTENCE_MODEL)


# --- Ablauf ohne Netz ----------------------------------------------------------

func test_without_key_the_judge_hears_nothing_and_nothing_is_billed() -> void:
	var backend: CloudModelBackend = auto_free(CloudModelBackend.new())
	add_child(backend)
	var answered := []
	backend.sentence_answered.connect(func(id, reply): answered.append([id, reply]))
	var got := [null]
	backend.judge(SENTENCE, ANSWER, func(reply): got[0] = reply)
	assert_dict(got[0]).is_empty()
	assert_int(answered.size()).is_equal(1)
	assert_str(str(answered[0][0])).is_equal("sen.zz.lighthouse")
	assert_int(int(answered[0][1]["usage"]["input_tokens"])).is_equal(0)
	assert_bool(backend.busy()).is_false()


func test_explain_has_nothing_for_an_answer_it_did_not_judge() -> void:
	var backend: CloudModelBackend = auto_free(CloudModelBackend.new())
	add_child(backend)
	var got := [null]
	backend.explain(SENTENCE, ANSWER, func(reply): got[0] = reply)
	assert_dict(got[0]).is_empty()


func test_the_choice_sits_with_the_key_in_the_content_screen() -> void:
	var screen: Control = auto_free(load("res://scenes/ui/content_manager.tscn").instantiate())
	var toggle := screen.get_node("%SentenceCloudToggle") as CheckBox
	assert_object(toggle).is_not_null()
	# Ohne Schlüssel gibt es keine Wahl — in der Szene ist sie aus.
	assert_bool(toggle.visible).is_false()
