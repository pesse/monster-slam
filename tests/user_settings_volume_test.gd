extends GdUnitTestSuite
## Lautstärken und Musik-Set je Profil (ADR 0028, Nachtrag ADR 0033): eigener Wert je
## Profil, ohne ihn der alte geräteweite aus [general]. Läuft auf einer eigenen Instanz
## mit eigener Datei.

const CFG := "user://zz-settings-volume-test.cfg"

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


func test_defaults_are_full_volume_and_the_standard_set() -> void:
	assert_float(_settings.call("sfx_volume")).is_equal(1.0)
	assert_float(_settings.call("music_volume")).is_equal(1.0)
	assert_str(String(_settings.call("music_set"))).is_equal(String(MusicSet.DEFAULT_ID))


func test_volume_is_clamped() -> void:
	_settings.call("set_sfx_volume", -1.0)
	_settings.call("set_music_volume", 9.0)
	assert_float(_settings.call("sfx_volume")).is_equal(0.0)
	assert_float(_settings.call("music_volume")).is_equal(1.0)


func test_volume_and_set_belong_to_one_profile() -> void:
	_settings.call("set_music_volume", 0.25)
	_settings.call("set_sfx_volume", 0.4)
	_settings.call("set_music_set", &"zz-andere")
	assert_float(_settings.call("music_volume")).is_equal_approx(0.25, 0.0001)
	assert_float(_settings.call("sfx_volume")).is_equal_approx(0.4, 0.0001)
	assert_float(_settings.call("music_volume", "zz-b")).is_equal(1.0)
	assert_float(_settings.call("sfx_volume", "zz-b")).is_equal(1.0)
	assert_str(String(_settings.call("music_set", "zz-b"))).is_equal(String(MusicSet.DEFAULT_ID))


## Wer vorher geräteweit leiser gestellt hatte, behält das in jedem Profil.
func test_an_old_device_volume_still_counts() -> void:
	(_settings.get("_config") as ConfigFile).set_value("general", "music_volume", 0.3)
	assert_float(_settings.call("music_volume", "zz-b")).is_equal_approx(0.3, 0.0001)
	_settings.call("set_music_volume", 0.8, "zz-b")
	assert_float(_settings.call("music_volume", "zz-b")).is_equal_approx(0.8, 0.0001)
	assert_float(_settings.call("music_volume", "zz-a")).is_equal_approx(0.3, 0.0001)
