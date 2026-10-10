class_name SaveStore
extends RefCounted
## Schreibt und liest Spielstand-Dateien so, dass ein Absturz sie nicht still zerstört
## (docs/adr/0024-spielstand-sicher-speichern.md).
##
## Zwei Regeln, aus einem Vorfall: Ein Spielstand fiel von Level 26 auf Level 1, weil die
## Erfahrung bei jedem Kill direkt überschrieben wurde (FileAccess.WRITE leert die Datei
## sofort) und eine danach unlesbare Datei als „neues Profil" galt.
##
## 1. Geschrieben wird erst in `<datei>.tmp`, zurückgelesen und geprüft, dann umbenannt.
##    Die alte Datei ist bis zum Umbenennen unberührt.
## 2. Jede Datei trägt die Prüfsumme ihres Inhalts. `read` unterscheidet deshalb drei
##    Fälle, die vorher einer waren: keine Datei (MISSING, ein neues Profil), eine
##    beschädigte (CORRUPT) und eine aus einer neueren Fassung (NEWER). Beschädigt ist
##    NIE „neu" — was damit geschieht, entscheidet der SaveCoordinator.
##
## Format — die Prüfsumme steht als erstes Feld in derselben Datei (keine Datei daneben:
## zwei Dateien lassen sich nicht gemeinsam ersetzen):
##
##     {"_save":{"format":1,"sha256":"<64 hex>"},<JSON.stringify(data, "\t") ohne das erste "{">
##
## Die Prüfsumme gilt den Bytes von `JSON.stringify(data, "\t")`; beim Prüfen werden sie aus
## der Datei zurückgewonnen („{" plus alles hinter dem Kopf), ohne Neu-Serialisieren
## (Kommazahlen kämen sonst nicht Byte für Byte gleich heraus). Die Datei bleibt das
## gewohnte JSON-Objekt mit einem Feld mehr: eine ältere Fassung des Spiels liest sie wie
## bisher und übergeht `_save` — wer zurückwechselt (ein älterer Branch, ein Downgrade),
## verliert nichts.
##
## Dateien aus der Zeit davor (ohne `_save`) gelten als OK mit `legacy`, wenn sie sich als
## Dictionary lesen lassen, und bekommen die Prüfsumme beim nächsten Schreiben.
##
## Was Godot nicht kann: ein fsync. `flush()` leert nur den Puffer des Programms; nach einem
## Stromausfall kann Windows die Umbenennung behalten und den Inhalt verlieren. Dagegen hilft
## nur, was die Prüfsumme erkennt und die Sicherungen (Backups) ersetzen. Und
## `DirAccess.rename_absolute` ist unter Windows „Ziel löschen, dann verschieben" — dazwischen
## gibt es kurz nur die `.tmp`. `pending_tmp` und der SaveCoordinator räumen das beim Öffnen auf.

enum Status { OK, MISSING, CORRUPT, NEWER }

const FORMAT := 1
const TMP_SUFFIX := ".tmp"
## Die Zeile, mit der eine gesicherte settings.cfg beginnt (ConfigFile überliest Kommentare).
const CFG_HASH_PREFIX := "; sha256="

const _PREFIX_PATTERN := "^\\{\"_save\":\\{\"format\":(\\d+),\"sha256\":\"([0-9a-f]{64})\"\\},?"

## Ein Zwischenformat ({"format":1,"sha256":…,"data":<daten>}), das nur auf dem
## Entwicklungsrechner geschrieben wurde, bevor die Hülle abwärtskompatibel wurde. Gelesen
## wird es als `legacy` und beim nächsten Schreiben umgestellt. Kann weg, sobald dort
## alles umgeschrieben ist.
const _INTERIM_PATTERN := "^\\{\"format\":1,\"sha256\":\"([0-9a-f]{64})\",\"data\":"

static var _prefix_regex: RegEx
static var _interim_regex: RegEx


## Liest `path`. Ergebnis:
##   { status: Status, data: Dictionary, legacy: bool, error: String }
## `data` ist nur bei OK gefüllt. Mit `parse = false` wird eine Datei mit Hülle nur über die
## Prüfsumme geprüft und nicht gelesen (`data` bleibt leer) — für große Dateien, deren
## Inhalt der Aufrufer nicht braucht.
static func read(path: String, parse := true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(Status.MISSING)
	return decode(FileAccess.get_file_as_bytes(path), parse)


## Wie `read`, für Bytes (Sicherungen, Archive).
static func decode(bytes: PackedByteArray, parse := true) -> Dictionary:
	if bytes.is_empty():
		return _result(Status.CORRUPT, {}, false, "leer")
	var head := bytes.slice(0, mini(bytes.size(), 120)).get_string_from_ascii()
	var found := _regex().search(head)
	if found == null:
		return _decode_interim(bytes, head) if head.begins_with('{"format":1,') else _decode_legacy(bytes)
	if int(found.get_string(1)) > FORMAT:
		return _result(Status.NEWER, {}, false, "Format %s" % found.get_string(1))
	var body := PackedByteArray([123])   # "{"
	body.append_array(bytes.slice(found.get_end()))
	if sha256_hex(body) != found.get_string(2):
		return _result(Status.CORRUPT, {}, false, "Prüfsumme")
	if not parse:
		return _result(Status.OK)
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return _result(Status.CORRUPT, {}, false, "kein Objekt")
	return _result(Status.OK, parsed)


## Die Datei, wie sie geschrieben wird (siehe Kopf).
static func encode(data: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(data, "\t").to_utf8_buffer()
	var out := ('{"_save":{"format":%d,"sha256":"%s"}' % [FORMAT, sha256_hex(body)]).to_utf8_buffer()
	if not data.is_empty():
		out.append_array(",".to_utf8_buffer())
	out.append_array(body.slice(1))
	return out


## Schreibt `data` sicher nach `path`: stage + promote.
static func write(path: String, data: Dictionary) -> Error:
	var err := stage(path, encode(data))
	if err != OK:
		return err
	return promote(path)


## Schreibt `bytes` nach `<path>.tmp` und liest sie zur Probe zurück. Die eigentliche Datei
## bleibt unberührt. Bei einem Fehler ist die `.tmp` wieder weg.
static func stage(path: String, bytes: PackedByteArray) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveStore: '%s' nicht schreibbar (%d)" % [tmp, FileAccess.get_open_error()])
		return ERR_CANT_CREATE
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(tmp) != bytes:
		push_warning("SaveStore: '%s' kam nicht vollständig an" % tmp)
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	return OK


## Ersetzt `path` durch `<path>.tmp`. Ein Virenscanner oder Indexer kann die Datei kurz
## halten; deshalb drei Versuche.
static func promote(path: String) -> Error:
	var tmp := path + TMP_SUFFIX
	var err := ERR_FILE_CANT_WRITE
	for attempt in 3:
		err = DirAccess.rename_absolute(tmp, path)
		if err == OK:
			return OK
		OS.delay_msec(50)
	push_warning("SaveStore: '%s' nicht ersetzt (%d)" % [path, err])
	return err


## Liegt eine `.tmp` neben `path`, die vollständig ist? Dann ist ein Schreiben zwischen
## „Ziel gelöscht" und „umbenannt" abgebrochen (Windows) oder vor dem Umbenennen.
static func pending_tmp(path: String) -> bool:
	var tmp := path + TMP_SUFFIX
	return FileAccess.file_exists(tmp) and int(read(tmp)["status"]) == Status.OK


## Liest eine settings.cfg: { status, text, legacy }. `text` ist der ConfigFile-Text ohne
## die Prüfzeile.
static func read_cfg(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": Status.MISSING, "text": "", "legacy": false}
	return decode_cfg(FileAccess.get_file_as_bytes(path))


static func decode_cfg(bytes: PackedByteArray) -> Dictionary:
	var corrupt := {"status": Status.CORRUPT, "text": "", "legacy": false}
	if bytes.is_empty() or bytes.has(0):
		return corrupt
	var text := bytes.get_string_from_utf8()
	if text.begins_with(CFG_HASH_PREFIX):
		var newline := text.find("\n")
		if newline < 0:
			return corrupt
		var expected := text.substr(CFG_HASH_PREFIX.length(), newline - CFG_HASH_PREFIX.length()).strip_edges()
		var body := text.substr(newline + 1)
		if sha256_hex(body.to_utf8_buffer()) != expected:
			return corrupt
		return {"status": Status.OK, "text": body, "legacy": false}
	var probe := ConfigFile.new()
	if probe.parse(text) != OK:
		return corrupt
	return {"status": Status.OK, "text": text, "legacy": true}


## Schreibt eine settings.cfg sicher, mit Prüfzeile vorn.
static func write_cfg(path: String, text: String) -> Error:
	var out := (CFG_HASH_PREFIX + sha256_hex(text.to_utf8_buffer()) + "\n" + text).to_utf8_buffer()
	var err := stage(path, out)
	if err != OK:
		return err
	return promote(path)


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Schiebt `path` nach `into_dir` (gleicher Name plus `suffix`) — gelöscht wird nie.
static func quarantine(path: String, into_dir: String, suffix := "") -> Error:
	if not FileAccess.file_exists(path):
		return OK
	DirAccess.make_dir_recursive_absolute(into_dir)
	return DirAccess.rename_absolute(path, into_dir.path_join(path.get_file() + suffix))


static func status_name(status: int) -> String:
	return ["OK", "MISSING", "CORRUPT", "NEWER"][status]


static func _decode_legacy(bytes: PackedByteArray) -> Dictionary:
	if bytes.has(0):
		return _result(Status.CORRUPT, {}, false, "NUL-Bytes")
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _result(Status.CORRUPT, {}, false, "kein JSON")
	return _result(Status.OK, parsed, true)


static func _decode_interim(bytes: PackedByteArray, head: String) -> Dictionary:
	if _interim_regex == null:
		_interim_regex = RegEx.create_from_string(_INTERIM_PATTERN)
	var found := _interim_regex.search(head)
	var end := bytes.size()
	while end > 0 and bytes[end - 1] in [9, 10, 13, 32]:
		end -= 1
	if found == null or end <= found.get_end() or bytes[end - 1] != 125:
		return _result(Status.CORRUPT, {}, false, "abgeschnitten")
	var body := bytes.slice(found.get_end(), end - 1)
	if sha256_hex(body) != found.get_string(1):
		return _result(Status.CORRUPT, {}, false, "Prüfsumme")
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return _result(Status.CORRUPT, {}, false, "kein Objekt")
	return _result(Status.OK, parsed, true)


static func _result(status: Status, data := {}, legacy := false, error := "") -> Dictionary:
	return {"status": status, "data": data, "legacy": legacy, "error": error}


static func _regex() -> RegEx:
	if _prefix_regex == null:
		_prefix_regex = RegEx.create_from_string(_PREFIX_PATTERN)
	return _prefix_regex
