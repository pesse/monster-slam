extends GdUnitTestSuite
## Zeitbasis des Schedulers: ein Fehler ist nach zehn Minuten wieder fällig, richtige
## Antworten rechnen in Tagen ab lokaler Mitternacht, und nur eine fällige Aufgabe rückt
## im Plan vor.

const DAY := 86400
## 2026-10-01 18:00 UTC; mit +2 h Versatz 20:00 Ortszeit.
const NOW := 1790877600
const OFFSET := 7200


func _sr() -> SpacedRepetition:
	var sr := SpacedRepetition.new()
	sr.utc_offset = OFFSET
	return sr


func _local_midnight_after(now: int, days: int) -> int:
	return int(floor(float(now + OFFSET) / DAY) + days) * DAY - OFFSET


func test_a_wrong_answer_is_due_again_after_ten_minutes() -> void:
	var sr := _sr()
	sr.review("a", 2, NOW)
	assert_int(sr.due_at("a")).is_equal(NOW + 600)
	assert_array(sr.due_items(NOW + 599)).is_empty()
	assert_array(sr.due_items(NOW + 600)).contains_exactly(["a"])


func test_a_correct_answer_is_due_at_the_next_local_midnight() -> void:
	var sr := _sr()
	sr.review("a", 5, NOW)
	assert_int(sr.due_at("a")).is_equal(_local_midnight_after(NOW, 1))


func test_answers_before_the_due_time_do_not_advance_the_plan() -> void:
	var sr := _sr()
	sr.review("a", 5, NOW)
	sr.review("a", 5, NOW + 60)
	sr.review("a", 5, NOW + 120)
	assert_int(sr.due_at("a")).is_equal(_local_midnight_after(NOW, 1))
	# Am nächsten Tag zählt sie wieder: 3 Tage.
	var tomorrow := _local_midnight_after(NOW, 1) + 3600
	sr.review("a", 5, tomorrow)
	assert_int(sr.due_at("a")).is_equal(_local_midnight_after(tomorrow, 3))


func test_a_wrong_answer_always_counts() -> void:
	var sr := _sr()
	sr.review("a", 5, NOW)
	sr.review("a", 2, NOW + 60)
	assert_int(sr.due_at("a")).is_equal(NOW + 60 + 600)


func test_legacy_day_counter_becomes_the_same_instant() -> void:
	var sr := _sr()
	sr.from_dict({"a": {"ease": 2.5, "interval": 1, "reps": 1, "due": 20728}})
	assert_int(sr.due_at("a")).is_equal(20728 * DAY)
	assert_bool(sr.to_dict()["a"].has("due")).is_false()
