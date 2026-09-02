extends GdUnitTestSuite
## Melde-Token: Ablage in `user://codes.cfg` und die Gestaltprüfung eines abgetippten
## Tokens (siehe docs/adr/0002-melde-rueckkanal.md).
##
## Der Test fasst die echte Codedatei an und sichert/restauriert sie — dort liegen im
## Entwicklungslauf die Pack-Zugangscodes.

var _backup: String = ""
var _had_backup: bool = false


func before_test() -> void:
	_had_backup = FileAccess.file_exists(ReportToken.PATH)
	_backup = FileAccess.get_file_as_string(ReportToken.PATH) if _had_backup else ""
	DirAccess.remove_absolute(ReportToken.PATH)


func after_test() -> void:
	if _had_backup:
		var file := FileAccess.open(ReportToken.PATH, FileAccess.WRITE)
		file.store_string(_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ReportToken.PATH)


func test_ohne_datei_ist_kein_token_hinterlegt() -> void:
	assert_dict(ReportToken.get_stored()).is_empty()
	assert_bool(ReportToken.has_token()).is_false()


func test_store_und_get_stored_mit_key_version() -> void:
	ReportToken.store("mia.6FRQ4TRQV7AY862H", 2)
	var stored := ReportToken.get_stored()
	assert_str(String(stored["token"])).is_equal("mia.6FRQ4TRQV7AY862H")
	assert_int(int(stored["key_version"])).is_equal(2)
	assert_bool(ReportToken.has_token()).is_true()


func test_eintrag_ohne_praefix_gilt_als_version_1() -> void:
	var config := ConfigFile.new()
	config.set_value(ReportToken.SECTION, ReportToken.KEY, "mia.6FRQ4TRQV7AY862H")
	config.save(ReportToken.PATH)
	assert_int(int(ReportToken.get_stored()["key_version"])).is_equal(1)


func test_forget_nimmt_zurueck() -> void:
	ReportToken.store("mia.6FRQ4TRQV7AY862H", 1)
	ReportToken.forget()
	assert_bool(ReportToken.has_token()).is_false()


## Das Token liegt in derselben Datei wie die Pack-Zugangscodes, aber in eigener Sektion:
## ein Melde-Token darf keinen Zugangscode überschreiben.
func test_token_und_pack_code_stehen_nebeneinander() -> void:
	AccessCodes.store("zz-test-pack", "geheim", 3)
	ReportToken.store("mia.6FRQ4TRQV7AY862H", 1)
	assert_str(String(AccessCodes.get_code("zz-test-pack")["code"])).is_equal("geheim")
	assert_str(String(ReportToken.get_stored()["token"])).is_equal("mia.6FRQ4TRQV7AY862H")
	AccessCodes.forget("zz-test-pack")


func test_normalize_bringt_abgetipptes_auf_kanonische_form() -> void:
	# Bindestriche, Kleinschreibung und die Crockford-Verwechslungen O->0, I/L->1.
	assert_str(ReportToken.normalize("  MIA.6frq-4trq-v7ay-862h ")).is_equal("mia.6FRQ4TRQV7AY862H")
	assert_str(ReportToken.normalize("mia.6FRQ 4TRQ V7AY 862H")).is_equal("mia.6FRQ4TRQV7AY862H")
	assert_str(ReportToken.normalize("mia.OFRQ4TRQV7AY862I")).is_equal("mia.0FRQ4TRQV7AY8621")
	assert_str(ReportToken.normalize("mia.lFRQ4TRQV7AY862H")).is_equal("mia.1FRQ4TRQV7AY862H")


func test_normalize_weist_kaputte_gestalt_ab() -> void:
	assert_str(ReportToken.normalize("")).is_empty()
	assert_str(ReportToken.normalize("mia")).is_empty()                       # kein Punkt
	assert_str(ReportToken.normalize(".6FRQ4TRQV7AY862H")).is_empty()         # kein Label
	assert_str(ReportToken.normalize("mia.6FRQ4TRQV7AY862")).is_empty()       # zu kurz
	assert_str(ReportToken.normalize("mia.6FRQ4TRQV7AY862HH")).is_empty()     # zu lang
	assert_str(ReportToken.normalize("mia.6FRQ4TRQV7AY862U")).is_empty()      # U nicht im Alphabet
	assert_str(ReportToken.normalize("Mia Meier.6FRQ4TRQV7AY862H")).is_empty()  # Label mit Leerzeichen
	assert_str(ReportToken.normalize("-mia.6FRQ4TRQV7AY862H")).is_empty()     # Label beginnt mit -


func test_label_of() -> void:
	assert_str(ReportToken.label_of("mia.6FRQ4TRQV7AY862H")).is_equal("mia")
	assert_str(ReportToken.label_of("kaputt")).is_empty()
