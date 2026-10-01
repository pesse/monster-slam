extends GdUnitTestSuite
## Der Weg zum Tor (BattlePath): er endet im Tor, bleibt in der Bahn und ist je Kampf ein
## anderer. Gezeichnet wird er im Bodenshader — hier zählt die Form, die die Streudeko und
## der Shader teilen.

const WaveRunnerScript := preload("res://src/battle/wave_runner.gd")


func _path(seed_value: int, kind := "trail") -> BattlePath:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattlePath.make(kind, WaveRunnerScript.GOAL_Z, rng)


## Vor dem Tor läuft er gerade auf die Torachse zu, egal wie er gewürfelt ist.
func test_the_path_ends_in_the_gate() -> void:
	for s in 50:
		var path := _path(s)
		assert_float(path.centre_x(WaveRunnerScript.GOAL_Z)).is_equal_approx(0.0, 0.0001)
		assert_float(path.centre_x(WaveRunnerScript.GOAL_Z - BattlePath.STRAIGHT)).is_equal_approx(0.0, 0.0001)


## Vom Spawn bis zum Tor liegt der ganze Weg in der Bahn.
func test_the_path_stays_in_the_lane() -> void:
	for s in 200:
		var path := _path(s, "cobble")
		var z: float = WaveRunnerScript.SPAWN_Z
		while z < WaveRunnerScript.GOAL_Z:
			assert_float(absf(path.centre_x(z)) + path.half_width()) \
				.is_less_equal(WaveRunnerScript.LANE_HALF_WIDTH)
			z += 0.5


## Der Shader rechnet weitab vom Weg nichts und verlässt sich darauf, dass er nie steiler
## als etwa 1 m quer je m längs läuft (path_at: Faktor 0.65 = 1/√(1 + 1.36²)).
func test_the_path_is_never_steeper_than_the_shader_assumes() -> void:
	for s in 200:
		var path := _path(s)
		var z := -60.0
		while z < WaveRunnerScript.GOAL_Z:
			assert_float(absf(path.centre_x(z + 0.05) - path.centre_x(z - 0.05)) / 0.1).is_less(1.36)
			z += 0.5


## Jeder Kampf würfelt einen eigenen Verlauf.
func test_every_battle_has_its_own_path() -> void:
	var a := _path(1)
	var b := _path(2)
	assert_float(absf(a.centre_x(-10.0) - b.centre_x(-10.0)) + absf(a.centre_x(-20.0) - b.centre_x(-20.0))) \
		.is_greater(0.1)


## Ein Weg gibt es immer: eine unbekannte Art wird zum Trampelpfad.
func test_an_unknown_kind_becomes_a_trail() -> void:
	assert_str(_path(1, "motorway").kind).is_equal("trail")


func test_blocks_covers_the_path_and_not_beyond() -> void:
	var path := _path(3)
	var z := -10.0
	var c := path.centre_x(z)
	assert_bool(path.blocks(c, z)).is_true()
	assert_bool(path.blocks(c + path.half_width() + 3.0, z)).is_false()
	# Hinter dem Tor liegt keiner.
	assert_bool(path.blocks(0.0, WaveRunnerScript.GOAL_Z + 3.0)).is_false()


## Art, Farbe und Form kommen im Bodenmaterial an; ohne Weg zeichnet der Shader keinen.
func test_the_ground_material_carries_the_path() -> void:
	var theme := BattleTheme.new()
	theme.path = "boardwalk"
	theme.path_color = Color(0.5, 0.4, 0.3)
	var path := _path(4, theme.path)
	var mat := theme.ground_material(path) as ShaderMaterial
	assert_int(mat.get_shader_parameter("path_kind")).is_equal(BattlePath.KINDS.keys().find("boardwalk"))
	assert_vector(mat.get_shader_parameter("path_big")).is_equal(path.big)
	assert_vector(mat.get_shader_parameter("path_color")).is_equal_approx(Vector3(0.5, 0.4, 0.3), Vector3.ONE * 0.0001)
	assert_that(theme.ground_material().get_shader_parameter("path_kind")).is_null()


## Jedes Thema nennt eine Wegart, die es gibt.
func test_every_theme_names_a_known_path() -> void:
	for file in DirAccess.get_files_at(BattleTheme.DIR):
		if not file.ends_with(".tres"):
			continue
		var theme := load(BattleTheme.DIR.path_join(file)) as BattleTheme
		assert_bool(BattlePath.KINDS.has(theme.path)) \
			.override_failure_message("%s: unbekannter Weg '%s'" % [file, theme.path]).is_true()
