extends GdUnitTestSuite
## Der Melde-Kanal: wann er überhaupt offen ist, und was ein Payload trägt
## (siehe docs/adr/0002-melde-rueckkanal.md).
##
## Es wird nichts gesendet — der Endpunkt gehört nicht in einen Testlauf. Geprüft wird
## die Entscheidung „darf gemeldet werden" und der Aufbau der Meldung.

const TOKEN := "mia.6FRQ4TRQV7AY862H"

## Die Gründe, die server/melden/melden.php benennt. Absichtlich hier wiederholt: die
## Liste IST der Vertrag zwischen Endpunkt und App, und ein neuer Grund ohne Text würde
## dem Spieler sonst als "Abgewiesen (…)" begegnen.
const ENDPOINT_ERRORS := [
	"bad_token", "stale_key", "revoked", "too_large",
	"rate_limited", "bad_payload", "bad_request", "server_error",
]

var _endpoint_backup := ""
var _codes_backup: String = ""
var _had_codes: bool = false


func before_test() -> void:
	_endpoint_backup = ReportService.endpoint
	_had_codes = FileAccess.file_exists(ReportToken.PATH)
	_codes_backup = FileAccess.get_file_as_string(ReportToken.PATH) if _had_codes else ""
	ReportToken.forget()


func after_test() -> void:
	ReportService.endpoint = _endpoint_backup
	if _had_codes:
		var file := FileAccess.open(ReportToken.PATH, FileAccess.WRITE)
		file.store_string(_codes_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ReportToken.PATH)


func test_ohne_endpunkt_ist_der_kanal_aus() -> void:
	ReportService.endpoint = ""
	ReportToken.store(TOKEN, 1)
	assert_bool(ReportService.configured()).is_false()
	assert_bool(ReportService.can_report()).is_false()


func test_ohne_token_darf_nicht_gemeldet_werden() -> void:
	ReportService.endpoint = "https://example.invalid/melden.php"
	assert_bool(ReportService.configured()).is_true()
	assert_bool(ReportService.can_report()).is_false()


func test_mit_endpunkt_und_token_ist_melden_offen() -> void:
	ReportService.endpoint = "https://example.invalid/melden.php"
	ReportToken.store(TOKEN, 1)
	assert_bool(ReportService.can_report()).is_true()


func test_verify_weist_kaputte_gestalt_ohne_netz_ab() -> void:
	# Die Gestaltprüfung ist der Sinn der lokalen Normalisierung: ein Tippfehler soll
	# auffallen, ohne dass eine Anfrage rausgeht.
	ReportService.endpoint = "https://example.invalid/melden.php"
	assert_bool(await ReportService.verify("mia.viel-zu-kurz")).is_false()
	assert_int(ReportService.state).is_equal(ReportService.State.ERROR)
	assert_str(ReportService.error).is_not_empty()
	assert_bool(ReportToken.has_token()).is_false()


func test_payload_traegt_zieltyp_und_herkunft() -> void:
	var item := {
		"lexeme_id": "lex.gibt.es.nicht",
		"comment": "Übersetzung passt nicht",
		"learnable_id": "learn.x",
		"at": "2026-09-02T18:04:11",
	}
	var payload := ReportService._payload(item, 3)
	assert_str(String(payload["action"])).is_equal("report")
	assert_int(int(payload["key_version"])).is_equal(3)
	# Nicht "lexeme_id": gemeldete Sätze sollen später ohne Formatbruch dazupassen.
	assert_str(String(payload["target_type"])).is_equal("lexeme")
	assert_str(String(payload["target_id"])).is_equal("lex.gibt.es.nicht")
	assert_str(String(payload["comment"])).is_equal("Übersetzung passt nicht")
	assert_str(String(payload["at"])).is_equal("2026-09-02T18:04:11")
	assert_str(String(payload["app_version"])).is_not_empty()


func test_payload_ohne_pack_wenn_der_eintrag_nicht_aus_einem_pack_kommt() -> void:
	var payload := ReportService._payload({"lexeme_id": "lex.gibt.es.nicht"}, 1)
	assert_bool(payload.has("pack")).is_false()


func test_jeder_grund_des_endpunkts_hat_einen_text() -> void:
	for code in ENDPOINT_ERRORS:
		assert_bool(ReportService.ERROR_TEXTS.has(code)) \
			.override_failure_message("Kein Anzeigetext für '%s'" % code).is_true()
		assert_str(String(ReportService.ERROR_TEXTS[code])).is_not_empty()
