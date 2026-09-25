class_name LocalModelBackend
extends Node
## Stufe 1: ein Sprachmodell, das auf DIESEM Rechner läuft — und nur dann, wenn es jemand
## dorthin gestellt hat (docs/adr/0004-satzbewertung-ohne-modell.md, Entscheidung 3).
##
## Ollama, llama.cpp-Server und LM Studio sprechen alle HTTP auf 127.0.0.1 und alle die
## OpenAI-Form `/v1/chat/completions`. Deshalb braucht es dafür kein GDExtension und keine
## Modellgewichte in der EXE: die Auslieferung enthält diese Klasse, aber nichts, was sie
## bedient. Läuft kein Dienst, schlägt die Anfrage fehl und das Ergebnis bleibt das der
## Prüfkarte.
##
## **Wer den Dienst hinstellt, ist dieser Klasse einerlei.** Entweder hat ihn jemand selbst
## installiert, oder `LocalModelServer` startet ihn aus `user://model/` — beides endet in
## einer `url` auf 127.0.0.1. Der Unterschied ist eine Zeichenkette, und genau deshalb war
## der Weg zu „für Benutzer installierbar" keine Änderung an der Bewertung.
##
## **Es gibt keine Stufe 2 in der Cloud.** Eine frei getippte Schülerantwort geht nicht ins
## Netz — der Unterschied zum Melde-Rückkanal (ADR 0002), der nur Ids kennt und keine
## Wörter. `URL` zeigt deshalb auf 127.0.0.1, und das ist keine Einstellung, sondern die
## Entscheidung.
##
## **Zwei Aufrufe** (docs/adr/0005-bosskampf-mit-erklaerung.md): `judge()` urteilt mit dem
## Lösungsschlüssel, `explain()` erklärt ohne ihn. Die Aufträge stehen in StageOnePrompts.
## Einhängen: `judge.model_backend = backend.judge`, `judge.explainer = backend.explain`
## (siehe SentenceJudge). Prompt-Bau und Antwort-Auswertung sind statisch und damit ohne
## Netz prüfbar.

## Die Adresse des Dienstes, den LocalModelServer startet. Wer Ollama oder LM Studio
## benutzt, setzt `url` auf deren Port (11434 bzw. 1234).
const URL := "http://127.0.0.1:11435/v1/chat/completions"
## llama-server beantwortet jeden Namen mit dem Modell, das er geladen hat; der Name hier
## ist für Ollama und LM Studio, die mehrere Modelle führen.
const MODEL := "gemma-4-e4b"

## Sekunden, nach denen eine Anfrage abgebrochen wird. Gemessen braucht Gemma auf einer
## schnellen CPU für das Urteil 3–5 s, auf einem Kinder-Laptop ein Mehrfaches — und ein
## Bosskampf hat keinen Zeitdruck, der eine Antwort nach zehn Sekunden wertlos machte
## (ADR 0005, Entscheidung 7). SentenceJudge wartet etwas länger als das hier.
const HTTP_TIMEOUT := 45.0

## Wie viel Spielraum das Modell bekommt: ein JSON-Objekt mit ein, zwei Sätzen darin. Die
## Werkstatt hat mit 400 bis 700 gemessen; beides ist nur eine Obergrenze, die ein
## Modell, das sich an die Form hält, nie erreicht.
const MAX_TOKENS := 400

## Was in `last_note` steht, wenn schon eine Anfrage offen ist. Als Konstante, weil ein
## Test daran hängt: dieser Fall war einmal der einzige, der gar nichts sagte.
const BUSY_NOTE := "Vorige Anfrage läuft noch — diese wurde nicht gestellt."

## Die Güte, die ein Urteil von Aufruf 1 bedeutet. Das Modell urteilt binär (ADR 0005);
## die Zahl ist die Form, in der SentenceJudge und der Kampf rechnen.
const CORRECT_QUALITY := 1.0
const INCORRECT_QUALITY := 0.0

var url := URL
var model := MODEL

## Wie lange auf den Dienst gewartet wird, bevor die Verbindung abgebrochen wird.
## Verstellbar für Messung und Werkbank, die länger warten dürfen als der Kampf. Gelesen
## wird der Wert in _ready(), also VOR dem Einhängen setzen.
var http_timeout := HTTP_TIMEOUT

## Woran es beim letzten Mal lag, im Klartext — leer, solange alles in Ordnung war.
##
## Eine Antwort ohne verwertbaren Inhalt ergibt {}, ebenso ein Dienst, der gar nicht
## antwortet. Für das Spiel ist beides dasselbe („kein Beitrag"), und das soll es bleiben.
## Beim Messen und in der Werkbank ist es der Unterschied zwischen „nichts installiert"
## und „falsches Modell" — und ohne diese Naht suchte man am falschen Ende.
var last_note := ""

## Die rohe Ausgabe des Modells bei der letzten Antwort — für die Werkbank, die zeigen
## will, WAS das Modell geschrieben hat, und nicht nur, was davon ankam.
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


## Steht noch eine Anfrage offen? Solange das gilt, wird jede weitere abgewiesen — wer
## der Reihe nach fragt (das Messskript), wartet darauf.
func busy() -> bool:
	return _on_done.is_valid()


## Der Rumpf der Anfrage — statisch und damit ohne Dienst prüfbar. Kein `response_format`:
## gemessen wurde ohne, und Gemma hält die Form aus dem Prompt heraus (ADR 0005).
static func request_body(messages: Array, model_name: String) -> String:
	return JSON.stringify({
		"model": model_name,
		"temperature": 0.0,
		"max_tokens": MAX_TOKENS,
		"messages": messages,
	})


func _ask(messages: Array, parse: Callable, on_done: Callable) -> void:
	if _http == null or _on_done.is_valid():
		# Eine Anfrage zur Zeit. Die zweite bekommt kein Ergebnis — das ist kein Fehler,
		# sondern der Normalfall „kein Modell da".
		#
		# Sie bekommt aber eine Begründung: gibt SentenceJudge früher auf, als HTTP_TIMEOUT
		# lang ist, bleibt die erste Anfrage offen und JEDE weitere fällt still hierher.
		# Wer misst, hat dann 24 von 25 Antworten nie gefragt — und sieht es nirgends.
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


## Der Text, den das Modell geschrieben hat, aus der OpenAI-Hülle — oder "", wenn die
## Hülle nicht stimmt.
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


## Das JSON-Objekt aus der Ausgabe des Modells, oder {}. Kleine Modelle schreiben gern
## einen Satz davor, legen einen Codeblock darum oder hängen ein zweites Objekt an. Erst
## wird von der ersten Klammer bis zur letzten gelesen; geht das nicht, zählt die erste
## Zeile, die ein Objekt ist — so liest auch die Werkstatt (`parts_of`).
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


## JSON.new().parse() statt JSON.parse_string(): eine Antwort, die kein JSON ist, ist hier
## der Normalfall und kein Fehler, den jemand in der Konsole lesen müsste.
static func _quiet_parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## Aufruf 1: { "verdict": "correct"|"incorrect", "reason" } -> { quality, verdict,
## feedback }, oder {} wenn das Urteil fehlt oder keins der beiden Wörter ist. Ein Modell,
## das sich nicht an die Form hält, ist kein Fehlerfall, sondern ein Modell ohne Beitrag.
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
## Erklärung ist keiner: das Spiel zeigte sonst „falsch, weil:" und dahinter nichts.
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


## In die Ausgabe, nicht nur auf den Bildschirm. `last_note` muss in eine Karte am Bildrand
## passen und ist deshalb gekürzt — beim Suchen will man aber genau das sehen, was gekürzt
## wurde: WELCHE Form das Modell statt der verabredeten geliefert hat. Gemeldet wird nur,
## was schiefging; eine geglückte Anfrage ist keine Nachricht.
static func _report(what: String, body: String) -> void:
	var full := body.strip_edges()
	print("LocalModelBackend: %s" % what if full.is_empty()
			else "LocalModelBackend: %s\n%s" % [what, full])


## Genug zum Wiedererkennen, wenig genug für eine Zeile.
static func _excerpt(text: String) -> String:
	var one_line := " ".join(text.strip_edges().split("\n", false))
	return one_line if one_line.length() <= 160 else one_line.substr(0, 160) + " …"


func _finish(reply: Dictionary) -> void:
	var done := _on_done
	_on_done = Callable()
	_parse = Callable()
	if done.is_valid():
		done.call(reply)
