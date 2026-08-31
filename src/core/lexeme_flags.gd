class_name LexemeFlags
extends RefCounted
## Nutzer-Meldungen ("das Wort ist falsch") — gespeichert in `user://`, nicht im Content.
##
## Früher schrieb `ContentRegistry.flag_lexeme()` das Feld `flag` in die Quell-JSON zurück.
## Das funktioniert nur im Editor: in einer exportierten EXE ist `res://` read-only, und ein
## Eintrag aus einem installierten Pack würde beim nächsten Pack-Update entweder überschrieben
## oder — weil der Installer lokal geänderte Dateien überspringt — das Update blockieren.
## Meldungen sind Spielerdaten, gehören also neben den Fortschritt nach `user://`.

const PATH := "user://lexeme_flags.json"


## lexeme_id -> {comment, learnable_id, at}. Leer, wenn es noch keine Meldungen gibt
## oder die Datei unlesbar ist (eine kaputte Meldungsliste darf das Spiel nicht aufhalten).
static func load_all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("LexemeFlags: '%s' nicht lesbar — Meldungen werden ignoriert." % PATH)
		return {}
	var result: Dictionary = {}
	for key in parsed:
		if parsed[key] is Dictionary:
			result[String(key)] = parsed[key]
	return result


static func save_all(flags: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("LexemeFlags: '%s' nicht schreibbar (%d)" % [PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(flags, "\t"))
	file.close()
	return true


static func entry(comment: String, learnable_id: String) -> Dictionary:
	return {
		"comment": comment,
		"learnable_id": learnable_id,
		"at": Time.get_datetime_string_from_system(),
	}
