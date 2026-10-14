class_name ReleaseVerifier
extends RefCounted
## Prüft eine geladene Programmdatei gegen latest.json. Die Prüfsumme fängt den kaputten
## Download, die Signatur den manipulierten; die Prüfsumme allein sichert nichts, sie steht
## im selben Manifest wie die URL.


## "" wenn die Datei echt ist, sonst der Grund. Eine fehlende Angabe ist ein Ablehnungsgrund.
static func problem(path: String, expected_sha256: String, signature_b64: String) -> String:
	var digest := Digest.of_file(path)
	if digest.is_empty():
		return "Geladene Datei nicht lesbar."
	if not Digest.equal(digest, expected_sha256):
		return "Prüfsumme weicht ab — Download verworfen."

	var key := ReleaseKey.load_public()
	if key == null:
		return "Kein Prüfschlüssel vorhanden — Update abgelehnt."
	if signature_b64.strip_edges().is_empty():
		return "Signatur fehlt — Update abgelehnt."
	var signature := Marshalls.base64_to_raw(signature_b64.strip_edges())
	if signature.is_empty():
		return "Signatur unlesbar — Update abgelehnt."
	if not Crypto.new().verify(HashingContext.HASH_SHA256, digest.hex_decode(), signature, key):
		return "Signatur ungültig — die Datei stammt nicht aus diesem Projekt."
	return ""
