extends GdUnitTestSuite
## Die Hülle geschützter Packs. Die Fixture ist mit tools/packs/build_packs.py erzeugt
## (tests/fixtures/packs/make_fixtures.py) — der Test läuft also gegen das echte Format und
## nicht gegen einen in GDScript nachgebauten Kopf.

const PACK := "res://tests/fixtures/packs/protected_v1.enc"
const CODE := "test-code"


func _blob() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PACK)


## Ein Byte kippen und den so veränderten Pack zurückgeben.
func _flipped(offset: int) -> PackedByteArray:
	var blob := _blob()
	blob[offset] = blob[offset] ^ 0xFF
	return blob


func test_pbkdf2_stimmt_mit_der_referenz() -> void:
	# Gegenprobe zu Pythons hashlib.pbkdf2_hmac — beide Seiten des Formats müssen dieselbe
	# Ableitung rechnen, sonst ist kein Pack lesbar.
	var derived := PackCrypto.pbkdf2_sha256(
		"test-code".to_utf8_buffer(), "monster-slam-salt".to_utf8_buffer(), 1000, 32
	)
	assert_str(derived.hex_encode()).is_equal(
		"7370b23d67564bf6effe158a18e64dabbec2a8d50cc35e34cec21dc9a53a1119"
	)


func test_pbkdf2_ueber_mehrere_bloecke() -> void:
	# 48 Bytes brauchen zwei HMAC-Blöcke; der zweite darf den ersten nicht verändern.
	var derived := PackCrypto.pbkdf2_sha256(
		"test-code".to_utf8_buffer(), "monster-slam-salt".to_utf8_buffer(), 1000, 48
	)
	assert_str(derived.hex_encode()).is_equal(
		"7370b23d67564bf6effe158a18e64dabbec2a8d50cc35e34cec21dc9a53a1119"
		+ "33e3f9260eb2aeb6e10ee44d1b4c69f2"
	)


func test_kopf_wird_gelesen() -> void:
	var header := PackCrypto.read_header(_blob())
	assert_str(header.error).is_empty()
	assert_int(header.iterations).is_equal(600000)
	assert_int(header.salt.size()).is_equal(PackCrypto.SALT_LEN)
	assert_int(header.mac.size()).is_equal(PackCrypto.MAC_LEN)


func test_zu_kurze_datei_wird_benannt() -> void:
	assert_str(PackCrypto.read_header(PackedByteArray([1, 2, 3])).error).contains("zu kurz")


func test_fremde_datei_ist_kein_pack() -> void:
	var blob := _blob()
	blob[0] = 0x58
	assert_str(PackCrypto.read_header(blob).error).contains("kein geschützter Pack")


func test_unbekannte_formatversion_verlangt_ein_app_update() -> void:
	var blob := _blob()
	blob[6] = 99
	assert_str(PackCrypto.read_header(blob).error).contains("aktualisieren")


func test_unplausibler_kostenparameter_wird_abgelehnt() -> void:
	# Ohne diese Schranke könnte eine manipulierte Datei die App vor der MAC-Prüfung
	# beliebig lange rechnen lassen.
	var blob := _blob()
	blob[8] = 0xFF
	assert_str(PackCrypto.read_header(blob).error).contains("Kostenparameter")


func test_richtiger_code_passt_zum_kopf() -> void:
	assert_bool(PackCrypto.code_matches(PackCrypto.read_header(_blob()), CODE)).is_true()


func test_falscher_code_passt_nicht() -> void:
	assert_bool(PackCrypto.code_matches(PackCrypto.read_header(_blob()), "falsch")).is_false()


func test_entschluesseln_ergibt_ein_zip() -> void:
	var result := PackCrypto.decrypt(_blob(), CODE)
	assert_str(str(result["error"])).is_empty()
	var zip: PackedByteArray = result["zip"]
	# ZIP-Signatur "PK\x03\x04".
	assert_array(Array(zip.slice(0, 4))).is_equal([0x50, 0x4B, 0x03, 0x04])


func test_falscher_code_wird_benannt() -> void:
	assert_str(str(PackCrypto.decrypt(_blob(), "falsch")["error"])).contains("Zugangscode")


func test_veraenderter_ciphertext_wird_erkannt() -> void:
	# Encrypt-then-MAC: das fällt VOR dem Entschlüsseln auf.
	var result := PackCrypto.decrypt(_flipped(PackCrypto.HEADER_LEN + 5), CODE)
	assert_str(str(result["error"])).contains("verändert")
	assert_int((result["zip"] as PackedByteArray).size()).is_equal(0)


func test_veraenderter_mac_wird_erkannt() -> void:
	assert_str(str(PackCrypto.decrypt(_flipped(80), CODE)["error"])).contains("verändert")


func test_herabgesetzter_kostenparameter_wird_nicht_akzeptiert() -> void:
	# Der Kopf geht in die Ableitung ein, also passt nach einer Manipulation weder Verifier
	# noch MAC. Was gemeldet wird, ist zweitrangig — entscheidend ist, dass NICHTS
	# entschlüsselt wird, statt still mit einem schwächeren Schlüssel weiterzumachen.
	var blob := _blob()
	blob[8] = 0
	blob[9] = 0
	blob[10] = 0x27
	blob[11] = 0x10  # 10000 statt 600000
	var result := PackCrypto.decrypt(blob, CODE)
	assert_str(str(result["error"])).is_not_empty()
	assert_int((result["zip"] as PackedByteArray).size()).is_equal(0)


func test_veraenderter_salt_macht_den_pack_unlesbar() -> void:
	assert_str(str(PackCrypto.decrypt(_flipped(14), CODE)["error"])).is_not_empty()


func test_offener_pack_ist_kein_geschuetzter() -> void:
	var open_zip := FileAccess.get_file_as_bytes("res://tests/fixtures/packs/open_v1.zip")
	assert_str(PackCrypto.read_header(open_zip).error).is_not_empty()
