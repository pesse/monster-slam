class_name LocalModelServer
extends Node
## Startet den lokalen Modelldienst `llama-server.exe` (llama.cpp) aus
## `user://model/` (`llama-server.exe` und `model.gguf`; ADR 0004, Nachtrag „Stufe 1 auf
## eigenen Beinen“). Fehlt etwas, gibt `start()` false zurück und nennt den Grund in
## `last_note`; das Spiel bleibt bei Stufe 0. `--host 127.0.0.1` steht ausdrücklich in den
## Argumenten: Kindertexte verlassen den Rechner nicht.

## Wo Programm und Gewichte liegen.
const DEFAULT_DIR := "user://model"
const EXE_NAME := "llama-server.exe"
const WEIGHTS_NAME := "model.gguf"

## Neben Ollamas 11434.
const DEFAULT_PORT := 11435

## Kontextlänge in Token; die Aufträge aus StageOnePrompts bleiben unter 1000.
const DEFAULT_CONTEXT := 4096

## Wartezeit auf „bereit“ beim Start (s); die Gewichte laden von der Platte.
const READY_TIMEOUT := 180.0
## Abstand der Gesundheitsabfragen (s).
const POLL_INTERVAL := 0.5
## Zeitlimit einer Gesundheitsabfrage (s); kurz, damit die Startschleife nicht hängt.
const HEALTH_TIMEOUT := 2.0

var dir := DEFAULT_DIR
var port := DEFAULT_PORT
var context_size := DEFAULT_CONTEXT
var ready_timeout := READY_TIMEOUT

## Ob llama-server ein eigenes Konsolenfenster bekommt; nur dort steht sein Log.
var show_console := false

## Woran es beim letzten Mal lag, im Klartext; leer, solange alles in Ordnung war.
var last_note := ""

var _pid := -1
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = HEALTH_TIMEOUT
	add_child(_http)


## Ein gestarteter Dienst darf diesen Knoten nicht überleben (sonst bleibt der Port belegt).
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


## Dasselbe ohne Instanz.
static func missing_in(dir: String) -> PackedStringArray:
	var missing := PackedStringArray()
	if not FileAccess.file_exists(dir.path_join(EXE_NAME)):
		missing.append(EXE_NAME)
	if not FileAccess.file_exists(dir.path_join(WEIGHTS_NAME)):
		missing.append(WEIGHTS_NAME)
	return missing


## Die Argumentliste. `--jinja` und `--reasoning off` sind die gemessene Einstellung; ohne
## sie denkt Gemma im Klartext und liefert kein JSON (ADR 0005).
static func arguments(weights: String, port: int, context_size: int) -> PackedStringArray:
	return PackedStringArray([
		"--model", weights,
		"--host", "127.0.0.1",
		"--port", str(port),
		"--ctx-size", str(context_size),
		"--jinja",
		"--reasoning", "off",
	])


func running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


## Startet den Dienst und wartet, bis er antwortet. Sonst false, Grund in `last_note`.
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
			# Gleich wieder weg: meist passen die Gewichte nicht zum Programm.
			_pid = -1
			return _note("llama-server hat sich sofort beendet — passen die Gewichte?"
					+ " (sein eigenes Log gibt es mit show_console = true)")
		if await _healthy():
			print("LocalModelServer: bereit auf %s" % url())
			return true
		await get_tree().create_timer(POLL_INTERVAL).timeout
	stop()
	return _note("llama-server war nach %.0f s noch nicht bereit" % ready_timeout)


## Setzt `last_note`, schreibt den Grund in die Ausgabe und gibt false zurück. Kein
## `push_warning`: ein fehlendes Modell ist der Normalfall.
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
