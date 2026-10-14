extends GdUnitTestSuite
## Sicherungen des Spielstands (ADR 0024): Generationen des ganzen Profils, gestaffelt
## aufbewahrt, nur vollständig gültig.
##
## Eigene Ordner unter user://; jede Datei wird einzeln weggeräumt.

const PROGRESS := "user://zz-backups-progress"
const BASE := "user://zz-backups-base"
const SETTINGS := "user://zz-backups-settings.cfg"
const PROFILE := "zz-backup"
const SUFFIXES := ["", "_level", "_skills"]
const DAY := 86_400_000
const NOW := 1_760_100_000_000


func before_test() -> void:
	_cleanup()


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for dir in Backups.generation_dirs(BASE, PROFILE):
		Backups._remove_dir(dir)
	DirAccess.remove_absolute(BASE.path_join(PROFILE))
	DirAccess.remove_absolute(BASE)
	for suffix: String in SUFFIXES:
		DirAccess.remove_absolute(PROGRESS.path_join(Backups.file_name(PROFILE, suffix)))
	DirAccess.remove_absolute(PROGRESS)
	DirAccess.remove_absolute(SETTINGS)


func _live(xp: int, skills := ["a"]) -> void:
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "")), {"records": {"t": {}}})
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "_level")), {"total_xp": xp})
	SaveStore.write(PROGRESS.path_join(Backups.file_name(PROFILE, "_skills")), {"unlocked": skills})


func _create(at: int) -> String:
	return Backups.create(BASE, PROFILE, PROGRESS, SUFFIXES, "test", at, SETTINGS)


func _xp() -> int:
	return int(SaveStore.read(PROGRESS.path_join(Backups.file_name(PROFILE, "_level")))["data"]["total_xp"])


# --- Anlegen, prüfen, zurückspielen ---------------------------------------------

func test_create_copies_the_whole_profile() -> void:
	_live(500)
	var dir := _create(NOW)
	var manifest := Backups.verify(dir)
	assert_dict(manifest).is_not_empty()
	assert_int((manifest["files"] as Dictionary).size()).is_equal(3)
	assert_int(int(Backups.latest(BASE, PROFILE)["created_ms"])).is_equal(NOW)


func test_a_damaged_copy_makes_the_generation_invalid() -> void:
	_live(500)
	var dir := _create(NOW)
	var file := FileAccess.open(dir.path_join(Backups.file_name(PROFILE, "_level")), FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	assert_dict(Backups.verify(dir)).is_empty()
	assert_dict(Backups.latest(BASE, PROFILE)).is_empty()


func test_without_manifest_it_does_not_count() -> void:
	_live(500)
	var dir := _create(NOW)
	DirAccess.remove_absolute(dir.path_join(Backups.MANIFEST))
	assert_dict(Backups.latest(BASE, PROFILE)).is_empty()


func test_a_corrupt_live_file_makes_no_backup() -> void:
	_live(500)
	var file := FileAccess.open(PROGRESS.path_join(Backups.file_name(PROFILE, "_level")), FileAccess.WRITE)
	file.close()
	assert_str(_create(NOW)).is_empty()
	assert_array(Backups.generation_dirs(BASE, PROFILE)).is_empty()


func test_restore_brings_back_every_file_together() -> void:
	_live(32500, ["a", "b"])
	_create(NOW)
	_live(10, [])
	assert_int(Backups.restore(Backups.latest(BASE, PROFILE), PROFILE, PROGRESS)).is_equal(OK)
	assert_int(_xp()).is_equal(32500)
	var skills: Dictionary = SaveStore.read(PROGRESS.path_join(Backups.file_name(PROFILE, "_skills")))["data"]
	assert_array(skills["unlocked"]).contains_exactly(["a", "b"])


func test_newest_valid_generation_wins() -> void:
	_live(100)
	_create(NOW - DAY)
	_live(200)
	_create(NOW)
	assert_int(int(Backups.latest(BASE, PROFILE)["created_ms"])).is_equal(NOW)


# --- Aufbewahrung ----------------------------------------------------------------

func test_few_generations_all_stay() -> void:
	assert_array(Backups.retained([NOW - 2, NOW - 1, NOW], NOW, 0)).has_size(3)


func test_one_day_keeps_the_three_newest() -> void:
	var stamps: Array = []
	for i in 10:
		stamps.append(NOW - i * 60_000)
	var kept := Backups.retained(stamps, NOW, 0)
	assert_array(kept).contains_exactly([NOW, NOW - 60_000, NOW - 120_000])


func test_a_month_daily_keeps_days_and_weeks() -> void:
	var stamps: Array = []
	for i in 60:
		stamps.append(NOW - i * DAY)
	var kept := Backups.retained(stamps, NOW, 0)
	# 3 neueste (Tag 0..2), Tage 3..6, dazu je Woche 1..7 eine.
	assert_int(kept.size()).is_equal(7 + 7)
	assert_bool(kept.size() <= Backups.KEEP_LATEST + Backups.KEEP_DAYS + Backups.KEEP_WEEKS).is_true()
	assert_bool(NOW - 49 * DAY in kept).is_true()
	assert_bool(NOW - 55 * DAY in kept).is_false()
	assert_bool(NOW - 56 * DAY in kept).is_false()


func test_future_stamps_stay() -> void:
	var stamps: Array = [NOW + DAY, NOW, NOW - DAY, NOW - 2 * DAY, NOW - 3 * DAY]
	assert_bool(NOW + DAY in Backups.retained(stamps, NOW, 0)).is_true()


func test_day_boundary_follows_local_time() -> void:
	# 23:30 und 00:30 UTC sind in UTC+2 derselbe Tag (01:30 und 02:30) — mit Offset bleibt nur die neuere.
	var midnight := 1_760_054_400_000   # ein Tagesbeginn UTC
	var early := midnight - 30 * 60_000
	var late := midnight + 30 * 60_000
	# Drei neuere drei Tage später, damit die beiden nicht zu den neuesten zählen.
	var now := midnight + 3 * DAY + 12 * 3_600_000
	var stamps: Array = [now, now - 1, now - 2, early, late]
	var kept_utc := Backups.retained(stamps, now, 0)
	var kept_local := Backups.retained(stamps, now, 2 * 3600)
	assert_bool(early in kept_utc and late in kept_utc).is_true()
	assert_bool(early in kept_local).is_false()


func test_prune_keeps_the_newest_and_removes_files_one_by_one() -> void:
	_live(1)
	for i in 6:
		_create(NOW - i * 60_000)
	Backups.prune(BASE, PROFILE, NOW, 0)
	assert_int(Backups.generation_dirs(BASE, PROFILE).size()).is_equal(3)
	assert_int(int(Backups.latest(BASE, PROFILE)["created_ms"])).is_equal(NOW)
