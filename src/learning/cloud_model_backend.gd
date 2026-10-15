class_name CloudModelBackend
extends Node
## Das Modell in der Cloud: Anthropic, mit dem EIGENEN Schlüssel des Spielers — für den
## Schreib-Boss (docs/adr/0023-schreib-boss.md, §1 und §2) und, wenn eingestellt, als
## Stufe 1 des Satzmeisters (ADR 0025).
##
## Das ist die Ausnahme von „Kindertexte gehen nicht ins Netz" (ADR 0004), und sie gilt nur
## hier: ohne bestätigten Schlüssel (`ApiKeys.anthropic()`) wird nichts gesendet. Hinaus
## gehen Aufgabe, Vorlage, Kernpunkte und der Schülertext (`WritingPrompts.summary_user`)
## bzw. Satz, Schlüssel und Übersetzung (`StageOnePrompts.cloud_user`) — kein Profil, keine
## Spieler-Id. Der Schlüssel steht nur im Kopf der Anfrage und nie in
## `last_note`, in der Ausgabe oder in der Antwort an den Aufrufer.
##
## Derselbe Zuschnitt wie `LocalModelBackend`: Anfrage rein, Dictionary raus, Zeitlimit,
## `last_note` im Klartext, und Anfrage-Bau wie Antwort-Auswertung statisch — ohne Netz
## prüfbar. Ein zweiter Anbieter passt dahinter, ohne dass Boss oder Richter davon wissen.
##
## **Strukturierte Ausgabe über `output_config.format`, nicht über ein erzwungenes Tool.**
## Claude Opus 5.5 lehnt `tool_choice` `any`/`tool` mit HTTP 400 ab; die JSON-Ausgabe mit
## Schema (`WritingPrompts.SUMMARY_SCHEMA`) ist der vorgesehene Ersatz und garantiert die
## Form genauso. Die Antwort steht dann als JSON im Text-Block. `parse_envelope` liest zur
## Sicherheit auch einen `tool_use`-Block, falls ein anderes Modell so antwortet.
##
## Verweigert das Modell (Sicherheitsfilter, `stop_reason: "refusal"`), versucht der Dienst
## es selbst auf einem Ersatzmodell (`fallbacks: "default"`). Welches Modell geantwortet hat,
## steht in der Antwort und geht so in `usage.model` — und damit in die Kostenrechnung.

const URL := "https://api.anthropic.com/v1/messages"
const MODELS_URL := "https://api.anthropic.com/v1/models/"
## Die Modell-Id steht an dieser EINEN Stelle (ADR 0023, §2).
const MODEL := "claude-opus-5-5"
## Das Modell für den Satzmeister: am Einzelsatz in der Werkstatt besser als Opus,
## schneller und billiger (ADR 0025).
const SENTENCE_MODEL := "claude-sonnet-5-5"
const API_VERSION := "2023-06-01"
## Beta für die serverseitige Ersatzanfrage in der Form `fallbacks: "default"`.
const FALLBACK_BETA := "server-side-fallback-2026-07-01"

## Wie gründlich das Modell nachdenkt. Opus 5.5 denkt immer; `medium` ist dort die
## Voreinstellung und hier ausdrücklich gesetzt, damit eine Änderung sichtbar ist. Ob
## `high` die Güte hebt, wird in der Werkstatt gemessen (ADR 0023, §9), nicht hier geraten.
const EFFORT := "medium"

## Obergrenze für Denken und Antwort zusammen. Die Antwort selbst ist ein JSON mit einer
## Handvoll Zitaten (wenige hundert Token); die Grenze trifft nur ein Modell, das aus der
## Form fällt.
const MAX_TOKENS := 16000

## Sekunden bis zum Abbruch. Gemessen ~4 s je Aufruf (ADR 0023, §9), mit Denken und einem
## langen Text eher eine halbe Minute; der Kampf hat keinen Zeitdruck.
const HTTP_TIMEOUT := 120.0

## Ein Satz hat eine Antwort bekommen oder ist gescheitert: `reply` wie bei `reply_from`,
## mit `result` = { mistake, explanation } oder {}. Für die Kostenbuchung (WritingLog).
signal sentence_answered(sentence_id: String, reply: Dictionary)

const BUSY_NOTE := "Vorige Anfrage läuft noch — diese wurde nicht gestellt."
const NO_KEY_NOTE := "Kein bestätigter API-Schlüssel eingetragen."

var model := MODEL
## Verstellbar für Werkbank und Messung; gelesen in _ready(), also VOR dem Einhängen setzen.
var http_timeout := HTTP_TIMEOUT
## Ein Schlüssel für Werkbank oder Messung. Leer heißt: der bestätigte aus ApiKeys.
var api_key := ""

## Woran es beim letzten Mal lag, im Klartext — leer, solange alles in Ordnung war.
var last_note := ""
## Wie lange die letzte Anfrage gedauert hat, in Sekunden.
var last_seconds := 0.0
## Der Rumpf der letzten Bewertungsanfrage (ohne Kopfzeilen, also ohne Schlüssel) und die
## rohe Antwort darauf mit HTTP-Status — für die Werkbank, die zeigen will, was wirklich
## hin- und zurückging.
var last_request: Dictionary = {}
var last_response := ""
var last_code := 0

var _http: HTTPRequest
var _on_done: Callable
## "summary", "sentence" oder "check" — was die offene Anfrage ist.
var _mode := ""
## Die Erklärung aus dem letzten Satz-Urteil, für `explain`: { key, mistake, explanation }.
var _explained: Dictionary = {}
var _started_msec := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = http_timeout
	add_child(_http)
	_http.request_completed.connect(_on_completed)


## Bewertet eine Summary. `on_done` bekommt { result, usage, note } (siehe `reply_from`):
## `result` ist {} bei jedem Fehler, `note` dann der Grund.
func judge_summary(task: Dictionary, text: String, on_done: Callable) -> void:
	if busy():
		last_note = BUSY_NOTE
		on_done.call(failed(BUSY_NOTE, model))
		return
	var key := _key()
	if key.is_empty():
		last_note = NO_KEY_NOTE
		on_done.call(failed(NO_KEY_NOTE, model))
		return
	_post(request_body(task, text, model), "summary", on_done, key)


## Bewertet eine Übersetzung im Satzmeister: ein Aufruf, Urteil und Erklärung zusammen.
## `on_done` bekommt { result, usage, note } mit `result` = { mistake, explanation } oder {}.
func judge_sentence(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	var id := str(sentence.get("id", ""))
	var done := func(reply: Dictionary) -> void:
		sentence_answered.emit(id, reply)
		on_done.call(reply)
	if busy():
		last_note = BUSY_NOTE
		done.call(failed(BUSY_NOTE, model))
		return
	var key := _key()
	if key.is_empty():
		last_note = NO_KEY_NOTE
		done.call(failed(NO_KEY_NOTE, model))
		return
	_post(sentence_body(sentence, answer, model), "sentence", done, key)


## Stufe 1 in der Callable-Form von `SentenceJudge.model_backend`. `on_done` bekommt
## { quality, verdict, feedback } oder {}; die Erklärung hält `explain` bereit.
func judge(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	_explained = {}
	judge_sentence(sentence, answer, func(reply: Dictionary) -> void:
		var result: Dictionary = reply["result"]
		if result.is_empty():
			on_done.call({})
			return
		var mistake := bool(result["mistake"])
		_explained = {"key": _answer_key(sentence, answer), "mistake": mistake,
				"explanation": str(result["explanation"])}
		on_done.call({
			"quality": LocalModelBackend.INCORRECT_QUALITY if mistake \
					else LocalModelBackend.CORRECT_QUALITY,
			"verdict": "incorrect" if mistake else "correct",
			"feedback": "",
		}))


## `SentenceJudge.explainer`: die Erklärung aus derselben Antwort wie das Urteil, ohne
## zweiten Aufruf. Zu einer anderen Antwort gibt es keine ({}).
func explain(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	if _explained.get("key", "") != _answer_key(sentence, answer):
		on_done.call({})
		return
	on_done.call({"mistake": _explained["mistake"], "explanation": _explained["explanation"]})


## Prüft den Schlüssel, ohne etwas zu kosten: fragt nur nach dem Modell (`GET /v1/models`).
## `on_done` bekommt "" für „in Ordnung", sonst den Grund. `key` leer = der gespeicherte.
func check_key(on_done: Callable, key := "") -> void:
	var use := key.strip_edges() if not key.strip_edges().is_empty() else _key()
	if busy():
		on_done.call(BUSY_NOTE)
		return
	if use.is_empty():
		on_done.call(NO_KEY_NOTE)
		return
	_begin(on_done, "check")
	var error := _http.request(MODELS_URL + model, request_headers(use, false),
			HTTPClient.METHOD_GET)
	if error != OK:
		_fail("Anfrage an Anthropic nicht abgesetzt (Fehler %d)." % error)


func busy() -> bool:
	return _on_done.is_valid()


# --- Anfrage (statisch) --------------------------------------------------------

## Die Kopfzeilen. Der Schlüssel steht NUR hier.
static func request_headers(key: String, with_fallback := true) -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: %s" % key,
		"anthropic-version: %s" % API_VERSION,
	])
	if with_fallback:
		headers.append("anthropic-beta: %s" % FALLBACK_BETA)
	return headers


## Der Rumpf der Anfrage für eine Summary. Kein `thinking`: Opus 5.5 denkt immer (adaptiv), und ein
## ausgeschaltetes Denken lehnt es ab. Kein `temperature`: wird dort ebenfalls abgelehnt.
static func request_body(task: Dictionary, text: String, model_name := MODEL) -> Dictionary:
	return {
		"model": model_name,
		"max_tokens": MAX_TOKENS,
		"system": WritingPrompts.SUMMARY_SYSTEM,
		"messages": [
			{"role": "user", "content": WritingPrompts.summary_user(task, text)},
		],
		"output_config": {
			"effort": EFFORT,
			"format": {"type": "json_schema", "schema": WritingPrompts.SUMMARY_SCHEMA},
		},
		"fallbacks": "default",
	}


## Der Rumpf der Anfrage für einen Satz im Satzmeister; sonst wie `request_body`.
static func sentence_body(sentence: Dictionary, answer: String,
		model_name := SENTENCE_MODEL) -> Dictionary:
	return {
		"model": model_name,
		"max_tokens": MAX_TOKENS,
		"system": StageOnePrompts.CLOUD_SYSTEM,
		"messages": [
			{"role": "user", "content": StageOnePrompts.cloud_user(sentence, answer)},
		],
		"output_config": {
			"effort": EFFORT,
			"format": {"type": "json_schema", "schema": StageOnePrompts.CLOUD_SCHEMA},
		},
		"fallbacks": "default",
	}


# --- Antwort (statisch) --------------------------------------------------------

## Die Antwort an den Aufrufer aus dem, was HTTPRequest geliefert hat:
## { "result": Modellantwort oder {}, "usage": {...}, "note": "" oder Grund }.
## `shape` ist "summary" oder "sentence" — welche Antwortform erwartet wird.
static func reply_from(http_result: int, code: int, text: String, seconds: float,
		model_name := MODEL, shape := "summary") -> Dictionary:
	if http_result != HTTPRequest.RESULT_SUCCESS:
		return failed(_transport_note(http_result), model_name, seconds)
	var envelope: Variant = _quiet_parse(text)
	var env: Dictionary = envelope if envelope is Dictionary else {}
	var usage := usage_of(env, model_name, seconds)
	if code != 200:
		return {"result": {}, "usage": usage, "note": error_note(code, env, text, model_name)}
	var parsed := parse_envelope(env, shape)
	return {"result": parsed["result"], "usage": usage, "note": parsed["note"]}


## Ein Fehlschlag ohne Verbrauch.
static func failed(note: String, model_name := MODEL, seconds := 0.0) -> Dictionary:
	return {"result": {}, "usage": usage_of({}, model_name, seconds), "note": note}


## Der Verbrauch aus der Hülle, in der Form, die WritingLog speichert. Fehlt er (Fehler,
## kein Netz), ist alles 0. `model` ist das Modell, das geantwortet hat — bei einer
## Ersatzanfrage nicht das bestellte.
static func usage_of(env: Dictionary, model_name: String, seconds: float) -> Dictionary:
	var raw: Variant = env.get("usage", {})
	var u: Dictionary = raw if raw is Dictionary else {}
	var answered := str(env.get("model", "")).strip_edges()
	return {
		"model": answered if not answered.is_empty() else model_name,
		"input_tokens": int(_num(u.get("input_tokens", 0))),
		"output_tokens": int(_num(u.get("output_tokens", 0))),
		"cache_read_input_tokens": int(_num(u.get("cache_read_input_tokens", 0))),
		"cache_creation_input_tokens": int(_num(u.get("cache_creation_input_tokens", 0))),
		"seconds": snappedf(seconds, 0.01),
	}


## Das Ergebnis aus einer erfolgreichen Hülle: { result, note }. Liest den Text-Block
## (strukturierte Ausgabe) oder, falls vorhanden, die Eingabe eines `tool_use`-Blocks.
static func parse_envelope(env: Dictionary, shape := "summary") -> Dictionary:
	var stop := str(env.get("stop_reason", ""))
	if stop == "refusal":
		return {"result": {}, "note": "Das Modell hat die Bewertung abgelehnt."}
	if stop == "max_tokens":
		return {"result": {}, "note": "Die Antwort des Modells wurde abgeschnitten."}
	var candidate: Variant = null
	var texts := PackedStringArray()
	for block in Array(env.get("content", [])):
		if not (block is Dictionary):
			continue
		var b: Dictionary = block
		match str(b.get("type", "")):
			"tool_use":
				if b.get("input") is Dictionary and candidate == null:
					candidate = b["input"]
			"text":
				texts.append(str(b.get("text", "")))
	if candidate == null and not texts.is_empty():
		candidate = _quiet_parse("".join(texts).strip_edges())
	if not (candidate is Dictionary):
		return {"result": {}, "note": "Antwort ohne Bewertung (kein JSON gefunden)."}
	var result := parse_sentence(candidate) if shape == "sentence" else parse_result(candidate)
	if result.is_empty():
		return {"result": {}, "note": "Antwort ohne Bewertung (Form stimmt nicht)."}
	return {"result": result, "note": ""}


## Die Modellantwort in fester Form, oder {} wenn sie nicht zum Vertrag passt. Ohne
## `intro`, `key_points`, `present_tense` oder `errors` gibt es kein Urteil; einzelne
## kaputte Einträge fallen weg, statt die ganze Antwort zu kippen.
static func parse_result(raw: Dictionary) -> Dictionary:
	if not (raw.get("intro") is Dictionary and raw.get("key_points") is Array \
			and raw.get("errors") is Array and raw.get("present_tense") is bool):
		return {}
	var intro: Dictionary = raw["intro"]
	var intro_met: bool = intro.get("met") is bool and intro["met"]
	var points: Array = []
	for item in raw["key_points"]:
		if not (item is Dictionary):
			continue
		var p: Dictionary = item
		var id := str(p.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		var covered: bool = p.get("covered") is bool and p["covered"]
		points.append({"id": id, "covered": covered,
				"quote": str(p.get("quote", "")).strip_edges() if covered else ""})
	var errors: Array = []
	for item in raw["errors"]:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		var quote := str(e.get("quote", "")).strip_edges()
		if quote.is_empty():
			continue
		var category := str(e.get("category", "")).strip_edges()
		var severity := str(e.get("severity", "")).strip_edges()
		errors.append({
			"quote": quote,
			"category": category if category in WritingPrompts.CATEGORIES else "grammar",
			# Was nicht ausdrücklich schwer ist, zählt als leicht: ein schwerer Fehler hält
			# einen Stapel, und das soll nur ein ausdrückliches Urteil tun.
			"severity": "major" if severity == "major" else "minor",
			"hint": str(e.get("hint", "")).strip_edges(),
		})
	return {
		"intro": {"met": intro_met,
				"quote": str(intro.get("quote", "")).strip_edges() if intro_met else ""},
		"key_points": points,
		"present_tense": bool(raw["present_tense"]),
		"tense_quotes": _quotes(raw.get("tense_quotes")),
		"direct_speech": _quotes(raw.get("direct_speech")),
		"copied": _quotes(raw.get("copied")),
		"opinion": _quotes(raw.get("opinion")),
		"errors": errors,
	}


## Das Satz-Urteil in fester Form, oder {} ohne `mistake`. Ohne Fehler keine Erklärung.
static func parse_sentence(raw: Dictionary) -> Dictionary:
	if not (raw.get("mistake") is bool):
		return {}
	var mistake: bool = raw["mistake"]
	return {"mistake": mistake,
			"explanation": str(raw.get("explanation", "")).strip_edges() if mistake else ""}


## Eine Liste von Zitaten ohne leere Einträge; fehlt sie, ist sie leer.
static func _quotes(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for quote in value:
			var q := str(quote).strip_edges()
			if not q.is_empty():
				out.append(q)
	return out


## Der Grund für einen HTTP-Fehler im Klartext, für Overlay und Einstellungen.
static func error_note(code: int, env: Dictionary, text := "", model_name := MODEL) -> String:
	var message := ""
	if env.get("error") is Dictionary:
		message = str((env["error"] as Dictionary).get("message", "")).strip_edges()
	if message.is_empty():
		message = _excerpt(text)
	match code:
		401:
			return "Der API-Schlüssel wurde abgelehnt (ungültig oder widerrufen)."
		403:
			return "Der API-Schlüssel darf dieses Modell nicht nutzen."
		404:
			return "Das Modell %s ist für diesen Schlüssel nicht verfügbar." % model_name
		429:
			return "Zu viele Anfragen oder Ausgabenlimit erreicht — später noch einmal."
		500, 502, 503, 529:
			return "Anthropic ist gerade überlastet — später noch einmal."
	return "HTTP %d von Anthropic: %s" % [code, message]


static func _transport_note(http_result: int) -> String:
	if http_result == HTTPRequest.RESULT_TIMEOUT:
		return "Keine Antwort von Anthropic in der Zeit."
	return "Anthropic nicht erreichbar — besteht eine Internetverbindung? (Ergebnis %d)" \
			% http_result


static func _num(value: Variant) -> float:
	return float(value) if (value is int or value is float) else 0.0


static func _quiet_parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


static func _excerpt(text: String) -> String:
	var one_line := " ".join(text.strip_edges().split("\n", false))
	return one_line if one_line.length() <= 160 else one_line.substr(0, 160) + " …"


# --- Ablauf --------------------------------------------------------------------

func _key() -> String:
	return api_key.strip_edges() if not api_key.strip_edges().is_empty() else ApiKeys.anthropic()


func _post(body: Dictionary, mode: String, on_done: Callable, key: String) -> void:
	_begin(on_done, mode)
	last_request = body
	last_response = ""
	last_code = 0
	var error := _http.request(URL, request_headers(key), HTTPClient.METHOD_POST,
			JSON.stringify(body))
	if error != OK:
		_fail("Anfrage an Anthropic nicht abgesetzt (Fehler %d)." % error)


## Woran `explain` erkennt, dass es um dieselbe Antwort geht wie das letzte Urteil.
static func _answer_key(sentence: Dictionary, answer: String) -> String:
	return "%s\n%s" % [str(sentence.get("id", "")), answer.strip_edges()]


func _begin(on_done: Callable, mode: String) -> void:
	_on_done = on_done
	_mode = mode
	last_note = ""
	_started_msec = Time.get_ticks_msec()


func _fail(note: String) -> void:
	last_note = note
	if _mode == "check":
		_finish(note)
	else:
		_finish(failed(note, model))


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_seconds = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var text := body.get_string_from_utf8()
	if _mode == "check":
		var note := ""
		if result != HTTPRequest.RESULT_SUCCESS:
			note = _transport_note(result)
		elif code != 200:
			var env: Variant = _quiet_parse(text)
			note = error_note(code, env if env is Dictionary else {}, text, model)
		last_note = note
		_finish(note)
		return
	last_response = text
	last_code = code
	var reply := reply_from(result, code, text, last_seconds, model, _mode)
	last_note = str(reply["note"])
	if not last_note.is_empty():
		# In die Ausgabe, wie bei LocalModelBackend: die Karte am Rand zeigt nur den
		# gekürzten Grund. Der Rumpf enthält nie den Schlüssel (der steht nur im Kopf).
		print("CloudModelBackend: %s\n%s" % [last_note, text.strip_edges()])
	_finish(reply)


func _finish(value: Variant) -> void:
	var done := _on_done
	_on_done = Callable()
	_mode = ""
	if done.is_valid():
		done.call(value)
