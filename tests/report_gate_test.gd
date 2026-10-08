extends GdUnitTestSuite
## „Melden" verschwindet ohne Rückkanal — die Bedienungsentscheidung aus
## docs/adr/0002-melde-rueckkanal.md, an den beiden Stellen geprüft, an denen sie wirkt.
##
## Kein Sicherheitsmechanismus: der Endpunkt entscheidet, ob eine Meldung angenommen
## wird. Hier geht es darum, dass niemand einen Knopf sieht, der ohne Folge bliebe.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const KEY := "app-1.6FRQ4TRQV7AY862H"

var _endpoint_backup := ""
var _key_backup := ""


func before_test() -> void:
	_endpoint_backup = ReportService.endpoint
	_key_backup = ReportService.key
	ReportService.endpoint = "https://example.invalid/melden.php"
	ReportService.key = ""


func after_test() -> void:
	ReportService.endpoint = _endpoint_backup
	ReportService.key = _key_backup


func _reveal() -> Control:
	var reveal := auto_free(REVEAL_SCENE.instantiate()) as Control
	add_child(reveal)
	reveal._apply_report_gate()
	return reveal


func _settings() -> Control:
	var menu := auto_free(SETTINGS_SCENE.instantiate()) as Control
	add_child(menu)
	return menu


func test_reveal_zeigt_melden_nur_mit_rueckkanal() -> void:
	assert_bool((_reveal().get_node("%FlagBtn") as Button).visible).is_false()
	ReportService.key = KEY
	assert_bool((_reveal().get_node("%FlagBtn") as Button).visible).is_true()


func test_einstellungen_verbergen_die_meldungsliste_ohne_rueckkanal() -> void:
	var menu := _settings()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_false()
	assert_str((menu.get_node("%ReportStatus") as Label).text).contains("keinen Rückkanal")


func test_einstellungen_zeigen_die_meldungsliste_mit_rueckkanal() -> void:
	ReportService.key = KEY
	var menu := _settings()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_true()
	assert_str((menu.get_node("%ReportStatus") as Label).text).not_contains("keinen Rückkanal")


func test_ohne_endpunkt_ist_melden_aus() -> void:
	ReportService.endpoint = ""
	ReportService.key = KEY
	var menu := _settings()
	assert_bool((menu.get_node("%FlagScroll") as ScrollContainer).visible).is_false()
	assert_str((menu.get_node("%ReportStatus") as Label).text).contains("keinen Rückkanal")
