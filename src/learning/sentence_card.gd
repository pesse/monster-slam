class_name SentenceCard
extends RefCounted
## Stufe 0 der Satzbewertung, die „Prüfkarte“ (ADR 0004): wertet den Lösungsschlüssel
## eines Satzes (`accepted`, `must_contain`, `pitfalls`) deterministisch aus, ohne Modell.
## Reine Rechnung ohne Zustand. Treffer- und Urteilsregeln: ADR 0004 und CONVENTIONS.
##
## Rückgabe:
##   "quality":   0..1, 0 solange `sure` falsch ist
##   "feedback":  Rückmeldung an den Spieler
##   "matched":   die getroffene Lösung in Originalschreibweise, "" ohne Treffer
##   "stage":     welche Stufe geantwortet hat
##   "sure":      Treffer oder bekannter Fehler; sonst darf Stufe 1 nachbessern
##   "overlap":   Nähe zum Wortlaut der Lösungen (0..1), nur für die Wortwahl der
##                Rückmeldung; 0, wo es ein Urteil gibt
##   "missing":   geforderte Wörter, die in der Antwort fehlen (Anzeige-Form)
##   "reference": die hinterlegte Musterlösung

## Kennung der Stufe im Ergebnis.
const STAGE := "card"

const MATCH_QUALITY := 1.0
## Getroffen, aber Optionales weggelassen (wie `AnswerEvaluator.evaluate()` bei Vokabeln).
const PARTIAL_QUALITY := 0.7
## Ein vorweggenommener Fehler (Stolperstelle).
const PITFALL_QUALITY := 0.35
## Die Karte hat kein Urteil (`sure` falsch), im Unterschied zu „nichts getippt“.
const NO_VERDICT := 0.0
## Ab dieser Nähe (`overlap`) heißt die Rückmeldung „nah dran“ statt „anderer Satz“.
const NEAR_QUALITY := 0.6

const EMPTY_FEEDBACK := "Da steht noch nichts."
const PRAISE_FEEDBACK := "Richtig!"
const INCOMPLETE_FEEDBACK := "Richtig — es fehlt nur eine Kleinigkeit."
const MISSING_FEEDBACK := "Fast — das Wort „%s“ gehört noch hinein."
const NEAR_FEEDBACK := "Nah dran. Vergleiche Wort für Wort."
const FAR_FEEDBACK := "Das ist noch ein anderer Satz. Lies den deutschen Satz noch einmal."


## Bewertet `answer` gegen den Lösungsschlüssel von `sentence`.
static func evaluate(sentence: Dictionary, answer: String) -> Dictionary:
	var evaluator := AnswerEvaluator.new()
	var result := {
		"quality": 0.0,
		"feedback": EMPTY_FEEDBACK,
		"matched": "",
		"stage": STAGE,
		"sure": true,
		"overlap": 0.0,
		"missing": [],
		"reference": str(sentence.get("reference_translation", "")),
	}
	var typed := answer.strip_edges()
	if typed.is_empty():
		return result

	var keys := solutions(sentence)
	var hit := evaluator.evaluate(keys, typed)
	if bool(hit["matched"]):
		result["matched"] = str(hit["canonical"])
		result["quality"] = MATCH_QUALITY if bool(hit["complete"]) else PARTIAL_QUALITY
		result["feedback"] = PRAISE_FEEDBACK if bool(hit["complete"]) else INCOMPLETE_FEEDBACK
		return result

	var tokens := evaluator.tokens(typed)
	var trap := pitfall_for(sentence, tokens, evaluator)
	if not trap.is_empty():
		result["feedback"] = str(trap.get("feedback", FAR_FEEDBACK))
		result["quality"] = PITFALL_QUALITY
		return result

	# Kein Urteil: nur Stufe 1 kann daraus einen Treffer machen. Die Nähe wählt nur die
	# Rückmeldung.
	result["sure"] = false
	result["quality"] = NO_VERDICT
	result["overlap"] = overlap(tokens, keys, evaluator)
	result["missing"] = missing_words(sentence, tokens, evaluator)
	var missing: Array = result["missing"]
	if not missing.is_empty():
		result["feedback"] = MISSING_FEEDBACK % str(missing[0])
	elif float(result["overlap"]) >= NEAR_QUALITY:
		result["feedback"] = NEAR_FEEDBACK
	else:
		result["feedback"] = FAR_FEEDBACK
	return result


## Alle Lösungen, die als richtig durchgehen: Musterlösung und `accepted`.
static func solutions(sentence: Dictionary) -> Array:
	var out: Array = []
	for candidate in [sentence.get("reference_translation", "")] + Array(sentence.get("accepted", [])):
		var text := str(candidate).strip_edges()
		if not text.is_empty() and not (text in out):
			out.append(text)
	return out


## Die erste passende Stolperstelle, oder {}. Sie passt, wenn alle ihre Bestandteile
## (`contains`) als Wortfolgen in der Antwort vorkommen.
static func pitfall_for(
	sentence: Dictionary, tokens: PackedStringArray, evaluator: AnswerEvaluator
) -> Dictionary:
	for raw in sentence.get("pitfalls", []):
		var trap: Dictionary = raw
		var parts: Array = Array(trap.get("contains", []))
		if parts.is_empty():
			continue
		var all_there := true
		for part in parts:
			if not contains_phrase(tokens, str(part), evaluator):
				all_there = false
				break
		if all_there:
			return trap
	return {}


## Geforderte Wörter, die in der Antwort fehlen, in Anzeige-Form (erste hinterlegte Form
## bzw. Lemma).
static func missing_words(
	sentence: Dictionary, tokens: PackedStringArray, evaluator: AnswerEvaluator
) -> Array:
	var out: Array = []
	for raw in sentence.get("must_contain", []):
		var required: Dictionary = raw
		var forms := forms_of(required)
		if forms.is_empty():
			continue
		var found := false
		for form in forms:
			if contains_phrase(tokens, str(form), evaluator):
				found = true
				break
		if not found:
			out.append(str(forms[0]))
	return out


## Die zulässigen Formen einer must_contain-Forderung; ohne `forms` aus dem Bestand.
static func forms_of(required: Dictionary) -> Array:
	var listed := Array(required.get("forms", []))
	if not listed.is_empty():
		return listed
	return known_forms(str(required.get("lexeme_id", "")))


## Alle Schreibweisen, unter denen der Bestand ein Lexem kennt: Lemma, Alternativen und
## die Einträge aus lexeme_forms.
static func known_forms(lexeme_id: String) -> Array:
	var lexeme := ContentRegistry.get_entry("lexemes", lexeme_id)
	if lexeme.is_empty():
		return []
	var out: Array = []
	for candidate in [lexeme.get("lemma_en", "")] + Array(lexeme.get("lemma_en_alt", [])):
		var text := str(candidate).strip_edges()
		if not text.is_empty() and not (text in out):
			out.append(text)
	for form in ContentRegistry.forms_for(lexeme_id):
		var value := str((form as Dictionary).get("value", "")).strip_edges()
		if not value.is_empty() and not (value in out):
			out.append(value)
	return out


## Kommt `phrase` als zusammenhängende Wortfolge in `tokens` vor? Wortweise, damit „go“
## nicht in „going“ steckt.
static func contains_phrase(
	tokens: PackedStringArray, phrase: String, evaluator: AnswerEvaluator
) -> bool:
	var needle := evaluator.tokens(phrase)
	if needle.is_empty() or needle.size() > tokens.size():
		return false
	for start in range(tokens.size() - needle.size() + 1):
		var same := true
		for i in needle.size():
			if tokens[start + i] != needle[i]:
				same = false
				break
		if same:
			return true
	return false


## Die beste Wort-Übereinstimmung mit einer der Lösungen (F1 über die Wortmengen, 0..1).
## Keine Güte: sie sieht weder Reihenfolge noch Beugung (ADR 0004).
static func overlap(
	tokens: PackedStringArray, keys: Array, evaluator: AnswerEvaluator
) -> float:
	var best := 0.0
	for key in keys:
		var other := evaluator.tokens(str(key))
		if other.is_empty() or tokens.is_empty():
			continue
		var pool: Dictionary = {}
		for t in other:
			pool[t] = int(pool.get(t, 0)) + 1
		var shared := 0
		for t in tokens:
			if int(pool.get(t, 0)) > 0:
				pool[t] = int(pool[t]) - 1
				shared += 1
		best = maxf(best, 2.0 * float(shared) / float(tokens.size() + other.size()))
	return best
