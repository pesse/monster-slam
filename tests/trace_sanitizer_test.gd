extends GdUnitTestSuite
## Bereinigte Spur (ADR 0021): was den Rechner verlässt, kennt keine Wörter mehr.
##
## Die Zeilen schreibt eine echte TraceLog-Instanz mit `zz-`-Profil (wie in
## tests/trace_log_test.gd) — so fällt auf, wenn TraceLog ein Feld bekommt, das die
## Bereinigung nicht kennt.

const TRACE_LOG := preload("res://src/learning/trace_log.gd")
const TEST_PROFILE := "zz-sanitizer-test"

const TASK := {
	"learnable_id": "translate:de_to_en:zz.lex.k1",
	"source_id": "zz.lex.k1",
	"task_type": "translate",
	"direction": "de_to_en",
	"prompt": "Koralle",
	"accepted_answers": ["coral"],
	"difficulty": 2,
	"initial_confidence": 0.3,
	"pick": {"group": "new", "pos": 0, "pool": 3},
}

## Wörter, die in keiner bereinigten Zeile vorkommen dürfen.
const SECRET_WORDS := ["Koralle", "coral\"", "corel", "Mein Satz", "weil darum", TEST_PROFILE]

var _log: Node


func before_test() -> void:
	GameState.reset()
	_log = auto_free(TRACE_LOG.new())
	_log.player_id = TEST_PROFILE
	_remove_files()


func after_test() -> void:
	_log._close()
	GameState.reset()
	_remove_files()


func _remove_files() -> void:
	DirAccess.remove_absolute("user://logs/%s_trace.jsonl" % TEST_PROFILE)
	DirAccess.remove_absolute("user://logs/%s_trace.1.jsonl" % TEST_PROFILE)


func _write_run() -> void:
	_log.note_run_start()
	_log.note_spawn(TASK)
	_log.note_answer("corel", {"matched": false, "candidates": [TASK["learnable_id"]],
			"response_time_ms": 2100})
	_log.note_answer("coral", {"matched": true, "complete": true,
			"learnable_id": TASK["learnable_id"], "canonical": "coral",
			"candidates": [TASK["learnable_id"]], "response_time_ms": 1800})
	_log.note_leak(TASK, 10)
	_log.note_catapult(TASK)
	_log.note_struck(TASK)
	_log.note_boss_answer("zz.s1", "Mein Satz ist lang", {"hit": true, "quality": 0.9,
			"stage": "card", "sure": true})
	_log.note_boss_explained("zz.s1", "weil darum")
	_log.note_run_end({"wave_reached": 2})
	_log._close()


func _sanitized(after: Array = [0, 0]) -> Array:
	return StatsUploader.trace_after(TEST_PROFILE, after)


func test_no_words_leave_the_machine() -> void:
	_write_run()
	var flat := JSON.stringify(_sanitized())
	for word in SECRET_WORDS:
		assert_bool(flat.contains(word)).append_failure_message(
				"'%s' steht in der bereinigten Spur: %s" % [word, flat]).is_false()
	for field in ["\"text\"", "\"prompt\"", "\"answers\"", "\"canonical\"", "\"why\"", "\"profile\""]:
		assert_bool(flat.contains(field)).append_failure_message(
				"Feld %s steht in der bereinigten Spur" % field).is_false()


func test_ids_and_timing_stay() -> void:
	_write_run()
	var lines := _sanitized()
	var spawn: Dictionary = lines.filter(func(l): return l["e"] == "spawn")[0]
	assert_str(str(spawn["id"])).is_equal(TASK["learnable_id"])
	assert_str(str(spawn["lex"])).is_equal("zz.lex.k1")
	assert_that(spawn.has("pick")).is_true()
	var answers := lines.filter(func(l): return l["e"] == "answer")
	assert_int(answers.size()).is_equal(2)
	assert_int(int(answers[0]["rt"])).is_equal(2100)
	for line in lines:
		assert_that(line.has("at") and line.has("ms")).is_true()


func test_a_miss_carries_its_distance_to_the_nearest_answer() -> void:
	_write_run()
	var answers := _sanitized().filter(func(l): return l["e"] == "answer")
	var miss: Dictionary = answers[0]
	assert_int(int(miss["dist"])).is_equal(1)              # corel -> coral
	assert_str(str(miss["near"])).is_equal(TASK["learnable_id"])
	assert_int(int(miss["len"])).is_equal(5)
	var hit: Dictionary = answers[1]
	assert_int(int(hit["dist"])).is_equal(0)
	assert_bool(hit.has("near")).is_false()


func test_boss_answer_keeps_only_numbers() -> void:
	_write_run()
	var boss: Dictionary = _sanitized().filter(func(l): return l["e"] == "boss_answer")[0]
	assert_int(int(boss["words"])).is_equal(4)
	assert_bool(bool(boss["hit"])).is_true()


func test_cursor_skips_sent_lines_but_still_knows_the_answers() -> void:
	var lines := [
		{"at": 100, "ms": 1, "e": "spawn", "id": "t:zz.k1", "answers": ["coral"]},
		{"at": 100, "ms": 2, "e": "wave_start", "wave": "w1"},
		{"at": 101, "ms": 3, "e": "answer", "text": "corel", "hit": false, "field": ["t:zz.k1"]},
	]
	# Der Cursor steht hinter dem spawn: die Lösungen kommen trotzdem aus der Zeile davor.
	var rest := TraceSanitizer.new().sanitize(lines, [100, 2])
	assert_int(rest.size()).is_equal(1)
	assert_int(int(rest[0]["dist"])).is_equal(1)
	assert_str(str(rest[0]["near"])).is_equal("t:zz.k1")


func test_a_chunk_never_splits_lines_of_the_same_mark() -> void:
	var events := [
		{"at": 1, "ms": 1, "e": "a"}, {"at": 1, "ms": 2, "e": "b"},
		{"at": 1, "ms": 2, "e": "c"}, {"at": 1, "ms": 2, "e": "d"}, {"at": 1, "ms": 3, "e": "e"},
	]
	assert_int(StatsUploader.chunk_end(events, 0, 2)).is_equal(4)
	assert_int(StatsUploader.chunk_end(events, 0, 1)).is_equal(1)
	assert_int(StatsUploader.chunk_end(events, 4, 2)).is_equal(5)


func test_rotated_generation_is_read_first() -> void:
	_log.max_bytes = 400
	_write_run()
	assert_bool(FileAccess.file_exists("user://logs/%s_trace.1.jsonl" % TEST_PROFILE)).is_true()
	var lines := _sanitized()
	for i in range(1, lines.size()):
		assert_bool(TraceSanitizer.is_after(TraceSanitizer.mark_of(lines[i - 1]),
				TraceSanitizer.mark_of(lines[i]))).is_false()


func test_unknown_events_do_not_leave() -> void:
	var clean := TraceSanitizer.new().sanitize_line({"at": 1, "ms": 2, "e": "zz_neu", "text": "x"})
	assert_dict(clean).is_empty()


## Jedes Ereignis, das TraceLog schreibt, ist in der Allowlist entschieden. Ein neues
## Ereignis ohne Eintrag ginge sonst still verloren — oder, schlimmer, jemand trüge es
## eilig mit allen Feldern ein.
func test_every_trace_event_is_decided() -> void:
	var source := FileAccess.get_file_as_string("res://src/learning/trace_log.gd")
	var re := RegEx.create_from_string("\"e\":\\s*\"([a-z_]+)\"")
	var found := 0
	for m in re.search_all(source):
		found += 1
		assert_bool(TraceSanitizer.KEEP.has(m.get_string(1))).append_failure_message(
				"Spurereignis '%s' fehlt in TraceSanitizer.KEEP" % m.get_string(1)).is_true()
	assert_int(found).is_greater(10)


func test_distance() -> void:
	assert_int(TraceSanitizer.distance("", "abc")).is_equal(3)
	assert_int(TraceSanitizer.distance("kitten", "sitting")).is_equal(3)
	assert_int(TraceSanitizer.distance("same", "same")).is_equal(0)


func test_marks_order_by_second_first() -> void:
	# ms springt nach einem Neustart zurück; die Sekunde entscheidet.
	assert_bool(TraceSanitizer.is_after([101, 5], [100, 90000])).is_true()
	assert_bool(TraceSanitizer.is_after([100, 5], [100, 6])).is_false()
	assert_bool(TraceSanitizer.is_after([100, 6], [100, 6])).is_false()
