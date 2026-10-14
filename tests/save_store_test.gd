extends GdUnitTestSuite
## SaveStore und SaveGuard (ADR 0024): sicher schreiben, Beschädigung erkennen, nie über
## eine unlesbare Datei schreiben, monotone Werte nicht sinken lassen.
##
## Läuft in einem eigenen Ordner unter user://; jede Datei wird einzeln weggeräumt.

const DIR := "user://zz-save-store-test"
const FILE := DIR + "/zz-save_level.json"
const CFG := DIR + "/zz-settings.cfg"


func before_test() -> void:
	_cleanup()


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for path in [FILE, FILE + ".tmp", CFG, CFG + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(DIR)


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _status(path := FILE) -> int:
	return int(SaveStore.read(path)["status"])


# --- Lesen und Schreiben ---------------------------------------------------------

func test_round_trip() -> void:
	var data := {"player_id": "zz", "total_xp": 32500, "ratio": 0.30000000000000004,
			"name": "Ärger mit Ü"}
	assert_int(SaveStore.write(FILE, data)).is_equal(OK)
	var read := SaveStore.read(FILE)
	assert_int(int(read["status"])).is_equal(SaveStore.Status.OK)
	assert_bool(bool(read["legacy"])).is_false()
	assert_int(int(read["data"]["total_xp"])).is_equal(32500)
	assert_str(str(read["data"]["name"])).is_equal("Ärger mit Ü")
	assert_bool(FileAccess.file_exists(FILE + ".tmp")).is_false()


func test_empty_dictionary_round_trips() -> void:
	SaveStore.write(FILE, {})
	assert_int(_status()).is_equal(SaveStore.Status.OK)
	assert_dict(SaveStore.read(FILE)["data"]).is_empty()


## Eine ältere Fassung liest die Datei wie bisher: das Feld `_save` kommt dazu, sonst nichts.
func test_older_versions_still_read_the_file() -> void:
	SaveStore.write(FILE, {"total_xp": 1234, "records": {"a": 1}})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	assert_bool(parsed is Dictionary).is_true()
	assert_int(int(parsed["total_xp"])).is_equal(1234)
	assert_bool(parsed.has("_save")).is_true()


## Der Fall aus dem Vorfall: eine überschriebene Datei existiert, ist aber leer.
func test_missing_is_not_corrupt() -> void:
	assert_int(_status()).is_equal(SaveStore.Status.MISSING)
	_put(FILE, PackedByteArray())
	assert_int(_status()).is_equal(SaveStore.Status.CORRUPT)


func test_nul_bytes_are_corrupt() -> void:
	var zeros := PackedByteArray()
	zeros.resize(77)
	_put(FILE, zeros)
	assert_int(_status()).is_equal(SaveStore.Status.CORRUPT)


func test_truncated_file_is_corrupt() -> void:
	var bytes := SaveStore.encode({"total_xp": 32500, "player_id": "zz"})
	_put(FILE, bytes.slice(0, bytes.size() - 5))
	assert_int(_status()).is_equal(SaveStore.Status.CORRUPT)


func test_changed_byte_is_corrupt() -> void:
	var bytes := SaveStore.encode({"total_xp": 32500})
	var at := bytes.size() - 4
	bytes[at] = 48 if bytes[at] != 48 else 49   # eine Ziffer der Zahl
	_put(FILE, bytes)
	assert_int(_status()).is_equal(SaveStore.Status.CORRUPT)


func test_valid_old_file_is_legacy() -> void:
	_put(FILE, JSON.stringify({"total_xp": 99}, "\t").to_utf8_buffer())
	var read := SaveStore.read(FILE)
	assert_int(int(read["status"])).is_equal(SaveStore.Status.OK)
	assert_bool(bool(read["legacy"])).is_true()
	assert_int(int(read["data"]["total_xp"])).is_equal(99)


func test_broken_old_file_is_corrupt() -> void:
	_put(FILE, '{"total_xp": 9'.to_utf8_buffer())
	assert_int(_status()).is_equal(SaveStore.Status.CORRUPT)


func test_newer_format_is_newer() -> void:
	var body := JSON.stringify({"total_xp": 5}, "\t").to_utf8_buffer()
	var bytes := ('{"_save":{"format":2,"sha256":"%s"},' % SaveStore.sha256_hex(body)).to_utf8_buffer()
	bytes.append_array(body.slice(1))
	_put(FILE, bytes)
	assert_int(_status()).is_equal(SaveStore.Status.NEWER)


## Unter Windows ist das Umbenennen „Ziel löschen, dann verschieben" — es muss ein
## vorhandenes Ziel ersetzen.
func test_write_replaces_an_existing_file() -> void:
	SaveStore.write(FILE, {"total_xp": 1})
	SaveStore.write(FILE, {"total_xp": 2})
	assert_int(int(SaveStore.read(FILE)["data"]["total_xp"])).is_equal(2)


func test_pending_tmp_is_recognised() -> void:
	SaveStore.stage(FILE, SaveStore.encode({"total_xp": 7}))
	assert_bool(SaveStore.pending_tmp(FILE)).is_true()
	assert_int(_status()).is_equal(SaveStore.Status.MISSING)
	SaveStore.promote(FILE)
	assert_int(int(SaveStore.read(FILE)["data"]["total_xp"])).is_equal(7)


func test_settings_round_trip_and_damage() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "active_profile", "zz")
	assert_int(SaveStore.write_cfg(CFG, config.encode_to_text())).is_equal(OK)
	var read := SaveStore.read_cfg(CFG)
	assert_int(int(read["status"])).is_equal(SaveStore.Status.OK)
	var back := ConfigFile.new()
	back.parse(str(read["text"]))
	assert_str(str(back.get_value("general", "active_profile"))).is_equal("zz")
	# Ein geändertes Zeichen hinter der Prüfzeile.
	var text := FileAccess.get_file_as_string(CFG).replace("\"zz\"", "\"zy\"")
	_put(CFG, text.to_utf8_buffer())
	assert_int(int(SaveStore.read_cfg(CFG)["status"])).is_equal(SaveStore.Status.CORRUPT)


func test_old_settings_are_legacy() -> void:
	_put(CFG, "[general]\nactive_profile=\"zz\"\n".to_utf8_buffer())
	var read := SaveStore.read_cfg(CFG)
	assert_int(int(read["status"])).is_equal(SaveStore.Status.OK)
	assert_bool(bool(read["legacy"])).is_true()


# --- Sperre ----------------------------------------------------------------------

func test_guard_refuses_falling_experience() -> void:
	SaveStore.write(FILE, {"total_xp": 32500})
	assert_int(SaveGuard.write(FILE, "_level", {"total_xp": 10})).is_equal(ERR_UNAUTHORIZED)
	assert_int(int(SaveStore.read(FILE)["data"]["total_xp"])).is_equal(32500)
	assert_int(SaveGuard.write(FILE, "_level", {"total_xp": 32510})).is_equal(OK)


func test_guard_never_writes_over_a_corrupt_file() -> void:
	_put(FILE, PackedByteArray())
	assert_int(SaveGuard.write(FILE, "_level", {"total_xp": 10})).is_equal(ERR_UNAUTHORIZED)
	assert_int(FileAccess.get_file_as_bytes(FILE).size()).is_equal(0)


func test_guard_allows_an_explicit_drop() -> void:
	SaveStore.write(FILE, {"records": {"a": {}, "b": {}}})
	assert_int(SaveGuard.write(FILE, "", {"records": {}})).is_equal(ERR_UNAUTHORIZED)
	assert_int(SaveGuard.write(FILE, "", {"records": {}}, true)).is_equal(OK)


func test_guard_watches_each_monotonic_value() -> void:
	assert_array(SaveGuard.drops("_wallet", {"gold": 50, "total_earned": 900, "chests_opened": 12},
			{"gold": 10, "total_earned": 900, "chests_opened": 12})).is_empty()
	assert_array(SaveGuard.drops("_wallet", {"total_earned": 900, "chests_opened": 12},
			{"total_earned": 900, "chests_opened": 11})).has_size(1)
	assert_array(SaveGuard.drops("_sessions", {"sessions": [1, 2]}, {"sessions": [1]})).has_size(1)
	assert_array(SaveGuard.drops("_bosses", {"wins": [1]}, {"wins": []})).has_size(1)
	assert_array(SaveGuard.drops("_skills", {"unlocked": ["a"]}, {"unlocked": []})).is_empty()
