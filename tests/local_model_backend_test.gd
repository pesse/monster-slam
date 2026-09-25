extends GdUnitTestSuite
## Stufe 1, soweit sie ohne Dienst prüfbar ist: der Auftrag an das Modell und das, was von
## seiner Antwort ankommt (src/learning/local_model_backend.gd).
##
## Kein Test spricht mit 127.0.0.1. Stufe 1 ist nicht Teil der Auslieferung, und ein Test,
## der einen laufenden Dienst braucht, wäre auf jedem anderen Rechner rot.

const SENTENCE := {
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"accepted": ["We saw the reef yesterday."],
}


## Aufruf 1 urteilt mit dem Schlüssel: Musterlösung, Alternativen und die Antwort stehen
## im Auftrag. Das ist die Frage, die ein kleines Modell noch beantworten kann.
func test_the_verdict_carries_the_key() -> void:
	var messages := StageOnePrompts.verdict_messages(SENTENCE, "The reef, we saw it yesterday.")
	assert_array(messages).has_size(2)
	assert_str(str(messages[0]["role"])).is_equal("system")
	var user := str(messages[1]["content"])
	assert_str(user).contains("Gestern haben wir das Riff gesehen.")
	assert_str(user).contains("Yesterday we saw the reef.")
	assert_str(user).contains("We saw the reef yesterday.")
	assert_str(user).contains("The reef, we saw it yesterday.")
	assert_str(user).not_contains("{{")


## Ein leeres Feld im Schlüssel bekommt den Gedankenstrich wie in der Werkstatt — ein
## leerer Platz nach dem Doppelpunkt lädt das Modell ein, ihn zu füllen.
func test_an_empty_key_field_is_a_dash() -> void:
	var user := str(StageOnePrompts.verdict_messages(
			{"source_text": "x", "reference_translation": "y"}, "z")[1]["content"])
	assert_str(user).contains("also accepted: —")
	assert_str(user).contains("required words: —")


## Die geforderten Wörter stehen mit ihren Formen im Auftrag: Formen mit „/",
## Forderungen mit „, ".
func test_required_words_list_their_forms() -> void:
	var sentence := {"must_contain": [
		{"lexeme_id": "lex.test.a", "forms": ["see", "saw"]},
		{"lexeme_id": "lex.test.b", "forms": ["reef"]},
	]}
	assert_str(StageOnePrompts.required_words(sentence)).is_equal("see/saw, reef")


## Aufruf 2 bekommt KEINEN Schlüssel außer der Musterlösung — sonst redete er über den
## Schlüssel und urteilte nicht unabhängig von Aufruf 1. Dafür die Regeln zu den Tags.
func test_the_explainer_gets_rules_but_no_key() -> void:
	var sentence := SENTENCE.duplicate()
	sentence["grammar_tags"] = ["simple_past"]
	var user := str(StageOnePrompts.explain_messages(sentence, "We have seen it.")[1]["content"])
	assert_str(user).contains("Yesterday we saw the reef.")
	assert_str(user).not_contains("We saw the reef yesterday.")
	assert_str(user).contains(GrammarRules.rule_for("past_simple"))
	assert_str(user).contains("We have seen it.")


## Der Rumpf schickt kein response_format mit: gemessen wurde ohne.
func test_the_request_is_the_measured_one() -> void:
	var body: Dictionary = JSON.parse_string(LocalModelBackend.request_body(
			StageOnePrompts.verdict_messages(SENTENCE, "x"), "gemma"))
	assert_float(float(body["temperature"])).is_equal(0.0)
	assert_bool(body.has("response_format")).is_false()
	assert_array(body["messages"]).has_size(2)


func test_a_clean_verdict_is_read() -> void:
	var reply := LocalModelBackend.parse_verdict(
			'{"verdict": "correct", "reason": "Andere Wörter, gleiche Aussage."}')
	assert_float(float(reply["quality"])).is_equal(LocalModelBackend.CORRECT_QUALITY)
	assert_str(str(reply["verdict"])).is_equal("correct")
	assert_str(str(reply["feedback"])).is_equal("Andere Wörter, gleiche Aussage.")
	var no := LocalModelBackend.parse_verdict('{"verdict": "Incorrect", "reason": "x"}')
	assert_float(float(no["quality"])).is_equal(LocalModelBackend.INCORRECT_QUALITY)


## Kleine Modelle schreiben gern etwas davor, legen einen Codeblock darum oder hängen ein
## zweites Objekt an. Das erste zählt.
func test_a_chatty_reply_is_read_too() -> void:
	var fenced := LocalModelBackend.parse_verdict(
			"Klar! ```json\n{\"verdict\": \"correct\", \"reason\": \"Gut.\"}\n``` Viel Erfolg!")
	assert_str(str(fenced["verdict"])).is_equal("correct")
	var twice := LocalModelBackend.parse_verdict(
			'{"verdict": "incorrect", "reason": "a"}\n{"verdict": "correct", "reason": "b"}')
	assert_str(str(twice["verdict"])).is_equal("incorrect")


## Alles, was nicht passt, ist hier kein Fehlerfall, sondern ein Modell ohne Beitrag —
## und damit dasselbe wie „kein Modell da".
func test_anything_else_is_simply_no_contribution() -> void:
	assert_dict(LocalModelBackend.parse_verdict("Da bin ich mir nicht sicher.")).is_empty()
	assert_dict(LocalModelBackend.parse_verdict('{"reason": "ohne Urteil"}')).is_empty()
	assert_dict(LocalModelBackend.parse_verdict('{"verdict": "maybe"}')).is_empty()
	assert_str(LocalModelBackend.content_of("<html>404</html>")).is_empty()
	assert_str(LocalModelBackend.content_of('{"choices": []}')).is_empty()


func test_the_openai_envelope_is_unwrapped() -> void:
	var body := JSON.stringify({
		"choices": [{"message": {"content": '{"verdict": "correct", "reason": "Richtig."}'}}],
	})
	assert_str(LocalModelBackend.content_of(body)).contains('"verdict"')


func test_an_explanation_is_read() -> void:
	var reply := LocalModelBackend.parse_explanation(
			'{"mistake": true, "explanation": "Mit ‚yesterday‘ steht das Simple Past."}')
	assert_bool(bool(reply["mistake"])).is_true()
	assert_str(str(reply["explanation"])).contains("Simple Past")


## „Kein Fehler" hat keine Erklärung, auch wenn das Modell trotzdem etwas hinschreibt —
## und „Fehler" ohne Erklärung ist keiner, sonst stünde „falsch, weil:" vor nichts.
func test_an_explanation_needs_a_mistake_and_words() -> void:
	var none := LocalModelBackend.parse_explanation('{"mistake": false, "explanation": "Gut so."}')
	assert_bool(bool(none["mistake"])).is_false()
	assert_str(str(none["explanation"])).is_empty()
	var mute := LocalModelBackend.parse_explanation('{"mistake": true, "explanation": ""}')
	assert_bool(bool(mute["mistake"])).is_false()
	assert_dict(LocalModelBackend.parse_explanation('{"explanation": "x"}')).is_empty()


## Das Ziel steht fest und ist keine Einstellung: Kindertexte gehen nicht ins Netz.
func test_stage_one_talks_to_this_machine_only() -> void:
	assert_str(LocalModelBackend.URL).contains("127.0.0.1")


## Die Diagnose-Naht: für das Spiel ist „kein Dienst" dasselbe wie „Modell ohne Beitrag"
## (beide Male {} und damit die Rückmeldung der Prüfkarte), beim Messen und in der
## Werkbank ist es der Unterschied zwischen „nichts installiert" und „falsches Modell".
## Ohne sie stünde in beiden Fällen derselbe Satz und man suchte am falschen Ende.
func test_a_dead_service_and_a_babbling_model_are_told_apart() -> void:
	var backend: LocalModelBackend = auto_free(LocalModelBackend.new())
	add_child(backend)

	backend._on_completed(
			HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	assert_str(backend.last_note).contains("Kein Dienst")

	backend._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
			'{"choices":[{"message":{"content":"Da bin ich mir nicht sicher."}}]}'.to_utf8_buffer())
	assert_str(backend.last_note).contains("ohne verwertbares Ergebnis")
	assert_str(backend.last_note).contains("Da bin ich mir nicht sicher.")

	backend._on_completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(),
			"model not found".to_utf8_buffer())
	assert_str(backend.last_note).contains("HTTP 404")


## Und sie bleibt nicht stehen: eine brauchbare Antwort löscht die Klage der vorigen.
func test_a_usable_reply_clears_the_note() -> void:
	var backend: LocalModelBackend = auto_free(LocalModelBackend.new())
	add_child(backend)
	backend._on_completed(
			HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	backend._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
			JSON.stringify({"choices": [{"message": {
				"content": '{"verdict": "correct", "reason": "Passt."}'}}]}).to_utf8_buffer())
	assert_str(backend.last_note).is_empty()


## Eine Anfrage zur Zeit — aber nicht stumm. Gibt SentenceJudge früher auf, als
## HTTP_TIMEOUT lang ist, steht die erste Anfrage noch, und jede weitere fällt hierher.
## Ohne die Begründung sähe das aus wie „kein Dienst", und eine Messung hätte 24 von 25
## Antworten nie gestellt, ohne dass es irgendwo stünde.
func test_a_question_asked_over_an_open_one_says_so() -> void:
	var backend: LocalModelBackend = auto_free(LocalModelBackend.new())
	add_child(backend)
	assert_bool(backend.busy()).is_false()

	# Eine offene Anfrage, ohne dafür mit 127.0.0.1 zu sprechen.
	backend._on_done = func(_reply: Dictionary) -> void: pass
	assert_bool(backend.busy()).is_true()

	var answered: Array = []
	backend.judge({}, "irgendwas", func(reply: Dictionary): answered.append(reply))
	assert_array(answered).has_size(1)
	assert_dict(answered[0]).is_empty()
	assert_str(backend.last_note).is_equal(LocalModelBackend.BUSY_NOTE)
