extends Node
## Autoload `ReportService`: der Melde-Kanal — der Weg zurück zum Content-Autor.
##
## Dritter Kanal neben `UpdateService` (App) und `ContentService` (Inhalte), und der
## einzige, der nach oben geht: eine Meldung („dieses Wort ist falsch") wird zu einer
## Korrektur im privaten Content-Repo und kommt über den Content-Kanal als Pack-Update
## zurück. Entscheidung und Format: docs/adr/0002-melde-rueckkanal.md.
##
## Wie im App-Kanal ist jeder Netzfehler ein Zustand, kein Abbruch: eine nicht
## zustellbare Meldung bleibt in `user://lexeme_flags.json` offen und geht beim nächsten
## Start mit. Gemeldet wird immer erst lokal, gesendet danach.
##
## Ohne hinterlegtes Token (und ohne eingetragenen Endpunkt) ist der Kanal aus, und die
## Oberfläche zeigt „Melden" gar nicht — eine Meldung, die nirgends ankommt, ist
## ärgerlicher als ein fehlender Knopf.

## Zustand hat sich geändert. Empfänger lesen `state`, `error`, `label()`.
signal changed

enum State {
	IDLE,        ## Nichts zu tun
	VERIFYING,   ## Token wird gegen den Endpunkt geprüft
	SENDING,     ## Offene Meldungen gehen raus
	ERROR,       ## Benannter Fehlschlag; `error` trägt den Text
}

## Der Endpunkt (server/melden/melden.php). **Leer = Rückkanal aus.**
##
## Absichtlich eine Konstante wie `MANIFEST_URL` im App-Kanal: die URL ist kein
## Geheimnis, sie steht im öffentlichen Repo. Genau deshalb setzt der Endpunkt selbst die
## Grenzen (Größe, Rate je Token) — hier davor steht nichts.
const ENDPOINT := ""

## Antworten sind ein paar Bytes JSON. Die Schranke fängt eine falsch geroutete Antwort
## (Fehlerseite, HTML) ab, bevor sie als Antwort durchläuft.
const MAX_RESPONSE_BYTES := 8 * 1024

const TIMEOUT_SECONDS := 15.0

## Nur `lexemes` ist heute meldbar; `sentences` sind in ContentRegistry vorgesehen. Der
## Payload trägt den Typ von Anfang an mit, damit das später kein Formatbruch ist.
const TARGET_TYPE_LEXEME := "lexeme"

## Die Gründe, die der Endpunkt benennt, in der Sprache der Oberfläche.
const ERROR_TEXTS := {
	"bad_token": "Token ist nicht gültig.",
	"stale_key": "Token ist abgelaufen — bitte das neue eintragen.",
	"revoked": "Token wurde zurückgezogen.",
	"too_large": "Meldung ist zu lang.",
	"rate_limited": "Zu viele Meldungen — später noch einmal.",
	"bad_payload": "Meldung war unvollständig.",
	"bad_request": "Anfrage wurde abgewiesen.",
	"server_error": "Der Server hat ein Problem.",
}

var state: State = State.IDLE
var error := ""

var endpoint := ENDPOINT

var _http: HTTPRequest
## HTTPRequest kann einen Vorgang; das verhindert, dass Startversand und Klick sich
## in die Quere kommen.
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = TIMEOUT_SECONDS
	_http.body_size_limit = MAX_RESPONSE_BYTES
	add_child(_http)
	if OS.is_debug_build():
		var override := OS.get_environment("MONSTER_SLAM_REPORT_URL")
		if not override.is_empty():
			endpoint = override
			print("ReportService: Endpunkt überschrieben -> %s" % endpoint)
	if can_report():
		# Stiller Nachversand beim Start — ohne await, das Spiel wartet auf niemanden.
		_send_silently.call_deferred()


## Melder-Name des hinterlegten Tokens, "" wenn keines hinterlegt ist.
##
## Bewusst abgeleitet statt gepuffert: der Name steht im Token, und der Endpunkt leitet
## ihn genauso ab. Ein Feld daneben könnte nur falsch werden.
func label() -> String:
	return ReportToken.label_of(str(ReportToken.get_stored().get("token", "")))


## Ist überhaupt ein Endpunkt eingetragen? Ohne ihn gibt es den Kanal nicht.
func configured() -> bool:
	return not endpoint.is_empty()


## Darf dieser Rechner melden? Steuert, ob „Melden" in der Oberfläche erscheint.
func can_report() -> bool:
	return configured() and ReportToken.has_token()


## Anzahl offener (noch nicht gesendeter) Meldungen.
func pending_count() -> int:
	return LexemeFlags.pending().size()


## Prüft ein abgetipptes Token gegen den Endpunkt und hinterlegt es bei Erfolg.
##
## Die Prüfung muss übers Netz: das Geheimnis liegt auf dem Server, die App kann nur die
## Gestalt prüfen. Dafür ist die Rückmeldung echt („Token gilt für Mia") statt eines
## stillen Speicherns, das erst bei der ersten Meldung auffällt.
##
## `key_version` wird bewusst NICHT mitgesendet — die App lernt sie aus der Antwort.
func verify(raw_token: String) -> bool:
	if not configured():
		_fail("Für diese Fassung ist kein Rückkanal eingetragen.")
		return false
	var token := ReportToken.normalize(raw_token)
	if token.is_empty():
		_fail("Das sieht nicht wie ein Melde-Token aus (erwartet: name.XXXX-XXXX-XXXX-XXXX).")
		return false
	_set_state(State.VERIFYING)
	var answer := await _post({"action": "verify"}, token)
	if not answer["error"].is_empty():
		_fail(answer["error"])
		return false
	var data: Dictionary = answer["data"]
	ReportToken.store(token, int(data.get("key_version", 1)))
	_set_state(State.IDLE)
	return true


## Nimmt das Token zurück. Danach ist „Melden" wieder aus; die lokalen Meldungen bleiben.
func forget() -> void:
	ReportToken.forget()
	_set_state(State.IDLE)


## Schickt alle offenen Meldungen, eine nach der anderen. Gibt true zurück, wenn danach
## keine mehr offen ist.
##
## `loud` unterscheidet den Klick vom Startversand: still bleibt still. Ein Fehlschlag
## lässt die Meldung offen — sie geht beim nächsten Mal mit, und der Endpunkt erkennt
## eine doppelt gesendete.
func send_pending(loud: bool) -> bool:
	if not can_report() or _busy:
		return false
	var open := LexemeFlags.pending()
	if open.is_empty():
		return true
	var stored := ReportToken.get_stored()
	var token := str(stored.get("token", ""))
	var key_version := int(stored.get("key_version", 1))
	_busy = true
	_set_state(State.SENDING)
	var all_sent := true
	var last_error := ""
	for item in open:
		var payload := _payload(item, key_version)
		var answer := await _post(payload, token)
		if not answer["error"].is_empty():
			all_sent = false
			last_error = answer["error"]
			# Der erste Fehlschlag beendet den Lauf: was den einen Versand hindert
			# (kein Netz, gesperrtes Token), hindert auch die anderen.
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


## Der Payload einer Meldung. `target_type`/`target_id` statt `lexeme_id`, damit gemeldete
## Sätze später dazupassen; Herkunft (App-Fassung, Pack) mit, weil eine Meldung sonst zu
## einem Wort im Raum steht, das inzwischen längst korrigiert wurde.
func _payload(item: Dictionary, key_version: int) -> Dictionary:
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
	var pack_id := ContentRegistry.pack_of("lexemes", lexeme_id)
	if not pack_id.is_empty():
		payload["pack"] = {
			"id": pack_id,
			"version": str(PackInstaller.read_state(pack_id).get("version", "")),
		}
	return payload


## Ein Vorgang gegen den Endpunkt. Rückgabe: {"error": String, "data": Dictionary}.
## `error` ist der fertige Anzeigetext, nicht der Code des Endpunkts.
func _post(payload: Dictionary, token: String) -> Dictionary:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token,
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
