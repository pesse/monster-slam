extends GdUnitTestSuite
## Kampfzeit aus der Spur (BattleBackfill): Abschnitte und Zuordnung zu Sitzungen.


func _line(e: String, at: int, ms: int, extra := {}) -> Dictionary:
	var line := {"at": at, "ms": ms, "e": e}
	line.merge(extra)
	return line


func test_a_cleared_wave_counts_from_start_to_clear() -> void:
	var segs := BattleBackfill.segments([
		_line("run_start", 100, 1000),
		_line("wave_start", 101, 2000),
		_line("answer", 110, 11000),
		_line("wave_clear", 140, 41000),
		_line("badge", 150, 51000),
	])
	assert_array(segs).has_size(1)
	assert_str(str(segs[0]["kind"])).is_equal("wave")
	assert_int(int(segs[0]["started_at"])).is_equal(101)
	assert_int(int(segs[0]["ms"])).is_equal(39000)


func test_a_lost_wave_ends_with_its_last_line_not_the_run_end() -> void:
	var segs := BattleBackfill.segments([
		_line("wave_start", 100, 1000),
		_line("leak", 120, 21000),
		_line("run_end", 400, 301000),
	])
	assert_int(int(segs[0]["ms"])).is_equal(20000)


func test_a_long_silence_counts_only_up_to_the_cap() -> void:
	var segs := BattleBackfill.segments([
		_line("wave_start", 100, 0),
		_line("answer", 1000, 900000),
		_line("wave_clear", 1010, 910000),
	])
	assert_int(int(segs[0]["ms"])).is_equal(BattleBackfill.GAP_CAP_MS + 10000)


func test_a_restart_closes_the_open_fight() -> void:
	var segs := BattleBackfill.segments([
		_line("boss_start", 100, 50000, {"boss": "boss.grammar_golem"}),
		_line("boss_answer", 130, 80000),
		_line("wave_start", 900, 3000),
		_line("wave_clear", 920, 23000),
	])
	assert_array(segs).has_size(2)
	assert_str(str(segs[0]["kind"])).is_equal("boss.grammar_golem")
	assert_int(int(segs[0]["ms"])).is_equal(30000)
	assert_int(int(segs[1]["ms"])).is_equal(20000)


func test_waves_go_into_their_session_and_bosses_stay_apart() -> void:
	var first := {"started_at": 100, "ended_at": 500}
	var second := {"started_at": 501, "ended_at": 900}
	var rest := BattleBackfill.apply([first, second], [
		{"kind": "wave", "started_at": 110, "ms": 1000},
		{"kind": "wave", "started_at": 502, "ms": 2000},
		{"kind": "wave", "started_at": 505, "ms": 3000},
		{"kind": "boss.grammar_golem", "started_at": 600, "ms": 4000},
		{"kind": "wave", "started_at": 5000, "ms": 5000},
	])
	assert_int(int(first["battle_ms"])).is_equal(1000)
	assert_int(int(second["battle_ms"])).is_equal(5000)
	assert_array(rest).has_size(2)
	assert_str(str(rest[0]["kind"])).is_equal("boss.grammar_golem")
	assert_int(int(rest[1]["battle_ms"])).is_equal(5000)
