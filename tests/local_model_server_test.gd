extends GdUnitTestSuite
## Der selbst gestartete Modelldienst, soweit er ohne das Programm prüfbar ist
## (src/learning/local_model_server.gd).
##
## Kein Test startet einen Prozess und keiner spricht mit 127.0.0.1: `llama-server.exe`
## und die Gewichte liegen in keinem Repo (zusammen über ein Gigabyte), und ein Test, der
## sie bräuchte, wäre auf jedem anderen Rechner rot. Geprüft wird deshalb das, was auch
## ohne sie eine Aussage ist: die Argumentliste, die Adressen und der Weg, auf dem ein
## fehlendes Modell zu einer Auskunft wird statt zu einem Absturz.

var _server: LocalModelServer


func before_test() -> void:
	_server = auto_free(LocalModelServer.new())
	add_child(_server)


## Kindertexte verlassen diesen Rechner nicht. Das steht im Prompt-Pfad (LocalModelBackend)
## und muss auch dort stehen, wo der Dienst SELBST gestartet wird — dort entscheidet ein
## Argument darüber, ob er von außen erreichbar ist.
func test_the_service_listens_only_on_this_machine() -> void:
	var args := LocalModelServer.arguments("C:/irgendwo/model.gguf", 11435, 2048)
	assert_array(args).contains(["--host", "127.0.0.1"])
	assert_str(_server.url()).starts_with("http://127.0.0.1:")
	assert_str(_server.health_url()).starts_with("http://127.0.0.1:")


func test_the_arguments_name_weights_port_and_context() -> void:
	var args := LocalModelServer.arguments("C:/irgendwo/model.gguf", 11435, 2048)
	assert_array(args).contains(["--model", "C:/irgendwo/model.gguf"])
	assert_array(args).contains(["--port", "11435"])
	assert_array(args).contains(["--ctx-size", "2048"])


## Gemma denkt ohne `--reasoning off` im Klartext und erreicht das JSON nie; so wurde in
## der Werkstatt gemessen (ADR 0005).
func test_the_service_runs_as_measured() -> void:
	var args := LocalModelServer.arguments("C:/irgendwo/model.gguf", 11435, 4096)
	assert_array(args).contains(["--jinja"])
	assert_array(args).contains(["--reasoning", "off"])


## Das Backend fragt ohne weitere Einstellung den Dienst, den das Spiel selbst startet.
func test_the_backend_asks_our_own_service() -> void:
	assert_str(LocalModelBackend.URL).is_equal(_server.url())


## Beide Adressen müssen auf denselben Dienst zeigen — sonst fragt die Messung den einen
## Port nach seinem Zustand und den anderen nach einem Urteil.
func test_both_addresses_share_the_port() -> void:
	_server.port = 12345
	assert_str(_server.url()).contains(":12345/")
	assert_str(_server.health_url()).contains(":12345/")


## Der Normalfall auf einem Rechner ohne Zusatz: nichts installiert. Das ist kein Fehler,
## sondern eine Auskunft — und sie nennt BEIDE fehlenden Dateien, damit man nicht zweimal
## sucht.
func test_a_missing_model_is_an_answer_and_not_a_crash() -> void:
	_server.dir = "user://zz-gibt-es-nicht"
	var missing := _server.missing_files()
	assert_array(missing).contains([LocalModelServer.EXE_NAME, LocalModelServer.WEIGHTS_NAME])
	assert_bool(await _server.start()).is_false()
	assert_str(_server.last_note).contains(LocalModelServer.EXE_NAME)
	assert_str(_server.last_note).contains(LocalModelServer.WEIGHTS_NAME)
	assert_bool(_server.running()).is_false()


## Die Auskunft sagt auch, WO gesucht wurde. Ohne das ist „kein Modell installiert" die
## Aufforderung, den Quelltext zu lesen.
func test_the_note_names_the_place_it_looked() -> void:
	_server.dir = "user://zz-gibt-es-nicht"
	await _server.start()
	assert_str(_server.last_note).contains("zz-gibt-es-nicht")


## Abräumen muss man auch dürfen, wenn nie etwas lief — der Messlauf tut das am Ende
## bedingungslos, und ein Durchstich, der beim Aufräumen abstürzt, hat nichts bewiesen.
func test_stopping_what_never_ran_is_allowed() -> void:
	_server.stop()
	_server.stop()
	assert_bool(_server.running()).is_false()


## Die Dateien liegen unter user://, nicht unter res://: im Export ist res:// nur lesbar,
## und ein heruntergeladenes Modell muss irgendwo landen können.
func test_the_model_lives_where_the_game_may_write() -> void:
	assert_str(LocalModelServer.DEFAULT_DIR).starts_with("user://")
	assert_str(_server.exe_path()).starts_with("user://")
	assert_str(_server.weights_path()).starts_with("user://")
