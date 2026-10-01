extends GdUnitTestSuite
## Die Grafikstufe (GraphicsQuality) und ihr Ablageort in UserSettings.
##
## Geräteweit wie die Lautstärke — kein Wegwerf-Profil, der Test sichert den echten Wert
## und stellt ihn wieder her.

const Level := GraphicsQuality.Level

var _saved: GraphicsQuality.Level = Level.FINE


func before_test() -> void:
	_saved = UserSettings.graphics_quality()


func after_test() -> void:
	UserSettings.set_graphics_quality(_saved)


func test_fine_keeps_everything() -> void:
	assert_int(GraphicsQuality.msaa(Level.FINE)).is_equal(Viewport.MSAA_4X)
	assert_bool(GraphicsQuality.glow(Level.FINE)).is_true()
	assert_bool(GraphicsQuality.clouds(Level.FINE)).is_true()
	assert_bool(GraphicsQuality.particles(Level.FINE)).is_true()
	assert_bool(GraphicsQuality.patches(Level.FINE)).is_true()
	assert_bool(GraphicsQuality.grading(Level.FINE)).is_true()


func test_medium_drops_glow_and_halves_msaa() -> void:
	assert_int(GraphicsQuality.msaa(Level.MEDIUM)).is_equal(Viewport.MSAA_2X)
	assert_bool(GraphicsQuality.glow(Level.MEDIUM)).is_false()
	assert_bool(GraphicsQuality.clouds(Level.MEDIUM)).is_true()
	assert_bool(GraphicsQuality.particles(Level.MEDIUM)).is_true()
	assert_bool(GraphicsQuality.patches(Level.MEDIUM)).is_true()
	assert_bool(GraphicsQuality.grading(Level.MEDIUM)).is_true()


func test_fast_drops_the_expensive_parts() -> void:
	assert_int(GraphicsQuality.msaa(Level.FAST)).is_equal(Viewport.MSAA_DISABLED)
	assert_bool(GraphicsQuality.glow(Level.FAST)).is_false()
	assert_bool(GraphicsQuality.clouds(Level.FAST)).is_false()
	assert_bool(GraphicsQuality.particles(Level.FAST)).is_false()
	assert_bool(GraphicsQuality.patches(Level.FAST)).is_false()
	assert_bool(GraphicsQuality.grading(Level.FAST)).is_false()


## Die Stufe liegt in [general] und damit am Gerät, nicht am Profil.
func test_the_setting_is_device_wide() -> void:
	UserSettings.set_graphics_quality(Level.MEDIUM)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(UserSettings.PATH)).is_equal(OK)
	assert_int(cfg.get_value("general", "graphics_quality", -1)).is_equal(Level.MEDIUM)
	assert_int(GraphicsQuality.level()).is_equal(Level.MEDIUM)


## Wer früher „Einfach" gewählt hatte (nur `graphics_simple`), spielt auf „Schnell".
func test_the_old_simple_switch_reads_as_fast() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "graphics_simple", true)
	assert_int(_level_of(cfg)).is_equal(Level.FAST)
	cfg.set_value("general", "graphics_simple", false)
	assert_int(_level_of(cfg)).is_equal(Level.FINE)
	# Eine gespeicherte Stufe geht vor.
	cfg.set_value("general", "graphics_simple", true)
	cfg.set_value("general", "graphics_quality", Level.MEDIUM)
	assert_int(_level_of(cfg)).is_equal(Level.MEDIUM)


## Umschalten wirkt sofort auf die Kantenglättung des Fensters.
func test_switching_applies_to_the_window() -> void:
	UserSettings.set_graphics_quality(Level.FAST)
	assert_int(get_tree().root.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	UserSettings.set_graphics_quality(Level.MEDIUM)
	assert_int(get_tree().root.msaa_3d).is_equal(Viewport.MSAA_2X)
	UserSettings.set_graphics_quality(Level.FINE)
	assert_int(get_tree().root.msaa_3d).is_equal(Viewport.MSAA_4X)


## Ohne Glow und Farbkorrektur wird das Environment kopiert, nicht das geteilte der Szene
## geändert.
func test_fast_turns_off_glow_and_grading_on_a_copy() -> void:
	var env := Environment.new()
	env.glow_enabled = true
	env.adjustment_enabled = true
	var world := auto_free(WorldEnvironment.new()) as WorldEnvironment
	world.environment = env
	GraphicsQuality.apply_environment(world, Level.FAST)
	assert_bool(world.environment.glow_enabled).is_false()
	assert_bool(world.environment.adjustment_enabled).is_false()
	assert_bool(env.glow_enabled).is_true()
	assert_object(world.environment).is_not_same(env)


## „Mittel" nimmt nur den Glow, die Farbkorrektur bleibt.
func test_medium_keeps_the_grading() -> void:
	var env := Environment.new()
	env.glow_enabled = true
	env.adjustment_enabled = true
	var world := auto_free(WorldEnvironment.new()) as WorldEnvironment
	world.environment = env
	GraphicsQuality.apply_environment(world, Level.MEDIUM)
	assert_bool(world.environment.glow_enabled).is_false()
	assert_bool(world.environment.adjustment_enabled).is_true()


## Die Stufe, die UserSettings aus dieser Datei läse — über eine eigene Instanz, damit die
## echte Einstellung unberührt bleibt.
func _level_of(cfg: ConfigFile) -> GraphicsQuality.Level:
	var settings: Node = auto_free(UserSettings.get_script().new())
	settings.set("_config", cfg)
	return settings.call("graphics_quality")
