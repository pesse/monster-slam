extends GdUnitTestSuite
## Kampfuhr (BattleClock): misst Echtzeit, ohne angehaltenen Baum und ohne `hold`.

var _clock: BattleClock


func before_test() -> void:
	_clock = BattleClock.new()
	_clock.emit_events = false
	add_child(_clock)


func after_test() -> void:
	get_tree().paused = false
	_clock.free()


func test_it_measures_between_start_and_stop() -> void:
	_clock.start()
	OS.delay_msec(40)
	_clock.stop()
	assert_int(_clock.elapsed_ms()).is_between(40, 200)
	assert_bool(_clock.is_running()).is_false()


func test_a_paused_tree_does_not_count() -> void:
	_clock.start()
	OS.delay_msec(20)
	get_tree().paused = true
	OS.delay_msec(300)
	get_tree().paused = false
	OS.delay_msec(20)
	_clock.stop()
	assert_int(_clock.elapsed_ms()).is_between(40, 200)


func test_a_start_in_a_paused_tree_waits_for_the_unpause() -> void:
	get_tree().paused = true
	_clock.start()
	OS.delay_msec(300)
	get_tree().paused = false
	OS.delay_msec(20)
	_clock.stop()
	assert_int(_clock.elapsed_ms()).is_between(20, 200)


func test_hold_stops_the_clock_without_ending_it() -> void:
	_clock.hold(true)
	_clock.start()
	OS.delay_msec(300)
	_clock.hold(false)
	OS.delay_msec(20)
	assert_bool(_clock.is_running()).is_true()
	_clock.stop()
	assert_int(_clock.elapsed_ms()).is_between(20, 200)


func test_stop_reports_once() -> void:
	var reports: Array = []
	var record := func(kind: String, _at: int, ms: int) -> void: reports.append([kind, ms])
	EventBus.battle_timed.connect(record)
	_clock.emit_events = true
	_clock.kind = "zz-clock-test"
	_clock.start()
	_clock.stop()
	_clock.stop()
	EventBus.battle_timed.disconnect(record)
	assert_array(reports).has_size(1)
	assert_str(str(reports[0][0])).is_equal("zz-clock-test")
