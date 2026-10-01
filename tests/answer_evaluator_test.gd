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


## "jmd." ist die geläufigste Kurzform und steht nicht im Buch. Als Wort gelesen, passte
## mit ihr die ganze Antwort nicht mehr.
func test_jmd_abbreviations_are_placeholders() -> void:
	var accepted := ["jn. kritisieren (wegen)"]
	for answer in ["jmd kritisieren wegen", "jmd. kritisieren (wegen)", "jmdn kritisieren wegen",
			"jmdn. kritisieren wegen", "jmdm kritisieren wegen", "JMD. KRITISIEREN WEGEN"]:
		assert_bool(_evaluator.evaluate(accepted, answer)["complete"]).override_failure_message(
			'"%s" sollte vollständig sein' % answer).is_true()


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


## Wort-Alternativen mit Schrägstrich sind eine Wahl: jede allein ist vollständig, die
## Breite einer Alternative steht nicht da („Bus/eine Fähre" = „einen Bus" | „eine Fähre").
func test_slashed_words_are_alternatives() -> void:
	for c in [["einen Bus/eine Fähre nehmen", "einen Bus nehmen"],
			["einen Bus/eine Fähre nehmen", "eine Fähre nehmen"],
			["einen Bus/eine Fähre nehmen", "einen Bus/eine Fähre nehmen"],
			["catch a bus/ferry", "catch a ferry"], ["turn left/right", "turn right"],
			["aus dem Bus/Boot/Flugzeug aussteigen", "aus dem Boot aussteigen"],
			["seit 10 Uhr/letzter Woche/…", "seit letzter Woche"],
			["stay (at/with)", "stay with"]]:
		assert_bool(_evaluator.evaluate([c[0]], c[1])["complete"]) \
				.override_failure_message("%s / %s" % c).is_true()
	assert_bool(_evaluator.evaluate_answers(["einen Bus/eine Fähre nehmen"], "nehmen")).is_false()
	assert_bool(_evaluator.evaluate_answers(["catch a bus/ferry"], "catch a bus ferry")).is_false()


## "sb./sth." ist eine Stelle mit zwei Lesarten: jede allein ist vollständig.
func test_slashed_placeholders_are_one_slot() -> void:
	var accepted := ["wait for sb./sth."]
	for answer in ["wait for sb./sth.", "wait for sb/sth", "wait for sb / sth", "wait for sb.",
			"wait for sth", "wait for somebody", "wait for something/somebody"]:
		assert_bool(_evaluator.evaluate(accepted, answer)["complete"]).override_failure_message(
			'"%s" sollte vollständig sein' % answer).is_true()
	var core := _evaluator.evaluate(accepted, "wait for")
	assert_bool(core["matched"]).is_true()
	assert_bool(core["complete"]).is_false()
	assert_bool(_evaluator.evaluate(["auf jn./etwas warten"], "auf jmd. warten")["complete"]).is_true()


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


# --- Französisch: nachsichtige Schreibweise (ADR 0008) ---


func test_missing_accents_match_leniently_and_name_the_spelling() -> void:
	var verdict := _evaluator.evaluate(["l'école"], "l'ecole", true)
	assert_bool(verdict["matched"]).is_true()
	assert_bool(verdict["complete"]).is_true()
	assert_bool(verdict["exact"]).is_false()
	assert_str(str(verdict["canonical"])).is_equal("l'école")
	for typed in ["lecole", "l ecole", "L'ÉCOLE", "l'école"]:
		assert_bool(_evaluator.evaluate(["l'école"], typed, true)["complete"]) \
				.override_failure_message(typed).is_true()


func test_exact_spelling_is_exact() -> void:
	var verdict := _evaluator.evaluate(["le cœur"], "le cœur", true)
	assert_bool(verdict["complete"]).is_true()
	assert_bool(verdict["exact"]).is_true()
	assert_bool(_evaluator.evaluate(["le cœur"], "le coeur", true)["exact"]).is_false()
	assert_bool(_evaluator.evaluate(["le garçon"], "le garcon", true)["matched"]).is_true()


func test_without_lenient_spelling_stays_strict() -> void:
	# Die Satzbewertung fragt ohne Nachsicht — dort bleibt alles, wie es war.
	assert_bool(_evaluator.evaluate(["l'école"], "l'ecole")["matched"]).is_false()
	assert_bool(_evaluator.evaluate(["don't"], "dont")["matched"]).is_false()


func test_hyphen_may_be_space_or_missing() -> void:
	for typed in ["est ce que", "estce que"]:
		var verdict := _evaluator.evaluate(["est-ce que"], typed, true)
		assert_bool(verdict["complete"]).override_failure_message(typed).is_true()
		assert_bool(verdict["exact"]).is_false()
	assert_bool(_evaluator.evaluate(["aujourd'hui"], "aujourdhui", true)["complete"]).is_true()


func test_umlauts_are_not_folded() -> void:
	# Die deutsche Seite: „schon" ist nicht „schön".
	assert_bool(_evaluator.evaluate(["schön"], "schon", true)["matched"]).is_false()


func test_french_article_is_required() -> void:
	assert_bool(_evaluator.evaluate(["la maison"], "maison", true)["matched"]).is_false()
	assert_bool(_evaluator.evaluate(["la maison"], "le maison", true)["matched"]).is_false()
	assert_bool(_evaluator.evaluate(["l'école"], "ecole", true)["matched"]).is_false()


func test_exact_partial_wins_over_lenient_partial_only_when_nothing_complete() -> void:
	# Exakt, aber unvollständig bleibt exakt, solange nachsichtig nichts Vollständiges trifft.
	var verdict := _evaluator.evaluate(["parler (à qn)"], "parler", true)
	assert_bool(verdict["complete"]).is_false()
	assert_bool(verdict["exact"]).is_true()
	# Nachsichtig vollständig schlägt exakt unvollständig.
	verdict = _evaluator.evaluate(["parler (à qn)"], "parler a qn", true)
	assert_bool(verdict["complete"]).is_true()
	assert_bool(verdict["exact"]).is_false()


func test_french_placeholders_are_wildcards() -> void:
	var accepted := ["parler à qn"]
	for typed in ["parler à quelqu'un", "parler à qn.", "parler à qn"]:
		assert_bool(_evaluator.evaluate(accepted, typed)["complete"]) \
				.override_failure_message(typed).is_true()
	assert_bool(_evaluator.evaluate(["faire qc"], "faire quelque chose")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(["faire qch"], "faire qc")["complete"]).is_true()


## Die deutsche Seite von À plus! schreibt „jdm“/„jdn“ ohne Punkt.
func test_german_placeholders_as_a_plus_writes_them() -> void:
	assert_bool(_evaluator.evaluate(["jdm etw. versprechen"], "jemandem etwas versprechen")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(["jdm Bescheid sagen"], "jmdm. Bescheid sagen")["complete"]).is_true()


# --- Auslassungspunkte und Komma ---


func test_ellipsis_is_normalized_away() -> void:
	# Die Lücke ist kein Bestandteil: weglassen ist vollständig, die Schreibweise egal.
	for typed in ["not only but also", "not only ... but also", "not only … but also",
			"not only .. but also", "not only…but also"]:
		var verdict := _evaluator.evaluate(["not only … but also"], typed)
		assert_bool(verdict["complete"]).override_failure_message(typed).is_true()
		assert_bool(verdict["exact"]).override_failure_message(typed).is_true()
	assert_bool(_evaluator.evaluate(["Moment mal …"], "Moment mal")["complete"]).is_true()
	assert_bool(_evaluator.evaluate(["either ... or ..."], "either or")["complete"]).is_true()


func test_ellipsis_before_comma_leaves_no_gap() -> void:
	assert_bool(_evaluator.evaluate(["les uns…, les autres"], "les uns, les autres")["exact"]).is_true()


func test_comma_is_lenient_spelling() -> void:
	# Ein Leerzeichen vor dem Komma ist bloß Leerraum und trifft exakt.
	assert_bool(_evaluator.evaluate(["yes, please"], "yes , please")["exact"]).is_true()
	for typed in ["yes please", "yes,please"]:
		var verdict := _evaluator.evaluate(["yes, please"], typed, true)
		assert_bool(verdict["complete"]).override_failure_message(typed).is_true()
		assert_bool(verdict["exact"]).override_failure_message(typed).is_false()
		assert_bool(_evaluator.evaluate(["yes, please"], typed)["matched"]) \
				.override_failure_message(typed).is_false()
	assert_bool(_evaluator.evaluate(["salut, ça va ?"], "salut ca va", true)["complete"]).is_true()
	assert_bool(_evaluator.evaluate(["yes please"], "yes, please", true)["matched"]).is_true()


func test_missing_comma_is_marked() -> void:
	assert_array(Array(AnswerEvaluator.spelling_marks("yes, please", "yes please"))).contains_exactly([3])
