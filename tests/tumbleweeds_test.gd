extends GdUnitTestSuite
## Steppenläufer (Tumbleweeds): rollen mit dem Wind über die Fläche und verschwinden.

const AREA := Rect2(-30.0, -40.0, 60.0, 70.0)


func test_a_weed_rolls_downwind_and_follows_the_ground() -> void:
	var weeds := _weeds(Rect2())
	weeds.roll()
	assert_int(weeds.alive()).is_equal(1)
	var node := weeds.get_child(0) as Node3D
	weeds.step(0.1)
	var from := node.position
	weeds.step(1.0)
	var moved := Vector2(node.position.x - from.x, node.position.z - from.z)
	assert_float(moved.length()).is_greater(1.0)
	assert_float(moved.normalized().dot(Tumbleweeds.WIND_DIR.normalized())).is_greater(0.9)
	# Über dem Boden (hier 2 m), nie darin.
	assert_float(node.position.y).is_greater(2.0)


func test_it_crosses_the_area_and_goes() -> void:
	var weeds := _weeds(Rect2())
	weeds.roll()
	var entered := false
	for i in 400:
		weeds.step(0.1)
		if weeds.alive() == 0:
			break
		var at := (weeds.get_child(0) as Node3D).position
		entered = entered or AREA.has_point(Vector2(at.x, at.z))
	assert_bool(entered).is_true()
	assert_int(weeds.alive()).is_equal(0)


## Wer an die Burg kommt, schrumpft weg und rollt nicht hindurch.
func test_it_vanishes_at_the_fortress() -> void:
	var weeds := _weeds(Rect2(-100.0, -100.0, 200.0, 200.0))
	weeds.roll()
	weeds.step(0.05)
	var size := (weeds.get_child(0) as Node3D).transform.basis.get_scale().x
	weeds.step(Tumbleweeds.FADE * 0.5)
	assert_float((weeds.get_child(0) as Node3D).transform.basis.get_scale().x).is_less(size)
	weeds.step(Tumbleweeds.FADE)
	assert_int(weeds.alive()).is_equal(0)


func test_at_most_two_at_a_time() -> void:
	var weeds := _weeds(Rect2())
	for i in 30:
		weeds._process(Tumbleweeds.INTERVAL.y)
	assert_int(weeds.alive()).is_less_equal(Tumbleweeds.MAX_ALIVE)


## Nur trockene Themen haben welche.
func test_dry_themes_have_them_green_ones_not() -> void:
	assert_bool(BattleTheme.named("desert").tumbleweeds).is_true()
	assert_bool(BattleTheme.named("savanna").tumbleweeds).is_true()
	assert_bool(BattleTheme.named("meadow").tumbleweeds).is_false()
	assert_bool(BattleTheme.named("forest").tumbleweeds).is_false()


func _weeds(keep_out: Rect2) -> Tumbleweeds:
	var weeds := Tumbleweeds.make(AREA, func(_x: float, _z: float) -> float: return 2.0, keep_out, 5)
	add_child(weeds)
	weeds.set_process(false)
	return auto_free(weeds)


## Mit Bildausschnitt startet er knapp davor, nicht am fernen Rand der Fläche.
func test_it_starts_just_outside_the_picture() -> void:
	var weeds := _weeds(Rect2())
	var picture := Rect2(-8.0, -8.0, 16.0, 16.0)
	weeds.on_screen = func(x: float, z: float) -> bool: return picture.has_point(Vector2(x, z))
	weeds.roll()
	var node := weeds.get_child(0) as Node3D
	var at := Vector2(node.position.x, node.position.z)
	assert_bool(picture.has_point(at)).is_false()
	assert_bool(picture.grow(4.0).has_point(at)).is_true()
	var seen := false
	for i in 30:
		weeds.step(0.1)
		at = Vector2(node.position.x, node.position.z)
		seen = seen or picture.has_point(at)
	assert_bool(seen).is_true()
