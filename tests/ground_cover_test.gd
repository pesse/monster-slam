extends GdUnitTestSuite
## Der Bewuchs (GroundCover): wo er wächst und wo nicht.

const GATE := 16.5


func test_tufts_grow_but_not_on_the_path_or_in_the_fortress() -> void:
	var site := _site()
	var tufts := _plan(_theme(), site, 1.0).tufts as Array
	assert_int(tufts.size()).is_greater(200)
	for item: Array in tufts:
		var at: Vector3 = (item[0] as Transform3D).origin
		assert_bool(site.path.blocks(at.x, at.z, 0.0)).is_false()
		assert_bool(site.keep_out.has_point(Vector2(at.x, at.z))).is_false()


func test_the_quality_thins_the_tufts() -> void:
	var full := (_plan(_theme(), _site(), 1.0).tufts as Array).size()
	var half := (_plan(_theme(), _site(), 0.5).tufts as Array).size()
	assert_float(float(half) / full).is_between(0.4, 0.6)
	assert_int((_plan(_theme(), _site(), 0.0).tufts as Array).size()).is_equal(0)


## In „Schnell" gibt es keine Büschel, die Sträucher um die Bäume bleiben.
func test_bushes_stay_without_tufts() -> void:
	var site := _site()
	site.trees = [Vector3(-20.0, 0.0, -10.0), Vector3(20.0, 0.0, 0.0), Vector3(-25.0, 0.0, 5.0)]
	var theme := _theme()
	theme.bushes = 1.0
	var bushes := _plan(theme, site, 0.0).bushes as Array
	assert_int(bushes.size()).is_greater(0)
	for item: Array in bushes:
		var at: Vector3 = (item[0] as Transform3D).origin
		assert_float(_nearest_tree(site.trees, at)).is_less_equal(GroundCover.BUSH_RING.y + 0.01)


func test_grow_builds_one_node_per_kind() -> void:
	var site := _site()
	site.trees = [Vector3(-20.0, 0.0, -10.0), Vector3(20.0, 0.0, 0.0), Vector3(-25.0, 0.0, 5.0)]
	var theme := _theme()
	theme.bushes = 1.0
	theme.cover_flowers = [Color.WHITE]
	theme.cover_flower_amount = 0.5
	var parent := auto_free(Node3D.new()) as Node3D
	GroundCover.grow(parent, theme, site, 1.0, _rng())
	assert_object(parent.get_node_or_null("Tufts")).is_instanceof(MultiMeshInstance3D)
	assert_object(parent.get_node_or_null("Flowers")).is_instanceof(MultiMeshInstance3D)
	assert_object(parent.get_node_or_null("Bushes")).is_instanceof(MultiMeshInstance3D)


func test_a_theme_without_cover_grows_nothing() -> void:
	var theme := _theme()
	theme.cover = 0.0
	theme.bushes = 0.0
	var site := _site()
	site.trees = [Vector3(-20.0, 0.0, -10.0)]
	var parent := auto_free(Node3D.new()) as Node3D
	GroundCover.grow(parent, theme, site, 1.0, _rng())
	assert_int(parent.get_child_count()).is_equal(0)


## Auf Schnee wächst kein Gras: hier ist alles über der Kuppenhöhe.
func test_nothing_grows_in_snow() -> void:
	var theme := _theme()
	theme.peak_height = 0.5
	var site := _site()
	site.height = func(_x: float, _z: float) -> float: return 2.0
	assert_int((_plan(theme, site, 1.0).tufts as Array).size()).is_equal(0)


## Ohne eigene Büschelfarbe die des Bodens darunter, heller; mit eigener die.
func test_tufts_take_the_ground_colour_unless_the_theme_names_one() -> void:
	var theme := _theme()
	var first: Color = (_plan(theme, _site(), 1.0).tufts as Array)[0][1]
	var ground := theme.ground_color(0.5, 0.0).srgb_to_linear() * GroundCover.TUFT_LIFT
	assert_float(first.g).is_between(ground.g * 0.8, ground.g * 1.2)
	theme.cover_color = Color(0.9, 0.1, 0.1)
	first = (_plan(theme, _site(), 1.0).tufts as Array)[0][1]
	assert_float(first.r).is_greater(first.g * 3.0)


func test_every_theme_has_sensible_cover() -> void:
	for f in DirAccess.get_files_at(BattleTheme.DIR):
		if not f.ends_with(".tres"):
			continue
		var theme := BattleTheme.named(f.get_basename())
		assert_float(theme.cover).override_failure_message(f).is_between(0.0, 4.0)
		assert_float(theme.bushes).override_failure_message(f).is_between(0.0, 1.0)


func _theme() -> BattleTheme:
	var theme := BattleTheme.new()
	theme.cover = 1.0
	return theme


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func _site() -> GroundCover.Site:
	var path_rng := RandomNumberGenerator.new()
	path_rng.seed = 7
	var site := GroundCover.Site.new()
	site.area = Rect2(-30.0, -30.0, 60.0, 60.0)
	site.on_screen = func(_x: float, _z: float) -> bool: return true
	site.height = func(_x: float, _z: float) -> float: return 0.0
	site.t_at = func(_x: float, _z: float) -> float: return 0.5
	site.path = BattlePath.make("trail", GATE, path_rng)
	site.keep_out = Rect2(-11.0, GATE - 0.5, 22.0, 12.0)
	return site


func _plan(theme: BattleTheme, site: GroundCover.Site, density: float) -> Dictionary:
	return GroundCover.plan(theme, site, density, _rng())


func _nearest_tree(trees: Array[Vector3], at: Vector3) -> float:
	var best := INF
	for t in trees:
		best = minf(best, Vector2(t.x, t.z).distance_to(Vector2(at.x, at.z)))
	return best
