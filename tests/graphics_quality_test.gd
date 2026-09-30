extends GdUnitTestSuite
## Die Grafikstufe (GraphicsQuality) und ihr Ablageort in UserSettings.
##
## Geräteweit wie die Lautstärke — kein Wegwerf-Profil, der Test sichert den echten Wert
## und stellt ihn wieder her.

var _saved := false


func before_test() -> void:
	_saved = UserSettings.graphics_simple()


func after_test() -> void:
	UserSettings.set_graphics_simple(_saved)


func test_fine_keeps_everything() -> void:
	assert_int(GraphicsQuality.msaa(false)).is_equal(Viewport.MSAA_4X)
	assert_bool(GraphicsQuality.glow(false)).is_true()
	assert_bool(GraphicsQuality.clouds(false)).is_true()
	assert_bool(GraphicsQuality.particles(false)).is_true()


func test_simple_drops_the_expensive_parts() -> void:
	assert_int(GraphicsQuality.msaa(true)).is_equal(Viewport.MSAA_DISABLED)
	assert_bool(GraphicsQuality.glow(true)).is_false()
	assert_bool(GraphicsQuality.clouds(true)).is_false()
	assert_bool(GraphicsQuality.particles(true)).is_false()


## Die Stufe liegt in [general] und damit am Gerät, nicht am Profil.
func test_the_setting_is_device_wide() -> void:
	UserSettings.set_graphics_simple(true)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(UserSettings.PATH)).is_equal(OK)
	assert_bool(cfg.get_value("general", "graphics_simple", false)).is_true()
	assert_bool(GraphicsQuality.simple()).is_true()


## Umschalten wirkt sofort auf die Kantenglättung des Fensters.
func test_switching_applies_to_the_window() -> void:
	UserSettings.set_graphics_simple(true)
	assert_int(get_tree().root.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	UserSettings.set_graphics_simple(false)
	assert_int(get_tree().root.msaa_3d).is_equal(Viewport.MSAA_4X)


## Ohne Glow wird das Environment kopiert, nicht das geteilte der Szene geändert.
func test_simple_turns_off_glow_on_a_copy() -> void:
	var env := Environment.new()
	env.glow_enabled = true
	var world := auto_free(WorldEnvironment.new()) as WorldEnvironment
	world.environment = env
	GraphicsQuality.apply_environment(world, true)
	assert_bool(world.environment.glow_enabled).is_false()
	assert_bool(env.glow_enabled).is_true()
	assert_object(world.environment).is_not_same(env)
