class_name SummaryCard
extends RefCounted
## Was der Schreib-Boss offline an einer Summary rechnet (docs/adr/0023-schreib-boss.md,
## Abschnitt 5): die Wortzahl für Randleiste und Länge, und die Suche der Modellzitate im
## Schülertext (`locate`). Alles Inhaltliche urteilt das Modell. Reine Rechnung ohne Zustand
## (tests/summary_card_test.gd).
##
## Normalisiert wird über `AnswerEvaluator.tokens()`. Das Wort wird hier nur aus dem Text
## GESCHNITTEN (WORD_PATTERN), damit jedes Token seine Stelle im Originaltext behält.
##
## Rückgabe von `check`:
##   "words":      Wortzahl (ein „don't“ ist ein Wort)
##   "length_ok":  Wortzahl im Zielbereich `target_words` (beide Grenzen eingeschlossen)

## Ein Wort: Buchstaben und Ziffern, im Wort auch Apostroph (gerade und typografisch) und
## Bindestrich — „don’t“ und „well-known“ sind je ein Wort.
const WORD_PATTERN := "[\\p{L}\\p{N}]+(?:['’‘\\-][\\p{L}\\p{N}]+)*"

static var _evaluator: AnswerEvaluator
static var _word_re: RegEx


static func check(task: Dictionary, text: String) -> Dictionary:
	var count := split_words(text).size()
	var target: Array = Array(task.get("target_words", []))
	var length_ok := count > 0
	if target.size() == 2:
		length_ok = count >= int(target[0]) and count <= int(target[1])
	return {"words": count, "length_ok": length_ok}


## Die Wörter eines Textes mit ihrer Stelle: [{ "token", "from", "to" }]. `from`/`to` sind
## Zeichenpositionen im Originaltext (`to` exklusiv), `token` die normalisierte Form.
## Ein Wort, das der Evaluator ganz wegnormalisiert, fällt heraus.
static func split_words(text: String) -> Array:
	_init_static()
	var out: Array = []
	for m in _word_re.search_all(text):
		var normalized := _evaluator.tokens(m.get_string())
		if normalized.is_empty():
			continue
		out.append({"token": " ".join(normalized), "from": m.get_start(), "to": m.get_end()})
	return out


## Sucht eine Wendung im Text, normalisiert (Groß/Klein, typografische Zeichen, Leerraum
## und Satzzeichen egal). Rückgabe { "from", "to" } im Originaltext für den ersten Treffer,
## {} ohne Treffer. Grundlage dafür, dass WritingJudge nur Zitate gelten lässt, die wirklich
## im Schülertext stehen.
static func locate(text: String, phrase: String) -> Dictionary:
	var words := split_words(text)
	var at := _find(_tokens_of(words), _tokens_of(split_words(phrase)), 0)
	if at.is_empty():
		return {}
	return {"from": int(words[at[0]]["from"]), "to": int(words[at[1] - 1]["to"])}


## Erste Stelle ab `start`, an der `needle` am Stück in `tokens` steht: [anfang, ende),
## leer ohne Treffer.
static func _find(tokens: PackedStringArray, needle: PackedStringArray, start: int) -> Array:
	if needle.is_empty():
		return []
	for i in range(start, tokens.size() - needle.size() + 1):
		var hit := true
		for k in range(needle.size()):
			if tokens[i + k] != needle[k]:
				hit = false
				break
		if hit:
			return [i, i + needle.size()]
	return []


static func _tokens_of(words: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for word in words:
		out.append(str(word["token"]))
	return out


static func _init_static() -> void:
	if _evaluator != null:
		return
	_evaluator = AnswerEvaluator.new()
	_word_re = RegEx.create_from_string(WORD_PATTERN)
