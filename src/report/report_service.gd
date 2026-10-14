extends Node
## Autoload `ReportService`: der Melde-Kanal zurück zum Content-Autor (ADR 0002, 0022).
## Gemeldet wird erst lokal (LexemeFlags), gesendet danach; eine nicht zustellbare Meldung
## bleibt offen. Ohne Endpunkt und App-Schlüssel ist der Kanal aus und „Melden“ unsichtbar.

## Zustand hat sich geändert. Empfänger lesen `state` und `error`.
signal changed

enum State {
	IDLE,        ## Nichts zu tun
	SENDING,     ## Offene Meldungen gehen raus
	ERROR,       ## Benannter Fehlschlag; `error` trägt den Text
}

## Vom Export geschrieben (`tools/stats/write_key.sh`), nicht im Repo: der App-Schlüssel
## des Statistik-Kanals und `[report] url=…`. Die URL ist kein Geheimnis; Größe und Rate
## begrenzt der Endpunkt.
const KEY_PATH := "res://stats_key.cfg"

## Größenschranke einer Antwort in Bytes, gegen falsch geroutete Antworten.
const MAX_RESPONSE_BYTES := 8 * 1024

const TIMEOUT_SECONDS := 15.0

## Zieltyp einer Lexem-Meldung; der Payload trägt den Typ, damit später Sätze dazupassen.
const TARGET_TYPE_LEXEME := "lexeme"

## Die Gründe, die der Endpunkt benennt, in der Sprache der Oberfläche.
const ERROR_TEXTS := {
	"bad_token": "Diese Fassung darf nicht mehr melden — bitte das Spiel aktualisieren.",
	"stale_key": "Diese Fassung darf nicht mehr melden — bitte das Spiel aktualisieren.",
	"revoked": "Diese Fassung darf nicht mehr melden — bitte das Spiel aktualisieren.",
	"too_large": "Meldung ist zu lang.",
	"rate_limited": "Zu viele Meldungen — später noch einmal.",
	"bad_payload": "Meldung war unvollständig.",
	"bad_request": "Anfrage wurde abgewiesen.",
	"server_error": "Der Server hat ein Problem.",
}

var state: State = State.IDLE
var error := ""

var endpoint := ""
## App-Schlüssel `app-<n>.<mac>` und die Schlüsselversion, unter der er geprägt wurde.
var key := ""
var key_version := 1

var _http: HTTPRequest
## HTTPRequest kann nur einen Vorgang zugleich.
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = TIMEOUT_SECONDS
	_http.body_size_limit = MAX_RESPONSE_BYTES
	add_child(_http)
	_load_key()
	if OS.is_debug_build():
		# Debug-Läufe melden nur mit beiden Umgebungsvariablen (lokaler Endpunkt).
		endpoint = OS.get_environment("MONSTER_SLAM_REPORT_URL")
		key = OS.get_environment("MONSTER_SLAM_REPORT_KEY")
		if not endpoint.is_empty():
			print("ReportService: Endpunkt überschrieben -> %s" % endpoint)
	if can_report():
		# Stiller Nachversand beim Start, ohne await.
		_send_silently.call_deferred()


## Darf diese Fassung melden? Steuert, ob „Melden" in der Oberfläche erscheint.
func can_report() -> bool:
	return not endpoint.is_empty() and not key.is_empty()


## Anzahl offener (noch nicht gesendeter) Meldungen.
func pending_count() -> int:
	return LexemeFlags.pending().size()


## Schickt alle offenen Meldungen nacheinander; true, wenn danach keine mehr offen ist.
## `loud` = Klick. Ein Fehlschlag lässt die Meldung offen.
func send_pending(loud: bool) -> bool:
	if not can_report() or _busy:
		return false
	var open := LexemeFlags.pending()
	if open.is_empty():
		return true
	_busy = true
	_set_state(State.SENDING)
	var all_sent := true
	var last_error := ""
	for item in open:
		var payload := _payload(item)
		var answer := await _post(payload)
		if not answer["error"].is_empty():
			all_sent = false
			last_error = answer["error"]
			# Der erste Fehlschlag beendet den Lauf (kein Netz, gesperrter Schlüssel).
			break
		ContentRegistry.mark_flag_sent(String(item.get("lexeme_id", "")))
	_busy = false
	if all_sent:
		_set_state(State.IDLE)
	elif loud:
		_fail(last_error)
	else:
		# Stiller Lauf: Zustand zurück auf IDLE, der Grund steht nur im Log.
		print("ReportService: Versand verschoben — %s" % last_error)
		_set_state(State.IDLE)
	return all_sent


## Der Payload einer Meldung mit Herkunft (App-Fassung, Pack), damit eine Meldung zu einem
## inzwischen korrigierten Wort erkennbar bleibt; `stats_id`, wenn vorhanden.
func _payload(item: Dictionary) -> Dictionary:
	var lexeme_id := String(item.get("lexeme_id", ""))
	var payload := {
		"action": "report",
		"key_version": key_version,
		"target_type": TARGET_TYPE_LEXEME,
		"target_id": lexeme_id,
		"learnable_id": String(item.get("learnable_id", "")),
		"comment": String(item.get("comment", "")),
		"at": String(item.get("at", "")),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
	}
	var stats_id := String(item.get("stats_id", ""))
	if not stats_id.is_empty():
		payload["stats_id"] = stats_id
	var pack_id := ContentRegistry.pack_of("lexemes", lexeme_id)
	if not pack_id.is_empty():
		payload["pack"] = {
			"id": pack_id,
			"version": str(PackInstaller.read_state(pack_id).get("version", "")),
		}
	return payload


## Ein Vorgang gegen den Endpunkt. Rückgabe: {"error": String, "data": Dictionary}.
## `error` ist der fertige Anzeigetext, nicht der Code des Endpunkts.
func _post(payload: Dictionary) -> Dictionary:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % key,
	])
	var err := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		return {"error": "Anfrage nicht startbar (Fehler %d)." % err, "data": {}}
	var result: Array = await _http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Server nicht erreichbar.", "data": {}}
	var body := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		return {"error": "Server antwortet unverständlich.", "data": {}}
	var data: Dictionary = parsed
	if not bool(data.get("ok", false)):
		var code := str(data.get("error", ""))
		return {"error": str(ERROR_TEXTS.get(code, "Abgewiesen (%s)." % code)), "data": data}
	return {"error": "", "data": data}


func _load_key() -> void:
	var config := ConfigFile.new()
	if config.load(KEY_PATH) != OK:
		return
	endpoint = str(config.get_value("report", "url", ""))
	key = str(config.get_value("stats", "key", ""))
	key_version = int(config.get_value("stats", "key_version", 1))


func _send_silently() -> void:
	await send_pending(false)


func _set_state(next: State) -> void:
	state = next
	if next != State.ERROR:
		error = ""
	changed.emit()


func _fail(message: String) -> void:
	error = message
	state = State.ERROR
	changed.emit()
