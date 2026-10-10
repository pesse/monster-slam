extends GdUnitTestSuite
## Statistik-Rückkanal (ADR 0021): was der Snapshot enthält, wer nie sendet, und dass die
## Kennung eines Profils zufällig und stabil ist.
##
## Kein Test spricht mit einem Dienst: der Autoload hat in Editor- und Testläufen keinen
## Endpunkt (nur über MONSTER_SLAM_STATS_URL), geprüft werden die reinen Teile.

const DIR := "user://zz-stats-test"
const PROFILE := "zz-stats-test"
const OTHER := "zz-stats-test-other"
const BACKUPS := "user://zz-stats-test-backups"


func before_test() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for suffix in StatsUploader.SNAPSHOT_FILES:
		DirAccess.remove_absolute("%s/%s%s.json" % [DIR, PROFILE, suffix])
	DirAccess.remove_absolute(DIR)
	for dir in Backups.generation_dirs(BACKUPS, PROFILE):
		Backups._remove_dir(dir)
	DirAccess.remove_absolute(BACKUPS.path_join(PROFILE))
	DirAccess.remove_absolute(BACKUPS)
	for profile in [PROFILE, OTHER]:
		for section in ["stats_id", "stats_cursor", "stats_sent"]:
			if UserSettings._config.has_section_key(section, profile):
				UserSettings._config.erase_section_key(section, profile)
	UserSettings._save()


func _write(suffix: String, data: Dictionary) -> void:
	var file := FileAccess.open("%s/%s%s.json" % [DIR, PROFILE, suffix], FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func test_snapshot_takes_only_allowed_fields() -> void:
	_write("", {"player_id": PROFILE, "records": {"translate:de_to_en:zz.lex.a": {"confidence": 0.5}}})
	_write("_sessions", {"player_id": PROFILE, "sessions": [{"started_at": 1, "answers": 4}],
			"current": {"started_at": 2}})
	_write("_wallet", {"player_id": PROFILE, "gold": 12, "total_earned": 40, "chests_opened": 1})
	_write("_level", {"player_id": PROFILE, "total_xp": 900, "level": 4, "skill_points": 2})
	_write("_skills", {"player_id": PROFILE, "unlocked": ["s.a"], "spent_points": 1})
	_write("_bosses", {"wins": [{"unit": "zz/1", "won_at": 5}]})
	var snap := StatsUploader.snapshot(PROFILE, {"difficulty": 3}, {"stats_id": "x"}, DIR)

	assert_int(int(snap["format"])).is_equal(StatsUploader.FORMAT)
	assert_str(str(snap["stats_id"])).is_equal("x")
	assert_float(float(snap["progress"]["translate:de_to_en:zz.lex.a"]["confidence"])).is_equal(0.5)
	assert_int((snap["sessions"] as Array).size()).is_equal(1)
	assert_dict(snap["wallet"]).is_equal({"gold": 12.0, "total_earned": 40.0, "chests_opened": 1.0})
	# Abgeleitetes (Level, Punkte) bleibt daheim — gerechnet wird in der Auswertung.
	assert_dict(snap["level"]).is_equal({"total_xp": 900.0})
	assert_int((snap["bosses"] as Array).size()).is_equal(1)
	assert_bool(snap.has("inventory")).is_false()      # keine Datei, kein Eintrag
	# Die player_id ist der Name des Kindes.
	assert_bool(JSON.stringify(snap).contains(PROFILE)).is_false()


## Gesendet wird nur aus einer fertigen Sicherung (ADR 0024), nie aus den Live-Dateien.
func test_snapshot_comes_from_the_newest_backup() -> void:
	SaveStore.write("%s/%s_level.json" % [DIR, PROFILE], {"total_xp": 900})
	assert_dict(StatsUploader.generation_snapshot(PROFILE, {}, {}, BACKUPS)).is_empty()
	assert_int(StatsUploader.saved_at(BACKUPS, PROFILE)).is_equal(0)
	Backups.create(BACKUPS, PROFILE, DIR, StatsUploader.SNAPSHOT_FILES.keys(), "test", 1_760_100_000_000,
			"user://zz-stats-test-none.cfg")
	# Danach geändert, aber nicht gesichert: geht nicht hinaus.
	SaveStore.write("%s/%s_level.json" % [DIR, PROFILE], {"total_xp": 950})
	var snap := StatsUploader.generation_snapshot(PROFILE, {}, {}, BACKUPS)
	assert_dict(snap["level"]).is_equal({"total_xp": 900.0})
	assert_bool(JSON.stringify(snap).contains("_save")).is_false()
	assert_int(StatsUploader.saved_at(BACKUPS, PROFILE)).is_equal(1_760_100_000)


func test_an_unreadable_file_sends_nothing() -> void:
	_write("_wallet", {"gold": 1})
	var file := FileAccess.open("%s/%s_level.json" % [DIR, PROFILE], FileAccess.WRITE)
	file.close()
	assert_dict(StatsUploader.snapshot(PROFILE, {}, {}, DIR)).is_empty()


func test_test_profiles_never_send() -> void:
	assert_bool(StatsUploader.sendable("zz-irgendwas")).is_false()
	assert_bool(StatsUploader.sendable("")).is_false()
	assert_bool(StatsUploader.sendable("anna")).is_true()


func test_not_sending_without_endpoint_or_notice() -> void:
	# Im Testlauf ist kein Endpunkt eingerichtet — senden geht dann nie.
	assert_bool(StatsUploader.configured()).is_false()
	assert_bool(await StatsUploader.send_profile(PROFILE)).is_false()


func test_stats_id_is_random_stable_and_not_the_name() -> void:
	var first := UserSettings.stats_id(PROFILE)
	assert_str(first).has_length(32)
	assert_bool(RegEx.create_from_string("^[0-9a-f]{32}$").search(first) != null).is_true()
	assert_str(UserSettings.stats_id(PROFILE)).is_equal(first)
	assert_str(UserSettings.stats_id(OTHER)).is_not_equal(first)


func test_trace_cursor_round_trip() -> void:
	assert_array(UserSettings.stats_trace_cursor(PROFILE)).is_equal([0, 0])
	UserSettings.set_stats_trace_cursor(PROFILE, [1791000000, 4711])
	assert_array(UserSettings.stats_trace_cursor(PROFILE)).is_equal([1791000000, 4711])
