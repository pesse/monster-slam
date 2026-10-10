class_name SummaryCard
extends RefCounted
## Stufe 0 des Schreib-Bosses — die Offline-Prüfung einer Summary
## (docs/adr/0023-schreib-boss.md, Abschnitt 5).
##
## Was sich am Text selbst abzählen lässt, rechnet das Spiel, nicht das Modell: Wortzahl,
## ob der erste Satz Titel und Autor nennt, direkte Rede und wörtliche Übernahmen, eigene
## Meinung, Konnektoren. Deterministisch, ohne Netz, schnell genug für die Randleiste, die
## beim Tippen mitläuft. Reine Rechnung ohne Zustand wie SentenceCard
## (tests/summary_card_test.gd).
##
## Normalisiert wird über `AnswerEvaluator.tokens()` — dieselbe Zerlegung wie überall. Das
## Wort wird hier nur aus dem Text GESCHNITTEN (WORD_PATTERN), damit jedes Token seine
## Stelle im Originaltext behält; was ein Token gleich macht, entscheidet der Evaluator.
## Auf dieser Zerlegung sucht auch WritingJudge die Zitate des Modells (`locate`).
##
## Rückgabe von `check`:
##   "words":      Wortzahl (ein „don't“ ist ein Wort)
##   "intro":      der erste Satz nennt Titel UND Autor
##   "quotes":     direkte Rede in Anführungszeichen und wörtliche Übernahmen ab
##                 MIN_COPIED_WORDS Wörtern aus der Vorlage — als Stellen im Originaltext
##   "opinion":    Meinungs-Signalphrasen, als Stellen im Originaltext
##   "length_ok":  Wortzahl im Zielbereich `target_words` (beide Grenzen eingeschlossen)
##   "connectors": gefundene Konnektoren (Schreibweise aus CONNECTORS), in Textreihenfolge

## Ab so vielen Wörtern am Stück gilt eine Übereinstimmung mit der Vorlage als
## abgeschrieben (ADR 0023). Darunter liegen Allerweltswendungen wie „at the end of“.
const MIN_COPIED_WORDS := 5

## Ein Wort: Buchstaben und Ziffern, im Wort auch Apostroph (gerade und typografisch) und
## Bindestrich — „don’t“ und „well-known“ sind je ein Wort.
const WORD_PATTERN := "[\\p{L}\\p{N}]+(?:['’‘\\-][\\p{L}\\p{N}]+)*"

## Direkte Rede: Text zwischen doppelten Anführungszeichen in allen üblichen Schreibweisen.
## Einfache Anführungszeichen bleiben außen vor — sie sind vom Apostroph nicht zu trennen.
const QUOTE_PATTERN := "\"[^\"\\n]+\"|“[^”\\n]+”|„[^“”\\n]+[“”]|«[^»\\n]+»|»[^«\\n]+«"

## Ein Satzende: Punkt, Ausrufe- oder Fragezeichen, gefolgt von Leerraum oder Textende.
const SENTENCE_END_PATTERN := "[.!?][\"”“»«]?(?=\\s|$)"

## Signalphrasen einer eigenen Meinung. Eine Summary gibt wieder, was im Text steht; die
## erste Person ist dort fast immer ein Zeichen für Meinung.
const OPINION_PHRASES := [
	"i think", "i believe", "i feel", "i guess", "i hope", "i wish", "i'm sure",
	"i am sure", "in my opinion", "in my view", "personally", "i like", "i liked",
	"i love", "i loved", "i hate", "i hated", "i don't like", "i didn't like",
	"i agree", "i disagree", "my favourite", "my favorite", "i would", "i'd",
]

## Konnektoren, allgemeines Englisch (ADR 0023: später eine Lexem-Gruppe, offene Frage 3).
## Bei Überschneidung zählt die längste Wendung — „even though“, nicht zusätzlich „though“.
const CONNECTORS := [
	"first", "first of all", "at first", "then", "next", "after that", "afterwards",
	"later", "finally", "in the end", "at the end", "at last", "eventually",
	"meanwhile", "suddenly", "when", "while", "before", "after", "as soon as", "until",
	"because", "since", "so", "so that", "as a result", "therefore", "that is why",
	"this is why", "but", "however", "although", "though", "even though", "instead",
	"in contrast", "on the other hand", "nevertheless", "despite", "in spite of",
	"also", "in addition", "moreover", "furthermore", "besides",
]

## Artikel, die vor einem Titel wegfallen dürfen („The Last Bus“ → „Last Bus“).
const _TITLE_ARTICLES := ["the", "a", "an"]

static var _evaluator: AnswerEvaluator
static var _word_re: RegEx
static var _quote_re: RegEx
static var _end_re: RegEx


static func check(task: Dictionary, text: String) -> Dictionary:
	var words := split_words(text)
	var tokens := _tokens_of(words)
	var count := words.size()
	var target: Array = Array(task.get("target_words", []))
	var length_ok := count > 0
	if target.size() == 2:
		length_ok = count >= int(target[0]) and count <= int(target[1])
	return {
		"words": count,
		"intro": has_intro(task, text),
		"quotes": quotes(task, text, words, tokens),
		"opinion": _phrases_at(text, words, tokens, OPINION_PHRASES),
		"length_ok": length_ok,
		"connectors": connectors(tokens),
	}


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


## Der erste Satz nennt Titel und Autor. Der Titel darf ohne Anfangsartikel stehen, der
## Autor auch nur mit Nachnamen („In the story by Linden …“) — eine Einleitung, die das
## Kind sichtbar richtig gebaut hat, soll nicht an einer Schreibweise scheitern.
static func has_intro(task: Dictionary, text: String) -> bool:
	var first := first_sentence(text)
	if first.is_empty():
		return false
	var tokens := _tokens_of(split_words(first))
	return _names_title(tokens, str(task.get("title", ""))) \
			and _names_author(tokens, str(task.get("author", "")))


## Der erste Satz des Textes, ohne führenden Leerraum. Ein Satzende ist ., ! oder ?
## (auch hinter einem schließenden Anführungszeichen) vor Leerraum oder Textende.
static func first_sentence(text: String) -> String:
	_init_static()
	var trimmed := text.strip_edges()
	var m := _end_re.search(trimmed)
	return trimmed if m == null else trimmed.substr(0, m.get_end())


## Direkte Rede und wörtliche Übernahmen, als Stellen im Originaltext. Ein Anführungszeichen
## um den Titel ist keine direkte Rede („In ‚The Lighthouse Cat‘ …“ ist die Regel, nicht
## der Fehler).
static func quotes(task: Dictionary, text: String, words: Array = [],
		tokens: PackedStringArray = PackedStringArray()) -> Array:
	_init_static()
	if words.is_empty():
		words = split_words(text)
		tokens = _tokens_of(words)
	var title := _tokens_of(split_words(str(task.get("title", ""))))
	var found: Array = []
	var spans: Array = []
	for m in _quote_re.search_all(text):
		var inner := _tokens_of(split_words(m.get_string()))
		if inner.is_empty() or _same_title(inner, title):
			continue
		found.append(m.get_string())
		spans.append([m.get_start(), m.get_end()])
	for run in copied_runs(tokens, _tokens_of(split_words(str(task.get("text", ""))))):
		var from := int(words[run[0]]["from"])
		var to := int(words[run[1] - 1]["to"])
		if spans.any(func(s): return from >= int(s[0]) and to <= int(s[1])):
			continue   # schon als direkte Rede gezählt
		found.append(text.substr(from, to - from))
	return found


## Die Abschnitte [start, ende) in `tokens`, die mindestens MIN_COPIED_WORDS Wörter am
## Stück mit der Vorlage teilen. Überlappende Treffer verschmelzen zu einem Abschnitt.
static func copied_runs(tokens: PackedStringArray, source: PackedStringArray) -> Array:
	var n := MIN_COPIED_WORDS
	var grams := {}
	for i in range(source.size() - n + 1):
		grams[" ".join(source.slice(i, i + n))] = true
	var runs: Array = []
	for i in range(tokens.size() - n + 1):
		if not grams.has(" ".join(tokens.slice(i, i + n))):
			continue
		if not runs.is_empty() and i <= int(runs[-1][1]):
			runs[-1][1] = i + n
		else:
			runs.append([i, i + n])
	return runs


## Gefundene Konnektoren in Textreihenfolge, jeder einmal. Die längste Wendung gewinnt;
## ihre Wörter zählen danach nicht noch einmal für eine kürzere.
static func connectors(tokens: PackedStringArray) -> Array:
	var phrases := CONNECTORS.duplicate()
	phrases.sort_custom(func(a, b): return str(a).split(" ").size() > str(b).split(" ").size())
	var used := {}
	var hits: Array = []   # [position, Wendung]
	for phrase in phrases:
		var needle := _tokens_of(split_words(str(phrase)))
		var start := 0
		while true:
			var at := _find(tokens, needle, start)
			if at.is_empty():
				break
			start = at[0] + 1
			if range(at[0], at[1]).any(func(k): return used.has(k)):
				continue
			for k in range(at[0], at[1]):
				used[k] = true
			hits.append([at[0], phrase])
	hits.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var out: Array = []
	for hit in hits:
		if not out.has(hit[1]):
			out.append(hit[1])
	return out


static func _phrases_at(text: String, words: Array, tokens: PackedStringArray,
		phrases: Array) -> Array:
	var hits: Array = []   # [from, to]
	for phrase in phrases:
		var needle := _tokens_of(split_words(str(phrase)))
		var start := 0
		while true:
			var at := _find(tokens, needle, start)
			if at.is_empty():
				break
			start = at[0] + 1
			hits.append([int(words[at[0]]["from"]), int(words[at[1] - 1]["to"])])
	hits.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var out: Array = []
	var last_to := -1
	for hit in hits:
		if int(hit[0]) < last_to:
			continue   # „I don't like“ enthält kein zweites „I“-Signal
		out.append(text.substr(int(hit[0]), int(hit[1]) - int(hit[0])))
		last_to = int(hit[1])
	return out


static func _names_title(tokens: PackedStringArray, title: String) -> bool:
	var needle := _tokens_of(split_words(title))
	if needle.is_empty():
		return false
	if not _find(tokens, needle, 0).is_empty():
		return true
	if needle.size() > 1 and needle[0] in _TITLE_ARTICLES:
		return not _find(tokens, needle.slice(1), 0).is_empty()
	return false


static func _names_author(tokens: PackedStringArray, author: String) -> bool:
	var needle := _tokens_of(split_words(author))
	if needle.is_empty():
		return false
	if not _find(tokens, needle, 0).is_empty():
		return true
	return tokens.has(needle[needle.size() - 1])


static func _same_title(inner: PackedStringArray, title: PackedStringArray) -> bool:
	if title.is_empty():
		return false
	if inner == title:
		return true
	return title.size() > 1 and title[0] in _TITLE_ARTICLES and inner == title.slice(1)


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
	_quote_re = RegEx.create_from_string(QUOTE_PATTERN)
	_end_re = RegEx.create_from_string(SENTENCE_END_PATTERN)
