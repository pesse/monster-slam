extends GdUnitTestSuite
## Tests für die Lautstärke-Einstellungen in UserSettings.
##
## Wichtig ist hier nicht nur der Wertebereich, sondern der Ablageort: Lautstärke gehört in
## die Sektion [general] und damit ans Gerät, NICHT ans Profil — sonst wäre es plötzlich
## laut, weil ein anderes Kind spielt. Der Test liest die Datei deshalb direkt nach.
##
## Die Einstellung ist geräteweit, es gibt also kein Wegwerf-Profil, hinter dem sich der
## Test verstecken könnte: er sichert den echten Wert und stellt ihn wieder her.

var _saved_sfx := 1.0
var _saved_music := 1.0


func before_test() -> void:
	_saved_sfx = UserSettings.sfx_volume()
	_saved_music = UserSettings.music_volume()


func after_test() -> void:
	UserSettings.set_sfx_volume(_saved_sfx)
	UserSettings.set_music_volume(_saved_music)


func test_defaults_are_full_volume() -> void:
	UserSettings.set_sfx_volume(UserSettings.DEFAULT_VOLUME)
	UserSettings.set_music_volume(UserSettings.DEFAULT_VOLUME)
	assert_float(UserSettings.sfx_volume()).is_equal(1.0)
	assert_float(UserSettings.music_volume()).is_equal(1.0)


func test_roundtrip() -> void:
	UserSettings.set_sfx_volume(0.42)
	UserSettings.set_music_volume(0.25)
	assert_float(UserSettings.sfx_volume()).is_equal_approx(0.42, 0.0001)
	assert_float(UserSettings.music_volume()).is_equal_approx(0.25, 0.0001)


func test_clamped_low() -> void:
	UserSettings.set_sfx_volume(-1.0)
	UserSettings.set_music_volume(-0.5)
	assert_float(UserSettings.sfx_volume()).is_equal(0.0)
	assert_float(UserSettings.music_volume()).is_equal(0.0)


func test_clamped_high() -> void:
	UserSettings.set_sfx_volume(4.0)
	UserSettings.set_music_volume(9.0)
	assert_float(UserSettings.sfx_volume()).is_equal(1.0)
	assert_float(UserSettings.music_volume()).is_equal(1.0)


func test_stored_in_general_section() -> void:
	UserSettings.set_sfx_volume(0.3)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(UserSettings.PATH)).is_equal(OK)
	assert_float(float(cfg.get_value("general", "sfx_volume", -1.0))).is_equal_approx(0.3, 0.0001)
