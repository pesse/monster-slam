extends GdUnitTestSuite
## settings.cfg (ADR 0024): eine kaputte oder fehlende Datei setzt die Profilliste nie still
## zurück. Erst die Kopie aus der neuesten Sicherung, sonst eine aus den Spielständen
## gebaute Liste — und in beiden Fällen ein Hinweis.
##
## Eine eigene Instanz mit eigenen Ordnern; jede Datei wird einzeln weggeräumt.

const USER_SETTINGS := preload("res://src/core/user_settings.gd")
const ROOT := "user://zz-settings-recovery"
const CFG := ROOT + "/settings.cfg"
const GOOD := ROOT + "/good.cfg"
const PROGRESS := ROOT + "/progress"
const BACKUPS := ROOT + "/backups"
const QUARANTINE := ROOT + "/quarantine"
const PROFILE_FILES := ["anna.json", "anna_level.json", "ben_wallet.json", "zz-probe.json"]

var _settings: Node


func before_test() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(PROGRESS)
	_settings = auto_free(USER_SETTINGS.new())
	_settings.config_path = CFG
	_settings.progress_dir = PROGRESS
	_settings.backup_dir = BACKUPS
	_settings.quarantine_dir = QUARANTINE


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for id in ["anna", "_settings"]:
		for base in [BACKUPS, QUARANTINE]:
			for dir in Backups.generation_dirs(base, id):
				Backups._remove_dir(dir)
			DirAccess.remove_absolute(base.path_join(id))
	DirAccess.remove_absolute(BACKUPS)
	DirAccess.remove_absolute(QUARANTINE)
	for name: String in PROFILE_FILES:
		DirAccess.remove_absolute(PROGRESS.path_join(name))
	DirAccess.remove_absolute(PROGRESS)
	for path in [CFG, CFG + SaveStore.TMP_SUFFIX, GOOD, GOOD + SaveStore.TMP_SUFFIX]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ROOT)


func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _player_files() -> void:
	for name: String in PROFILE_FILES:
		SaveStore.write(PROGRESS.path_join(name), {"total_xp": 1})


func _roster() -> Array:
	return Array(_settings.profiles())


func test_first_start_makes_the_default() -> void:
	DirAccess.remove_absolute(PROGRESS)
	_settings.load_config()
	assert_array(_roster()).contains_exactly([USER_SETTINGS.DEFAULT_PROFILE])
	assert_dict(_settings.take_recovery_notice()).is_empty()
	assert_int(int(SaveStore.read_cfg(CFG)["status"])).is_equal(SaveStore.Status.OK)


func test_old_file_is_kept_and_gets_a_checksum() -> void:
	_put(CFG, "[profiles]\nroster=PackedStringArray(\"anna\")\n")
	_settings.load_config()
	assert_array(_roster()).contains_exactly(["anna"])
	assert_bool(bool(SaveStore.read_cfg(CFG)["legacy"])).is_false()


func test_corrupt_file_comes_back_from_the_backup() -> void:
	_player_files()
	var config := ConfigFile.new()
	config.set_value("profiles", "roster", PackedStringArray(["anna", "ben"]))
	config.set_value("general", "active_profile", "ben")
	SaveStore.write_cfg(GOOD, config.encode_to_text())
	Backups.create(BACKUPS, "anna", PROGRESS, ["", "_level"], "test", 1_760_100_000_000, GOOD)
	_put(CFG, "; sha256=" + "0".repeat(64) + "\n[profiles]\nroster=PackedStringArray()\n")
	_settings.load_config()
	assert_array(_roster()).contains_exactly(["anna", "ben"])
	assert_str(_settings.active_profile()).is_equal("ben")
	assert_str(str(_settings.take_recovery_notice()["kind"])).is_equal("settings_restored")
	# Die kaputte Datei liegt in der Quarantäne.
	var held := Backups.generation_dirs(QUARANTINE, "_settings")
	assert_int(held.size()).is_equal(1)
	assert_bool(FileAccess.file_exists(held[0].path_join("settings.cfg.corrupt"))).is_true()


func test_without_backup_the_roster_is_rebuilt_from_the_saves() -> void:
	_player_files()
	var file := FileAccess.open(CFG, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0, 0, 0]))
	file.close()
	_settings.load_config()
	assert_array(_roster()).contains_exactly(["anna"])
	assert_str(_settings.active_profile()).is_equal("anna")
	assert_str(str(_settings.take_recovery_notice()["kind"])).is_equal("settings_rebuilt")


## Fehlt die Datei, obwohl es Spielstände gibt, ist das kein Erststart.
func test_missing_file_with_saves_is_not_a_first_start() -> void:
	_player_files()
	_settings.load_config()
	assert_array(_roster()).contains_exactly(["anna"])
	assert_str(str(_settings.take_recovery_notice()["kind"])).is_equal("settings_rebuilt")
