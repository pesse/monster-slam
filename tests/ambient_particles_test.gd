extends GdUnitTestSuite
## Was in der Luft treibt (AmbientParticles), je Art des BattleTheme.

const AREA := Rect2(-30.0, -60.0, 60.0, 90.0)


func test_every_kind_fills_the_area() -> void:
	for kind: String in AmbientParticles.KINDS:
		var p := auto_free(AmbientParticles.build(kind, AREA)) as CPUParticles3D
		assert_object(p).override_failure_message(kind).is_not_null()
		assert_int(p.amount).is_greater_equal(8)
		assert_float(p.position.x).is_equal_approx(AREA.get_center().x, 0.001)
		assert_float(p.position.z).is_equal_approx(AREA.get_center().y, 0.001)
		assert_float(p.emission_box_extents.x).is_equal_approx(AREA.size.x * 0.5, 0.001)
		assert_float(p.emission_box_extents.z).is_equal_approx(AREA.size.y * 0.5, 0.001)
		# Beim Aufziehen des Schleiers schon voll.
		assert_float(p.preprocess).is_equal_approx(p.lifetime, 0.001)


## Dichte je Fläche: ein doppelt so großer Boden bekommt doppelt so viele Teilchen.
func test_amount_grows_with_the_area() -> void:
	# Klein genug, dass auch das Doppelte unter der Obergrenze bleibt.
	var small := auto_free(AmbientParticles.build("snow", Rect2(0.0, 0.0, 40.0, 40.0))) as CPUParticles3D
	var big := auto_free(AmbientParticles.build("snow", Rect2(0.0, 0.0, 80.0, 40.0))) as CPUParticles3D
	assert_int(big.amount).is_between(small.amount * 2 - 1, small.amount * 2 + 1)


func test_no_kind_means_clear_air() -> void:
	assert_object(AmbientParticles.build("", AREA)).is_null()
