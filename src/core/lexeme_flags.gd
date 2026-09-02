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


## lexeme_id -> {comment, learnable_id, at, sent}. Leer, wenn es noch keine Meldungen gibt
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
		"sent": false,
	}


## Meldungen, die noch nicht beim Content-Autor angekommen sind — die Warteschlange des
## Rückkanals (siehe docs/adr/0002-melde-rueckkanal.md). Je Eintrag zusätzlich `lexeme_id`.
##
## Ein Eintrag ohne Feld `sent` gilt als offen: Meldungen aus einer Fassung vor dem
## Rückkanal sollen mitgehen, nicht stillschweigend verfallen.
static func pending() -> Array:
	var result: Array = []
	var flags := load_all()
	for lexeme_id in flags:
		if bool(flags[lexeme_id].get("sent", false)):
			continue
		var item: Dictionary = (flags[lexeme_id] as Dictionary).duplicate()
		item["lexeme_id"] = String(lexeme_id)
		result.append(item)
	return result


## Hakt eine gesendete Meldung ab. false, wenn es sie nicht (mehr) gibt oder die Datei
## nicht schreibbar ist — dann bleibt sie offen und geht beim nächsten Versuch mit.
## Ein doppelter Versand ist der harmlosere Fehler: der Endpunkt erkennt ihn.
static func mark_sent(lexeme_id: String) -> bool:
	var flags := load_all()
	if not flags.has(lexeme_id):
		return false
	flags[lexeme_id]["sent"] = true
	return save_all(flags)
