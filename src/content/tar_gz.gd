class_name TarGz
extends RefCounted
## Liest ein `.tar.gz` ganz in den Speicher; Godot selbst kennt nur ZIP. Gedacht für die
## Linux-Builds von llama.cpp (ADR 0030): Regeldateien, Verzeichnisse, symbolische Links
## und GNU-Langnamen. Was sonst im Archiv steht (Hardlinks, Geräte), wird übergangen.

## Obergrenze des entpackten Archivs in Bytes; ein llama.cpp-Build ist gut 40 MB groß.
const MAX_UNPACKED := 512 * 1024 * 1024

const BLOCK := 512
const TYPE_FILE := "0"
## Sehr alte Archive tragen bei Regeldateien ein NUL statt "0".
const TYPE_FILE_OLD := ""
const TYPE_SYMLINK := "2"
const TYPE_GNU_LONGNAME := "L"


## Ob die Datei mit der gzip-Kennung beginnt.
static func is_gzip(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 2:
		return false
	var head := file.get_buffer(2)
	return head[0] == 0x1f and head[1] == 0x8b


## Die Dateien im Archiv als `{Pfad im Archiv: Inhalt}`. Ein symbolischer Link wird zu
## einer Kopie seines Ziels (auch über Ketten); ein Link ins Leere fällt weg. Bei einem
## kaputten Archiv oder einer Datei ohne gzip-Kennung kommt ein leeres Dictionary zurück.
static func read_files(path: String) -> Dictionary:
	if not is_gzip(path):
		return {}
	var packed := FileAccess.get_file_as_bytes(path)
	if packed.is_empty():
		return {}
	var tar := packed.decompress_dynamic(MAX_UNPACKED, FileAccess.COMPRESSION_GZIP)
	if tar.is_empty():
		return {}
	return parse(tar)


## Dasselbe für ein schon entpacktes tar.
static func parse(tar: PackedByteArray) -> Dictionary:
	var files := {}
	var links := {}
	var long_name := ""
	var at := 0
	while at + BLOCK <= tar.size():
		var header := tar.slice(at, at + BLOCK)
		if header.count(0) == BLOCK:
			break
		var size := _octal(header.slice(124, 136))
		var type := _text(header.slice(156, 157))
		var name := long_name if not long_name.is_empty() else _name(header)
		long_name = ""
		var body := at + BLOCK
		if size < 0 or body + size > tar.size():
			return {}
		match type:
			TYPE_FILE, TYPE_FILE_OLD:
				files[name] = tar.slice(body, body + size)
			TYPE_SYMLINK:
				links[name] = _text(header.slice(157, 257))
			TYPE_GNU_LONGNAME:
				long_name = _text(tar.slice(body, body + size))
		at = body + ceili(float(size) / BLOCK) * BLOCK
	for link in links:
		var target := _resolve(str(link), links)
		if files.has(target):
			files[link] = files[target]
	return files


## Folgt einer Kette von Links bis zu einer Datei; Ziele sind relativ zum Ordner des Links.
static func _resolve(link: String, links: Dictionary) -> String:
	var current := link
	for _hop in links.size() + 1:
		if not links.has(current):
			return current
		var target := str(links[current])
		current = target if target.begins_with("/") \
				else current.get_base_dir().path_join(target).simplify_path()
	return ""


static func _name(header: PackedByteArray) -> String:
	var name := _text(header.slice(0, 100))
	if _text(header.slice(257, 262)) == "ustar":
		var prefix := _text(header.slice(345, 500))
		if not prefix.is_empty():
			name = prefix.path_join(name)
	return name


## Text bis zum ersten NUL.
static func _text(bytes: PackedByteArray) -> String:
	var end := bytes.find(0)
	return (bytes if end < 0 else bytes.slice(0, end)).get_string_from_utf8()


## Eine Oktalzahl aus einem Kopffeld; -1, wenn sie unlesbar ist.
static func _octal(bytes: PackedByteArray) -> int:
	var digits := _text(bytes).strip_edges()
	var value := 0
	for digit in digits:
		if digit < "0" or digit > "7":
			return -1
		value = value * 8 + int(digit)
	return value
