class_name AnswerEvaluator
extends RefCounted
## Evaluates player answers.
##
## Two modes, matching the game design:
##  - evaluate_answers(): tolerant match for Vokabel-Antworten (offline, deterministisch).
##  - evaluate_sentence(): semantic quality score for boss sentences.
##
## The sentence evaluator is deliberately behind a pluggable interface. The
## default implementation is a simple offline heuristic (token overlap). A
## local LLM backend can be plugged in later by replacing `sentence_backend`
## WITHOUT changing any caller — see docs/ARCHITECTURE.md.

## Optional callable: func(prompt, reference, answer) -> { "quality": float, "feedback": String }
var sentence_backend: Callable = Callable()

## Ziel ist Englisch lernen, nicht Deutsch — deshalb ist der deutsche Artikel
## optional. Wird auf Eingabe UND hinterlegte Antwort angewendet, sodass
## "das Haus" und "Haus" gleichwertig akzeptiert werden (keine Datenmigration).
const _DE_ARTICLES := ["der ", "die ", "das ", "eine ", "ein "]

## Grammatik-Platzhalter aus dem Lehrbuch ("criticize sb. (for)"). Sie werden auf EIN
## Wildcard-Token abgebildet, sodass Schreibweise und Sprache der Notation gleichgültig
## sind: "sb." = "sb" = "somebody" = "jn." = "jemanden". Zusätzlich darf jeder Platzhalter
## ganz entfallen. Längere Alternativen zuerst, damit die Alternation nicht kürzer greift.
const WILDCARD := "•"
const PLACEHOLDER_PATTERN := \
	"(?<!\\p{L})(?:somebody|someone|something|jemandem|jemanden|jemand|etwas|etw\\.?" \
	+ "|sth\\.?|sb\\.?|jdn\\.?|jm\\.?|jn\\.?|jd\\.?|…|\\.\\.\\.)(?!\\p{L})"

## Klammergruppen sind optional: "(for)", "(wegen)", aber auch Glossen wie "(Kleidung)"
## oder "(Pl.)". Für die Auswertung ist beides dasselbe — was in Klammern steht, darf
## getippt werden, mit oder ohne Klammern, oder eben nicht.
const GROUP_PATTERN := "\\(([^)]*)\\)"

## Deckel gegen Kombinatorik. Im Bestand liegt das Maximum bei einer Klammergruppe und
## zwei Platzhaltern (10 Varianten); was darüber liegt, wird nur noch "behalten".
const MAX_GROUPS := 3
const MAX_PLACEHOLDERS := 4

static var _group_re: RegEx = RegEx.create_from_string(GROUP_PATTERN)
static var _placeholder_re: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)


## Wertet `answer` gegen alle hinterlegten Antworten aus.
##
## Rückgabe:
##   "matched":   passt die Antwort?
##   "complete":  passt sie OHNE dass etwas Optionales weggelassen wurde? Notation darf
##                abweichen ("criticize sb for" ist vollständig), ein fehlender Bestandteil
##                nicht ("criticize" ist richtig, aber unvollständig).
##   "canonical": die getroffene hinterlegte Antwort in Originalschreibweise — bei
##                unvollständigem Treffer die Form, die der Spieler noch sehen soll.
func evaluate(accepted: Array, answer: String) -> Dictionary:
	var result := {"matched": false, "complete": false, "canonical": ""}
	var input := _variants(answer)
	if input.is_empty():
		return result
	for a in accepted:
		var candidate := str(a)
		var forms := _variants(candidate)
		var hit := false
		var complete := false
		for key in forms:
			if input.has(key):
				hit = true
				complete = complete or bool(forms[key])
		if not hit:
			continue
		if not bool(result["matched"]):
			result["matched"] = true
			result["canonical"] = candidate
		if complete:
			# Bester Fall — die Suche kann hier aufhören.
			result["complete"] = true
			result["canonical"] = candidate
			return result
	return result


## Returns true if `answer` matches any accepted answer.
## Nimmt direkt die Liste gültiger Antworten (z. B. task.accepted_answers).
func evaluate_answers(accepted: Array, answer: String) -> bool:
	return bool(evaluate(accepted, answer)["matched"])


## Kompatibilitäts-Helfer: prüft gegen entry["answers"].
func evaluate_vocab(entry: Dictionary, answer: String) -> bool:
	return evaluate_answers(entry.get("answers", []), answer)


## Returns { "quality": 0.0..1.0, "feedback": String }.
func evaluate_sentence(prompt: String, reference: String, answer: String) -> Dictionary:
	if sentence_backend.is_valid():
		return sentence_backend.call(prompt, reference, answer)
	return _heuristic_sentence(reference, answer)


func _heuristic_sentence(reference: String, answer: String) -> Dictionary:
	var ref_tokens := _tokens(reference)
	var ans_tokens := _tokens(answer)
	if ref_tokens.is_empty():
		return {"quality": 0.0, "feedback": "Keine Referenz hinterlegt."}
	var hits := 0
	for t in ref_tokens:
		if t in ans_tokens:
			hits += 1
	var quality := float(hits) / float(ref_tokens.size())
	var feedback := "Gut getroffen!" if quality >= 0.8 else "Fast — achte auf die fehlenden Wörter."
	if quality < 0.4:
		feedback = "Versuch es nochmal, viele Kernbegriffe fehlen."
	return {"quality": quality, "feedback": feedback}


## Alle Schreibweisen, unter denen ein String akzeptiert wird: Variante -> „vollständig".
## Vollständig heißt: bei der Erzeugung wurde nichts weggelassen. Ein Vergleich zweier
## Strings ist damit der Schnitt ihrer Variantenmengen — symmetrisch, sodass es keine
## Rolle spielt, ob Klammern und Platzhalter in den Daten oder in der Eingabe stehen.
func _variants(s: String) -> Dictionary:
	var base := _normalize(s)
	if base.is_empty():
		return {}
	var result := {}
	# Erst die Klammern, dann die Platzhalter: ein Platzhalter kann INNERHALB einer
	# Klammergruppe stehen ("prefer sth. (to sth.)"), und auch der soll zum Wildcard
	# werden. Zwei Stufen, weil sich die Bereiche sonst überlappen würden.
	for group_form in _expand(base, _group_slots(base)):
		for form in _expand(str(group_form[0]), _placeholder_slots(str(group_form[0]))):
			var key := _strip_article(str(form[0]))
			if key.is_empty():
				continue
			var complete: bool = bool(group_form[1]) and bool(form[1])
			result[key] = bool(result.get(key, false)) or complete
	if result.is_empty():
		result[base] = true
	return result


## Klammergruppen dreifach auflösen: behalten, entklammert, weggelassen. Nur das
## Weglassen macht die Variante unvollständig — Klammern sind bloß Notation.
func _group_slots(s: String) -> Array:
	var slots: Array = []
	for g in _group_re.search_all(s):
		if slots.size() >= MAX_GROUPS:
			break
		slots.append({
			"start": g.get_start(0),
			"end": g.get_end(0),
			"options": [[g.get_string(0), true], [g.get_string(1).strip_edges(), true], ["", false]],
		})
	return slots


## Platzhalter je Vorkommen entweder auf das Wildcard-Token abbilden (Notation egal,
## Struktur erhalten -> vollständig) oder weglassen (-> unvollständig).
func _placeholder_slots(s: String) -> Array:
	var slots: Array = []
	for m in _placeholder_re.search_all(s):
		if slots.size() >= MAX_PLACEHOLDERS:
			break
		slots.append({
			"start": m.get_start(0),
			"end": m.get_end(0),
			"options": [[WILDCARD, true], ["", false]],
		})
	return slots


## Setzt den String aus seinen festen Teilen und allen Kombinationen der optionalen
## Bereiche neu zusammen. Positionsbasiert und nicht über replace(), weil derselbe
## Platzhalter mehrfach vorkommen kann ("prefer sth. (to sth.)") und dann jedes
## Vorkommen einzeln entscheidbar sein muss.
## Rückgabe: Array von [String, bool complete].
func _expand(s: String, slots: Array) -> Array:
	if slots.is_empty():
		return [[_collapse(s), true]]
	var forms: Array = [["", true]]
	var cursor := 0
	for slot in slots:
		var fixed := s.substr(cursor, int(slot["start"]) - cursor)
		var next: Array = []
		for f in forms:
			for option in slot["options"]:
				next.append([
					str(f[0]) + fixed + str(option[0]),
					bool(f[1]) and bool(option[1]),
				])
		forms = next
		cursor = int(slot["end"])
	var tail := s.substr(cursor)
	var out: Array = []
	for f in forms:
		out.append([_collapse(str(f[0]) + tail), bool(f[1])])
	return out


## Vereinheitlicht Schreibweise: Kleinschreibung, typografische Zeichen, Mehrfach-
## Leerzeichen, Satzendzeichen ("That's fine by me." == "that's fine by me").
func _normalize(s: String) -> String:
	var normalized := s.strip_edges().to_lower()
	normalized = normalized.replace("’", "'").replace("‘", "'")
	normalized = normalized.replace("“", '"').replace("”", '"')
	normalized = normalized.replace("–", "-").replace("—", "-")
	while normalized.ends_with(".") or normalized.ends_with("!") or normalized.ends_with("?"):
		normalized = normalized.substr(0, normalized.length() - 1).strip_edges()
	return _strip_article(_collapse(normalized))


func _strip_article(s: String) -> String:
	for article in _DE_ARTICLES:
		if s.begins_with(article):
			return s.substr(article.length()).strip_edges()
	return s


## Mehrfach-Leerzeichen zusammenziehen — entsteht beim Weglassen von Bestandteilen.
## Auch direkt an den Klammern, sonst bliebe aus "(to sth.)" ohne Platzhalter ein
## "(to )" stehen, das die getippte Form "(to)" nicht mehr trifft.
func _collapse(s: String) -> String:
	var out := " ".join(s.split(" ", false))
	return out.replace("( ", "(").replace(" )", ")")


func _tokens(s: String) -> PackedStringArray:
	return _normalize(s).replace(".", " ").replace(",", " ").split(" ", false)
