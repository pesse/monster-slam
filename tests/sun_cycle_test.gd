extends GdUnitTestSuite
## Der Tag der Sonne: tief am Morgen, hoch am Mittag, dann der Sprung zurück — aber nicht,
## solange `hold` gesetzt ist (im Kampf: während einer Welle).

const WAVE_RUNNER := preload("res://src/battle/wave_runner.gd")


func _cycle() -> SunCycle:
	var cycle: SunCycle = auto_free(SunCycle.new())
	cycle.sun = auto_free(DirectionalLight3D.new())
	cycle.noon_yaw = 45.0
	cycle.follow_clock = false
	return cycle


func test_a_day_in_the_game_lasts_a_quarter_of_a_real_one() -> void:
	assert_float(SunCycle.clock_phase(0.0)).is_equal_approx(0.0, 1e-6)
	assert_float(SunCycle.clock_phase(3.0 * 3600.0)).is_equal_approx(0.5, 1e-6)
	# Nach sechs Stunden beginnt der nächste Tag.
	assert_float(SunCycle.clock_phase(6.0 * 3600.0 + 60.0)).is_less(0.01)


func test_the_sun_stands_low_in_the_morning_and_high_at_noon() -> void:
	var cycle := _cycle()
	assert_float(cycle.elevation_at(0.0)).is_equal_approx(SunCycle.LOW, 1e-4)
	assert_float(cycle.elevation_at(0.5)).is_equal_approx(SunCycle.HIGH, 1e-4)
	assert_float(cycle.yaw_at(0.5)).is_equal_approx(45.0, 1e-4)
	assert_float(cycle.yaw_at(0.0)).is_equal_approx(45.0 - SunCycle.SWEEP * 0.5, 1e-4)


## `sun_sin` für den Boden lässt sich kopflos nicht zurücklesen (global_shader_parameter_get
## gibt es nur mit Renderer) — geprüft wird die Sonne selbst.
func test_apply_turns_the_sun() -> void:
	var cycle := _cycle()
	cycle.phase = 0.0
	cycle.apply()
	assert_float(cycle.sun.rotation_degrees.x).is_equal_approx(-SunCycle.LOW, 1e-3)
	assert_float(cycle.sun.rotation_degrees.y).is_equal_approx(45.0 - SunCycle.SWEEP * 0.5, 1e-3)


## Das eigentliche Versprechen: aus der Iso-Sicht fallen die Schatten morgens nach rechts
## und abends nach links. Geprüft an der Kamera des Kampfs (WaveRunner.setup_view).
func test_shadows_fall_right_in_the_morning_and_left_in_the_evening() -> void:
	var pivot: Node3D = auto_free(Node3D.new())
	var camera: Camera3D = auto_free(Camera3D.new())
	var sun: DirectionalLight3D = auto_free(DirectionalLight3D.new())
	pivot.add_child(camera)
	add_child(pivot)
	add_child(sun)
	WAVE_RUNNER.setup_view(pivot, camera, sun)
	var cycle := _cycle()
	cycle.sun = sun
	cycle.noon_yaw = SunCycle.yaw_of(pivot)
	var right := camera.global_transform.basis.x
	var ahead := -camera.global_transform.basis.z
	var shadow := func(p: float) -> Vector3:
		cycle.phase = p
		cycle.apply()
		var d := -sun.global_transform.basis.z
		return Vector3(d.x, 0.0, d.z).normalized()
	assert_float(shadow.call(0.0).dot(right)).is_greater(0.99)
	assert_float(shadow.call(0.9999).dot(right)).is_less(-0.99)
	# Mittags steht die Sonne hinter der Kamera: die Schatten fallen nach hinten ins Bild.
	assert_float(shadow.call(0.5).dot(Vector3(ahead.x, 0.0, ahead.z).normalized())).is_greater(0.99)
	remove_child(pivot)
	remove_child(sun)


func test_the_jump_to_morning_waits_for_the_wave() -> void:
	var cycle := _cycle()
	cycle.advance(0.99)
	cycle.hold = true
	cycle.advance(0.995)
	assert_float(cycle.phase).is_equal_approx(0.995, 1e-6)
	# Die Uhr springt auf den Morgen — die Sonne bleibt am Abend.
	cycle.advance(0.01)
	assert_float(cycle.phase).is_equal_approx(0.995, 1e-6)
	cycle.hold = false
	cycle.advance(0.02)
	assert_float(cycle.phase).is_equal_approx(0.02, 1e-6)


func test_yaw_of_reads_the_direction_back() -> void:
	var sun: DirectionalLight3D = auto_free(DirectionalLight3D.new())
	add_child(sun)
	sun.rotation_degrees = Vector3(-40.0, 70.0, 0.0)
	assert_float(SunCycle.yaw_of(sun)).is_equal_approx(70.0, 1e-3)
	remove_child(sun)
