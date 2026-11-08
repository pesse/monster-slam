extends GdUnitTestSuite
## Karten als Pack je Buch (ADR 0031): Pfade im Installer, Vorrang vor res://, Bilder ohne
## Import, Aufräumen und die Kopplung des Begleit-Packs an seinen Sprach-Pack.

const PACK_ID := "zz-maps-test"
const BOOK := "zz_mapbook"
const ENTRY := {"version": "v1", "minVersion": "0.2.0", "keyVersion": 1}

var _zip := ""


func before_test() -> void:
	_zip = "user://tmp/%s.zip" % PACK_ID
	_clean()


func after_test() -> void:
	_clean()


func _clean() -> void:
	if not PackInstaller.read_state(PACK_ID).is_empty():
		PackInstaller.uninstall(PACK_ID)
	_remove_recursive(PackInstaller.pack_dir(PACK_ID))
	DirAccess.remove_absolute(PackInstaller.state_path(PACK_ID))
	DirAccess.remove_absolute(_zip)
	ContentRegistry.reload()


func _remove_recursive(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_recursive(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Ein Karten-Pack mit map.json und einem Gebietsbild in der Farbe `tint`.
func _make_zip(book: String, tint: Color, points := {"units": {"1": {"x": 0.25, "y": 0.5}}}) -> void:
	DirAccess.make_dir_recursive_absolute(_zip.get_base_dir())
	var image := Image.create(8, 4, false, Image.FORMAT_RGB8)
	image.fill(tint)
	var packer := ZIPPacker.new()
	assert_int(packer.open(_zip)).is_equal(OK)
	packer.start_file("maps/%s/map.json" % book)
	packer.write_file(JSON.stringify(points).to_utf8_buffer())
	packer.close_file()
	packer.start_file("maps/%s/unit1.webp" % book)
	packer.write_file(image.save_webp_to_buffer(true))
	packer.close_file()
	packer.close()


func _install() -> void:
	var summary := PackInstaller.install_zip(PACK_ID, _zip, ENTRY, false)
	assert_str(summary.error).is_empty()
	ContentRegistry.reload()


# --- Installer ---------------------------------------------------------------------------

func test_karten_liegen_genau_eine_ebene_unter_dem_buch() -> void:
	assert_bool(PackInstaller.is_allowed_entry("maps/access2/map.json")).is_true()
	assert_bool(PackInstaller.is_allowed_entry("maps/access2/unit1_water.webp")).is_true()
	assert_bool(PackInstaller.is_allowed_entry("maps/map.json")).is_false()
	assert_bool(PackInstaller.is_allowed_entry("maps/access2/drafts/unit1.webp")).is_false()
	assert_bool(PackInstaller.is_allowed_entry("maps/access2/book.png")).is_false()
	assert_bool(PackInstaller.is_allowed_entry("maps/access2/skript.gd")).is_false()
	assert_bool(PackInstaller.is_allowed_entry("maps/../lexemes/x.json")).is_false()


func test_registry_kennt_die_kartenkategorie() -> void:
	assert_array(ContentRegistry.categories()).contains(["maps"])
	assert_array(ContentRegistry.all("maps")).is_empty()


func test_deinstallieren_raeumt_den_buchordner_weg() -> void:
	_make_zip(BOOK, Color.RED)
	_install()
	PackInstaller.uninstall(PACK_ID)
	assert_bool(DirAccess.dir_exists_absolute(PackInstaller.pack_dir(PACK_ID))).is_false()


# --- Lesen -------------------------------------------------------------------------------

func test_ohne_pack_liest_die_karte_aus_dem_repo() -> void:
	assert_str(MapLayout.source_of(BOOK)).is_equal(MapLayout.dir_of(BOOK))
	assert_dict(MapLayout.data(BOOK)).is_empty()
	assert_object(MapLayout.unit_texture(BOOK, 1)).is_null()


func test_karte_aus_dem_pack() -> void:
	_make_zip(BOOK, Color.RED)
	_install()
	assert_str(MapLayout.source_of(BOOK)).is_equal("%s/maps/%s" % [PackInstaller.pack_dir(PACK_ID), BOOK])
	assert_vector(MapLayout.unit_points(MapLayout.data(BOOK))["1"]).is_equal(Vector2(0.25, 0.5))
	var texture := MapLayout.unit_texture(BOOK, 1)
	assert_object(texture).is_not_null()
	assert_vector(texture.get_size()).is_equal(Vector2(8, 4))
	assert_object(MapLayout.unit_texture(BOOK, 1)).is_same(texture)


func test_pack_geht_vor_dem_repo_ausser_fuer_die_werkbank() -> void:
	_make_zip("access2", Color.RED, {"units": {}})
	_install()
	assert_dict(MapLayout.data("access2").get("units")).is_empty()
	MapLayout.bundled_only = true
	var bundled := MapLayout.data("access2")
	MapLayout.bundled_only = false
	if FileAccess.file_exists(MapLayout.json_path("access2")):
		assert_dict(bundled.get("units", {})).is_not_empty()


func test_hintergrundladen_aus_dem_pack() -> void:
	_make_zip(BOOK, Color.RED)
	_install()
	MapLayout.preload_unit_textures(BOOK, [1, 2])
	var texture := MapLayout.unit_texture(BOOK, 1)
	assert_object(texture).is_not_null()
	assert_object(MapLayout.unit_texture(BOOK, 2)).is_null()


func test_neue_fassung_ersetzt_das_zwischengespeicherte_bild() -> void:
	_make_zip(BOOK, Color.RED)
	_install()
	var first := MapLayout.unit_texture(BOOK, 1)
	_make_zip(BOOK, Color.BLUE)
	PackInstaller.install_zip(PACK_ID, _zip, {"version": "v2", "minVersion": "0.2.0"}, false)
	ContentRegistry.reload()
	var second := MapLayout.unit_texture(BOOK, 1)
	assert_object(second).is_not_same(first)
	assert_float(second.get_image().get_pixel(0, 0).b).is_greater(0.8)


func test_benennung_folgt_dem_pack() -> void:
	assert_str(BookNaming.title(BOOK)).is_empty()
	_make_zip(BOOK, Color.RED, {"naming": {"title": "Kartenbuch"}})
	_install()
	assert_str(BookNaming.title(BOOK)).is_equal("Kartenbuch")


# --- Begleit-Packs -----------------------------------------------------------------------

func _status(id: String, installed_version := "", protected := false, code := {},
		companion_of := "") -> PackStatus:
	var entry := {"id": id, "version": "v2", "minVersion": "0.2.0", "protected": protected}
	if not companion_of.is_empty():
		entry["companionOf"] = companion_of
	var installed := {} if installed_version.is_empty() \
			else {"version": installed_version, "minVersion": "0.2.0"}
	return PackStatus.evaluate(entry, installed, "1.0.0", code)


func test_begleiter_haengt_am_sprach_pack() -> void:
	var language := _status("language-x", "v2")
	var maps := _status("maps-x", "", false, {}, "language-x")
	var orphan := _status("maps-y", "", false, {}, "language-y")
	var all: Array[PackStatus] = [language, maps, orphan]
	ContentService.link_companions(all)
	assert_array(language.companions).contains_exactly([maps])
	assert_array(orphan.companions).is_empty()


func test_fehlender_begleiter_macht_den_installierten_pack_holbar() -> void:
	var language := _status("language-x", "v2")
	var maps := _status("maps-x", "", false, {}, "language-x")
	var all: Array[PackStatus] = [language, maps]
	ContentService.link_companions(all)
	assert_bool(language.own_installable()).is_false()
	assert_bool(language.companion_pending()).is_true()
	assert_bool(language.installable()).is_true()
	assert_bool(language.wants_attention()).is_true()


func test_begleiter_eines_gesperrten_packs_zaehlt_nicht() -> void:
	var language := _status("language-x", "v2", true)
	var maps := _status("maps-x", "", false, {}, "language-x")
	var all: Array[PackStatus] = [language, maps]
	ContentService.link_companions(all)
	assert_bool(language.companion_pending()).is_false()
	assert_bool(language.wants_attention()).is_false()


func test_nie_geholter_pack_wartet_nicht_auf_seinen_begleiter() -> void:
	var language := _status("language-x")
	var maps := _status("maps-x", "", false, {}, "language-x")
	var all: Array[PackStatus] = [language, maps]
	ContentService.link_companions(all)
	assert_bool(language.companion_pending()).is_false()
	assert_bool(language.installable()).is_true()


func test_holen_nimmt_faellige_begleiter_mit() -> void:
	var saved := ContentService.packs.duplicate()
	var current := _status("language-x", "v2")
	var fresh := _status("language-z")
	var maps_x := _status("maps-x", "", false, {}, "language-x")
	var maps_z := _status("maps-z", "", false, {}, "language-z")
	var all: Array[PackStatus] = [current, fresh, maps_x, maps_z]
	ContentService.link_companions(all)
	ContentService.packs = all
	var listed := ContentService.listed()
	var order := ContentService.install_order(["language-x", "language-z"], false)
	var adopted := ContentService.install_order(["maps-x"], true)
	ContentService.packs = saved
	assert_array(listed).contains_exactly([current, fresh])
	assert_array(order).contains_exactly(["maps-x", "language-z", "maps-z"])
	assert_array(adopted).contains_exactly(["maps-x"])
