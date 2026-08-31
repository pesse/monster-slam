class_name Digest
extends RefCounted
## SHA-256 als Hex-String — für Download-Prüfsummen und den Dateizustand installierter Packs.


## Prüfsumme einer Datei. Godots eigene Implementierung liest gepuffert; eine 120-MB-EXE
## landet also nicht als Ganzes im Speicher.
static func of_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


static func of_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Vergleich zweier Hex-Prüfsummen, groß/klein-unabhängig.
static func equal(a: String, b: String) -> bool:
	return not a.is_empty() and a.to_lower() == b.to_lower()
