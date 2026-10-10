extends GdUnitTestSuite
## SaveArchive (ADR 0024): ein Spielstand als Datei — schreiben, misstrauisch lesen,
## fürs eigene Profil umschreiben.
##
## Eigene Ordner unter user://; jede Datei wird einzeln weggeräumt.

const ROOT := "user://zz-archive-test"
const PROGRESS := ROOT + "/progress"
const BACKUPS := ROOT + "/backups"
const ZIP := ROOT + "/stand.zip"
const PROFILE := "zz-archive"
const SUFFIXES := ["", "_level", "_wallet"]


func before_test() -> void:
	_cleanup()


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for dir in Backups.generation_dirs(BACKUPS, PROFILE):
		Backups._remove_dir(dir)
	DirAccess.remove_absolute(BACKUPS.path_join(PROFILE))
	DirAccess.remove_absolute(BACKUPS)
	for suffix: String in SUFFIXES:
		DirAccess.remove_absolute(PROGRESS.path_join(Backups.file_name(PROFILE, suffix)))
	DirAccess.remove_absolute(PROGRESS)
	DirAccess.remove_absolute(ZIP)
	DirAccess.remove_absolute(ROOT)


func _generation() -> Dictionary:
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "")), {"player_id": PROFILE, "records": {"a": {}}})
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "_level")), {"player_id": PROFILE, "total_xp": 300})
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "_wallet")), {"player_id": PROFILE, "gold": 77})
	Backups.create(BACKUPS, PROFILE, PROGRESS, SUFFIXES, "test", 1_760_100_000_000, ROOT + "/none.cfg")
	return Backups.latest(BACKUPS, PROFILE)


## Ein Archiv von Hand: `entries` Name → Bytes.
func _zip(entries: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var zip := ZIPPacker.new()
	zip.open(ZIP)
	for name: String in entries:
		zip.start_file(name)
		zip.write_file(entries[name])
		zip.close_file()
	zip.close()


func _head(files: Dictionary, format := SaveArchive.FORMAT) -> PackedByteArray:
	return JSON.stringify({"format": format, "name": "Anna", "saved_at": 1, "files": files}).to_utf8_buffer()


func test_round_trip_with_preview() -> void:
	assert_int(SaveArchive.write(ZIP, _generation(), "Anna")).is_equal(OK)
	var archive := SaveArchive.read(ZIP)
	assert_str(str(archive["error"])).is_empty()
	assert_array((archive["data"] as Dictionary).keys()).contains_exactly_in_any_order(SUFFIXES)
	var seen := SaveArchive.preview(archive)
	assert_str(str(seen["name"])).is_equal("Anna")
	assert_int(int(seen["level"])).is_equal(3)
	assert_int(int(seen["gold"])).is_equal(77)
	assert_int(int(seen["saved_at"])).is_equal(1_760_100_000)


func test_import_files_belong_to_the_target_profile() -> void:
	SaveArchive.write(ZIP, _generation(), "Anna")
	var files := SaveArchive.files_for(SaveArchive.read(ZIP)["data"], "anna")
	var level := SaveStore.decode(files["_level"])
	assert_int(int(level["status"])).is_equal(SaveStore.Status.OK)
	assert_str(str(level["data"]["player_id"])).is_equal("anna")
	assert_int(int(level["data"]["total_xp"])).is_equal(300)


func test_a_changed_entry_is_rejected() -> void:
	var body := SaveStore.encode({"total_xp": 300})
	_zip({SaveArchive.HEAD: _head({"_level": SaveStore.sha256_hex(body)}),
			SaveArchive.entry_name("_level"): SaveStore.encode({"total_xp": 99999})})
	assert_str(str(SaveArchive.read(ZIP)["error"])).is_not_empty()


func test_a_missing_entry_is_rejected() -> void:
	var body := SaveStore.encode({"total_xp": 300})
	_zip({SaveArchive.HEAD: _head({"_level": SaveStore.sha256_hex(body), "_wallet": "00"}),
			SaveArchive.entry_name("_level"): body})
	assert_str(str(SaveArchive.read(ZIP)["error"])).contains("unvollständig")


func test_a_newer_format_is_rejected() -> void:
	var body := SaveStore.encode({"total_xp": 300})
	_zip({SaveArchive.HEAD: _head({"_level": SaveStore.sha256_hex(body)}, SaveArchive.FORMAT + 1),
			SaveArchive.entry_name("_level"): body})
	assert_str(str(SaveArchive.read(ZIP)["error"])).contains("neueren Fassung")


## Unbekannte Einträge, auch solche mit Pfaden, werden nicht gelesen.
func test_unknown_entries_are_ignored() -> void:
	var body := SaveStore.encode({"total_xp": 300})
	_zip({SaveArchive.HEAD: _head({"_level": SaveStore.sha256_hex(body)}),
			SaveArchive.entry_name("_level"): body,
			"../../settings.cfg": "boom".to_utf8_buffer()})
	var archive := SaveArchive.read(ZIP)
	assert_str(str(archive["error"])).is_empty()
	assert_array((archive["data"] as Dictionary).keys()).contains_exactly(["_level"])


func test_not_an_archive() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var file := FileAccess.open(ZIP, FileAccess.WRITE)
	file.store_string("kein zip")
	file.close()
	assert_str(str(SaveArchive.read(ZIP)["error"])).is_not_empty()


func test_suggested_name_is_a_safe_file_name() -> void:
	assert_str(SaveArchive.suggested_name("Anna Lena / ü", 1_760_100_000)).is_equal("MonsterSlam-Anna-Lena-ü-2025-10-10.zip")
	assert_str(SaveArchive.suggested_name("  ", 1_760_100_000)).is_equal("MonsterSlam-Spielstand-2025-10-10.zip")


## tools/stats/rebuild_save.py baut dieselbe Hülle in Python — die Datei kommt von dort.
func test_reads_an_archive_built_by_the_rebuild_tool() -> void:
	var archive := SaveArchive.read("res://tests/fixtures/rebuilt_save.zip")
	assert_str(str(archive["error"])).is_empty()
	var seen := SaveArchive.preview(archive)
	assert_str(str(seen["name"])).is_equal("Änne")
	assert_int(int(archive["data"]["_level"]["total_xp"])).is_equal(32500)
	assert_array(archive["data"]["_skills"]["unlocked"]).contains_exactly(["s.ä"])
