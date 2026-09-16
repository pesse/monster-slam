extends GdUnitTestSuite
## Die Satz-Werkbank (scenes/dev/boss_lab.tscn) muss sich bauen lassen und ihre
## Bedienelemente über die eindeutigen Namen finden — genau das geht in einer
## handgeschriebenen .tscn leicht schief, und eine kaputte Werkbank fällt sonst erst dann
## auf, wenn man sie zum Beurteilen einer Bewertungsregel gerade braucht.
##
## Gearbeitet wird mit einem ERFUNDENEN Satz (`show_sentences`), nicht mit dem, was auf
## diesem Rechner installiert ist: der Test soll auf einem Rechner ohne Sprachdaten
## dasselbe prüfen. Die Werkbank speichert nichts und lernt nichts, also kann der Test sie
## ohne Rücksicht bedienen.

const LAB_SCENE := preload("res://scenes/dev/boss_lab.tscn")

const SENTENCE := {
	"id": "sen.test.reef",
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"accepted": ["We saw the reef yesterday."],
	"pitfalls": [{"contains": ["have seen", "yesterday"], "feedback": "Simple Past: „saw“."}],
	"difficulty": 2,
	"grammar_tags": ["past_simple"],
}

var _lab: Control


func before_test() -> void:
	_lab = auto_free(LAB_SCENE.instantiate()) as Control
	add_child(_lab)
	_lab.call("show_sentences", [SENTENCE])


func test_the_lab_builds_with_all_its_controls() -> void:
	for unique_name in ["BossSelect", "SentenceSelect", "OnlyKeyed", "UseProfile", "PoolInfo",
			"RollButton", "SourceText", "SentenceInfo", "KeyEdit", "KeyStatus",
			"AnswerEdit", "JudgeButton", "CardResult", "ModelResult", "ModelToggle",
			"ModelUrl", "ServeButton", "ServeStatus", "BackButton"]:
		assert_object(_lab.get_node("%" + unique_name)).override_failure_message(
				"Werkbank findet '%s' nicht" % unique_name).is_not_null()


func test_the_chosen_sentence_is_on_the_table() -> void:
	assert_str((_lab.get_node("%SourceText") as Label).text) \
			.is_equal(str(SENTENCE["source_text"]))
	assert_str((_lab.get_node("%SentenceInfo") as Label).text).contains("sen.test.reef")


## Der Schlüssel steht im Feld — sonst wäre die Werkbank nur ein zweites Eingabefeld.
func test_the_key_is_shown_and_can_be_read_back() -> void:
	var shown: Variant = JSON.parse_string((_lab.get_node("%KeyEdit") as TextEdit).text)
	assert_array(Array((shown as Dictionary)["accepted"])).contains(["We saw the reef yesterday."])
	assert_dict(_lab.call("sentence_under_test") as Dictionary).contains_key_value(
			"id", "sen.test.reef")


func test_judging_fills_the_card_column() -> void:
	(_lab.get_node("%AnswerEdit") as LineEdit).text = "Yesterday we saw the reef."
	(_lab.get_node("%JudgeButton") as Button).pressed.emit()
	assert_str((_lab.get_node("%CardResult") as Label).text).contains("100 %")
	assert_str((_lab.get_node("%CardResult") as Label).text).contains(SentenceCard.PRAISE_FEEDBACK)


## Die vorweggenommene Rückmeldung kommt an — das ist das, was man hier beurteilen will.
func test_a_pitfall_shows_its_own_feedback() -> void:
	(_lab.get_node("%AnswerEdit") as LineEdit).text = "Yesterday we have seen the reef."
	(_lab.get_node("%JudgeButton") as Button).pressed.emit()
	assert_str((_lab.get_node("%CardResult") as Label).text).contains("Simple Past")


## Der eigentliche Grund für die Werkbank: eine Stolperstelle formulieren und sofort
## dagegen tippen, ohne die Datei im Submodule anzufassen.
func test_the_key_in_the_field_beats_the_one_from_the_data() -> void:
	(_lab.get_node("%KeyEdit") as TextEdit).text = JSON.stringify({
		"accepted": [], "must_contain": [],
		"pitfalls": [{"contains": ["saw"], "feedback": "Frisch erfunden."}],
	})
	(_lab.get_node("%AnswerEdit") as LineEdit).text = "We saw something else."
	(_lab.get_node("%JudgeButton") as Button).pressed.emit()
	assert_str((_lab.get_node("%CardResult") as Label).text).contains("Frisch erfunden.")
	assert_str((_lab.get_node("%KeyStatus") as Label).text).is_not_empty()


## Eine halb getippte Klammer hält die Bewertung nicht an — sie sagt es nur.
func test_a_broken_key_falls_back_to_the_data() -> void:
	(_lab.get_node("%KeyEdit") as TextEdit).text = '{"accepted": ['
	(_lab.get_node("%AnswerEdit") as LineEdit).text = "Yesterday we saw the reef."
	(_lab.get_node("%JudgeButton") as Button).pressed.emit()
	assert_str((_lab.get_node("%CardResult") as Label).text).contains("100 %")
	assert_str((_lab.get_node("%KeyStatus") as Label).text).contains("JSON")


## Stufe 1 ist aus, solange niemand sie einschaltet — sie ist nicht Teil der Auslieferung.
func test_stage_one_is_off_until_someone_turns_it_on() -> void:
	assert_bool((_lab.get_node("%ModelToggle") as CheckButton).button_pressed).is_false()
	assert_str((_lab.get_node("%ModelUrl") as LineEdit).text).contains("127.0.0.1")
	(_lab.get_node("%AnswerEdit") as LineEdit).text = "Yesterday we saw the reef."
	(_lab.get_node("%JudgeButton") as Button).pressed.emit()
	assert_str((_lab.get_node("%ModelResult") as Label).text).contains("Aus.")


## „Satz ziehen wie im Spiel" zieht aus DERSELBEN Menge, die auch in der Liste steht.
## Sonst legt der Knopf bei angehaktem „Nur Sätze mit Schlüssel" einen ohne Schlüssel
## daneben — und man sieht einen leeren Schlüssel, ohne zu wissen, warum. Findet der Pool
## nichts (keine Sprachdaten), bleibt der erfundene Satz stehen; geprüft wird so oder so.
func test_the_roll_respects_the_filter() -> void:
	assert_bool((_lab.get_node("%OnlyKeyed") as CheckButton).button_pressed).is_true()
	(_lab.get_node("%RollButton") as Button).pressed.emit()
	var shown := _lab.call("selected") as Dictionary
	assert_bool(_lab.call("has_key", shown)).override_failure_message(
			"Gezogen wurde '%s' ohne Schlüssel" % shown.get("id", "?")).is_true()


## Woher der Satz kommt, steht dabei: ein installierter Pack gewinnt bei gleicher Id gegen
## das Submodule, und ein unerwartet leerer Schlüssel ist sonst nicht zu erklären.
func test_the_origin_is_on_the_label() -> void:
	assert_str((_lab.get_node("%SentenceInfo") as Label).text).contains("Submodule")
	assert_str(_lab.call("origin_label", "sen.test.reef") as String).is_not_empty()


## Der Knopf startet den Dienst, den das URL-Feld MEINT. Vorher stand dort Ollamas 11434,
## während LocalModelServer auf 11435 kommt — wer den Umschalter anwarf, bekam „kein Dienst
## erreichbar", obwohl gerade einer lief. Gestartet wird hier nichts: ein Test, der einen
## Prozess anwirft, wäre auf einem Rechner ohne Modell rot und auf einem mit Modell teuer.
func test_the_url_points_at_the_service_the_button_starts() -> void:
	assert_str((_lab.get_node("%ModelUrl") as LineEdit).text) \
			.contains(str(LocalModelServer.DEFAULT_PORT))
	assert_str((_lab.get_node("%ServeButton") as Button).text).contains("starten")


## „Kein Modell" ist keine Auskunft, solange nicht dabeisteht, wo gesucht wurde — und die
## Werkbank sucht woanders als der Entwickler vermutet (`user://`, nicht im Projekt).
func test_the_serve_status_says_where_it_looks() -> void:
	assert_str((_lab.get_node("%ServeStatus") as Label).text).contains("model")


## Die Zeitlimits des KAMPFES sind hier falsch. Der Boss holt vier Sekunden aus; ein
## 1,7-B-Modell auf der CPU ist danach nicht fertig, und die Werkbank meldete dann „kein
## Dienst erreichbar", während der Dienst einwandfrei rechnete. Beurteilt wird hier, ob ein
## Modell die Aufgabe KANN — ob es das rechtzeitig tut, ist eine Frage für den Kampf.
func test_the_lab_waits_longer_than_the_fight_would() -> void:
	var backend: LocalModelBackend = _lab.get("_backend")
	var judge: SentenceJudge = _lab.get("_judge")
	assert_float(backend.http_timeout).is_greater(LocalModelBackend.HTTP_TIMEOUT)
	assert_float(judge.timeout).is_greater(SentenceJudge.DEFAULT_TIMEOUT)
	# Und der Richter muss LÄNGER warten als das Backend: gäbe er früher auf, stünde die
	# Anfrage noch und jede weitere fiele in die Sperre (BUSY_NOTE).
	assert_float(judge.timeout).is_greater(backend.http_timeout)
