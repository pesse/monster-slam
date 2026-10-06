extends GdUnitTestSuite
## Meisterung mit Abstand (ADR 0018, Issue #18): drei richtige Antworten an drei Tagen
## meistern eine Aufgabe, dieselben drei in einer Sitzung nicht. Ein Fehler bringt sie bald
## wieder.
##
## Auf einer EIGENEN PlayerProgress-Instanz mit `zz-`-Profil, nie im Szenenbaum: kein
## _ready(), nichts wird gespeichert, der Lernstand des Entwicklungsprofils bleibt unberührt.

const PROGRESS := preload("res://src/learning/player_progress.gd")
const TASK := "translate:de_to_en:zz-word"
const DAY := 86400
## 2026-10-01 18:00 UTC.
const NOW := 1790877600

var _pp: Node


func before_test() -> void:
	_pp = auto_free(PROGRESS.new())
	_pp.player_id = "zz-spaced-mastery"


func test_three_days_in_a_row_master_the_task() -> void:
	for day in 3:
		_pp.record(TASK, true, 0, 0.3, NOW + day * DAY)
	assert_bool(_pp.is_mastered(TASK)).is_true()


func test_three_answers_in_one_session_do_not() -> void:
	for i in 3:
		_pp.record(TASK, true, 0, 0.3, NOW + i * 900)
	assert_bool(_pp.is_mastered(TASK)).is_false()


## Möglich bleibt es auch in einer Sitzung, nur mit viel mehr Treffern.
func test_cramming_masters_eventually() -> void:
	var hits := 0
	while not _pp.is_mastered(TASK) and hits < 30:
		_pp.record(TASK, true, 0, 0.3, NOW + hits * 60)
		hits += 1
	assert_int(hits).is_between(8, 10)


func test_a_mastered_task_comes_back_after_days_not_tomorrow() -> void:
	for day in 3:
		_pp.record(TASK, true, 0, 0.3, NOW + day * DAY)
	var last := NOW + 2 * DAY
	assert_int(_pp.due_at(TASK) - last).is_greater(2 * DAY)


func test_a_wrong_answer_is_due_again_in_ten_minutes() -> void:
	for day in 3:
		_pp.record(TASK, true, 0, 0.3, NOW + day * DAY)
	var at := NOW + 3 * DAY
	_pp.record(TASK, false, 0, 0.3, at)
	assert_bool(_pp.is_mastered(TASK)).is_false()
	assert_int(_pp.due_at(TASK)).is_equal(at + 600)
	assert_array(_pp.due_task_ids(at + 599)).is_empty()
	assert_array(_pp.due_task_ids(at + 600)).contains_exactly([TASK])


## Altstände tragen einen SM-2-Plan und dessen Ergebnis je Record — beides wird gerechnet
## und fällt beim Laden weg.
func test_a_legacy_plan_is_dropped_on_load() -> void:
	DirAccess.make_dir_recursive_absolute("user://progress")
	var path := "user://progress/zz-spaced-mastery.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"player_id": "zz-spaced-mastery",
		"records": {TASK: {"confidence": 0.9, "last_correct": true, "last_seen_at": NOW,
			"next_review_at": NOW + 600 * DAY}},
		"sr": {TASK: {"ease": 3.3, "interval": 595, "reps": 7, "due_at": NOW + 595 * DAY}}}))
	file.close()
	_pp.load_progress()
	_pp.save_progress()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert_bool(saved.has("sr")).is_false()
	assert_bool(saved["records"][TASK].has("next_review_at")).is_false()
	assert_int(_pp.due_at(TASK) - NOW).is_less_equal(8 * DAY)
