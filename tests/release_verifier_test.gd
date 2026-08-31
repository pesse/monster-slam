extends GdUnitTestSuite
## Die Prüfung eines Programm-Downloads. Die Fixtures sind mit demselben Schlüssel
## signiert, dessen öffentlicher Teil in `ReleaseKey` steht — der Test läuft also über den
## echten Prüfpfad, nicht über einen nachgebauten.

const PAYLOAD := "res://tests/fixtures/update/payload.bin"
const SIG_FILE := "res://tests/fixtures/update/payload.sig.b64"
const SHA_FILE := "res://tests/fixtures/update/payload.sha256"

var _sha := ""
var _sig := ""


func before_test() -> void:
	_sha = FileAccess.get_file_as_string(SHA_FILE).strip_edges()
	_sig = FileAccess.get_file_as_string(SIG_FILE).strip_edges()


func test_echte_datei_besteht() -> void:
	assert_str(ReleaseVerifier.problem(PAYLOAD, _sha, _sig)).is_empty()


func test_pruefsumme_wird_gegen_die_datei_geprueft() -> void:
	var wrong := "0".repeat(64)
	assert_str(ReleaseVerifier.problem(PAYLOAD, wrong, _sig)).contains("Prüfsumme")


func test_fehlende_datei_wird_benannt() -> void:
	assert_str(ReleaseVerifier.problem("res://gibt-es-nicht.bin", _sha, _sig)).contains("nicht lesbar")


func test_fehlende_signatur_wird_abgelehnt() -> void:
	assert_str(ReleaseVerifier.problem(PAYLOAD, _sha, "")).contains("Signatur fehlt")


func test_falsche_signatur_wird_abgelehnt() -> void:
	# Gültiges Base64, aber die Bytes stammen nicht von diesem Schlüssel.
	var forged := Marshalls.raw_to_base64(PackedByteArray([1, 2, 3, 4]))
	assert_str(ReleaseVerifier.problem(PAYLOAD, _sha, forged)).contains("Signatur ungültig")


func test_veraenderte_signatur_wird_abgelehnt() -> void:
	# Ein einzelnes gekipptes Byte in einer sonst echten Signatur.
	var raw := Marshalls.base64_to_raw(_sig)
	raw[10] = raw[10] ^ 0xFF
	assert_str(ReleaseVerifier.problem(PAYLOAD, _sha, Marshalls.raw_to_base64(raw))).contains(
		"Signatur ungültig"
	)


func test_pruefsumme_ist_gross_klein_unabhaengig() -> void:
	assert_str(ReleaseVerifier.problem(PAYLOAD, _sha.to_upper(), _sig)).is_empty()
