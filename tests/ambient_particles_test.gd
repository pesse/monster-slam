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


## Zur Asche gehört Glut: sie steigt als eigener Schwarm über derselben Fläche auf.
func test_ash_brings_embers() -> void:
	var ash := auto_free(AmbientParticles.build("ash", AREA)) as CPUParticles3D
	assert_int(ash.get_child_count()).is_equal(1)
	var embers := ash.get_child(0) as CPUParticles3D
	assert_float(embers.direction.y).is_greater(0.0)
	assert_float(ash.direction.y).is_less(0.0)
	assert_float((ash.position + embers.position).x).is_equal_approx(AREA.get_center().x, 0.001)
	assert_float((ash.position + embers.position).z).is_equal_approx(AREA.get_center().y, 0.001)


func test_no_kind_means_clear_air() -> void:
	assert_object(AmbientParticles.build("", AREA)).is_null()


## Laub fällt aus den Kronen, wenn es welche gibt: alle Startpunkte liegen in einer.
func test_leaves_fall_from_the_crowns() -> void:
	var crowns: Array[AABB] = [AABB(Vector3(-10.0, 3.0, 0.0), Vector3(3.0, 4.0, 3.0)),
			AABB(Vector3(8.0, 2.0, -5.0), Vector3(2.0, 3.0, 2.0))]
	var p := auto_free(AmbientParticles.build("leaves", AREA, crowns)) as CPUParticles3D
	assert_int(p.emission_shape).is_equal(CPUParticles3D.EMISSION_SHAPE_POINTS)
	assert_int(p.emission_points.size()).is_equal(crowns.size() * AmbientParticles.POINTS_PER_CROWN)
	for point in p.emission_points:
		assert_bool(crowns.any(func(c: AABB) -> bool: return c.grow(0.001).has_point(point))).is_true()
	assert_object(p.mesh).is_instanceof(ArrayMesh)


## Kirschblüten fallen aus den Kronen der Blütenbäume, kleiner als Laub; ohne Kronen keine.
func test_blossoms_fall_from_blossom_crowns() -> void:
	assert_object(AmbientParticles.blossoms([])).is_null()
	var crowns: Array[AABB] = [AABB(Vector3(-4.0, 2.0, 1.0), Vector3(3.0, 3.0, 3.0))]
	var p := auto_free(AmbientParticles.blossoms(crowns)) as CPUParticles3D
	assert_int(p.emission_shape).is_equal(CPUParticles3D.EMISSION_SHAPE_POINTS)
	for point in p.emission_points:
		assert_bool(crowns[0].grow(0.001).has_point(point)).is_true()
	assert_float(p.mesh.get_aabb().size.y).is_less(AmbientParticles.SPEC.leaves.size)
	assert_bool(AmbientParticles.LEAF_TREES.has("blossom_tree")).is_false()
