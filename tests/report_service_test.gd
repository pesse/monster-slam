extends GdUnitTestSuite
## Der Melde-Kanal: wann er überhaupt offen ist, und was ein Payload trägt
## (siehe docs/adr/0002-melde-rueckkanal.md).
##
## Es wird nichts gesendet — der Endpunkt gehört nicht in einen Testlauf. Geprüft wird
## die Entscheidung „darf gemeldet werden" und der Aufbau der Meldung.

const KEY := "app-1.6FRQ4TRQV7AY862H"

## Die Gründe, die server/melden/melden.php benennt. Absichtlich hier wiederholt: die
## Liste IST der Vertrag zwischen Endpunkt und App, und ein neuer Grund ohne Text würde
## dem Spieler sonst als "Abgewiesen (…)" begegnen.
const ENDPOINT_ERRORS := [
	"bad_token", "stale_key", "revoked", "too_large",
	"rate_limited", "bad_payload", "bad_request", "server_error",
]

var _endpoint_backup := ""
var _key_backup := ""
var _key_version_backup := 1


func before_test() -> void:
	_endpoint_backup = ReportService.endpoint
	_key_backup = ReportService.key
	_key_version_backup = ReportService.key_version


func after_test() -> void:
	ReportService.endpoint = _endpoint_backup
	ReportService.key = _key_backup
	ReportService.key_version = _key_version_backup


func test_ohne_endpunkt_ist_der_kanal_aus() -> void:
	ReportService.endpoint = ""
	ReportService.key = KEY
	assert_bool(ReportService.can_report()).is_false()


func test_ohne_schluessel_ist_der_kanal_aus() -> void:
	ReportService.endpoint = "https://example.invalid/melden.php"
	ReportService.key = ""
	assert_bool(ReportService.can_report()).is_false()


func test_mit_endpunkt_und_schluessel_ist_melden_offen() -> void:
	# Kein Token je Person mehr: was die Fassung mitbringt, reicht (ADR 0022).
	ReportService.endpoint = "https://example.invalid/melden.php"
	ReportService.key = KEY
	assert_bool(ReportService.can_report()).is_true()


func test_ohne_rueckkanal_wird_nichts_gesendet() -> void:
	ReportService.endpoint = ""
	ReportService.key = ""
	assert_bool(await ReportService.send_pending(true)).is_false()
	assert_int(ReportService.state).is_not_equal(ReportService.State.SENDING)


func test_payload_traegt_zieltyp_und_herkunft() -> void:
	var item := {
		"lexeme_id": "lex.gibt.es.nicht",
		"comment": "Übersetzung passt nicht",
		"learnable_id": "learn.x",
		"at": "2026-09-02T18:04:11",
	}
	ReportService.key_version = 3
	var payload := ReportService._payload(item)
	assert_str(String(payload["action"])).is_equal("report")
	assert_int(int(payload["key_version"])).is_equal(3)
	# Nicht "lexeme_id": gemeldete Sätze sollen später ohne Formatbruch dazupassen.
	assert_str(String(payload["target_type"])).is_equal("lexeme")
	assert_str(String(payload["target_id"])).is_equal("lex.gibt.es.nicht")
	assert_str(String(payload["comment"])).is_equal("Übersetzung passt nicht")
	assert_str(String(payload["at"])).is_equal("2026-09-02T18:04:11")
	assert_str(String(payload["app_version"])).is_not_empty()


func test_payload_ohne_pack_wenn_der_eintrag_nicht_aus_einem_pack_kommt() -> void:
	var payload := ReportService._payload({"lexeme_id": "lex.gibt.es.nicht"})
	assert_bool(payload.has("pack")).is_false()


func test_jeder_grund_des_endpunkts_hat_einen_text() -> void:
	for code in ENDPOINT_ERRORS:
		assert_bool(ReportService.ERROR_TEXTS.has(code)) \
			.override_failure_message("Kein Anzeigetext für '%s'" % code).is_true()
		assert_str(String(ReportService.ERROR_TEXTS[code])).is_not_empty()
