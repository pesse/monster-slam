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
## Einhängen: `judge.model_backend = backend.judge` (siehe SentenceJudge). Prompt-Bau und
## Antwort-Auswertung sind statisch und damit ohne Netz prüfbar.

## Ollamas Vorgabe-Port. Wer LM Studio benutzt, setzt `url` auf 1234.
const URL := "http://127.0.0.1:11434/v1/chat/completions"
const MODEL := "qwen2.5:3b-instruct"

## Sekunden, nach denen die Anfrage abgebrochen wird. Kürzer als SentenceJudge wartet:
## eine Verbindung, die dann noch offen ist, hilft niemandem mehr.
const HTTP_TIMEOUT := 3.5

## Wie viel Spielraum das Modell bekommt. Es soll ein Urteil und einen Satz Rückmeldung
## liefern, keinen Aufsatz.
const MAX_TOKENS := 200

## Was in `last_note` steht, wenn schon eine Anfrage offen ist. Als Konstante, weil ein
## Test daran hängt: dieser Fall war einmal der einzige, der gar nichts sagte.
const BUSY_NOTE := "Vorige Anfrage läuft noch — diese wurde nicht gestellt."

var url := URL
var model := MODEL

## Wie lange auf den Dienst gewartet wird, bevor die Verbindung abgebrochen wird. Im Spiel
## bleibt es bei HTTP_TIMEOUT — der Boss holt vier Sekunden lang aus, eine Antwort nach
## dreißig ist wertlos.
##
## Verstellbar, weil eine MESSUNG etwas anderes fragt als der Kampf: dort geht es darum, ob
## ein Modell die Aufgabe kann, und nicht darum, ob es das rechtzeitig tut. Ohne diese Naht
## lief jede Anfrage an ein 3-B-Modell auf der CPU in den Abbruch und die Messung meldete
## „kein Dienst erreichbar", während der Dienst einwandfrei rechnete. Gelesen wird der Wert
## in _ready(), also VOR dem Einhängen setzen.
var http_timeout := HTTP_TIMEOUT

## Woran es beim letzten Mal lag, im Klartext — leer, solange alles in Ordnung war.
##
## `parse_reply()` gibt {} zurück, wenn KEIN Dienst antwortet, und ebenso, wenn ein Modell
## antwortet, das sich nicht an die Form hält. Für das Spiel ist beides dasselbe („kein
## Beitrag"), und das soll es bleiben. Beim Messen und in der Werkbank ist es der
## Unterschied zwischen „nichts installiert" und „falsches Modell" — und ohne diese Naht
## sähe man an derselben Stelle denselben Satz und suchte am falschen Ende.
var last_note := ""

var _http: HTTPRequest
var _on_done: Callable


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = http_timeout
	add_child(_http)
	_http.request_completed.connect(_on_completed)


## Die Callable-Form, die SentenceJudge erwartet.
func judge(sentence: Dictionary, answer: String, on_done: Callable) -> void:
	if _http == null or _on_done.is_valid():
		# Eine Anfrage zur Zeit. Die zweite bekommt kein Urteil — das ist kein Fehler,
		# sondern der Normalfall „kein Modell da".
		#
		# Sie bekommt aber eine Begründung: gibt SentenceJudge früher auf, als HTTP_TIMEOUT
		# lang ist, bleibt die erste Anfrage offen und JEDE weitere fällt still hierher.
		# Wer misst, hat dann 24 von 25 Antworten nie gefragt — und sieht es nirgends.
		last_note = BUSY_NOTE
		on_done.call({})
		return
	_on_done = on_done
	last_note = ""
	var body := JSON.stringify({
		"model": model,
		"temperature": 0.0,
		"max_tokens": MAX_TOKENS,
		"messages": [{"role": "user", "content": prompt_for(sentence, answer)}],
	})
	var error := _http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		last_note = "Anfrage an %s nicht abgesetzt (Fehler %d)" % [url, error]
		_finish({})


## Steht noch eine Anfrage offen? Solange das gilt, wird jede weitere abgewiesen — wer
## der Reihe nach fragt (das Messskript), wartet darauf.
func busy() -> bool:
	return _on_done.is_valid()


## Der Auftrag an das Modell. Es bewertet NICHT auf freiem Feld: es bekommt den Satz, die
## Musterlösung und die gleichwertigen Formulierungen mit — die Frage ist nur noch, ob die
## Antwort eine weitere gleichwertige Formulierung ist. Das ist die Frage, die auch ein
## kleines Modell noch beantworten kann.
static func prompt_for(sentence: Dictionary, answer: String) -> String:
	var lines := PackedStringArray([
		"Du bewertest die Übersetzung einer Schülerin oder eines Schülers (Klasse 9).",
		"Deutscher Satz: %s" % str(sentence.get("source_text", "")),
		"Musterlösung: %s" % str(sentence.get("reference_translation", "")),
	])
	var accepted := Array(sentence.get("accepted", []))
	if not accepted.is_empty():
		lines.append("Ebenfalls richtig: %s" % "; ".join(PackedStringArray(accepted.map(str))))
	lines.append("Antwort: %s" % answer)
	lines.append(
		"Ist die Antwort sinngemäß richtig? Im Zweifel großzügig sein: eine richtige "
		+ "Antwort abzulehnen ist schlimmer, als eine falsche durchzulassen."
	)
	lines.append(
		'Antworte NUR mit JSON: {"quality": 0.0 bis 1.0, "feedback": "ein kurzer Satz '
		+ 'auf Deutsch"}'
	)
	return "\n".join(lines)


## Zieht { "quality", "feedback" } aus der Antwort des Dienstes, oder {} wenn dabei
## irgendetwas nicht stimmt. Ein Modell, das sich nicht an die Form hält, ist hier kein
## Fehlerfall, sondern schlicht ein Modell ohne Beitrag.
static func parse_reply(body: String) -> Dictionary:
	var envelope: Variant = JSON.parse_string(body)
	if not (envelope is Dictionary):
		return {}
	var choices: Array = Array((envelope as Dictionary).get("choices", []))
	if choices.is_empty():
		return {}
	var message: Dictionary = (choices[0] as Dictionary).get("message", {})
	return parse_content(str(message.get("content", "")))


## Das JSON-Objekt aus der Ausgabe des Modells. Kleine Modelle schreiben gern noch einen
## Satz davor oder legen einen Codeblock darum — deshalb wird von der ersten Klammer bis
## zur letzten gelesen, statt auf ein sauberes Dokument zu hoffen.
static func parse_content(content: String) -> Dictionary:
	var start := content.find("{")
	var end := content.rfind("}")
	if start < 0 or end <= start:
		return {}
	var parsed: Variant = JSON.parse_string(content.substr(start, end - start + 1))
	if not (parsed is Dictionary):
		return {}
	var out: Dictionary = parsed
	if not out.has("quality"):
		return {}
	return {
		"quality": clampf(float(out["quality"]), 0.0, 1.0),
		"feedback": str(out.get("feedback", "")),
	}


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_note = ""
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
	var reply := parse_reply(text)
	if reply.is_empty():
		last_note = "Antwort ohne verwertbares Urteil: %s" % _excerpt(text)
		_report("Antwort ohne verwertbares Urteil von %s" % url, text)
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
	if done.is_valid():
		done.call(reply)
