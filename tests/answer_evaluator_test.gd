extends GdUnitTestSuite
## Muster-Test für reine Logik-Klassen (extends RefCounted, kein SceneTree nötig).
## Vorlage für weitere Unit-Tests von AnswerEvaluator / TaskResolver / SpacedRepetition.

var _evaluator: AnswerEvaluator


func before_test() -> void:
	_evaluator = AnswerEvaluator.new()


func test_matches_case_and_whitespace_insensitive() -> void:
	assert_bool(_evaluator.evaluate_answers(["house"], "  HOUSE ")).is_true()


func test_german_article_is_optional() -> void:
	assert_bool(_evaluator.evaluate_answers(["das Haus"], "Haus")).is_true()


func test_english_definite_article_is_optional() -> void:
	# "die U-Bahn" steht im Buch als "the underground", einen Eintrag weiter als
	# "underground" — der Artikel gehört zur Notation des Eintrags, nicht zur Vokabel.
	assert_bool(_evaluator.evaluate_answers(["the underground"], "underground")).is_true()
	assert_bool(_evaluator.evaluate_answers(["underground"], "the underground")).is_true()
	assert_bool(_evaluator.evaluate_answers(["the underground"], "the underground")).is_true()
	# Und vollständig ist der Treffer auch ohne ihn — kein Hinweis auf Fehlendes.
	assert_bool(_evaluator.evaluate(["the underground"], "underground")["complete"]).is_true()


func test_the_word_the_itself_survives() -> void:
	# Dieselbe Regel wie bei "to": weggekürzt wird nur MIT folgendem Wort.
	assert_bool(_evaluator.evaluate_answers(["the"], "the")).is_true()
	assert_bool(_evaluator.evaluate_answers(["the"], "")).is_false()
	assert_bool(_evaluator.evaluate_answers(["the"], "underground")).is_false()


func test_english_indefinite_article_stays_mandatory() -> void:
	# "a few" (ein paar) und "few" (wenige) sind zwei Vokabeln, und der Unterschied
	# zwischen ihnen ist genau der Artikel. Dasselbe bei "a little"/"little".
	assert_bool(_evaluator.evaluate_answers(["a few"], "few")).is_false()
	assert_bool(_evaluator.evaluate_answers(["few"], "a few")).is_false()
	assert_bool(_evaluator.evaluate_answers(["a little"], "little")).is_false()


func test_english_infinitive_to_is_optional() -> void:
	# Im Lehrbuch steht mal "brainstorm", mal "to brainstorm" — für die Abfrage ist das
	# dasselbe Wort, und zwar in beide Richtungen.
	assert_bool(_evaluator.evaluate_answers(["brainstorm"], "to brainstorm")).is_true()
	assert_bool(_evaluator.evaluate_answers(["to brainstorm"], "brainstorm")).is_true()
	assert_bool(_evaluator.evaluate_answers(["to brainstorm"], "to brainstorm")).is_true()
	# Vollständig ist der Treffer trotzdem: "to" ist Notation, kein Bestandteil.
	assert_bool(_evaluator.evaluate(["brainstorm"], "to brainstorm")["complete"]).is_true()


func test_the_word_to_itself_survives() -> void:
	# Weggekürzt wird nur "to " MIT folgendem Wort, sonst bliebe von der Vokabel "to"
	# nichts übrig und jede leere Eingabe träfe sie.
	assert_bool(_evaluator.evaluate_answers(["to"], "to")).is_true()
	assert_bool(_evaluator.evaluate_answers(["to"], "")).is_false()
	assert_bool(_evaluator.evaluate_answers(["to"], "brainstorm")).is_false()


func test_accepts_any_listed_variant() -> void:
	# Regression zum Slash-Fix: "each" (en->de) liefert alle Genus-Formen als
	# einzelne akzeptierte Antworten statt eines wörtlichen "jeder / jede / jedes".
	var accepted := ["jeder", "jede", "jedes"]
	assert_bool(_evaluator.evaluate_answers(accepted, "jede")).is_true()
	assert_bool(_evaluator.evaluate_answers(accepted, "jedes")).is_true()


func test_rejects_wrong_answer() -> void:
	assert_bool(_evaluator.evaluate_answers(["each"], "house")).is_false()


# --- Grammatik-Platzhalter und Klammern (sb./sth., jn., "(for)") -------------------
# Lehrbuch-Notation soll nicht mitgetippt werden müssen. Vollständig heißt: nichts
# weggelassen; die Schreibweise der Notation ist gleichgültig.

func test_placeholder_notation_is_free() -> void:
	var accepted := ["criticize sb. (for)"]
	for answer in ["criticize sb for", "criticize sb. (for)", "criticize somebody for",
			"criticize someone (for)", "CRITICIZE  SB.  FOR"]:
		var verdict := _evaluator.evaluate(accepted, answer)
		assert_bool(verdict["matched"]).override_failure_message(
			'"%s" sollte passen' % answer).is_true()
		assert_bool(verdict["complete"]).override_failure_message(
			'"%s" sollte vollständig sein' % answer).is_true()


func test_core_only_answer_is_correct_but_incomplete() -> void:
	var verdict := _evaluator.evaluate(["criticize sb. (for)"], "criticize")
	assert_bool(verdict["matched"]).is_true()
	assert_bool(verdict["complete"]).is_false()
	# Die Vollform in Originalschreibweise, damit der WaveRunner sie zeigen kann.
	assert_str(str(verdict["canonical"])).is_equal("criticize sb. (for)")


func test_missing_optional_group_is_incomplete() -> void:
	var verdict := _evaluator.evaluate(["criticize sb. (for)"], "criticize sb")
	assert_bool(verdict["matched"]).is_true()
	assert_bool(verdict["complete"]).is_false()


func test_german_placeholders_are_equivalent() -> void:
	var accepted := ["jn. kritisieren (wegen)"]
	assert_bool(_evaluator.evaluate(accepted, "jemanden kritisieren wegen")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "jn. kritisieren (wegen)")["complete"]).is_true()
	var core := _evaluator.evaluate(accepted, "kritisieren")
	assert_bool(core["matched"]).is_true()
	assert_bool(core["complete"]).is_false()


func test_placeholder_in_the_middle() -> void:
	var accepted := ["write sth. down"]
	assert_bool(_evaluator.evaluate(accepted, "write something down")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "write sth down")["complete"]).is_true()
	var core := _evaluator.evaluate(accepted, "write down")
	assert_bool(core["matched"]).is_true()
	assert_bool(core["complete"]).is_false()


func test_two_placeholders_are_decided_separately() -> void:
	# Derselbe Platzhalter zweimal, einer davon in einer Klammergruppe.
	var accepted := ["prefer sth. (to sth.)"]
	assert_bool(_evaluator.evaluate(accepted, "prefer sth to sth")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "prefer something to something")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "prefer")["matched"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "prefer")["complete"]).is_false()


func test_optional_preposition_without_placeholder() -> void:
	var accepted := ["disagree (with)"]
	assert_bool(_evaluator.evaluate(accepted, "disagree with")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "disagree (with)")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "disagree")["matched"]).is_true()
	assert_bool(_evaluator.evaluate(accepted, "disagree")["complete"]).is_false()


func test_gloss_in_brackets_is_optional() -> void:
	# Klammern tragen im Bestand auch reine Erklärungen — die sind nie Pflicht.
	assert_bool(_evaluator.evaluate_answers(["tragen (Kleidung)"], "tragen")).is_true()
	assert_bool(_evaluator.evaluate_answers(["(landschaftlich) schön"], "schön")).is_true()
	assert_bool(_evaluator.evaluate_answers(["die Süßigkeiten (Pl.)"], "Süßigkeiten")).is_true()


func test_sentence_punctuation_and_typography() -> void:
	assert_bool(_evaluator.evaluate_answers(["That's fine by me."], "that's fine by me")).is_true()
	# Typografisches Apostroph in den Daten, gerades auf der Tastatur.
	assert_bool(_evaluator.evaluate_answers(["That’s fine by me."], "that's fine by me")).is_true()
	assert_bool(_evaluator.evaluate_answers(["What's wrong with …?"], "what's wrong with")).is_true()


func test_tolerance_does_not_accept_wrong_words() -> void:
	var accepted := ["criticize sb. (for)"]
	# Anderer Kern: bleibt falsch.
	assert_bool(_evaluator.evaluate_answers(accepted, "blame sb for")).is_false()
	# Andere Schreibweise gehört in lemma_en_alt, nicht in den Normalisierer.
	assert_bool(_evaluator.evaluate_answers(accepted, "criticise sb for")).is_false()
	# Nur die Notation ist keine Antwort.
	assert_bool(_evaluator.evaluate_answers(accepted, "sb")).is_false()
	assert_bool(_evaluator.evaluate_answers(accepted, "for")).is_false()


func test_empty_answer_never_matches() -> void:
	assert_bool(_evaluator.evaluate_answers(["criticize sb. (for)"], "")).is_false()
	assert_bool(_evaluator.evaluate_answers(["criticize sb. (for)"], "   ")).is_false()
	# Ein Lemma, das nur aus einem Platzhalter besteht, darf nicht zu "" schrumpfen.
	assert_bool(_evaluator.evaluate_answers(["etwas"], "")).is_false()
	assert_bool(_evaluator.evaluate_answers(["etwas"], "etwas")).is_true()


func test_complete_match_wins_over_partial_across_answers() -> void:
	# Reihenfolge in accepted_answers darf das Ergebnis nicht bestimmen: die
	# vollständig passende Antwort gewinnt, auch wenn sie hinten steht.
	var accepted := ["take (on sth.)", "take"]
	var verdict := _evaluator.evaluate(accepted, "take")
	assert_bool(verdict["matched"]).is_true()
	assert_bool(verdict["complete"]).is_true()
	assert_str(str(verdict["canonical"])).is_equal("take")
