class_name SaveArchive
extends RefCounted
## Ein Spielstand als Datei zum Mitnehmen (ADR 0024): „Sichern…“ schreibt die neueste
## Sicherung eines Profils als Zip, „Laden…“ spielt so eine Datei ins aktive Profil ein.
##
## Für den Fall, dass alles andere weg ist — ein neuer Rechner, ein gelöschter Ordner. Die
## Sicherungen unter user://backups liegen auf derselben Platte wie der Spielstand.
##
##     monster-slam.json            Kopf: Format, Version, Name, Zeitpunkt, Prüfsummen
##     spielstand<endung>.json      die Dateien der Sicherung, Bytes unverändert
##
## Gelesen wird misstrauisch: nur bekannte Einträge, eine Größengrenze, jede Datei gegen
## ihre Prüfsumme im Kopf und gegen ihre eigene Hülle. Eine neuere Fassung wird abgelehnt.

const FORMAT := 1
const HEAD := "monster-slam.json"
const ENTRY_PREFIX := "spielstand"
## Ein Spielstand nach Jahren liegt bei wenigen MB; was weit darüber liegt, ist keiner.
const MAX_BYTES := 64 * 1024 * 1024


## Vorschlag für den Dateinamen: `MonsterSlam-Anna-2026-10-10.zip`.
static func suggested_name(display_name: String, at_unix: int) -> String:
	var safe := RegEx.create_from_string("[^\\p{L}\\p{N}_-]+").sub(display_name.strip_edges(), "-", true)
	safe = safe.trim_prefix("-").trim_suffix("-")
	var day := Time.get_date_string_from_unix_time(at_unix)
	return "MonsterSlam-%s-%s.zip" % [safe if not safe.is_empty() else "Spielstand", day]


static func entry_name(suffix: String) -> String:
	return "%s%s.json" % [ENTRY_PREFIX, suffix]


## Schreibt die Generation `generation` (Manifest aus `Backups.verify`) nach `path`.
static func write(path: String, generation: Dictionary, display_name: String) -> Error:
	var dir := str(generation.get("dir", ""))
	var profile := str(generation.get("profile", ""))
	var entries := {}
	var sums := {}
	for name: String in generation.get("files", {}):
		var entry: Dictionary = generation["files"][name]
		if bool(entry.get("settings", false)):
			continue   # gilt allen Profilen dieses Rechners, nicht diesem Spielstand
		var suffix := str(entry.get("suffix", ""))
		if suffix not in SaveCoordinator.PROFILE_SUFFIXES or name != Backups.file_name(profile, suffix):
			continue
		var bytes := FileAccess.get_file_as_bytes(dir.path_join(name))
		entries[entry_name(suffix)] = bytes
		sums[suffix] = SaveStore.sha256_hex(bytes)
	if entries.is_empty():
		return ERR_FILE_NOT_FOUND
	var head := {
		"format": FORMAT, "name": display_name,
		"saved_at": int(generation.get("created_at", 0)),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"files": sums,
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var zip := ZIPPacker.new()
	var err := zip.open(path)
	if err != OK:
		return err
	entries[HEAD] = JSON.stringify(head, "\t").to_utf8_buffer()
	for name: String in entries:
		err = zip.start_file(name)
		if err == OK:
			err = zip.write_file(entries[name])
		zip.close_file()
		if err != OK:
			break
	zip.close()
	return err


## Liest ein Archiv: {"error": String, "data": {suffix: Dictionary}, "head": Dictionary}.
## `error` ist ein Satz für den Spieler, leer wenn alles stimmt.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("Die Datei gibt es nicht.")
	var size := FileAccess.open(path, FileAccess.READ).get_length()
	if size > MAX_BYTES:
		return _fail("Die Datei ist zu groß für einen Spielstand.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return _fail("Die Datei ist kein gesicherter Spielstand.")
	var names := zip.get_files()
	if not HEAD in names:
		zip.close()
		return _fail("Die Datei ist kein gesicherter Spielstand.")
	var parsed: Variant = JSON.parse_string(zip.read_file(HEAD).get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).get("files") is Dictionary:
		zip.close()
		return _fail("Die Datei ist beschädigt.")
	var head: Dictionary = parsed
	if int(head.get("format", 0)) > FORMAT:
		zip.close()
		return _fail("Der Spielstand stammt aus einer neueren Fassung des Spiels. Erst aktualisieren.")
	var data := {}
	var total := 0
	for suffix: String in SaveCoordinator.PROFILE_SUFFIXES:
		var name := entry_name(suffix)
		if not name in names:
			continue
		var bytes := zip.read_file(name)
		total += bytes.size()
		if total > MAX_BYTES:
			zip.close()
			return _fail("Die Datei ist zu groß für einen Spielstand.")
		if SaveStore.sha256_hex(bytes) != str(head["files"].get(suffix, "")):
			zip.close()
			return _fail("Die Datei ist beschädigt.")
		var decoded := SaveStore.decode(bytes)
		match int(decoded["status"]):
			SaveStore.Status.OK:
				data[suffix] = decoded["data"]
			SaveStore.Status.NEWER:
				zip.close()
				return _fail("Der Spielstand stammt aus einer neueren Fassung des Spiels. Erst aktualisieren.")
			_:
				zip.close()
				return _fail("Die Datei ist beschädigt.")
	zip.close()
	# Jede Datei, die der Kopf nennt, muss auch da sein — sonst fehlte still ein Teil.
	for suffix: String in head["files"]:
		if not data.has(suffix):
			return _fail("Die Datei ist unvollständig.")
	if data.is_empty():
		return _fail("In der Datei ist kein Spielstand.")
	return {"error": "", "data": data, "head": head}


## Die Dateien fürs Einspielen (`SaveCoordinator.import_files`): als Profil `profile`.
static func files_for(data: Dictionary, profile: String) -> Dictionary:
	var out := {}
	for suffix: String in data:
		var content: Dictionary = (data[suffix] as Dictionary).duplicate(true)
		if content.has("player_id"):
			content["player_id"] = profile
		out[suffix] = SaveStore.encode(content)
	return out


## Was die Rückfrage vor dem Einspielen zeigt: Name, Level, Gold, Zeitpunkt und welche
## Teile die Datei hat (ein Teil-Archiv ersetzt nur diese).
static func preview(archive: Dictionary) -> Dictionary:
	var data: Dictionary = archive.get("data", {})
	var head: Dictionary = archive.get("head", {})
	var xp := int((data.get("_level", {}) as Dictionary).get("total_xp", 0))
	return {
		"name": str(head.get("name", "")),
		"level": Experience.level_for(xp),
		"gold": int((data.get("_wallet", {}) as Dictionary).get("gold", 0)),
		"saved_at": int(head.get("saved_at", 0)),
		"parts": data.keys(),
	}


static func _fail(message: String) -> Dictionary:
	return {"error": message, "data": {}, "head": {}}
