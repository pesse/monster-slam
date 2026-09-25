extends GdUnitTestSuite
## Der Vertrag aus ADR 0004: Stufe 0 antwortet immer und sofort, Stufe 1 ist optional,
## und keine von beiden blockiert (src/learning/sentence_judge.gd).
##
## Stufe 1 wird hier von einem erfundenen Backend gespielt. Ein echtes Modell im Test wäre
## das Gegenteil dessen, was das ADR entscheidet — und ein Test, der eine Antwort von
## 127.0.0.1 braucht, ist auf jedem anderen Rechner rot.

const SENTENCE := {
	"id": "sen.test.reef",
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"pitfalls": [{"contains": ["have seen", "yesterday"], "feedback": "Simple Past."}],
}

var _judge: SentenceJudge
var _refined: Array = []
var _denied: Array = []
var _explained: Array = []
var _gave_up := 0
## Der letzte Rückruf, den das erfundene Backend bekommen hat — damit ein Test die Antwort
## des Modells zu einem beliebigen Zeitpunkt eintreffen lassen kann.
var _reply_to: Callable = Callable()
var _asked := 0
var _explain_to: Callable = Callable()
var _explain_asked := 0


func before_test() -> void:
	_judge = auto_free(SentenceJudge.new())
	add_child(_judge)
	_refined = []
	_denied = []
	_explained = []
	_gave_up = 0
	_asked = 0
	_explain_asked = 0
	_reply_to = Callable()
	_explain_to = Callable()
	_judge.refined.connect(func(result: Dictionary): _refined.append(result))
	_judge.denied.connect(func(result: Dictionary): _denied.append(result))
	_judge.explained.connect(func(result: Dictionary): _explained.append(result))
	_judge.gave_up.connect(func(): _gave_up += 1)


## Ein Backend, das nicht von selbst antwortet — der Test bestimmt, wann und was.
func _backend(_sentence: Dictionary, _answer: String, on_done: Callable) -> void:
	_asked += 1
	_reply_to = on_done


## Der Erklärer, ebenso erfunden.
func _explainer(_sentence: Dictionary, _answer: String, on_done: Callable) -> void:
	_explain_asked += 1
	_explain_to = on_done


func test_stage_zero_answers_right_away() -> void:
	var result := _judge.judge(SENTENCE, "Yesterday we saw the reef.")
	assert_float(float(result["quality"])).is_equal(SentenceCard.MATCH_QUALITY)
	assert_str(str(result["stage"])).is_equal(SentenceCard.STAGE)


## Ohne Stufe 1 ist nach Stufe 0 Schluss — und zwar ohne dass ein Aufrufer davon weiß.
func test_without_a_backend_nothing_stays_open() -> void:
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	assert_bool(_judge.pending()).is_false()


## Gefragt wird nur, wo die Karte zweifelt. Ein Treffer ist ein Urteil; ein Modell, das
## darauf noch etwas zu sagen hätte, könnte es nur verschlimmern.
func test_the_model_is_not_asked_when_the_card_is_sure() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "Yesterday we saw the reef.")
	assert_int(_asked).is_equal(0)
	_judge.judge(SENTENCE, "Yesterday we have seen the reef.")
	assert_int(_asked).is_equal(0)
	assert_bool(_judge.pending()).is_false()


func test_the_model_is_asked_when_the_card_is_unsure() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	assert_int(_asked).is_equal(1)
	assert_bool(_judge.pending()).is_true()


## Das ist der Sinn von Stufe 1: eine Formulierung durchlassen, die im Schlüssel fehlt.
func test_stage_one_may_lift() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 0.95, "feedback": "Ungewöhnlich gebaut, aber richtig."})
	assert_int(_refined.size()).is_equal(1)
	assert_float(float(_refined[0]["quality"])).is_equal(0.95)
	assert_str(str(_refined[0]["stage"])).is_equal("model")
	assert_str(str(_refined[0]["feedback"])).is_equal("Ungewöhnlich gebaut, aber richtig.")
	assert_bool(_judge.pending()).is_false()


## Und das ist die Grenze: ein kleines Modell lehnt richtige Antworten ab. Sein Urteil
## „falsch" senkt nichts — die Güte bleibt die der Karte, und auch seine Begründung bleibt
## draußen: sie ist mit dem Schlüssel vor Augen geschrieben (ADR 0005). Was falsch ist,
## sagt erst der Erklärer.
##
## Gefragt wird Stufe 1 nur, wo die Karte KEIN Urteil hat (Güte 0, SentenceCard.NO_VERDICT).
## Damit ist „senken" dort gar nicht mehr möglich, und die Regel wird zu ihrer schärferen
## Fassung: ohne eine Anhebung bleibt die Antwort kein Treffer.
func test_stage_one_may_never_lower() -> void:
	_judge.model_backend = _backend
	var card := _judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	assert_float(float(card["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_bool(bool(card["sure"])).is_false()
	_reply_to.call({"quality": 0.0, "verdict": "incorrect", "feedback": "Falsch."})
	assert_array(_refined).is_empty()
	assert_int(_gave_up).is_equal(0)
	assert_int(_denied.size()).is_equal(1)
	assert_float(float(_denied[0]["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_bool(bool(_denied[0]["sure"])).is_true()
	assert_str(str(_denied[0]["stage"])).is_equal("model")
	assert_str(str(_denied[0]["feedback"])).is_equal(str(card["feedback"]))


## Nach „falsch" erklärt der zweite Aufruf, und seine Erklärung ersetzt die Rückmeldung.
func test_a_denial_is_explained() -> void:
	_judge.model_backend = _backend
	_judge.explainer = _explainer
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 0.0, "verdict": "incorrect"})
	assert_bool(_judge.explaining()).is_true()
	await get_tree().process_frame
	assert_int(_explain_asked).is_equal(1)
	_explain_to.call({"mistake": true, "explanation": "Mit yesterday: Simple Past."})
	assert_int(_explained.size()).is_equal(1)
	assert_str(str(_explained[0]["explanation"])).is_equal("Mit yesterday: Simple Past.")
	assert_str(str(_explained[0]["feedback"])).is_equal("Mit yesterday: Simple Past.")
	assert_float(float(_explained[0]["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_bool(_judge.explaining()).is_false()


## Findet der Erklärer keinen Fehler, gibt es keine Erklärung — der Fall, in dem Aufruf 1
## eine richtige Antwort abgewiesen hat. Es kommt trotzdem ein `explained`, damit niemand
## auf etwas wartet, das nicht kommt.
func test_no_mistake_found_means_no_explanation() -> void:
	_judge.model_backend = _backend
	_judge.explainer = _explainer
	var card := _judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 0.0, "verdict": "incorrect"})
	await get_tree().process_frame
	_explain_to.call({"mistake": false, "explanation": ""})
	assert_int(_explained.size()).is_equal(1)
	assert_str(str(_explained[0]["explanation"])).is_empty()
	assert_str(str(_explained[0]["feedback"])).is_equal(str(card["feedback"]))


## Ein Treffer braucht keine Erklärung.
func test_a_lift_is_not_explained() -> void:
	_judge.model_backend = _backend
	_judge.explainer = _explainer
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 1.0, "verdict": "correct"})
	await get_tree().process_frame
	assert_int(_explain_asked).is_equal(0)
	assert_array(_explained).is_empty()


## Eine Erklärung zu einer älteren Antwort ist keine — der Spieler ist schon weiter.
func test_a_late_explanation_is_dropped() -> void:
	_judge.model_backend = _backend
	_judge.explainer = _explainer
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 0.0, "verdict": "incorrect"})
	await get_tree().process_frame
	var stale := _explain_to
	_judge.judge(SENTENCE, "Yesterday we saw the reef.")
	stale.call({"mistake": true, "explanation": "Zu spät."})
	assert_array(_explained).is_empty()


## Schweigt der Erklärer, endet auch dieses Warten von selbst — mit leerer Erklärung.
func test_a_silent_explainer_runs_into_the_timeout() -> void:
	_judge.model_backend = _backend
	_judge.explainer = _explainer
	_judge.timeout = 0.1
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({"quality": 0.0, "verdict": "incorrect"})
	await get_tree().create_timer(0.3).timeout
	assert_bool(_judge.explaining()).is_false()
	assert_int(_explained.size()).is_equal(1)
	assert_str(str(_explained[0]["explanation"])).is_empty()


## „Nichts beizutragen" ist der Normalfall — kein Dienst, kein JSON, kein Urteil.
func test_an_empty_reply_changes_nothing() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_reply_to.call({})
	assert_array(_refined).is_empty()
	assert_int(_gave_up).is_equal(1)


## Im Kampf tippt der Spieler weiter, während das Modell noch rechnet. Eine Antwort auf
## eine ältere Frage ist keine Antwort.
func test_a_late_reply_to_an_old_question_is_dropped() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	var stale := _reply_to
	_judge.judge(SENTENCE, "We were looking at that reef yesterday.")
	stale.call({"quality": 1.0, "feedback": "Zu spät."})
	assert_array(_refined).is_empty()


func test_cancel_closes_the_question() -> void:
	_judge.model_backend = _backend
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	_judge.cancel()
	assert_bool(_judge.pending()).is_false()
	_reply_to.call({"quality": 1.0, "feedback": "Zu spät."})
	assert_array(_refined).is_empty()


## Antwortet niemand, endet das Warten von selbst — der Kampf hängt nicht an einem Modell.
func test_a_silent_model_runs_into_the_timeout() -> void:
	_judge.model_backend = _backend
	_judge.timeout = 0.1
	_judge.judge(SENTENCE, "The reef was what we saw yesterday.")
	assert_bool(_judge.pending()).is_true()
	await get_tree().create_timer(0.3).timeout
	assert_bool(_judge.pending()).is_false()
	assert_int(_gave_up).is_equal(1)
