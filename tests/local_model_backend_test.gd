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


## Das Modell bewertet nicht auf freiem Feld: es bekommt den Schlüssel mit. Das ist der
## Unterschied zwischen „übersetze das mal" und „ist das auch richtig" — und die Frage,
## die ein kleines Modell noch beantworten kann.
func test_the_prompt_carries_the_key() -> void:
	var prompt := LocalModelBackend.prompt_for(SENTENCE, "The reef, we saw it yesterday.")
	assert_str(prompt).contains("Gestern haben wir das Riff gesehen.")
	assert_str(prompt).contains("Yesterday we saw the reef.")
	assert_str(prompt).contains("We saw the reef yesterday.")
	assert_str(prompt).contains("The reef, we saw it yesterday.")


## Und es bekommt die Haltung mit, um die es in diesem ADR geht.
func test_the_prompt_asks_for_mercy() -> void:
	assert_str(LocalModelBackend.prompt_for(SENTENCE, "egal")).contains("abzulehnen ist schlimmer")


func test_a_clean_reply_is_read() -> void:
	var reply := LocalModelBackend.parse_content('{"quality": 0.9, "feedback": "Passt."}')
	assert_float(float(reply["quality"])).is_equal(0.9)
	assert_str(str(reply["feedback"])).is_equal("Passt.")


## Kleine Modelle schreiben gern noch etwas davor oder legen einen Codeblock darum.
func test_a_chatty_reply_is_read_too() -> void:
	var reply := LocalModelBackend.parse_content(
			"Klar! ```json\n{\"quality\": 0.8, \"feedback\": \"Fast.\"}\n``` Viel Erfolg!")
	assert_float(float(reply["quality"])).is_equal(0.8)


## Alles, was nicht passt, ist hier kein Fehlerfall, sondern ein Modell ohne Beitrag —
## und damit dasselbe wie „kein Modell da".
func test_anything_else_is_simply_no_contribution() -> void:
	assert_dict(LocalModelBackend.parse_content("Da bin ich mir nicht sicher.")).is_empty()
	assert_dict(LocalModelBackend.parse_content('{"feedback": "ohne Urteil"}')).is_empty()
	assert_dict(LocalModelBackend.parse_reply("<html>404</html>")).is_empty()
	assert_dict(LocalModelBackend.parse_reply('{"choices": []}')).is_empty()


func test_the_openai_envelope_is_unwrapped() -> void:
	var body := JSON.stringify({
		"choices": [{"message": {"content": '{"quality": 1.0, "feedback": "Richtig."}'}}],
	})
	assert_float(float(LocalModelBackend.parse_reply(body)["quality"])).is_equal(1.0)


## Eine Güte außerhalb von 0..1 wäre ein Schaden, der bis in die Anzeige durchschlägt.
func test_the_quality_stays_in_range() -> void:
	assert_float(float(LocalModelBackend.parse_content('{"quality": 7}')["quality"])).is_equal(1.0)
	assert_float(float(LocalModelBackend.parse_content('{"quality": -3}')["quality"])).is_equal(0.0)


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
	assert_str(backend.last_note).contains("ohne verwertbares Urteil")
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
				"content": '{"quality": 0.9, "feedback": "Passt."}'}}]}).to_utf8_buffer())
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
