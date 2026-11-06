class_name TarBuilder
extends RefCounted
## Baut kleine tar-Archive für Tests (`TarGz`, `ModelService`): ustar-Köpfe mit Name, Größe,
## Typ und Linkziel. Die Prüfsumme bleibt leer, `TarGz` liest sie nicht.

const BLOCK := 512


## Eine Regeldatei.
static func entry(name: String, text: String) -> PackedByteArray:
	return _member(name, "0", text.to_utf8_buffer(), "")


## Ein symbolischer Link auf `target` (relativ zum Ordner des Links).
static func link(name: String, target: String) -> PackedByteArray:
	return _member(name, "2", PackedByteArray(), target)


## Ein Name über 100 Zeichen, wie GNU tar ihn schreibt: erst ein `L`-Eintrag mit dem Namen,
## dann der eigentliche Eintrag mit gekürztem Namen.
static func long_entry(name: String, text: String) -> PackedByteArray:
	var bytes := _member("././@LongLink", "L", name.to_utf8_buffer(), "")
	bytes.append_array(_member(name.substr(0, 99), "0", text.to_utf8_buffer(), ""))
	return bytes


## Die Einträge hintereinander, abgeschlossen von zwei leeren Blöcken.
static func tar(members: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for member in members:
		bytes.append_array(member)
	bytes.resize(bytes.size() + 2 * BLOCK)
	return bytes


static func _member(name: String, type: String, body: PackedByteArray,
		target: String) -> PackedByteArray:
	var header := PackedByteArray()
	header.resize(BLOCK)
	_put(header, 0, name.to_utf8_buffer())
	_put(header, 100, "0000755".to_ascii_buffer())
	_put(header, 124, ("%011o" % body.size()).to_ascii_buffer())
	_put(header, 156, type.to_ascii_buffer())
	_put(header, 157, target.to_utf8_buffer())
	_put(header, 257, "ustar".to_ascii_buffer())
	var padded := body.duplicate()
	padded.resize(ceili(float(body.size()) / BLOCK) * BLOCK)
	header.append_array(padded)
	return header


static func _put(bytes: PackedByteArray, at: int, value: PackedByteArray) -> void:
	for i in value.size():
		bytes[at + i] = value[i]
