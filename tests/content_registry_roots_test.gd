extends GdUnitTestSuite
## Die Vorrangregel der drei Roots. Ein installierter Pack muss einen eingebauten Eintrag
## überschreiben können — das ist der Weg, auf dem die ausgelieferte EXE zu Inhalten kommt.
##
## Fasst den echten ContentRegistry-Autoload an und räumt danach auf: der Katalog ist
## globaler Zustand, ein liegengebliebener Pack würde andere Tests verfälschen.

const OVERRIDE_PACK := "res://tests/fixtures/packs/open_override.zip"
const PACK_ID := "fixture-roots"
const ENTRY := {"version": "ovr", "minVersion": "0.2.0"}

## Aus data/monsters/basic_monsters.json — die Kollision, an der sich der Vorrang zeigt.
const BUILTIN_ID := "monster.skeleton_minion"


func before_test() -> void:
	_clean()


func after_test() -> void:
	_clean()
	ContentRegistry.reload()


func _clean() -> void:
	_remove_recursive(PackInstaller.pack_dir(PACK_ID))
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


func test_eingebauter_eintrag_gilt_ohne_pack() -> void:
	ContentRegistry.reload()
	assert_str(str(ContentRegistry.get_entry("monsters", BUILTIN_ID).get("name", ""))) \
		.is_not_equal("Aus dem Pack")


func test_pack_ueberschreibt_eingebauten_eintrag() -> void:
	PackInstaller.install_zip(PACK_ID, OVERRIDE_PACK, ENTRY, false)
	ContentRegistry.reload()

	var entry := ContentRegistry.get_entry("monsters", BUILTIN_ID)
	assert_str(str(entry.get("name", ""))).is_equal("Aus dem Pack")
	assert_int(int(entry.get("hp", 0))).is_equal(42)
	# Die Quelldatei benennt, woher der geltende Eintrag stammt.
	assert_str(ContentRegistry.source_file("monsters", BUILTIN_ID)).contains(PackInstaller.pack_dir(PACK_ID))


func test_pack_ergaenzt_neue_eintraege() -> void:
	PackInstaller.install_zip(PACK_ID, OVERRIDE_PACK, ENTRY, false)
	ContentRegistry.reload()
	assert_bool(ContentRegistry.lexemes.has("lex.fixture.extra")).is_true()


func test_nach_dem_entfernen_gilt_wieder_der_eingebaute_eintrag() -> void:
	PackInstaller.install_zip(PACK_ID, OVERRIDE_PACK, ENTRY, false)
	ContentRegistry.reload()
	PackInstaller.uninstall(PACK_ID)
	ContentRegistry.reload()

	assert_str(str(ContentRegistry.get_entry("monsters", BUILTIN_ID).get("name", ""))) \
		.is_not_equal("Aus dem Pack")
	assert_bool(ContentRegistry.lexemes.has("lex.fixture.extra")).is_false()


func test_der_zustandsordner_wird_nicht_als_pack_gelesen() -> void:
	# user://content/.state hält den Installationszustand; er darf nicht als Katalog-Root
	# auftauchen (sonst würde ein Zustands-JSON ohne "id" Fehler werfen).
	PackInstaller.install_zip(PACK_ID, OVERRIDE_PACK, ENTRY, false)
	ContentRegistry.reload()
	for category in ["monsters", "lexemes"]:
		for id in ContentRegistry._by_category[category]:
			assert_str(ContentRegistry.source_file(category, str(id))) \
				.not_contains(PackInstaller.STATE_DIR)


# --- Kategorien in drei Quellen -----------------------------------------------------------

## Die Kategorienliste steht dreimal: hier, im Installer und im Pack-Build. Weichen sie
## voneinander ab, liefert ein Pack Dateien aus, die der Installer stillschweigend
## verwirft. Die dritte Stelle (tools/packs/build_packs.py) trägt den Verweis im Kommentar.
func test_registry_und_installer_kennen_dieselben_kategorien() -> void:
	var registry := ContentRegistry.categories()
	registry.sort()
	var installer: Array = Array(PackInstaller.CATEGORIES).duplicate()
	installer.sort()
	assert_array(registry).is_equal(installer)
