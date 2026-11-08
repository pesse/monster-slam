extends GdUnitTestSuite

const FreezeWatchScript := preload("res://src/core/freeze_watch.gd")


func test_report_only_on_crossing_the_limit() -> void:
	var crumbs := PackedStringArray(["12:00:00 Welle procedural_1"])
	assert_str(FreezeWatchScript.report(4999, false, 5000, 7, crumbs)).is_empty()
	assert_str(FreezeWatchScript.report(5000, false, 5000, 7, crumbs)) \
			.contains("5.0 s").contains("Frame 7").contains("Welle procedural_1")
	assert_str(FreezeWatchScript.report(9000, true, 5000, 7, crumbs)).is_empty()
	assert_str(FreezeWatchScript.report(10, true, 5000, 7, crumbs)).contains("läuft wieder")


func test_blocked_main_thread_is_reported_and_its_end_too() -> void:
	var watch: Node = auto_free(FreezeWatchScript.new())
	var lines: Array[String] = []
	watch.sink = func(line: String) -> void: lines.append(line)
	watch.limit_ms = 300
	watch.note("Monster translate")
	watch.start()
	OS.delay_msec(900)   # der Hauptthread schlägt nicht
	for i in 4:
		watch.beat()
		OS.delay_msec(FreezeWatchScript.POLL_MS)
	watch.stop()
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).contains("[FREEZE] Hauptthread steht").contains("Monster translate")
	assert_str(lines[1]).contains("läuft wieder nach")
