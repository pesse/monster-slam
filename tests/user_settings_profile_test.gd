extends GdUnitTestSuite
## Einstellungen je Profil (ADR 0028): eigener Wert je Profil, ohne ihn der alte
## geräteweite aus [general]. Läuft auf einer eigenen Instanz mit eigener Datei.

const CFG := "user://zz-settings-profile-test.cfg"

var _settings: Node


func before_test() -> void:
	_settings = auto_free(UserSettings.get_script().new())
	_settings.set("config_path", CFG)
	var cfg := ConfigFile.new()
	cfg.set_value("general", "active_profile", "zz-a")
	cfg.set_value("profiles", "roster", PackedStringArray(["zz-a", "zz-b"]))
	_settings.set("_config", cfg)


func after_test() -> void:
	for path in [CFG, CFG + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_standstill_is_off_by_default() -> void:
	assert_bool(_settings.call("typing_standstill")).is_false()


func test_standstill_belongs_to_one_profile() -> void:
	_settings.call("set_typing_standstill", true)
	assert_bool(_settings.call("typing_standstill")).is_true()
	assert_bool(_settings.call("typing_standstill", "zz-b")).is_false()


func test_trace_switch_belongs_to_one_profile() -> void:
	_settings.call("set_trace_enabled", false, "zz-b")
	assert_bool(_settings.call("trace_enabled", "zz-b")).is_false()
	assert_bool(_settings.call("trace_enabled", "zz-a")).is_true()


## Wer vor ADR 0028 gespielt hat, behält den geräteweiten Wert, bis das Profil eigenen hat.
func test_the_old_device_value_is_the_fallback() -> void:
	var cfg: ConfigFile = _settings.get("_config")
	cfg.set_value("general", "ui_size", UiScale.Size.LARGE)
	cfg.set_value("general", "fullscreen", true)
	cfg.set_value("general", "graphics_quality", GraphicsQuality.Level.FAST)
	cfg.set_value("ui_size", "zz-b", UiScale.Size.SMALL)
	assert_int(_settings.call("ui_size")).is_equal(UiScale.Size.LARGE)
	assert_int(_settings.call("ui_size", "zz-b")).is_equal(UiScale.Size.SMALL)
	assert_bool(_settings.call("fullscreen", "zz-b")).is_true()
	assert_int(_settings.call("graphics_quality", "zz-b")).is_equal(GraphicsQuality.Level.FAST)
