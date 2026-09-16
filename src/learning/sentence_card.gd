class_name SentenceCard
extends RefCounted
## Stufe 0 der Satzbewertung — die „Prüfkarte" aus
## docs/adr/0004-satzbewertung-ohne-modell.md.
##
## Bewerten ist nur deshalb teuer, weil man es als offene Aufgabe behandelt. Der Autor des
## Satzes kennt aber die Lösung, die gleichwertigen Formulierungen (`accepted`), die
## Lexeme, um derentwillen der Satz überhaupt gestellt wird (`must_contain`), und die
## Fehler, die zu erwarten sind (`pitfalls`). Diese Klasse ist die Auswertung dieses
## Schlüssels: deterministisch, unter einer Millisekunde, ohne Modell, ohne Netz.
##
## Sie ist reine Rechnung ohne Zustand, Szene und Autoload — wie ChestReward und
## Experience — und damit für sich prüfbar (tests/sentence_card_test.gd). Wer sie aufruft
## und wer eine zweite Stufe daneben stellt, ist SentenceJudge.
##
## **Ein Treffer schlägt jede Stolperstelle.** In einem Lernspiel für Kinder ist der zu
## Unrecht getadelte richtige Satz der teuerste Fehler, den das System machen kann —
## teurer als eine durchgewinkte falsche Antwort. Wer einmal erlebt hat, dass das Spiel
## seine richtige Übersetzung nicht anerkennt, glaubt ihm den nächsten Tadel nicht mehr.
## Dieselbe Regel steht als Datentest daneben (tests/sentence_data_test.gd: keine
## Stolperstelle darf auf eine akzeptierte Lösung passen).
##
## Rückgabe (der Vertrag aus dem ADR, plus was die Werkbank und die zweite Stufe brauchen):
##   "quality":   0..1
##   "feedback":  Rückmeldung an den Spieler
##   "matched":   die getroffene Lösung in Originalschreibweise, "" ohne Treffer
##   "stage":     welche Stufe geantwortet hat
##   "sure":      Karte weiß Bescheid (Treffer oder bekannter Fehler) — sonst darf
##                Stufe 1 nachbessern
##   "missing":   geforderte Wörter, die in der Antwort fehlen (Anzeige-Form)
##   "reference": die hinterlegte Musterlösung

## Wer geantwortet hat. Steht im Ergebnis, damit die Werkbank (und später der Kampf)
## Karte und Modell auseinanderhalten kann, ohne zwei Verträge zu kennen.
const STAGE := "card"

## Ein Volltreffer.
const MATCH_QUALITY := 1.0
## Getroffen, aber es wurde etwas Optionales weggelassen (Klammergruppe, Platzhalter) —
## dieselbe Unterscheidung, die AnswerEvaluator.evaluate() für Vokabeln macht.
const PARTIAL_QUALITY := 0.7
## Ein vorweggenommener Fehler. Nicht 0: der Satz steht ja im Wesentlichen da, es hakt an
## einer Stelle — und genau die benennt die Rückmeldung.
const PITFALL_QUALITY := 0.35
## Deckel, wenn ein gefordertes Lexem fehlt. Der Satz wird um dieses Wortes willen
## gestellt; ohne das Wort ist er nicht gelöst, egal wie ähnlich der Rest klingt.
const MISSING_CAP := 0.5
## Ab hier heißt die Rückmeldung „nah dran" statt „anderer Satz".
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

	# Weder bekannte Lösung noch bekannter Fehler: die Karte schätzt — und sagt, dass sie
	# schätzt. Genau hier darf eine zweite Stufe nachbessern (siehe SentenceJudge).
	result["sure"] = false
	result["quality"] = overlap(tokens, keys, evaluator)
	result["missing"] = missing_words(sentence, tokens, evaluator)
	var missing: Array = result["missing"]
	if not missing.is_empty():
		result["quality"] = minf(float(result["quality"]), MISSING_CAP)
		result["feedback"] = MISSING_FEEDBACK % str(missing[0])
	elif float(result["quality"]) >= NEAR_QUALITY:
		result["feedback"] = NEAR_FEEDBACK
	else:
		result["feedback"] = FAR_FEEDBACK
	return result


## Alle Lösungen, die als richtig durchgehen: die Musterlösung und die gleichwertigen
## Formulierungen. EINE Liste, damit „Referenz" und „Alternative" nicht zwei Wege durch
## die Bewertung nehmen — für den Spieler ist beides einfach richtig.
static func solutions(sentence: Dictionary) -> Array:
	var out: Array = []
	for candidate in [sentence.get("reference_translation", "")] + Array(sentence.get("accepted", [])):
		var text := str(candidate).strip_edges()
		if not text.is_empty() and not (text in out):
			out.append(text)
	return out


## Die erste passende Stolperstelle, oder {}. Eine Stolperstelle passt, wenn ALLE ihre
## Bestandteile in der Antwort vorkommen — sie ist eine Liste von Bestandteilen und kein
## regulärer Ausdruck, damit ein Generierungslauf sie zuverlässig erzeugen und ein Test sie
## prüfen kann. Ein fehlerhaftes Muster in den Daten kostet dann höchstens eine
## ausbleibende Rückmeldung.
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


## Geforderte Wörter, die in der Antwort fehlen — als Anzeige-Form (die erste hinterlegte
## Form bzw. das Lemma), denn genau die soll in der Rückmeldung stehen.
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


## Die zulässigen Formen einer must_contain-Forderung. Stehen sie nicht in den Daten,
## kommen sie aus dem Bestand (Lemma + lexeme_forms) — dieselbe Quelle, gegen die
## tests/sentence_data_test.gd die hinterlegten Formen prüft.
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


## Kommt `phrase` als zusammenhängende Wortfolge in `tokens` vor? Wortweise und nicht als
## Teilzeichenkette, damit „reef" nicht in „reeforama" steckt und „go" nicht in „going".
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
## Nur für den unsicheren Fall — als Urteil taugt eine Überschneidung nicht, als Schätzung
## für „nah dran" gegen „ganz anderer Satz" reicht sie.
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
