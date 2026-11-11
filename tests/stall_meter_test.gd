extends GdUnitTestSuite


## Füttert `meter` mit `count` Frames im Abstand `gap_ms` ab `start`; gibt die Meldungen zurück.
func _feed(meter: StallMeter, start: int, gap_ms: int, count: int) -> Array[int]:
	var hits: Array[int] = []
	for i in count:
		var stalled := meter.frame(start + i * gap_ms)
		if stalled > 0:
			hits.append(stalled)
	return hits


func test_smooth_frames_never_stall() -> void:
	assert_array(_feed(StallMeter.new(), 0, 16, 600)).is_empty()
	assert_array(_feed(StallMeter.new(), 0, 1000 / StallMeter.MIN_FRAMES, 120)).is_empty()


func test_a_long_gap_stalls_once() -> void:
	var meter := StallMeter.new()
	_feed(meter, 0, 16, 60)
	assert_int(meter.frame(944 + StallMeter.GAP_MS)).is_equal(StallMeter.GAP_MS)
	assert_array(_feed(meter, 944 + StallMeter.GAP_MS + 16, 16, 120)).is_empty()


func test_a_shader_hitch_is_no_stall() -> void:
	var meter := StallMeter.new()
	_feed(meter, 0, 16, 60)
	assert_int(meter.frame(944 + 1500)).is_equal(0)
	assert_array(_feed(meter, 944 + 1500 + 16, 16, 120)).is_empty()


func test_low_frame_rate_stalls_within_a_second() -> void:
	var meter := StallMeter.new()
	_feed(meter, 0, 16, 60)
	var hits := _feed(meter, 960, 125, 10)
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0]).is_equal(125)
	# Danach misst es neu: wieder erst nach einer vollen Sekunde.
	assert_int(_feed(StallMeter.new(), 0, 125, 9).size()).is_equal(1)
	assert_int(_feed(meter, 960 + 10 * 125, 125, 6).size()).is_equal(0)
