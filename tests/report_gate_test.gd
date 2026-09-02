extends GdUnitTestSuite
## „Melden" verschwindet ohne Rückkanal — die Bedienungsentscheidung aus
## docs/adr/0002-melde-rueckkanal.md, an den beiden Stellen geprüft, an denen sie wirkt.
##
## Kein Sicherheitsmechanismus: der Endpunkt entscheidet, ob eine Meldung angenommen
## wird. Hier geht es darum, dass niemand einen Knopf sieht, der ohne Folge bliebe.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const TOKEN := "mia.6FRQ4TRQV7AY862H"

var _endpoint_backup := ""
var _codes_backup: String = ""
var _had_codes: bool = false


func before_test() -> void:
	_endpoint_backup = ReportService.endpoint
	_had_codes = FileAccess.file_exists(ReportToken.PATH)
	_codes_backup = FileAccess.get_file_as_string(ReportToken.PATH) if _had_codes else ""
	ReportService.endpoint = "https://example.invalid/melden.php"
	ReportToken.forget()


func after_test() -> void:
	ReportService.endpoint = _endpoint_backup
	if _had_codes:
		var file := FileAccess.open(ReportToken.PATH, FileAccess.WRITE)
		file.store_string(_codes_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ReportToken.PATH)


func _reveal() -> Control:
	var reveal := auto_free(REVEAL_SCENE.instantiate()) as Control
	add_child(reveal)
	reveal._apply_report_gate()
	return reveal


func _settings() -> Control:
	var menu := auto_free(SETTINGS_SCENE.instantiate()) as Control
	add_child(menu)
	return menu


func test_reveal_zeigt_melden_nur_mit_token() -> void:
	assert_bool((_reveal().get_node("%FlagBtn") as Button).visible).is_false()
	ReportToken.store(TOKEN, 1)
	assert_bool((_reveal().get_node("%FlagBtn") as Button).visible).is_true()


func test_einstellungen_verbergen_die_meldungsliste_ohne_token() -> void:
	var menu := _settings()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_false()
	assert_str((menu.get_node("%TokenStatus") as Label).text).contains("Kein Token")


func test_einstellungen_zeigen_die_meldungsliste_mit_token() -> void:
	ReportToken.store(TOKEN, 1)
	var menu := _settings()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_true()
	assert_str((menu.get_node("%TokenStatus") as Label).text).contains("mia")


func test_ohne_endpunkt_ist_auch_das_eingabefeld_aus() -> void:
	ReportService.endpoint = ""
	var menu := _settings()
	assert_bool((menu.get_node("%TokenInput") as LineEdit).editable).is_false()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_false()
	assert_str((menu.get_node("%TokenStatus") as Label).text).contains("keinen Rückkanal")
