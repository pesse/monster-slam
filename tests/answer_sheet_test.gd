extends GdUnitTestSuite
## Der ANTWORTBOGEN selbst (src/dev/answer_sheet.json) — nicht das Messergebnis.
##
## Der Bogen ist der Maßstab, an dem src/dev/measure_sentences.gd die Bewertung misst.
## Ein Maßstab, der in sich nicht stimmt, macht jede Messung wertlos, und zwar still: eine
## Stolperstelle, die auf eine richtige Lösung passt, erzeugt ein Falsch-Negativ, das im
## Bogen steht und nicht im Code. Deshalb gelten hier dieselben Regeln, die
## tests/sentence_data_test.gd an die ausgelieferten Sätze anlegt — nur ohne Submodule,
## denn die Sätze im Bogen sind erfunden.
##
## Was hier NICHT geprüft wird: ob die Bewertung die Antworten richtig einordnet. Das ist
## das Messergebnis, und es darf sich ändern, ohne dass ein Test rot wird.

const SHEET := "res://src/dev/answer_sheet.json"
const KINDS := ["muster", "variante", "frei", "falle", "fehler", "leer"]

var _sheet: Dictionary = {}
var _sentences: Array = []
var _evaluator := AnswerEvaluator.new()


func before_test() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET))
	_sheet = parsed if parsed is Dictionary else {}
	_sentences = Array(_sheet.get("sentences", []))


## Ohne diesen Satz wäre jede Schleife unten still grün.
func test_the_sheet_carries_sentences_and_answers() -> void:
	assert_array(_sentences).override_failure_message(
			"Kein Antwortbogen unter %s — es wurde nichts geprüft." % SHEET).is_not_empty()
	for sentence in _sentences:
		assert_array(Array((sentence as Dictionary).get("answers", []))
		).override_failure_message("'%s' hat keine Antworten" % sentence.get("id", "?")
		).is_not_empty()


## Die Regel, um derentwillen der Bogen geprüft wird: keine Stolperstelle darf auf eine
## akzeptierte Lösung passen. Dieselbe Regel wie in den ausgelieferten Daten — hier
## schlägt ihr Bruch nur nicht auf ein Kind durch, sondern auf die Messung.
func test_no_pitfall_matches_an_accepted_solution() -> void:
	for sentence in _sentences:
		for solution in SentenceCard.solutions(sentence):
			var trap := SentenceCard.pitfall_for(
					sentence, _evaluator.tokens(str(solution)), _evaluator)
			assert_bool(trap.is_empty()).override_failure_message(
					"'%s': die Stolperstelle %s passt auf die richtige Lösung „%s“"
					% [sentence.get("id", "?"), trap.get("contains", []), solution]).is_true()


func test_every_accepted_solution_contains_the_required_words() -> void:
	for sentence in _sentences:
		for solution in SentenceCard.solutions(sentence):
			var missing := SentenceCard.missing_words(
					sentence, _evaluator.tokens(str(solution)), _evaluator)
			assert_array(missing).override_failure_message(
					"'%s': in der richtigen Lösung „%s“ fehlt %s"
					% [sentence.get("id", "?"), solution, missing]).is_empty()


func test_every_pitfall_has_parts_and_something_to_say() -> void:
	for sentence in _sentences:
		for trap in sentence.get("pitfalls", []):
			var id := str(sentence.get("id", "?"))
			assert_array(Array((trap as Dictionary).get("contains", []))
			).override_failure_message("'%s' hat eine Stolperstelle ohne Bestandteile" % id
			).is_not_empty()
			assert_str(str((trap as Dictionary).get("feedback", ""))
			).override_failure_message("'%s' hat eine Stolperstelle ohne Rückmeldung" % id
			).is_not_empty()


## Der Bogen soll OHNE das private Submodule gelten. Das hängt an einer einzigen Stelle:
## nennt eine Forderung ihre Formen nicht selbst, holt SentenceCard.forms_of() sie aus der
## ContentRegistry — und die kennt die erfundenen Lexeme nicht. Die Forderung liefe dann
## ins Leere, ohne dass irgendetwas rot würde.
func test_every_requirement_brings_its_own_forms() -> void:
	for sentence in _sentences:
		for required in sentence.get("must_contain", []):
			assert_array(Array((required as Dictionary).get("forms", []))
			).override_failure_message(
					"'%s' fordert '%s' ohne eigene Formen — das fragte die ContentRegistry"
					% [sentence.get("id", "?"), (required as Dictionary).get("lexeme_id", "?")]
			).is_not_empty()


## `expect` ist das Urteil einer Lehrkraft und muss eines von zweien sein; `kind` sortiert
## den Befund und muss aus der Liste kommen, sonst taucht eine Art in der Auswertung auf,
## die niemand erklärt hat.
func test_every_answer_is_labelled() -> void:
	for sentence in _sentences:
		for answer in Array((sentence as Dictionary).get("answers", [])):
			var id := "%s/„%s“" % [sentence.get("id", "?"), (answer as Dictionary).get("text", "")]
			assert_array(["richtig", "falsch"]).override_failure_message(
					"%s: unbekannte Erwartung '%s'" % [id, (answer as Dictionary).get("expect", "")]
			).contains([str((answer as Dictionary).get("expect", ""))])
			assert_array(KINDS).override_failure_message(
					"%s: unbekannte Art '%s'" % [id, (answer as Dictionary).get("kind", "")]
			).contains([str((answer as Dictionary).get("kind", ""))])


## Die Etiketten müssen zum Schlüssel passen: was als `muster` oder `variante` dasteht,
## MUSS von der Prüfkarte getroffen werden. Tut es das nicht, ist nicht die Bewertung
## schlecht, sondern der Bogen falsch beschriftet — und die Messung zählte ein
## Falsch-Negativ, das keines ist.
func test_a_listed_answer_is_really_listed() -> void:
	for sentence in _sentences:
		for answer in Array((sentence as Dictionary).get("answers", [])):
			var kind := str((answer as Dictionary).get("kind", ""))
			if not (kind in ["muster", "variante"]):
				continue
			var text := str((answer as Dictionary).get("text", ""))
			assert_bool(_evaluator.evaluate_answers(SentenceCard.solutions(sentence), text)
			).override_failure_message(
					"'%s': „%s“ ist als '%s' beschriftet, steht aber in keiner Lösung"
					% [sentence.get("id", "?"), text, kind]).is_true()
			assert_str(str((answer as Dictionary).get("expect", ""))).override_failure_message(
					"'%s': „%s“ steht in den Lösungen und kann nicht falsch sein"
					% [sentence.get("id", "?"), text]).is_equal("richtig")


## Umgekehrt: was als `frei` dasteht, ist richtig und NICHT hinterlegt — das ist genau die
## Klasse, um derentwillen es Stufe 1 gibt. Stünde sie doch im Schlüssel, misste der Bogen
## an der interessanten Stelle nichts.
func test_a_free_answer_is_really_free() -> void:
	for sentence in _sentences:
		for answer in Array((sentence as Dictionary).get("answers", [])):
			if str((answer as Dictionary).get("kind", "")) != "frei":
				continue
			var text := str((answer as Dictionary).get("text", ""))
			assert_bool(_evaluator.evaluate_answers(SentenceCard.solutions(sentence), text)
			).override_failure_message(
					"'%s': „%s“ ist als 'frei' beschriftet, steht aber im Schlüssel"
					% [sentence.get("id", "?"), text]).is_false()


## Ein Bogen aus lauter richtigen Antworten misst keine Falsch-Positiven, einer aus lauter
## falschen keine Falsch-Negativen — und die eine Zahl, an der die Entscheidung hängt, ist
## die der Falsch-Negativen.
func test_both_verdicts_are_represented() -> void:
	var counted := {"richtig": 0, "falsch": 0}
	for sentence in _sentences:
		for answer in Array((sentence as Dictionary).get("answers", [])):
			var expect := str((answer as Dictionary).get("expect", ""))
			if counted.has(expect):
				counted[expect] += 1
	assert_int(counted["richtig"]).override_failure_message(
			"Keine richtigen Antworten im Bogen — Falsch-Negative wären nicht messbar."
	).is_greater(0)
	assert_int(counted["falsch"]).override_failure_message(
			"Keine falschen Antworten im Bogen — Falsch-Positive wären nicht messbar."
	).is_greater(0)
