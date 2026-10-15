extends GdUnitTestSuite
## Das Urteil über eine Summary (src/learning/writing_judge.gd,
## docs/adr/0023-schreib-boss.md): Länge offline, alles andere aus der Modellantwort.
##
## Die Modellantwort ist hier von Hand gebaut — kein Test spricht mit einem Dienst.

const FIXTURE := "res://tests/fixtures/writing/summary_fixture.json"

const TEXT := "In the story \"The Lighthouse Cat\" by Mara Linden, an old man called Tom and his cat look after a lighthouse. One night the lamp breaks while a boat sails towards the rocks. The cat brings the rope of an old lantern and they pull it up. The light saves the boat. The fishermen thanked Tom, but he says the cat deserve the thanks."

var _task: Dictionary


func before() -> void:
	_task = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _reply(overrides := {}) -> Dictionary:
	var reply := {
		"intro": {"met": true, "quote": "\"The Lighthouse Cat\" by Mara Linden"},
		"key_points": [
			{"id": "kp1", "covered": true, "quote": "an old man called Tom and his cat"},
			{"id": "kp2", "covered": true, "quote": "the lamp breaks while a boat sails"},
			{"id": "kp3", "covered": true, "quote": "the rope of an old lantern"},
			{"id": "kp4", "covered": true, "quote": "The light saves the boat."},
			{"id": "kp5", "covered": true, "quote": "he says the cat deserve the thanks"},
			{"id": "kp6", "covered": false, "quote": ""},
		],
		"present_tense": true,
		"tense_quotes": [],
		"direct_speech": [],
		"copied": [],
		"opinion": [],
		"errors": [],
	}
	reply.merge(overrides, true)
	return reply


func _by_id(list: Array) -> Dictionary:
	var out := {}
	for entry in list:
		out[entry["id"]] = entry
	return out


func _judge(reply: Dictionary, text := TEXT) -> Dictionary:
	return _by_id(WritingJudge.criteria(_task, text, SummaryCard.check(_task, text), reply))


func test_criteria_come_in_the_fixed_order() -> void:
	var ids: Array = WritingJudge.criteria(_task, TEXT, {}, _reply()).map(func(c): return c["id"])
	assert_array(ids).is_equal(WritingJudge.CRITERIA)


func test_a_clean_reply_meets_content_genre_and_language() -> void:
	var result := _judge(_reply())
	for id in ["intro", "content", "genre", "language"]:
		assert_bool(bool(result[id]["decided"])).override_failure_message(id).is_true()
		assert_bool(bool(result[id]["met"])).override_failure_message(id).is_true()
	for id in ["intro", "content", "genre", "language"]:
		assert_str(str(result[id]["source"])).override_failure_message(id).is_equal("model")
	assert_str(str(result["length"]["source"])).is_equal("offline")
	# Zu kurz für den Zielbereich der Fixture (80–140).
	assert_bool(bool(result["length"]["met"])).is_false()


## Ohne Modellantwort entscheidet nur die Länge.
func test_without_a_reply_the_model_criteria_stay_open() -> void:
	var result := _judge({})
	assert_bool(bool(result["length"]["decided"])).is_true()
	for id in ["intro", "content", "genre", "language"]:
		assert_bool(bool(result[id]["decided"])).override_failure_message(id).is_false()
		assert_bool(bool(result[id]["met"])).override_failure_message(id).is_false()


## Ein Fetzen ohne Fehler ist keine Summary: Textsorte und Sprache halten, auch wenn das
## Modell nichts findet.
func test_a_scrap_does_not_meet_genre_or_language() -> void:
	var reply := _reply({"intro": {"met": false, "quote": ""}, "key_points": []})
	var result := _judge(reply, "dsgf")
	for id in ["genre", "language", "length"]:
		assert_bool(bool(result[id]["decided"])).override_failure_message(id).is_true()
		assert_bool(bool(result[id]["met"])).override_failure_message(id).is_false()
	assert_array(result["genre"]["marks"]).is_empty()
	assert_array(result["language"]["marks"]).is_empty()


func test_half_the_minimum_length_is_enough_to_judge() -> void:
	assert_bool(WritingJudge.substantial(_task, 39)).is_false()
	assert_bool(WritingJudge.substantial(_task, 40)).is_true()
	assert_bool(WritingJudge.substantial({}, 19)).is_false()
	assert_bool(WritingJudge.substantial({}, 20)).is_true()


## Die Einleitung gilt nur mit einem Zitat, das im Text steht.
func test_the_intro_needs_evidence() -> void:
	var reply := _reply({"intro": {"met": true, "quote": "The Lighthouse Dog by Mara Linden"}})
	assert_bool(bool(_judge(reply)["intro"]["met"])).is_false()
	reply = _reply({"intro": {"met": false, "quote": ""}})
	assert_bool(bool(_judge(reply)["intro"]["met"])).is_false()
	assert_array(_judge(reply)["intro"]["marks"]).is_empty()


## Direkte Rede, Abgeschriebenes und Meinung des Modells halten die Textsorte, jede Stelle
## mit der Regel ihrer Kategorie; was nicht im Text steht, fällt weg.
func test_speech_copies_and_opinion_hold_the_genre() -> void:
	var text := TEXT + " Tom shouts: Help me! I think Tom is a hero."
	var reply := _reply({"direct_speech": ["Help me!"], "copied": ["the waves were as high as houses"],
			"opinion": ["I think Tom is a hero"]})
	var genre: Dictionary = _judge(reply, text)["genre"]
	assert_bool(bool(genre["met"])).is_false()
	var found := {}
	for mark: Dictionary in genre["marks"]:
		found[text.substr(int(mark["from"]), int(mark["to"]) - int(mark["from"]))] = mark
	assert_array(found.keys()).contains_exactly_in_any_order(["Help me", "I think Tom is a hero"])
	assert_str(str(found["Help me"]["hint"])).is_equal(WritingJudge.DEFAULT_HINTS["quote"])
	assert_str(str(found["I think Tom is a hero"]["hint"]))\
			.is_equal(WritingJudge.DEFAULT_HINTS["opinion"])
	var invented := _reply({"opinion": ["I loved this story"]})
	assert_bool(bool(_judge(invented)["genre"]["met"])).is_true()


## Ein Kernpunkt gilt nur mit einem Zitat, das wirklich im Text steht.
func test_a_key_point_without_evidence_is_not_covered() -> void:
	var reply := _reply()
	reply["key_points"][2] = {"id": "kp3", "covered": true, "quote": "the cat climbs down a rope"}
	assert_bool(bool(_judge(reply)["content"]["met"])).is_false()
	reply = _reply()
	reply["key_points"][4] = {"id": "kp5", "covered": false, "quote": ""}
	assert_bool(bool(_judge(reply)["content"]["met"])).is_false()


func test_an_optional_key_point_is_not_needed() -> void:
	var reply := _reply()
	(reply["key_points"] as Array).remove_at(5)
	assert_bool(bool(_judge(reply)["content"]["met"])).is_true()


## Erfundene Fehler fallen weg; Zitate werden normalisiert gesucht, die Stelle bezieht sich
## auf den Originaltext.
func test_error_quotes_are_verified_in_the_text() -> void:
	var reply := _reply({"errors": [
		{"quote": "the cat DESERVE the thanks", "category": "grammar", "severity": "major",
			"hint": "Achte auf das -s in der dritten Person Singular."},
		{"quote": "the dog barks loudly", "category": "spelling", "severity": "major",
			"hint": "Prüfe die Schreibweise."},
	]})
	var language: Dictionary = _judge(reply)["language"]
	assert_bool(bool(language["met"])).is_false()
	assert_int((language["marks"] as Array).size()).is_equal(1)
	var mark: Dictionary = language["marks"][0]
	assert_str(str(mark["quote"])).is_equal("the cat deserve the thanks")
	assert_str(TEXT.substr(int(mark["from"]), int(mark["to"]) - int(mark["from"])))\
			.is_equal("the cat deserve the thanks")
	assert_str(str(mark["hint"])).is_equal("Achte auf das -s in der dritten Person Singular.")


func test_minor_errors_are_marked_but_do_not_hold_the_stack() -> void:
	var reply := _reply({"errors": [
		{"quote": "they pull it up", "category": "style", "severity": "minor", "hint": ""},
	]})
	var language: Dictionary = _judge(reply)["language"]
	assert_bool(bool(language["met"])).is_true()
	assert_str(str(language["marks"][0]["hint"])).is_equal(WritingJudge.DEFAULT_HINTS["style"])


## Nicht im Präsens zählt nur mit einer Stelle, die im Text steht.
func test_past_tense_needs_a_verified_quote() -> void:
	var reply := _reply({"present_tense": false, "tense_quotes": ["The fishermen thanked Tom"]})
	var genre: Dictionary = _judge(reply)["genre"]
	assert_bool(bool(genre["met"])).is_false()
	assert_str(str(genre["marks"][0]["category"])).is_equal("tense")
	assert_str(str(genre["marks"][0]["hint"])).is_equal(WritingJudge.DEFAULT_HINTS["tense"])
	var invented := _reply({"present_tense": false, "tense_quotes": ["Tom was very sad"]})
	assert_bool(bool(_judge(invented)["genre"]["met"])).is_true()


func test_a_hint_never_gives_the_solution() -> void:
	for hint in [
		"Use 'deserves' here.",
		"deserve → deserves",
		"Write \"deserves\" instead of \"deserve\".",
		"This should be 'deserves'.",
		"Change it to 'deserves'.",
		"Schreib „deserves“.",
		"Richtig wäre: deserves.",
		"Hier muss es deserves heißen.",
		"deserves statt deserve",
	]:
		assert_bool(WritingJudge.reveals_solution(hint)).override_failure_message(hint).is_true()
		assert_str(WritingJudge.safe_hint("grammar", hint))\
				.is_equal(WritingJudge.DEFAULT_HINTS["grammar"])
	for hint in [
		"Achte auf das -s in der dritten Person Singular.",
		"Eine Summary steht im Present Tense.",
		"Change the verb to the present tense.",
	]:
		assert_bool(WritingJudge.reveals_solution(hint)).override_failure_message(hint).is_false()
	assert_str(WritingJudge.safe_hint("unknown", "")).is_equal(WritingJudge.FALLBACK_HINT)
