class_name PackInstaller
extends RefCounted
## Auspacken eines Content-Packs nach user://content/<pack-id>/ und der Zustand darüber.
##
## Ohne Netz und ohne SceneTree benutzbar, damit die Regeln prüfbar sind, die hier
## eigentlich zählen (siehe tests/pack_installer_test.gd):
##
## 1. Ein Pack schreibt AUSSCHLIESSLICH unter user://content/<pack-id>/ und dort nur in die
##    Kategorieverzeichnisse. user://progress und user://settings.cfg sind unerreichbar.
## 2. Eine lokal veränderte Datei wird nicht überschrieben, sondern übersprungen.
## 3. Eine Datei, die der neue Stand nicht mehr enthält, wird entfernt — aber nur, wenn wir
##    sie installiert haben und sie seither unverändert ist.

const CONTENT_ROOT := "user://content"
## Der Punkt-Präfix hält das Verzeichnis aus dem Katalog-Scan der ContentRegistry heraus.
const STATE_DIR := "user://content/.state"

## Verzeichnisse, in die ein Pack schreiben darf. Muss mit `_by_category` in
## src/core/content_registry.gd und CATEGORIES in tools/packs/build_packs.py übereinstimmen.
const CATEGORIES: Array[String] = [
	"lexemes",
	"lexeme_forms",
	"lexeme_relations",
	"sentences",
	"sentence_lexemes",
	"task_definitions",
	"monster_task_rules",
	"monsters",
	"bosses",
	"skills",
	"waves",
]


## Ergebnis einer Installation. `error` gesetzt heißt: es wurde nichts geschrieben.
class Summary:
	var written := 0
	## Übersprungen, weil lokal bearbeitet.
	var skipped_modified := 0
	## Entfernt, weil im neuen Stand nicht mehr enthalten.
	var removed := 0
	## Vorhanden, aber nicht von uns installiert. Ist dieser Wert > 0 und wurde nicht
	## `adopt` übergeben, wurde nichts geschrieben.
	var needs_adopt := 0
	var error := ""

	func describe() -> String:
		if not error.is_empty():
			return error
		var parts := PackedStringArray(["%d Datei(en) geschrieben" % written])
		if removed > 0:
			parts.append("%d entfernt" % removed)
		if skipped_modified > 0:
			parts.append("%d lokal geändert, übersprungen" % skipped_modified)
		return ", ".join(parts)


static func pack_dir(pack_id: String) -> String:
	return "%s/%s" % [CONTENT_ROOT, pack_id]


static func state_path(pack_id: String) -> String:
	return "%s/%s.json" % [STATE_DIR, pack_id]


## Lokaler Zustand eines Packs, oder {} wenn er nicht installiert ist.
static func read_state(pack_id: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(state_path(pack_id))
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Alle installierten Packs: id -> Zustand. Ohne Netzzugriff.
static func installed() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(STATE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var pack_id := file.trim_suffix(".json")
		var state := read_state(pack_id)
		if not state.is_empty():
			out[pack_id] = state
	return out


## True, wenn ein Pfad aus dem Pack geschrieben werden darf.
##
## Zweite Sicherung neben dem Pack-Build: erlaubt sind nur die Kategorieverzeichnisse, und
## kein Segment darf aus dem Zielverzeichnis herausführen (Zip-Slip).
static func is_allowed_entry(name: String) -> bool:
	if name.is_empty() or name.begins_with("/") or name.contains("\\") or name.contains(":"):
		return false
	var segments := name.split("/")
	if segments.size() < 2:
		return false
	if segments[0] not in CATEGORIES:
		return false
	for segment in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return not segments[segments.size() - 1].is_empty()


## Packt ein ZIP aus und schreibt den Zustand fort.
##
## `entry` ist der Index-Eintrag (für Version und minVersion im Zustand), `adopt` erlaubt
## das Übernehmen bereits vorhandener, nicht von uns installierter Dateien.
static func install_zip(pack_id: String, zip_path: String, entry: Dictionary, adopt: bool) -> Summary:
	var summary := Summary.new()
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		summary.error = "Pack ist kein gültiges ZIP."
		return summary

	var previous := read_state(pack_id)
	var known := {}
	for file in previous.get("files", []):
		known[str(file.get("path", ""))] = str(file.get("sha256", ""))

	var target_dir := pack_dir(pack_id)
	# (Pfad, Inhalt, sha256) — erst vollständig planen, dann schreiben.
	var planned: Array = []

	for name in reader.get_files():
		var rel := str(name)
		if rel.ends_with("/"):
			continue
		if not is_allowed_entry(rel):
			# Ein Pack, der außerhalb der Kategorieverzeichnisse schreiben will, ist
			# fehlerhaft gebaut oder manipuliert. Nichts davon wird teilweise eingespielt.
			reader.close()
			summary.error = "Pack enthält einen unzulässigen Pfad (%s) — abgebrochen." % rel
			return summary

		var data := reader.read_file(rel)
		var hash := Digest.of_bytes(data)
		var target := "%s/%s" % [target_dir, rel]

		if FileAccess.file_exists(target):
			if known.has(rel):
				# Von uns installiert: nur überschreiben, wenn unverändert.
				if not Digest.equal(Digest.of_file(target), known[rel]):
					summary.skipped_modified += 1
					continue
			else:
				# Vorhanden, aber nicht von uns — etwa nach einem verlorenen Zustand.
				summary.needs_adopt += 1
				if not adopt:
					continue
		planned.append([rel, data, hash])
	reader.close()

	# Ohne Zustimmung nichts anfassen, wenn Fremddateien betroffen wären.
	if summary.needs_adopt > 0 and not adopt:
		return summary

	var files: Array = []
	for item in planned:
		var rel: String = item[0]
		var target := "%s/%s" % [target_dir, rel]
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			summary.error = "Verzeichnis nicht anlegbar: %s" % target.get_base_dir()
			return summary
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			summary.error = "%s nicht schreibbar." % rel
			return summary
		file.store_buffer(item[1])
		file.close()
		files.append({"path": rel, "sha256": item[2]})
		summary.written += 1

	summary.removed = _remove_retracted(target_dir, previous, files)
	_write_state(pack_id, entry, files)
	return summary


## Entfernt Dateien, die der neue Stand nicht mehr enthält — nur unsere und nur unveränderte.
static func _remove_retracted(target_dir: String, previous: Dictionary, files: Array) -> int:
	if previous.is_empty():
		return 0
	var still_here := {}
	for file in files:
		still_here[str(file["path"])] = true
	var removed := 0
	for old in previous.get("files", []):
		var rel := str(old.get("path", ""))
		if still_here.has(rel) or not is_allowed_entry(rel):
			continue
		var target := "%s/%s" % [target_dir, rel]
		if not FileAccess.file_exists(target):
			continue
		if Digest.equal(Digest.of_file(target), str(old.get("sha256", ""))):
			if DirAccess.remove_absolute(target) == OK:
				removed += 1
	return removed


static func _write_state(pack_id: String, entry: Dictionary, files: Array) -> void:
	DirAccess.make_dir_recursive_absolute(STATE_DIR)
	var state := {
		"version": str(entry.get("version", "")),
		"keyVersion": int(entry.get("keyVersion", 1)),
		# Die Inhalts-Generation: gegen die minVersion des Index misst sich später, ob der
		# installierte Stand eine App-Fassung zurückliegt.
		"minVersion": str(entry.get("minVersion", "")),
		"installedAt": int(Time.get_unix_time_from_system()),
		"files": files,
	}
	var file := FileAccess.open(state_path(pack_id), FileAccess.WRITE)
	if file == null:
		push_warning("PackInstaller: Zustand für '%s' nicht schreibbar." % pack_id)
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()


## Entfernt einen Pack vollständig: alle von uns installierten, unveränderten Dateien und
## den Zustand. Lokal Verändertes bleibt liegen — es wäre sonst unwiederbringlich weg.
static func uninstall(pack_id: String) -> Summary:
	var summary := Summary.new()
	var previous := read_state(pack_id)
	if previous.is_empty():
		summary.error = "Nicht installiert."
		return summary
	summary.removed = _remove_retracted(pack_dir(pack_id), previous, [])
	summary.skipped_modified = int(previous.get("files", []).size()) - summary.removed
	DirAccess.remove_absolute(state_path(pack_id))
	_prune_empty_dirs(pack_dir(pack_id))
	return summary


## Räumt leere Verzeichnisse eines entfernten Packs weg. Ein Verzeichnis, in dem noch etwas
## liegt (lokal Verändertes), bleibt stehen — `remove_absolute` scheitert dann stillschweigend,
## und genau das ist gewollt.
static func _prune_empty_dirs(pack_path: String) -> void:
	for category in CATEGORIES:
		DirAccess.remove_absolute("%s/%s" % [pack_path, category])
	DirAccess.remove_absolute(pack_path)
