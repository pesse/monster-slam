extends GdUnitTestSuite
## Stufe 0 der Satzbewertung — die Prüfkarte (src/learning/sentence_card.gd,
## docs/adr/0004-satzbewertung-ohne-modell.md).
##
## Geprüft wird an einem ERFUNDENEN Satz und nicht am Bestand: hier stehen die REGELN, und
## sie sollen auch auf einem Rechner ohne installierte Inhalte gelten. Dass die
## ausgelieferten Sätze zu den Regeln passen, prüft tests/sentence_data_test.gd.

const SENTENCE := {
	"id": "sen.test.reef",
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"accepted": ["We saw the reef yesterday.", "Yesterday, we saw the reef."],
	"must_contain": [{"lexeme_id": "lex.test.reef", "forms": ["reef", "reefs"]}],
	"pitfalls": [{
		"contains": ["have seen", "yesterday"],
		"feedback": "Mit „yesterday“ steht das Simple Past: „saw“.",
	}],
	"grammar_tags": ["past_simple"],
	"difficulty": 2,
}

## Ein Satz ohne Schlüssel — so sehen die Sätze aus, die es vor ADR 0004 schon gab.
const BARE := {
	"id": "sen.test.bare",
	"source_text": "Der Drache schläft.",
	"reference_translation": "The dragon is asleep.",
}


func test_the_reference_is_a_hit() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "Yesterday we saw the reef.")
	assert_float(float(result["quality"])).is_equal(SentenceCard.MATCH_QUALITY)
	assert_str(str(result["matched"])).is_equal("Yesterday we saw the reef.")
	assert_bool(bool(result["sure"])).is_true()


## Groß-/Kleinschreibung und Satzzeichen sind keine Übersetzungsfehler — dieselbe
## Normalisierung, die AnswerEvaluator für Vokabeln schon leistet.
func test_case_and_punctuation_do_not_matter() -> void:
	assert_float(float(SentenceCard.evaluate(SENTENCE, "yesterday we saw the reef")["quality"])) \
			.is_equal(SentenceCard.MATCH_QUALITY)


func test_an_accepted_rephrasing_is_just_as_right() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "We saw the reef yesterday.")
	assert_float(float(result["quality"])).is_equal(SentenceCard.MATCH_QUALITY)
	assert_str(str(result["feedback"])).is_equal(SentenceCard.PRAISE_FEEDBACK)


## Der vorweggenommene Fehler bekommt die Rückmeldung, die er verdient — und nicht die
## Auskunft „viele Kernbegriffe fehlen", die die alte Token-Überschneidung gegeben hätte.
func test_a_known_mistake_gets_its_own_feedback() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "Yesterday we have seen the reef.")
	assert_float(float(result["quality"])).is_equal(SentenceCard.PITFALL_QUALITY)
	assert_str(str(result["feedback"])).is_equal(str(SENTENCE["pitfalls"][0]["feedback"]))
	# Ein bekannter Fehler ist ein Urteil, kein Zweifel: Stufe 1 hat hier nichts zu suchen.
	assert_bool(bool(result["sure"])).is_true()


## Eine Stolperstelle passt nur, wenn ALLE ihre Bestandteile dastehen. „have seen" allein
## ist im Perfekt ohne Zeitangabe kein Fehler.
func test_a_pitfall_needs_all_its_parts() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "We have seen the reef.")
	assert_float(float(result["quality"])).is_not_equal(SentenceCard.PITFALL_QUALITY)


## Die teuerste Sorte Fehler, die dieses System machen könnte: eine richtige Antwort
## tadeln. Trifft die Antwort eine hinterlegte Lösung, gilt sie — auch wenn eine
## Stolperstelle darauf passen würde. (Dass es in den DATEN gar nicht erst so weit kommt,
## hält tests/sentence_data_test.gd.)
func test_a_hit_beats_a_pitfall() -> void:
	var tricky := SENTENCE.duplicate(true)
	tricky["accepted"] = ["Yesterday we have seen the reef."]
	var result := SentenceCard.evaluate(tricky, "Yesterday we have seen the reef.")
	assert_float(float(result["quality"])).is_equal(SentenceCard.MATCH_QUALITY)


## Der Satz wird um seiner Lexeme willen gestellt. Fehlt das Wort, ist er nicht gelöst —
## wie ähnlich der Rest auch klingt.
func test_a_missing_word_is_named_and_is_no_hit() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "Yesterday we saw the coral.")
	assert_array(result["missing"] as Array).contains(["reef"])
	assert_float(float(result["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_str(str(result["feedback"])).contains("reef")


func test_any_listed_form_counts_as_the_word() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "Yesterday we saw reefs.")
	assert_array(result["missing"] as Array).is_empty()


## Wortweise und nicht als Teilzeichenkette: „reef" steckt in „reefs", aber „reefs" ist
## eine hinterlegte Form und „coral reefs" hat mit beidem nichts zu tun.
func test_a_word_is_a_word_and_not_a_substring() -> void:
	var evaluator := AnswerEvaluator.new()
	assert_bool(SentenceCard.contains_phrase(
			evaluator.tokens("we saw the reeforama"), "reef", evaluator)).is_false()
	assert_bool(SentenceCard.contains_phrase(
			evaluator.tokens("we saw the reef yesterday"), "saw the reef", evaluator)).is_true()


## Weder Lösung noch bekannter Fehler: genau der Fall, für den es Stufe 1 gibt. Die Karte
## hat hier KEIN Urteil — die Nähe am Wortlaut steht daneben und wählt nur die Worte.
func test_an_unknown_rephrasing_stays_unsure() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "The reef was what we saw yesterday.")
	assert_bool(bool(result["sure"])).is_false()
	assert_str(str(result["matched"])).is_empty()
	assert_float(float(result["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_float(float(result["overlap"])).is_greater(0.0)


## Die Regel, um derentwillen die Messung am Antwortbogen gelaufen ist: **ohne Urteil kein
## Treffer.** Vorher gab die Karte hier die Wort-Überschneidung als Güte aus, und ein
## Aufrufer mit einer Schwelle nahm sie für ein Urteil. Keine dieser Antworten darf eine
## Güte tragen, so nah sie dem Wortlaut auch kommt.
func test_without_a_verdict_nothing_scores() -> void:
	for answer in [
		"The reef was what we saw yesterday.",   # richtig, nur nicht hinterlegt
		"Yesterday we seen the reef.",           # falsch gebeugt
		"Yesterday we saw the coral.",           # falsches Wort
		"My bicycle is green.",                  # ganz anderer Satz
	]:
		var result := SentenceCard.evaluate(SENTENCE, str(answer))
		assert_bool(bool(result["sure"])).override_failure_message(
				"„%s“ sollte die Karte nicht sicher machen" % answer).is_false()
		assert_float(float(result["quality"])).override_failure_message(
				"„%s“ trägt eine Güte, obwohl die Karte kein Urteil hat" % answer
		).is_equal(SentenceCard.NO_VERDICT)


## Der Fall, an dem es aufgefallen ist. Dieselben Wörter in falscher Reihenfolge sind für
## eine Wortmengen-Überschneidung nicht von der Lösung zu unterscheiden — sie bekommt die
## volle Nähe. Genau deshalb darf sie nicht die Güte sein: im Bosskampf geht es um Satzbau,
## und eine durchgewinkte Wortsalat-Antwort lehrt die falsche Form als richtig.
func test_the_same_words_in_the_wrong_order_are_not_a_hit() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "Yesterday the reef we saw.")
	assert_float(float(result["overlap"])).is_equal(1.0)
	assert_float(float(result["quality"])).is_equal(SentenceCard.NO_VERDICT)
	assert_bool(bool(result["sure"])).is_false()


func test_an_empty_answer_is_zero_and_needs_no_model() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "   ")
	assert_float(float(result["quality"])).is_equal(0.0)
	assert_bool(bool(result["sure"])).is_true()
	assert_str(str(result["feedback"])).is_equal(SentenceCard.EMPTY_FEEDBACK)


## Ein ganz anderer Satz ist auch ohne Schlüssel als solcher zu erkennen — an der NÄHE,
## die dafür da ist, die Rückmeldung zu wählen, und für nichts sonst.
func test_a_different_sentence_is_told_from_a_near_miss() -> void:
	var far := SentenceCard.evaluate(BARE, "My bicycle is green.")
	assert_float(float(far["overlap"])).is_less(SentenceCard.NEAR_QUALITY)
	assert_str(str(far["feedback"])).is_equal(SentenceCard.FAR_FEEDBACK)
	var near := SentenceCard.evaluate(BARE, "The dragon is not asleep.")
	assert_float(float(near["overlap"])).is_greater_equal(SentenceCard.NEAR_QUALITY)
	assert_str(str(near["feedback"])).is_equal(SentenceCard.NEAR_FEEDBACK)


## Steht ein gefordertes Wort im Schlüssel, geht dessen Rückmeldung vor: sie sagt, was zu
## tun ist, und „das ist ein anderer Satz" sagt es nicht.
func test_the_missing_word_is_the_more_useful_answer() -> void:
	var result := SentenceCard.evaluate(SENTENCE, "My bicycle is green.")
	assert_str(str(result["feedback"])).contains("reef")


## Ohne Schlüssel bleibt die Karte, was sie kann: die eine Musterlösung. Sie soll dabei
## nicht schlechter sein als vorher — nur ehrlicher darüber, dass sie schätzt.
func test_a_sentence_without_a_key_still_works() -> void:
	assert_float(float(SentenceCard.evaluate(BARE, "The dragon is asleep.")["quality"])) \
			.is_equal(SentenceCard.MATCH_QUALITY)
	var guess := SentenceCard.evaluate(BARE, "The dragon has fallen asleep.")
	assert_bool(bool(guess["sure"])).is_false()


## Die Musterlösung steht immer mit in den Lösungen — sonst wäre sie die einzige Antwort,
## die nicht gilt.
func test_the_reference_is_one_of_the_solutions() -> void:
	assert_array(SentenceCard.solutions(SENTENCE)).contains(["Yesterday we saw the reef."])
	assert_int(SentenceCard.solutions(SENTENCE).size()).is_equal(3)
