class_name PackCrypto
extends RefCounted
## Hülle geschützter Content-Packs: Kopf lesen, Zugangscode prüfen, entschlüsseln.
##
## Format und Begründung: docs/PACK_FORMAT.md. Zweitimplementierungen sind
## tools/packs/build_packs.py (Erzeuger) und tools/packs/verify_pack.py (Prüfer) — eine
## Änderung hier ist eine Änderung an allen drei Stellen und braucht eine neue Formatversion.
##
## AES-CBC mit HMAC statt AES-GCM, weil Godots AESContext kein GCM kennt; PBKDF2 statt
## scrypt, weil Godot kein scrypt hat. Beides mit den Folgen, die in PACK_FORMAT.md stehen.

const MAGIC := "MSPACK"
const FORMAT_VERSION := 1
const KDF_PBKDF2 := 1
const SALT_LEN := 16
const VERIFIER_LEN := 32
const IV_LEN := 16
const MAC_LEN := 32
const HEADER_LEN := 108
## Der MAC deckt alles vor sich selbst plus den Ciphertext ab.
const MAC_OFFSET := HEADER_LEN - MAC_LEN

const LABEL_ENC := "monster-slam:enc"
const LABEL_MAC := "monster-slam:mac"
const LABEL_VERIFY := "monster-slam:verify"

## Obergrenze für den Kostenparameter im Kopf. Ohne sie könnte eine manipulierte Datei die
## App vor der MAC-Prüfung beliebig lange rechnen lassen — der Kopf ist an dieser Stelle
## noch nicht verifiziert.
const MAX_ITERATIONS := 5_000_000


## Gelesener Kopf. `error` ist "" wenn er brauchbar ist.
class Header:
	var iterations := 0
	var salt := PackedByteArray()
	var verifier := PackedByteArray()
	var iv := PackedByteArray()
	var mac := PackedByteArray()
	## Bytes 0..MAC_OFFSET — gehen so in die MAC-Berechnung ein.
	var signed_prefix := PackedByteArray()
	var error := ""


static func read_header(blob: PackedByteArray) -> Header:
	var header := Header.new()
	if blob.size() < HEADER_LEN:
		header.error = "Pack ist zu kurz (%d statt mindestens %d Bytes)." % [blob.size(), HEADER_LEN]
		return header
	if blob.slice(0, 6).get_string_from_ascii() != MAGIC:
		header.error = "Datei ist kein geschützter Pack."
		return header
	if blob[6] != FORMAT_VERSION:
		header.error = "Pack-Format %d kennt diese Fassung nicht — bitte das Spiel aktualisieren." % blob[6]
		return header
	if blob[7] != KDF_PBKDF2:
		header.error = "Unbekanntes Schlüsselverfahren (%d)." % blob[7]
		return header

	var iterations := (blob[8] << 24) | (blob[9] << 16) | (blob[10] << 8) | blob[11]
	if iterations <= 0 or iterations > MAX_ITERATIONS:
		header.error = "Unplausibler Kostenparameter (%d)." % iterations
		return header

	header.iterations = iterations
	header.salt = blob.slice(12, 28)
	header.verifier = blob.slice(28, 60)
	header.iv = blob.slice(60, 76)
	header.mac = blob.slice(76, 108)
	header.signed_prefix = blob.slice(0, MAC_OFFSET)
	return header


## Verschlüsselungs-, MAC- und Prüfschlüssel aus dem Zugangscode.
static func derive(code: String, salt: PackedByteArray, iterations: int) -> Dictionary:
	var master := pbkdf2_sha256(code.to_utf8_buffer(), salt, iterations, 32)
	var crypto := Crypto.new()
	return {
		"enc": crypto.hmac_digest(HashingContext.HASH_SHA256, master, LABEL_ENC.to_utf8_buffer()),
		"mac": crypto.hmac_digest(HashingContext.HASH_SHA256, master, LABEL_MAC.to_utf8_buffer()),
		"verify": crypto.hmac_digest(HashingContext.HASH_SHA256, master, LABEL_VERIFY.to_utf8_buffer()),
	}


## PBKDF2-HMAC-SHA256, RFC 8018. In GDScript, weil Godot keine eigene Ableitung anbietet;
## 600 000 Iterationen kosten hier rund 0,9 s (gemessen, siehe PACK_FORMAT.md).
static func pbkdf2_sha256(
	password: PackedByteArray, salt: PackedByteArray, iterations: int, length: int
) -> PackedByteArray:
	var crypto := Crypto.new()
	var out := PackedByteArray()
	var block := 1
	while out.size() < length:
		var u := crypto.hmac_digest(
			HashingContext.HASH_SHA256,
			password,
			salt + PackedByteArray([block >> 24 & 0xFF, block >> 16 & 0xFF, block >> 8 & 0xFF, block & 0xFF]),
		)
		var acc := u.duplicate()
		for _i in iterations - 1:
			u = crypto.hmac_digest(HashingContext.HASH_SHA256, password, u)
			for j in acc.size():
				acc[j] ^= u[j]
		out.append_array(acc)
		block += 1
	return out.slice(0, length)


## Prüft einen Zugangscode allein am Kopf — ohne den ganzen Pack zu laden.
##
## Der Verifier steht vorn, der MAC am Ende: eine Codeprüfung über den MAC müsste die
## komplette Datei ziehen. Ein Angreifer erfährt dadurch nichts Zusätzliches — wer die
## Datei hat, könnte ebenso gegen den MAC raten; die Kosten pro Versuch bestimmt allein
## die Ableitung.
static func code_matches(header: Header, code: String) -> bool:
	if not header.error.is_empty():
		return false
	var keys := derive(code, header.salt, header.iterations)
	return constant_time_eq(keys["verify"], header.verifier)


## Entschlüsselt einen Pack. Rückgabe: {"error": String, "zip": PackedByteArray}.
static func decrypt(blob: PackedByteArray, code: String) -> Dictionary:
	var header := read_header(blob)
	if not header.error.is_empty():
		return {"error": header.error, "zip": PackedByteArray()}

	var ciphertext := blob.slice(HEADER_LEN)
	if ciphertext.is_empty() or ciphertext.size() % 16 != 0:
		return {"error": "Pack ist beschädigt (Länge passt nicht).", "zip": PackedByteArray()}

	var keys := derive(code, header.salt, header.iterations)
	if not constant_time_eq(keys["verify"], header.verifier):
		return {"error": "Falscher Zugangscode.", "zip": PackedByteArray()}

	# VOR dem Entschlüsseln: ein veränderter Kopf — etwa ein herabgesetzter
	# Kostenparameter — darf nicht erst nach dem Entpacken auffallen.
	var expected := Crypto.new().hmac_digest(
		HashingContext.HASH_SHA256, keys["mac"], header.signed_prefix + ciphertext
	)
	if not constant_time_eq(expected, header.mac):
		return {"error": "Pack ist beschädigt oder wurde verändert.", "zip": PackedByteArray()}

	var aes := AESContext.new()
	# AESContext schreibt in den übergebenen IV, deshalb eine Kopie.
	if aes.start(AESContext.MODE_CBC_DECRYPT, keys["enc"], header.iv.duplicate()) != OK:
		return {"error": "Entschlüsselung nicht startbar.", "zip": PackedByteArray()}
	var padded := aes.update(ciphertext)
	aes.finish()
	return _unpad(padded)


## PKCS#7 abziehen. Godot padded nicht selbst, also wird hier auch nicht darauf vertraut:
## eine unplausible Füllung ist ein Fehler, kein zu kürzender Rest.
static func _unpad(padded: PackedByteArray) -> Dictionary:
	if padded.is_empty():
		return {"error": "Pack ist leer.", "zip": PackedByteArray()}
	var pad := padded[padded.size() - 1]
	if pad < 1 or pad > 16 or pad > padded.size():
		return {"error": "Pack ist beschädigt (Füllung ungültig).", "zip": PackedByteArray()}
	for i in pad:
		if padded[padded.size() - 1 - i] != pad:
			return {"error": "Pack ist beschädigt (Füllung ungültig).", "zip": PackedByteArray()}
	return {"error": "", "zip": padded.slice(0, padded.size() - pad)}


static func constant_time_eq(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0
