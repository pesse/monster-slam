extends GdUnitTestSuite
## Welches Monster eine Antwort trifft (WaveRunner.best_hit): exakt und vollständig vor
## nachsichtig vor unvollständig (ADR 0008). Reine Regel, keine Welle.

const WAVE_RUNNER := preload("res://src/battle/wave_runner.gd")

var _evaluator: AnswerEvaluator


func before_test() -> void:
	_evaluator = AnswerEvaluator.new()


func test_the_exact_spelling_wins_over_the_accent_twin() -> void:
	# „wo" = „où", „oder" = „ou": wer „ou" tippt, meint „oder".
	var field := [["où"], ["ou"]]
	var hit := WAVE_RUNNER.best_hit(_evaluator, field, "ou")
	assert_int(int(hit["index"])).is_equal(1)
	assert_bool(hit["verdict"]["exact"]).is_true()


func test_without_the_twin_the_accent_is_forgiven() -> void:
	var hit := WAVE_RUNNER.best_hit(_evaluator, [["où"]], "ou")
	assert_int(int(hit["index"])).is_equal(0)
	assert_bool(hit["verdict"]["exact"]).is_false()
	assert_str(str(hit["verdict"]["canonical"])).is_equal("où")


func test_a_complete_lenient_hit_wins_over_an_exact_partial_one() -> void:
	var field := [["take (on sth.)"], ["tâke"], ["take"]]
	var hit := WAVE_RUNNER.best_hit(_evaluator, field, "take")
	assert_int(int(hit["index"])).is_equal(2)
	hit = WAVE_RUNNER.best_hit(_evaluator, [["take (on sth.)"], ["tâke"]], "take")
	assert_int(int(hit["index"])).is_equal(1)


func test_nothing_matches() -> void:
	assert_int(int(WAVE_RUNNER.best_hit(_evaluator, [["la maison"]], "maison")["index"])).is_equal(-1)
