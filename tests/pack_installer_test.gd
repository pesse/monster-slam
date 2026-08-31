extends GdUnitTestSuite
## Was beim Auspacken eines Packs zählt: wohin geschrieben werden darf, was NICHT
## überschrieben wird und was verschwindet.

const OPEN_V1 := "res://tests/fixtures/packs/open_v1.zip"
const OPEN_V2 := "res://tests/fixtures/packs/open_v2.zip"
const HOSTILE := "res://tests/fixtures/packs/hostile.zip"

const PACK_ID := "fixture-test"

const ENTRY_V1 := {"version": "v1", "minVersion": "0.2.0", "keyVersion": 1}
const ENTRY_V2 := {"version": "v2", "minVersion": "0.2.0", "keyVersion": 1}

var _dir := ""


func before_test() -> void:
	_dir = PackInstaller.pack_dir(PACK_ID)
	_clean()


func after_test() -> void:
	_clean()


func _clean() -> void:
	_remove_recursive(_dir)
	DirAccess.remove_absolute(PackInstaller.state_path(PACK_ID))


func _remove_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_recursive("%s/%s" % [path, sub])
	for file in dir.get_files():
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)


func _read(rel: String) -> String:
	return FileAccess.get_file_as_string("%s/%s" % [_dir, rel])


func _write(rel: String, text: String) -> void:
	var full := "%s/%s" % [_dir, rel]
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# --- Pfad-Schutz ------------------------------------------------------------------------

func test_kategorieverzeichnisse_sind_erlaubt() -> void:
	assert_bool(PackInstaller.is_allowed_entry("lexemes/basics.json")).is_true()
	assert_bool(PackInstaller.is_allowed_entry("monsters/unter/ordner.json")).is_true()


func test_alles_ausserhalb_der_kategorien_wird_abgelehnt() -> void:
	# user://progress und user://settings.cfg müssen unerreichbar bleiben.
	for bad in [
		"",
		"settings.cfg",
		"progress/default.json",
		"../settings.cfg",
		"lexemes/../../settings.cfg",
		"/lexemes/abs.json",
		"lexemes",
		"lexemes/",
		"C:/windows/system32/x.json",
		"lexemes\\windows.json",
	]:
		assert_bool(PackInstaller.is_allowed_entry(bad)).override_failure_message(
			"'%s' hätte nicht erlaubt sein dürfen" % bad
		).is_false()


func test_ein_unzulaessiger_pfad_bricht_die_ganze_installation_ab() -> void:
	var summary := PackInstaller.install_zip(PACK_ID, HOSTILE, ENTRY_V1, false)
	assert_str(summary.error).contains("unzulässigen Pfad")
	assert_int(summary.written).is_equal(0)
	# Auch die zulässige Datei desselben Packs bleibt aus: erst planen, dann schreiben.
	assert_bool(FileAccess.file_exists("%s/lexemes/ok.json" % _dir)).is_false()
	assert_dict(PackInstaller.read_state(PACK_ID)).is_empty()


# --- Installieren -----------------------------------------------------------------------

func test_installation_schreibt_dateien_und_zustand() -> void:
	var summary := PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	assert_str(summary.error).is_empty()
	assert_int(summary.written).is_equal(2)
	assert_str(_read("lexemes/fixture.json")).contains("lex.fixture.thing")

	var state := PackInstaller.read_state(PACK_ID)
	assert_str(str(state.get("version", ""))).is_equal("v1")
	assert_str(str(state.get("minVersion", ""))).is_equal("0.2.0")
	assert_int((state.get("files", []) as Array).size()).is_equal(2)


func test_installation_ist_wiederholbar() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	var again := PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	assert_str(again.error).is_empty()
	assert_int(again.written).is_equal(2)
	assert_int(again.skipped_modified).is_equal(0)
	assert_int(again.needs_adopt).is_equal(0)


func test_installierte_packs_werden_aufgelistet() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	var installed := PackInstaller.installed()
	assert_bool(installed.has(PACK_ID)).is_true()
	assert_str(str(installed[PACK_ID]["version"])).is_equal("v1")


# --- Lokale Änderungen ------------------------------------------------------------------

func test_lokal_geaenderte_datei_wird_nicht_ueberschrieben() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	var path := "%s/lexemes/fixture.json" % _dir
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"id": "lex.fixture.thing", "lemma_de": "von Hand"}')
	file.close()

	var summary := PackInstaller.install_zip(PACK_ID, OPEN_V2, ENTRY_V2, false)
	assert_int(summary.skipped_modified).is_equal(1)
	assert_int(summary.written).is_equal(0)
	assert_str(_read("lexemes/fixture.json")).contains("von Hand")


func test_zurueckgezogene_datei_wird_entfernt() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	assert_bool(FileAccess.file_exists("%s/monsters/fixture.json" % _dir)).is_true()

	# v2 enthält monsters/fixture.json nicht mehr.
	var summary := PackInstaller.install_zip(PACK_ID, OPEN_V2, ENTRY_V2, false)
	assert_int(summary.removed).is_equal(1)
	assert_bool(FileAccess.file_exists("%s/monsters/fixture.json" % _dir)).is_false()
	assert_str(_read("lexemes/fixture.json")).contains("Sache")


func test_zurueckgezogene_aber_veraenderte_datei_bleibt_liegen() -> void:
	# Löschen wäre hier unwiederbringlich — deshalb bleibt sie stehen.
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	var path := "%s/monsters/fixture.json" % _dir
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"id": "mon.fixture", "hp": 99}')
	file.close()

	var summary := PackInstaller.install_zip(PACK_ID, OPEN_V2, ENTRY_V2, false)
	assert_int(summary.removed).is_equal(0)
	assert_bool(FileAccess.file_exists(path)).is_true()


# --- Fremddateien -----------------------------------------------------------------------

func test_fremde_datei_verlangt_zustimmung() -> void:
	# Vorhanden, aber ohne Zustand — etwa nach einem verlorenen .state-Verzeichnis.
	DirAccess.make_dir_recursive_absolute("%s/lexemes" % _dir)
	var file := FileAccess.open("%s/lexemes/fixture.json" % _dir, FileAccess.WRITE)
	file.store_string('{"id": "lex.fixture.thing", "lemma_de": "älter"}')
	file.close()

	var refused := PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	assert_int(refused.needs_adopt).is_equal(1)
	assert_int(refused.written).is_equal(0)
	assert_str(_read("lexemes/fixture.json")).contains("älter")
	assert_dict(PackInstaller.read_state(PACK_ID)).is_empty()

	var accepted := PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, true)
	assert_int(accepted.written).is_equal(2)
	assert_str(_read("lexemes/fixture.json")).contains("Ding")


# --- Deinstallieren ---------------------------------------------------------------------

func test_deinstallieren_entfernt_dateien_und_zustand() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	var summary := PackInstaller.uninstall(PACK_ID)
	assert_str(summary.error).is_empty()
	assert_int(summary.removed).is_equal(2)
	assert_bool(FileAccess.file_exists("%s/lexemes/fixture.json" % _dir)).is_false()
	assert_dict(PackInstaller.read_state(PACK_ID)).is_empty()


func test_deinstallieren_laesst_kein_leeres_verzeichnis_zurueck() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	PackInstaller.uninstall(PACK_ID)
	assert_bool(DirAccess.dir_exists_absolute(_dir)).is_false()


func test_deinstallieren_behaelt_verzeichnis_mit_lokaler_datei() -> void:
	PackInstaller.install_zip(PACK_ID, OPEN_V1, ENTRY_V1, false)
	_write("lexemes/eigenes.json", '{"id": "lex.eigen"}')
	PackInstaller.uninstall(PACK_ID)
	assert_bool(DirAccess.dir_exists_absolute(_dir)).is_true()
	assert_str(_read("lexemes/eigenes.json")).contains("lex.eigen")


func test_deinstallieren_ohne_installation_wird_benannt() -> void:
	assert_str(PackInstaller.uninstall(PACK_ID).error).is_equal("Nicht installiert.")
