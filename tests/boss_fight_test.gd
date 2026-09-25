extends GdUnitTestSuite
## Der Bosskampf (scenes/battle/boss_fight.tscn, ADR 0005) — mit erfundenem Boss, erfundenen
## Sätzen und einem erfundenen Stufe-1-Backend. Kein Test startet llama-server.

const SCENE := "res://scenes/battle/boss_fight.tscn"

const BOSS := {"id": "boss.zz_test", "name": "Test-Golem", "hp": 2}

const REEF := {
	"id": "sen.zz.reef",
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"accepted": ["We saw the reef yesterday."],
	"grammar_tags": ["past_simple"],
}
const SCHOOL := {
	"id": "sen.zz.school",
	"source_text": "Sie geht immer zu Fuß zur Schule.",
	"reference_translation": "She always walks to school.",
	"grammar_tags": ["adverb_position"],
}
const BIKE := {
	"id": "sen.zz.bike",
	"source_text": "Wann hast du das Fahrrad gekauft?",
	"reference_translation": "When did you buy the bike?",
	"grammar_tags": ["question"],
}

var _fight: Control
var _verdict_to: Callable = Callable()
var _explain_to: Callable = Callable()
var _asked := 0


func _backend(_sentence: Dictionary, _answer: String, on_done: Callable) -> void:
	_asked += 1
	_verdict_to = on_done


func _explainer(_sentence: Dictionary, _answer: String, on_done: Callable) -> void:
	_explain_to = on_done


## Ein Kampf mit oder ohne erfundenes Modell. Ohne heißt: nur die Prüfkarte.
func _build(with_model: bool, sentences: Array = [REEF, SCHOOL, BIKE]) -> void:
	_asked = 0
	_verdict_to = Callable()
	_explain_to = Callable()
	_fight = auto_free(load(SCENE).instantiate())
	_fight.start_service = false
	if with_model:
		_fight.fake_backend = _backend
		_fight.fake_explainer = _explainer
	add_child(_fight)
	_fight.begin(BOSS, sentences)


func _answer(text: String) -> void:
	(_fight.get_node("%AnswerEdit") as LineEdit).text = text
	(_fight.get_node("%SubmitButton") as Button).pressed.emit()


func _next() -> void:
	(_fight.get_node("%NextButton") as Button).pressed.emit()


func _text(node: String) -> String:
	return (_fight.get_node("%" + node) as Label).text


func test_the_first_sentence_is_on_the_table() -> void:
	_build(false)
	assert_str(_text("SourceText")).is_equal(REEF["source_text"])
	assert_str(_text("HpLabel")).contains("2/2")
	assert_str(_text("RoundLabel")).contains("1 von 3")
	assert_bool((_fight.get_node("%NextButton") as Button).disabled).is_true()


## Ein Treffer der Prüfkarte kostet den Golem 1 HP — sofort, ohne Modell.
func test_a_known_solution_hits() -> void:
	_build(true)
	_answer("We saw the reef yesterday.")
	assert_int(_asked).is_equal(0)
	assert_int(_fight.hp).is_equal(1)
	assert_str(_text("HpLabel")).contains("1/2")
	assert_bool((_fight.get_node("%NextButton") as Button).disabled).is_false()


## Nichts getippt ist kein Versuch: der Satz bleibt, der Golem auch.
func test_an_empty_answer_is_not_a_try() -> void:
	_build(true)
	_answer("   ")
	assert_int(_fight.hp).is_equal(2)
	assert_bool((_fight.get_node("%NextButton") as Button).disabled).is_true()
	assert_int(_asked).is_equal(0)


## Ohne Modell und ohne Schlüsseltreffer gibt es kein Urteil — und ohne Urteil keinen
## Treffer. Die Musterlösung steht da, damit das Kind weiß, was gemeint war.
func test_without_a_model_an_unknown_answer_does_not_hit() -> void:
	_build(false)
	_answer("The reef was seen by us yesterday.")
	assert_int(_fight.hp).is_equal(2)
	assert_str(_text("ReferenceLabel")).contains("Yesterday we saw the reef.")
	assert_bool((_fight.get_node("%NextButton") as Button).disabled).is_false()


## Solange das Modell rechnet, nimmt der Golem keine zweite Antwort an.
func test_the_input_is_locked_while_the_model_thinks() -> void:
	_build(true)
	_answer("Yesterday, we have been at the reef.")
	assert_int(_asked).is_equal(1)
	assert_bool((_fight.get_node("%SubmitButton") as Button).disabled).is_true()
	assert_bool((_fight.get_node("%AnswerEdit") as LineEdit).editable).is_false()
	_answer("noch einmal")
	assert_int(_asked).is_equal(1)


## Das Modell hebt: ein Treffer, den der Schlüssel nicht kannte.
func test_the_model_may_lift_to_a_hit() -> void:
	_build(true)
	_answer("It was yesterday that we saw the reef.")
	_verdict_to.call({"quality": 1.0, "verdict": "correct", "feedback": "Andere Wörter, gleiche Aussage."})
	assert_int(_fight.hp).is_equal(1)


## „Falsch" steht sofort da, und „Weiter" ist schon frei. Rückmeldung und Musterlösung
## kommen erst mit der Erklärung — bis dahin steht keine Rückmeldung der Karte da.
func test_a_denial_is_shown_at_once_and_explained_later() -> void:
	_build(true)
	_answer("Yesterday we seen the reef.")
	_verdict_to.call({"quality": 0.0, "verdict": "incorrect", "feedback": "egal"})
	assert_int(_fight.hp).is_equal(2)
	assert_bool((_fight.get_node("%NextButton") as Button).disabled).is_false()
	assert_str(_text("GolemLine")).is_equal(_fight.EXPLAINING_TEXT)
	# Die Begründung des Urteils wird nie gezeigt — sie ist mit dem Schlüssel geschrieben.
	assert_str(_text("VerdictLabel")).is_empty()
	assert_str(_text("ReferenceLabel")).is_empty()
	await get_tree().process_frame
	_explain_to.call({"mistake": true, "explanation": "„seen“ steht nie allein: „saw“."})
	assert_str(_text("VerdictLabel")).is_equal("Das stimmt noch nicht:")
	assert_str(_text("ExplanationLabel")).is_equal("„seen“ steht nie allein: „saw“.")
	assert_str(_text("ReferenceLabel")).contains("Yesterday we saw the reef.")


## Findet der Erklärer keinen Fehler, steht keine Erklärung da — nur die Musterlösung.
func test_no_mistake_found_shows_only_the_reference() -> void:
	_build(true)
	_answer("The reef was what we saw yesterday.")
	_verdict_to.call({"quality": 0.0, "verdict": "incorrect"})
	await get_tree().process_frame
	_explain_to.call({"mistake": false, "explanation": ""})
	assert_str(_text("ExplanationLabel")).is_empty()
	assert_str(_text("VerdictLabel")).is_empty()
	assert_str(_text("ReferenceLabel")).contains("Yesterday we saw the reef.")


## Zwei Treffer bei 2 HP: der Golem fällt, bevor die Sätze aus sind.
func test_the_golem_can_be_beaten() -> void:
	_build(false)
	_answer("Yesterday we saw the reef.")
	_next()
	_answer("She always walks to school.")
	assert_str((_fight.get_node("%NextButton") as Button).text).is_equal("Ergebnis")
	_next()
	assert_bool(_fight.over()).is_true()
	assert_bool(_fight.won()).is_true()
	assert_str(_text("GolemLine")).is_equal(_fight.WON_TEXT)


## Sind die Sätze aus und der Golem steht noch, zieht er ab — mehr passiert nicht.
func test_the_golem_leaves_when_the_sentences_run_out() -> void:
	_build(false, [REEF, SCHOOL])
	_answer("Yesterday we saw the reef.")
	_next()
	_answer("She walks to school.")
	_next()
	assert_bool(_fight.over()).is_true()
	assert_bool(_fight.won()).is_false()
	assert_str(_text("GolemLine")).is_equal(_fight.LOST_TEXT)
	assert_str((_fight.get_node("%NextButton") as Button).text).is_equal("Noch einmal")


## Ohne passenden Satz beginnt kein Kampf, und die Szene sagt, warum.
func test_an_empty_pool_says_so() -> void:
	_build(false, [])
	assert_bool(_fight.over()).is_true()
	assert_str(_text("GolemLine")).is_equal(_fight.EMPTY_POOL_TEXT)
	assert_bool((_fight.get_node("%SubmitButton") as Button).disabled).is_true()


## Die Szene passt in das kleinste Fenster (1152×648), in jedem Zustand. Je Achse geprüft —
## is_less_equal auf Vector2 vergleicht lexikografisch.
func test_it_fits_the_smallest_window_in_every_state() -> void:
	_build(true)
	var margin := _fight.get_node("Margin") as Control
	_assert_fits(margin)
	_answer("Yesterday we seen the reef.")
	_verdict_to.call({"quality": 0.0, "verdict": "incorrect"})
	await get_tree().process_frame
	_explain_to.call({"mistake": true, "explanation": "Eine lange Erklärung. ".repeat(30)})
	await get_tree().process_frame
	_assert_fits(margin)


func _assert_fits(margin: Control) -> void:
	var need := margin.get_combined_minimum_size()
	assert_float(need.x).is_less_equal(1152.0)
	assert_float(need.y).is_less_equal(648.0)
