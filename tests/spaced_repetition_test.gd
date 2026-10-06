extends GdUnitTestSuite
## Wiederholung mit Abstand (ADR 0018): wie viel ein Treffer nach welchem Abstand zählt und
## wann eine Aufgabe aus ihrer Confidence wieder fällig ist.

const DAY := 86400
## 2026-10-01 18:00 UTC; mit +2 h Versatz 20:00 Ortszeit.
const NOW := 1790877600
const OFFSET := 7200


func _local_midnight_after(now: int, days: int) -> int:
	return int(floor(float(now + OFFSET) / DAY) + days) * DAY - OFFSET


func test_the_first_answer_counts_fully() -> void:
	assert_float(SpacedRepetition.spacing_gain(-1, 0)).is_equal(SpacedRepetition.GAIN_MAX)


func test_an_answer_right_after_the_last_counts_least() -> void:
	assert_float(SpacedRepetition.spacing_gain(30, 600)).is_equal(SpacedRepetition.GAIN_MIN)
	assert_float(SpacedRepetition.spacing_gain(600, 600)).is_equal(SpacedRepetition.GAIN_MIN)


## Eine Stunde später zählt etwa ein Drittel des Wegs, ein Tag später alles.
func test_the_gain_grows_with_the_spacing() -> void:
	var hour := SpacedRepetition.spacing_gain(3600, DAY)
	assert_float(hour).is_between(0.18, 0.24)
	assert_float(SpacedRepetition.spacing_gain(DAY, DAY)).is_equal_approx(SpacedRepetition.GAIN_MAX, 1e-6)
	assert_float(SpacedRepetition.spacing_gain(5 * DAY, DAY)).is_equal_approx(SpacedRepetition.GAIN_MAX, 1e-6)


## Wer vor der Zeit wiederholt, lernt weniger: ein Tag zählt bei sieben Tagen Intervall nicht voll.
func test_reviewing_before_a_long_interval_counts_less() -> void:
	assert_float(SpacedRepetition.spacing_gain(DAY, 7 * DAY)).is_less(SpacedRepetition.GAIN_MAX - 0.05)


func test_a_wrong_answer_is_due_after_ten_minutes() -> void:
	assert_int(SpacedRepetition.due_at(0.4, false, NOW, OFFSET)).is_equal(NOW + 600)


func test_a_correct_answer_is_due_at_a_local_midnight() -> void:
	assert_int(SpacedRepetition.due_at(0.6, true, NOW, OFFSET)).is_equal(_local_midnight_after(NOW, 1))
	assert_int(SpacedRepetition.due_at(0.85, true, NOW, OFFSET)).is_equal(_local_midnight_after(NOW, 3))


## Die Kurve ist auf ein Schuljahr ausgelegt: von einem Tag bis höchstens 45.
func test_the_interval_grows_with_confidence_and_is_capped() -> void:
	var last := 0
	for c in [0.3, 0.79, 0.8, 0.9, 0.95, 0.975, 0.985, 1.0]:
		var days := SpacedRepetition.interval_days(c)
		assert_int(days).is_greater_equal(last)
		last = days
	assert_int(SpacedRepetition.interval_days(0.3)).is_equal(1)
	assert_int(SpacedRepetition.interval_days(1.0)).is_equal(45)


func test_a_task_never_answered_is_not_due() -> void:
	assert_int(SpacedRepetition.due_at(0.3, false, 0, OFFSET)).is_equal(0)
