class_name LocalModelServer
extends Node
## Startet den lokalen Modelldienst SELBST, statt ihn vorzufinden — der Durchstich zu
## „Stufe 1 muss für Benutzer installierbar sein" (docs/adr/0004-satzbewertung-ohne-modell.md,
## Nachtrag „Stufe 1 auf eigenen Beinen").
##
## Bedient wird `llama-server.exe` aus llama.cpp: ein Programm ohne Abhängigkeiten, MIT,
## das dieselbe OpenAI-Form spricht wie Ollama und LM Studio. Deshalb ändert sich an
## LocalModelBackend nichts — es bekommt nur eine andere `url`.
##
##     user://model/llama-server.exe      das Programm
##     user://model/model.gguf            die Gewichte
##
## Diese beiden Dateien sind das, was später ein optionales Pack mitbringt. Für den
## Durchstich legt man sie von Hand dorthin; der Weg dahin (Download, Signatur, Knopf im
## Einstellungs-Screen) ist ausdrücklich noch nicht gebaut.
##
## **Fehlt etwas, ist das kein Fehler, sondern der Normalfall.** `start()` gibt dann false
## zurück und schreibt in `last_note`, woran es lag — genau wie LocalModelBackend zwischen
## „kein Dienst" und „falsches Modell" unterscheidet. Das Spiel bleibt bei Stufe 0.
##
## **`--host 127.0.0.1` steht ausdrücklich in den Argumenten**, obwohl llama-server ohnehin
## so vorbelegt ist. Eine Voreinstellung kann sich ändern; die Entscheidung, dass
## Kindertexte diesen Rechner nicht verlassen, soll man in der Argumentliste lesen können.

## Wo Programm und Gewichte liegen. `user://`, weil `res://` im Export nur lesbar ist und
## ein heruntergeladener Pack ohnehin dorthin ausgepackt wird.
const DEFAULT_DIR := "user://model"
const EXE_NAME := "llama-server.exe"
const WEIGHTS_NAME := "model.gguf"

## Nicht 8080: das ist der Port, auf dem erfahrungsgemäß schon etwas anderes lauscht.
## 11435 liegt neben Ollamas 11434 und sagt damit auch, was hier läuft.
const DEFAULT_PORT := 11435

## Wie viel Zusammenhang das Modell bekommt. Der Auftrag aus `LocalModelBackend.prompt_for`
## ist ein paar Zeilen lang — mehr Kontext kostet nur Speicher.
const DEFAULT_CONTEXT := 2048

## Wie lange auf „bereit" gewartet wird. Großzügig, denn hier lädt ein Gigabyte von der
## Platte in den Arbeitsspeicher; das ist die Wartezeit EINMAL beim Start und nicht die
## je Frage. Das Zeitlimit im Kampf ist ein anderes (SentenceJudge.DEFAULT_TIMEOUT).
const READY_TIMEOUT := 180.0
const POLL_INTERVAL := 0.5

var dir := DEFAULT_DIR
var port := DEFAULT_PORT
var context_size := DEFAULT_CONTEXT
var ready_timeout := READY_TIMEOUT

## Ob llama-server sein eigenes Fenster bekommt. Er schreibt SEIN Log dorthin und nirgends
## sonst — ohne Konsole verschwindet es, und „passen die Gewichte?" bleibt eine Vermutung,
## die nirgends nachzulesen ist. In einer Werkbank will man dieses Fenster; im Spiel wäre
## es ein zweites, das der Spieler nicht bestellt hat. Deshalb aus, und die Werkbank setzt es.
var show_console := false

## Woran es beim letzten Mal lag, im Klartext — leer, solange alles in Ordnung war.
var last_note := ""

var _pid := -1
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	# Kurz: die Gesundheitsabfrage geht an einen Port auf diesem Rechner. Antwortet dort
	# nichts, soll sie schnell wiederkommen und nicht die Startschleife aufhalten.
	_http.timeout = 2.0
	add_child(_http)


## Ein gestarteter Dienst darf diesen Knoten nicht überleben. Ohne das bliebe nach einem
## Messlauf ein llama-server im Speicher stehen, und der nächste Lauf fände den Port belegt.
func _exit_tree() -> void:
	stop()


func exe_path() -> String:
	return dir.path_join(EXE_NAME)


func weights_path() -> String:
	return dir.path_join(WEIGHTS_NAME)


## Die Adresse, die LocalModelBackend bekommt.
func url() -> String:
	return "http://127.0.0.1:%d/v1/chat/completions" % port


## llama-server meldet hier 200, sobald die Gewichte geladen sind, und 503, solange nicht.
func health_url() -> String:
	return "http://127.0.0.1:%d/health" % port


## Was von den beiden Dateien fehlt. Leer heißt: es ist etwas installiert.
func missing_files() -> PackedStringArray:
	return missing_in(dir)


## Dasselbe ohne Instanz — `ModelService` fragt danach, bevor es überhaupt einen Dienst gibt.
static func missing_in(dir: String) -> PackedStringArray:
	var missing := PackedStringArray()
	if not FileAccess.file_exists(dir.path_join(EXE_NAME)):
		missing.append(EXE_NAME)
	if not FileAccess.file_exists(dir.path_join(WEIGHTS_NAME)):
		missing.append(WEIGHTS_NAME)
	return missing


## Die Argumentliste — statisch und damit ohne Programm prüfbar, wie der Prompt-Bau in
## LocalModelBackend.
static func arguments(weights: String, port: int, context_size: int) -> PackedStringArray:
	return PackedStringArray([
		"--model", weights,
		"--host", "127.0.0.1",
		"--port", str(port),
		"--ctx-size", str(context_size),
	])


func running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


## Startet den Dienst und wartet, bis er antwortet. Gibt false zurück, wenn er nicht kommt
## — dann steht der Grund in `last_note` und der Aufrufer bleibt bei Stufe 0.
func start() -> bool:
	if running():
		return true
	last_note = ""
	var missing := missing_files()
	if not missing.is_empty():
		return _note("Kein Modell in %s — es fehlt: %s" % [
				ProjectSettings.globalize_path(dir), ", ".join(missing)])
	var exe := ProjectSettings.globalize_path(exe_path())
	var args := arguments(ProjectSettings.globalize_path(weights_path()), port, context_size)
	# Der ganze Aufruf in die Ausgabe: er ist das, was man beim Suchen von Hand nachspielt.
	print("LocalModelServer: starte %s %s" % [exe, " ".join(args)])
	_pid = OS.create_process(exe, args, show_console)
	if _pid <= 0:
		_pid = -1
		return _note("%s ließ sich nicht starten" % exe)
	print("LocalModelServer: pid %d, warte auf %s" % [_pid, health_url()])
	return await _wait_until_ready()


## Beendet den Dienst. Mehrfach aufrufbar; ein nie gestarteter Dienst tut hier nichts.
func stop() -> void:
	if _pid <= 0:
		return
	if OS.is_process_running(_pid):
		print("LocalModelServer: beende pid %d" % _pid)
		OS.kill(_pid)
	_pid = -1


func _wait_until_ready() -> bool:
	var deadline := Time.get_ticks_msec() + int(ready_timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if not OS.is_process_running(_pid):
			# Gestartet und gleich wieder weg: fast immer die Gewichte, die nicht zu
			# diesem Programm passen. Warum genau, steht in SEINER Ausgabe — die gibt es
			# nur mit `show_console`, und deshalb steht der Hinweis darauf hier.
			_pid = -1
			return _note("llama-server hat sich sofort beendet — passen die Gewichte?"
					+ " (sein eigenes Log gibt es mit show_console = true)")
		if await _healthy():
			print("LocalModelServer: bereit auf %s" % url())
			return true
		await get_tree().create_timer(POLL_INTERVAL).timeout
	stop()
	return _note("llama-server war nach %.0f s noch nicht bereit" % ready_timeout)


## Setzt den Grund UND schreibt ihn in die Ausgabe — und gibt false zurück, weil jeder
## Aufrufer das gerade tun will. Beides ist nötig: `last_note` steht in der Werkbank am
## Bildrand, aber wer hinterher im Log nachsieht, fand dort bisher gar nichts. Kein
## `push_warning`: ein fehlendes Modell ist hier der Normalfall und kein Fehler.
func _note(text: String) -> bool:
	last_note = text
	print("LocalModelServer: %s" % text)
	return false


func _healthy() -> bool:
	if _http == null or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return false
	if _http.request(health_url()) != OK:
		return false
	var result: Array = await _http.request_completed
	return int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200
