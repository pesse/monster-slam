class_name LocalModelBackend
extends Node
## Stufe 1: ein Sprachmodell als lokaler Dienst auf 127.0.0.1 in der OpenAI-Form
## `/v1/chat/completions` (ADR 0004 Entscheidung 3, ADR 0005). Ohne Dienst bleibt es beim
## Ergebnis der Prüfkarte. Die Adresse bleibt lokal: Schülertexte gehen nicht ins Netz.
## `judge()` urteilt mit Lösungsschlüssel, `explain()` erklärt ohne ihn (Aufträge in
## StageOnePrompts). Prompt-Bau und Auswertung sind statisch und ohne Netz prüfbar.

## Die Adresse des Dienstes, den LocalModelServer startet. Wer Ollama oder LM Studio
## benutzt, setzt `url` auf deren Port (11434 bzw. 1234).
const URL := "http://127.0.0.1:11435/v1/chat/completions"
## Für Ollama und LM Studio; llama-server antwortet auf jeden Namen mit seinem Modell.
const MODEL := "gemma-4-e4b"

## Sekunden, nach denen eine Anfrage abgebrochen wird (ADR 0005, Entscheidung 7).
const HTTP_TIMEOUT := 45.0

## Obergrenze der Antwortlänge in Token (ein JSON-Objekt mit ein, zwei Sätzen).
const MAX_TOKENS := 400

## `last_note`, wenn schon eine Anfrage offen ist (ein Test prüft den Text).
const BUSY_NOTE := "Vorige Anfrage läuft noch — diese wurde nicht gestellt."

## Die Güte eines binären Urteils von Aufruf 1 (ADR 0005).
const CORRECT_QUALITY := 1.0
const INCORRECT_QUALITY := 0.0

## Länge eines Auszugs in `last_note` (Zeichen).
const EXCERPT_CHARS := 160

var url := URL
var model := MODEL

## Wartezeit auf den Dienst (s). Wird in _ready() gelesen, also vor dem Einhängen setzen.
var http_timeout := HTTP_TIMEOUT

## Woran es beim letzten Mal lag, im Klartext; leer, solange alles in Ordnung war. Der
## Aufrufer bekommt bei jedem Fehlschlag nur {}.
var last_note := ""

## Die rohe Ausgabe des Modells bei der letzten Antwort.
var last_content := ""

## Wie lange die letzte Anfrage gedauert hat, in Sekunden.
var last_seconds := 0.0

var _http: HTTPRequest
var _on_done: Callable
## Wie die Antwort der offenen Anfrage gelesen wird: parse_verdict oder parse_explanation.
var _parse: Callable
var _started_msec := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = http_timeout
	add_child(_http)
	_http.request_completed.connect(_on_completed)


## Aufruf 1 in der Callable-Form, die SentenceJudge als `model_backend` erwartet.
## `on_done` bekommt { "quality", "verdict", "feedback" } oder {}.
func judge(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	_ask(StageOnePrompts.verdict_messages(sentence, answer), parse_verdict, on_done)


## Aufruf 2 in der Callable-Form, die SentenceJudge als `explainer` erwartet.
## `on_done` bekommt { "mistake", "explanation" } oder {}.
func explain(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	_ask(StageOnePrompts.explain_messages(sentence, answer), parse_explanation, on_done)


## Steht noch eine Anfrage offen? Solange das gilt, wird jede weitere abgewiesen.
func busy() -> bool:
	return _on_done.is_valid()


## Der Rumpf der Anfrage. Ohne `response_format`, so wurde gemessen (ADR 0005).
static func request_body(messages: Array, model_name: String) -> String:
	return JSON.stringify({
		"model": model_name,
		"temperature": 0.0,
		"max_tokens": MAX_TOKENS,
		"messages": messages,
	})


func _ask(messages: Array, parse: Callable, on_done: Callable) -> void:
	if _http == null or _on_done.is_valid():
		# Eine Anfrage zur Zeit; die zweite bekommt {} und eine Begründung in `last_note`.
		last_note = BUSY_NOTE
		on_done.call({})
		return
	_on_done = on_done
	_parse = parse
	last_note = ""
	last_content = ""
	_started_msec = Time.get_ticks_msec()
	var error := _http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			request_body(messages, model))
	if error != OK:
		last_note = "Anfrage an %s nicht abgesetzt (Fehler %d)" % [url, error]
		_finish({})


## Der Text des Modells aus der OpenAI-Hülle, oder "", wenn die Hülle nicht stimmt.
static func content_of(body: String) -> String:
	var envelope: Variant = _quiet_parse(body)
	if not (envelope is Dictionary):
		return ""
	var choices: Array = Array((envelope as Dictionary).get("choices", []))
	if choices.is_empty() or not (choices[0] is Dictionary):
		return ""
	var message: Variant = (choices[0] as Dictionary).get("message", {})
	if not (message is Dictionary):
		return ""
	return str((message as Dictionary).get("content", ""))


## Das JSON-Objekt aus der Ausgabe des Modells, oder {}. Erst von der ersten bis zur letzten
## Klammer, sonst die erste Zeile, die ein Objekt ist (Text oder Codeblock drumherum).
static func object_in(content: String) -> Dictionary:
	var start := content.find("{")
	var end := content.rfind("}")
	if start < 0 or end <= start:
		return {}
	var chunk := content.substr(start, end - start + 1)
	var parsed: Variant = _quiet_parse(chunk)
	if parsed is Dictionary:
		return parsed
	for line in chunk.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("{") and trimmed.ends_with("}"):
			parsed = _quiet_parse(trimmed)
			if parsed is Dictionary:
				return parsed
	return {}


## Parst ohne Fehlermeldung in der Konsole (anders als JSON.parse_string()).
static func _quiet_parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## Aufruf 1: { "verdict": "correct"|"incorrect", "reason" } -> { quality, verdict,
## feedback }, oder {}, wenn das Urteil fehlt oder keins der beiden Wörter ist.
static func parse_verdict(content: String) -> Dictionary:
	var obj := object_in(content)
	var verdict := str(obj.get("verdict", "")).strip_edges().to_lower()
	if not (verdict in ["correct", "incorrect"]):
		return {}
	return {
		"verdict": verdict,
		"quality": CORRECT_QUALITY if verdict == "correct" else INCORRECT_QUALITY,
		"feedback": str(obj.get("reason", "")).strip_edges(),
	}


## Aufruf 2: { "mistake": bool, "explanation" } -> dasselbe, oder {}. Ein Fehler ohne
## Erklärung zählt nicht als Fehler.
static func parse_explanation(content: String) -> Dictionary:
	var obj := object_in(content)
	if not obj.has("mistake"):
		return {}
	var raw: Variant = obj["mistake"]
	var mistake: bool = (raw is bool and raw) or str(raw).strip_edges().to_lower() == "true"
	var explanation := str(obj.get("explanation", "")).strip_edges()
	return {
		"mistake": mistake and not explanation.is_empty(),
		"explanation": explanation if mistake else "",
	}


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_note = ""
	last_seconds = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if result != HTTPRequest.RESULT_SUCCESS:
		last_note = "Kein Dienst auf %s erreichbar (Ergebnis %d)" % [url, result]
		_report(last_note, "")
		_finish({})
		return
	var text := body.get_string_from_utf8()
	if code != 200:
		last_note = "HTTP %d von %s: %s" % [code, url, _excerpt(text)]
		_report("HTTP %d von %s" % [code, url], text)
		_finish({})
		return
	last_content = content_of(text)
	var parse := _parse if _parse.is_valid() else Callable(parse_verdict)
	var reply: Dictionary = parse.call(last_content)
	if reply.is_empty():
		last_note = "Antwort ohne verwertbares Ergebnis: %s" % _excerpt(
				last_content if not last_content.is_empty() else text)
		_report("Antwort ohne verwertbares Ergebnis von %s" % url, text)
	_finish(reply)


## Schreibt einen Fehlschlag ungekürzt in die Ausgabe (`last_note` ist gekürzt).
static func _report(what: String, body: String) -> void:
	var full := body.strip_edges()
	print("LocalModelBackend: %s" % what if full.is_empty()
			else "LocalModelBackend: %s\n%s" % [what, full])


## Einzeiliger Auszug, höchstens EXCERPT_CHARS Zeichen.
static func _excerpt(text: String) -> String:
	var one_line := " ".join(text.strip_edges().split("\n", false))
	return one_line if one_line.length() <= EXCERPT_CHARS else one_line.substr(0, EXCERPT_CHARS) + " …"


func _finish(reply: Dictionary) -> void:
	var done := _on_done
	_on_done = Callable()
	_parse = Callable()
	if done.is_valid():
		done.call(reply)
