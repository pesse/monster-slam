extends GdUnitTestSuite
## SaveCoordinator (ADR 0024): gemeinsam speichern, Welle verwerfen, beschädigte Profile aus
## der Sicherung zurückholen oder sperren, abgebrochene Commits zu Ende bringen.
##
## Eine eigene Instanz mit eigenen Sicherungs- und Quarantäne-Ordnern, Speicher-Instanzen
## auf einem `zz-`-Profil. Die Felder der Speicher werden direkt gesetzt: deren eigene
## Schreibwege laufen über das Autoload, und um das geht es hier nicht.

const COORDINATOR := preload("res://src/core/save_coordinator.gd")
const WALLET := preload("res://src/economy/wallet.gd")
const PLAYER_LEVEL := preload("res://src/progression/player_level.gd")
const PROFILE := "zz-coord"
const PROGRESS := "user://progress"
const BACKUPS := "user://zz-coord-backups"
const QUARANTINE := "user://zz-coord-quarantine"
const SETTINGS := "user://zz-coord-settings.cfg"

var _coord: Node
var _wallet: Node
var _level: Node


func before_test() -> void:
	_cleanup()
	_coord = auto_free(COORDINATOR.new())
	_coord.progress_dir = PROGRESS
	_coord.backup_dir = BACKUPS
	_coord.quarantine_dir = QUARANTINE
	_coord.settings_path = SETTINGS
	_coord.profile = PROFILE
	_wallet = auto_free(WALLET.new())
	_wallet.player_id = PROFILE
	_level = auto_free(PLAYER_LEVEL.new())
	_level.player_id = PROFILE
	_coord.register(_wallet)
	_coord.register(_level)


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for suffix: String in COORDINATOR.PROFILE_SUFFIXES:
		var path := _path(suffix)
		for file in [path, path + SaveStore.TMP_SUFFIX]:
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(file)
	var journal := PROGRESS.path_join(PROFILE + COORDINATOR.JOURNAL_SUFFIX)
	if FileAccess.file_exists(journal):
		DirAccess.remove_absolute(journal)
	for dir in Backups.generation_dirs(BACKUPS, PROFILE):
		Backups._remove_dir(dir)
	DirAccess.remove_absolute(BACKUPS.path_join(PROFILE))
	DirAccess.remove_absolute(BACKUPS)
	for dir in Backups.generation_dirs(QUARANTINE, PROFILE):
		Backups._remove_dir(dir)
	DirAccess.remove_absolute(QUARANTINE.path_join(PROFILE))
	DirAccess.remove_absolute(QUARANTINE)


func _path(suffix: String) -> String:
	return PROGRESS.path_join(Backups.file_name(PROFILE, suffix))


func _disk_xp() -> int:
	return int(SaveStore.read(_path("_level"))["data"].get("total_xp", -1))


func _put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _give(xp: int, gold: int) -> void:
	_level.total_xp = xp
	_wallet.gold = gold
	_wallet.total_earned = gold


# --- Commit -----------------------------------------------------------------------

func test_commit_writes_every_store_and_a_backup() -> void:
	_give(500, 40)
	assert_bool(_coord.commit("wave_end")).is_true()
	assert_int(_disk_xp()).is_equal(500)
	assert_int(int(SaveStore.read(_path("_wallet"))["data"]["gold"])).is_equal(40)
	var newest: Dictionary = Backups.latest(BACKUPS, PROFILE)
	assert_str(str(newest.get("reason", ""))).is_equal("wave_end")
	assert_bool(FileAccess.file_exists(PROGRESS.path_join(PROFILE + COORDINATOR.JOURNAL_SUFFIX))).is_false()


## Der Vorfall: im Speicher 10 XP, auf der Platte 32 500 — nichts wird geschrieben, auch
## nicht die anderen Dateien.
func test_a_falling_value_stops_the_whole_commit() -> void:
	_give(32500, 40)
	_coord.commit("wave_end")
	_give(10, 90)
	assert_bool(_coord.commit("wave_end")).is_false()
	assert_int(_disk_xp()).is_equal(32500)
	assert_int(int(SaveStore.read(_path("_wallet"))["data"]["gold"])).is_equal(40)


func test_an_explicit_drop_is_allowed() -> void:
	_give(500, 40)
	_coord.commit("wave_end")
	_give(0, 40)
	assert_bool(_coord.commit("progress_reset", ["_level"])).is_true()
	assert_int(_disk_xp()).is_equal(0)


func test_discard_brings_back_the_last_commit() -> void:
	_give(500, 40)
	_coord.commit("wave_end")
	_give(900, 70)
	_coord.discard_uncommitted()
	assert_int(_level.total_xp).is_equal(500)
	assert_int(_wallet.gold).is_equal(40)


func test_stores_of_another_profile_are_left_alone() -> void:
	_level.player_id = "zz-coord-other"
	_give(500, 40)
	_coord.commit("wave_end")
	assert_bool(FileAccess.file_exists(_path("_level"))).is_false()
	assert_bool(FileAccess.file_exists(_path("_wallet"))).is_true()


# --- Öffnen -----------------------------------------------------------------------

func test_a_corrupt_file_is_replaced_from_the_backup() -> void:
	_give(32500, 40)
	_coord.commit("wave_end")
	_put(_path("_level"), PackedByteArray())
	_coord.open_profile(PROFILE)
	assert_int(_disk_xp()).is_equal(32500)
	assert_bool(_coord.is_blocked()).is_false()
	var notices: Array = _coord.take_notices()
	assert_str(str(notices[0]["kind"])).is_equal("restored")
	assert_array(notices[0]["files"]).contains_exactly(["_level"])
	# Die kaputte Datei liegt in der Quarantäne, gelöscht wurde nichts.
	var held := Backups.generation_dirs(QUARANTINE, PROFILE)
	assert_int(held.size()).is_equal(1)
	assert_bool(FileAccess.file_exists(held[0].path_join(Backups.file_name(PROFILE, "_level") + ".corrupt"))).is_true()


func test_a_missing_file_that_was_backed_up_is_restored() -> void:
	_give(32500, 40)
	_coord.commit("wave_end")
	DirAccess.remove_absolute(_path("_level"))
	_coord.open_profile(PROFILE)
	assert_int(_disk_xp()).is_equal(32500)


func test_corrupt_without_backup_blocks_saving() -> void:
	_put(_path("_level"), PackedByteArray([0, 0, 0, 0]))
	_coord.open_profile(PROFILE)
	assert_bool(_coord.is_blocked()).is_true()
	assert_str(str(_coord.take_notices()[0]["kind"])).is_equal("blocked")
	_give(10, 0)
	assert_bool(_coord.commit("wave_end")).is_false()
	assert_int(FileAccess.get_file_as_bytes(_path("_level")).size()).is_equal(4)
	# Der Spieler entscheidet sich für einen leeren Stand: die Datei geht in die Quarantäne.
	_coord.start_blank()
	assert_bool(_coord.is_blocked()).is_false()
	assert_int(_disk_xp()).is_equal(0)


func test_a_broken_off_commit_is_completed_from_the_journal() -> void:
	_give(500, 40)
	_coord.commit("wave_end")
	SaveStore.stage(_path("_level"), SaveStore.encode({"total_xp": 800}))
	SaveStore.write(PROGRESS.path_join(PROFILE + COORDINATOR.JOURNAL_SUFFIX),
			{"files": [Backups.file_name(PROFILE, "_level")]})
	_coord.open_profile(PROFILE)
	assert_int(_disk_xp()).is_equal(800)
	assert_bool(FileAccess.file_exists(_path("_level") + SaveStore.TMP_SUFFIX)).is_false()


func test_a_tmp_without_journal_is_dropped() -> void:
	_give(500, 40)
	_coord.commit("wave_end")
	SaveStore.stage(_path("_level"), SaveStore.encode({"total_xp": 800}))
	_coord.open_profile(PROFILE)
	assert_int(_disk_xp()).is_equal(500)
	assert_bool(FileAccess.file_exists(_path("_level") + SaveStore.TMP_SUFFIX)).is_false()


## Windows hat das Ziel schon gelöscht, das Umbenennen kam nicht mehr: die `.tmp` gilt.
func test_a_tmp_replaces_a_missing_target() -> void:
	SaveStore.stage(_path("_level"), SaveStore.encode({"total_xp": 800}))
	_coord.open_profile(PROFILE)
	assert_int(_disk_xp()).is_equal(800)


func test_old_files_get_checksums_and_a_first_backup() -> void:
	_put(_path("_level"), JSON.stringify({"total_xp": 700}, "\t").to_utf8_buffer())
	_coord.open_profile(PROFILE)
	var read := SaveStore.read(_path("_level"))
	assert_bool(bool(read["legacy"])).is_false()
	assert_int(int(read["data"]["total_xp"])).is_equal(700)
	assert_dict(Backups.latest(BACKUPS, PROFILE)).is_not_empty()


func test_a_new_profile_needs_nothing() -> void:
	_coord.open_profile(PROFILE)
	assert_bool(_coord.is_blocked()).is_false()
	assert_array(_coord.take_notices()).is_empty()
	assert_array(Backups.generation_dirs(BACKUPS, PROFILE)).is_empty()


# --- Import -----------------------------------------------------------------------

func test_import_replaces_the_profile_and_keeps_the_old_one() -> void:
	_give(500, 40)
	_coord.commit("wave_end")
	var files := {"_level": SaveStore.encode({"total_xp": 9000})}
	assert_bool(_coord.import_files(files)).is_true()
	assert_int(_disk_xp()).is_equal(9000)
	assert_int(_level.total_xp).is_equal(9000)
	# Die Geldbörse hatte das Archiv nicht: sie bleibt, wie sie war.
	assert_int(int(SaveStore.read(_path("_wallet"))["data"]["gold"])).is_equal(40)
	var reasons := Backups.list_valid(BACKUPS, PROFILE).map(func(m): return str(m["reason"]))
	assert_array(reasons).contains(["before_import", "import"])


## Ein gesperrtes Profil: die kaputte Datei geht in die Quarantäne, auch wenn das Archiv
## sie nicht ersetzt.
func test_import_clears_a_blocked_profile() -> void:
	_put(_path("_wallet"), PackedByteArray([0, 0]))
	_coord.open_profile(PROFILE)
	assert_bool(_coord.is_blocked()).is_true()
	assert_bool(_coord.import_files({"_level": SaveStore.encode({"total_xp": 9000})})).is_true()
	assert_bool(_coord.is_blocked()).is_false()
	assert_bool(FileAccess.file_exists(_path("_wallet"))).is_false()
	assert_int(_disk_xp()).is_equal(9000)
