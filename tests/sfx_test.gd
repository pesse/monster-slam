extends GdUnitTestSuite
## Tests für die Soundausgabe (Autoload `Sfx`).
##
## Geprüft wird die Auswahl-Logik über den Test-Seam `Sfx.last_played`, nicht der Ton:
## headless läuft der Dummy-Audio-Treiber, und `assets/audio/` kann leer sein (die Dateien
## liegen nicht zwingend im Checkout). Beides darf die Tests weder rot machen noch
## still durchwinken — deshalb der Seam.
##
## Jeder Testfall benutzt eigene Ids: der Cooldown lebt im Autoload und wird zwischen den
## Fällen nicht zurückgesetzt, zwei Fälle mit derselben Id würden sich gegenseitig
## unterdrücken.

var _saved_sfx_volume := 1.0


func before_test() -> void:
	# Die Lautstärke steht geräteweit in user://settings.cfg — der Testlauf darf die echte
	# Einstellung des Entwicklers nicht verstellen.
	_saved_sfx_volume = UserSettings.sfx_volume()


func after_test() -> void:
	UserSettings.set_sfx_volume(_saved_sfx_volume)
	Sfx.apply_volumes()


func test_buses_from_layout_exist() -> void:
	assert_int(AudioServer.get_bus_index(Sfx.BUS_SFX)).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index(Sfx.BUS_MUSIC)).is_greater_equal(0)
	assert_str(AudioServer.get_bus_send(AudioServer.get_bus_index(Sfx.BUS_SFX))).is_equal("Master")


func test_unknown_id_does_not_crash() -> void:
	Sfx.last_played = &""
	Sfx.play(&"gibt_es_nicht")
	# Nur angenommene Ids landen im Seam — eine unbekannte hinterlässt nichts.
	assert_str(String(Sfx.last_played)).is_equal("")


func test_seam_reports_requested_id() -> void:
	Sfx.play(&"slow_mo_in")
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_in")


func test_cooldown_suppresses_immediate_repeat() -> void:
	Sfx.play(&"monster_kill")
	assert_str(String(Sfx.last_played)).is_equal("monster_kill")
	# Andere Id, eigener Cooldown: wird angenommen …
	Sfx.play(&"slow_mo_out")
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_out")
	# … dieselbe Id unmittelbar danach nicht mehr.
	Sfx.play(&"monster_kill")
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_out")


func test_cooldown_expires() -> void:
	# ignore_time_scale, damit der Timer auch bei laufender Slow-Motion in Echtzeit misst.
	await get_tree().create_timer(Sfx.COOLDOWN_MS * 2.0 / 1000.0, true, false, true).timeout
	Sfx.play(&"monster_kill")
	assert_str(String(Sfx.last_played)).is_equal("monster_kill")


func test_volume_zero_mutes_instead_of_minus_inf() -> void:
	var idx := AudioServer.get_bus_index(Sfx.BUS_SFX)
	UserSettings.set_sfx_volume(0.0)
	Sfx.apply_volumes()
	assert_bool(AudioServer.is_bus_mute(idx)).is_true()
	assert_bool(is_inf(AudioServer.get_bus_volume_db(idx))).is_false()
	UserSettings.set_sfx_volume(1.0)
	Sfx.apply_volumes()
	assert_bool(AudioServer.is_bus_mute(idx)).is_false()
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(0.0, 0.01)
