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


func test_accepts_any_listed_variant() -> void:
	# Regression zum Slash-Fix: "each" (en->de) liefert alle Genus-Formen als
	# einzelne akzeptierte Antworten statt eines wörtlichen "jeder / jede / jedes".
	var accepted := ["jeder", "jede", "jedes"]
	assert_bool(_evaluator.evaluate_answers(accepted, "jede")).is_true()
	assert_bool(_evaluator.evaluate_answers(accepted, "jedes")).is_true()


func test_rejects_wrong_answer() -> void:
	assert_bool(_evaluator.evaluate_answers(["each"], "house")).is_false()
