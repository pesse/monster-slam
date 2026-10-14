class_name LexemeFlags
extends RefCounted
## Nutzer-Meldungen („das Wort ist falsch“), geräteweit in `user://`, nicht im Content.

const PATH := "user://lexeme_flags.json"


## lexeme_id -> {comment, learnable_id, at, sent, stats_id?}. Leer ohne Meldungen oder bei
## unlesbarer Datei.
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


## `stats_id` ist die Profilnummer zum Zeitpunkt der Meldung (ADR 0022); beim späteren
## Senden spielt womöglich ein anderes Profil.
static func entry(comment: String, learnable_id: String, stats_id := "") -> Dictionary:
	var item := {
		"comment": comment,
		"learnable_id": learnable_id,
		"at": Time.get_datetime_string_from_system(),
		"sent": false,
	}
	if not stats_id.is_empty():
		item["stats_id"] = stats_id
	return item


## Offene Meldungen, die Warteschlange des Rückkanals (ADR 0002), je Eintrag mit
## `lexeme_id`. Ohne Feld `sent` gilt ein Eintrag als offen.
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


## Hakt eine gesendete Meldung ab. False, wenn es sie nicht gibt oder die Datei nicht
## schreibbar ist; dann bleibt sie offen (den doppelten Versand erkennt der Endpunkt).
static func mark_sent(lexeme_id: String) -> bool:
	var flags := load_all()
	if not flags.has(lexeme_id):
		return false
	flags[lexeme_id]["sent"] = true
	return save_all(flags)
