extends Node
## Central, data-driven content registry (autoload).
##
## Scans res://data/<category>/ at startup and loads EVERY .json file it finds
## (recursively, so language subfolders like vocabulary/en/ work).
##
## To add new content — a monster, a skill, a vocab pack, a boss, a wave —
## drop a JSON file into the matching folder. No code changes required.
## Each JSON file may contain a single object OR an array of objects.
## Every object MUST have a unique string "id".

const DATA_ROOT := "res://data"

## Per-category catalogs (id -> entry Dictionary). Filled by reload().
##
## Sprachdaten und Aufgaben sind normalisiert (ERM, siehe docs/ARCHITECTURE.md):
## lexemes/forms/relations beschreiben die Sprache, task_definitions die Aufgaben-Regeln
## (die konkrete Aufgabe wird zur Laufzeit aus Definition × Lexeme erzeugt),
## monster_task_rules nur die Darstellung. sentences/sentence_lexemes sind für das
## (noch zurückgestellte) Satz-/Boss-Feature reserviert und vorerst leer.
var lexemes: Dictionary = {}
var lexeme_forms: Dictionary = {}
var lexeme_relations: Dictionary = {}
var sentences: Dictionary = {}
var sentence_lexemes: Dictionary = {}
var task_definitions: Dictionary = {}
var monster_task_rules: Dictionary = {}
var monsters: Dictionary = {}
var bosses: Dictionary = {}
var skills: Dictionary = {}
var waves: Dictionary = {}

## category name -> the Dictionary above (Dictionaries are references in GDScript,
## so clearing/filling these in place also updates the member vars).
var _by_category: Dictionary = {}

## "<category>|<id>" -> Quelldatei-Pfad. Wird beim Laden gefüllt, damit
## Bearbeitungen (z.B. flag_lexeme) in die richtige Quell-JSON zurückschreiben.
var _source_files: Dictionary = {}


func _ready() -> void:
	_by_category = {
		"lexemes": lexemes,
		"lexeme_forms": lexeme_forms,
		"lexeme_relations": lexeme_relations,
		"sentences": sentences,
		"sentence_lexemes": sentence_lexemes,
		"task_definitions": task_definitions,
		"monster_task_rules": monster_task_rules,
		"monsters": monsters,
		"bosses": bosses,
		"skills": skills,
		"waves": waves,
	}
	reload()


## Rescans the whole data tree. Safe to call at runtime (e.g. after adding files).
func reload() -> void:
	_source_files.clear()
	for category in _by_category:
		var target: Dictionary = _by_category[category]
		target.clear()
		_scan_dir("%s/%s" % [DATA_ROOT, category], target, category)


## Returns all entries of a category as an Array of Dictionaries.
func all(category: String) -> Array:
	return _by_category.get(category, {}).values()


## Returns a single entry by id, or {} if not found.
func get_entry(category: String, id: String) -> Dictionary:
	return _by_category.get(category, {}).get(id, {})


## Returns lexeme entries whose "tags" intersect the requested tags.
## Leere `tags` -> alle Lexeme (kein Filter).
func lexemes_by_tags(tags: Array) -> Array:
	if tags.is_empty():
		return lexemes.values()
	var result: Array = []
	for entry in lexemes.values():
		for tag in entry.get("tags", []):
			if tag in tags:
				result.append(entry)
				break
	return result


## Alle Formen eines Lexems; optional auf einen form_type gefiltert.
func forms_for(lexeme_id: String, form_type: String = "") -> Array:
	var result: Array = []
	for entry in lexeme_forms.values():
		if entry.get("lexeme_id", "") != lexeme_id:
			continue
		if form_type != "" and entry.get("form_type", "") != form_type:
			continue
		result.append(entry)
	return result


## Relationen, die von `lexeme_id` ausgehen und den gewünschten Typ haben
## (opposite | synonym | confused_with | related).
func relations_of(lexeme_id: String, relation_type: String) -> Array:
	var result: Array = []
	for entry in lexeme_relations.values():
		if entry.get("from_lexeme_id", "") == lexeme_id \
				and entry.get("relation_type", "") == relation_type:
			result.append(entry)
	return result


## Findet die monster_task_rule für (task_type, direction), oder {} wenn keine passt.
func monster_rule_for(task_type: String, direction: String) -> Dictionary:
	for entry in monster_task_rules.values():
		if entry.get("task_type", "") == task_type \
				and entry.get("direction", "") == direction:
			return entry
	return {}


## Quelldatei-Pfad, aus dem der Eintrag geladen wurde, oder "" wenn unbekannt.
func source_file(category: String, id: String) -> String:
	return _source_files.get("%s|%s" % [category, id], "")


## Lexeme, die eine Nutzer-Meldung tragen (Feld "flag"), für die Menü-Anzeige.
func flagged_lexemes() -> Array:
	var result: Array = []
	for entry in lexemes.values():
		if entry.has("flag"):
			result.append(entry)
	return result


## Schreibt eine Meldung ("flag") in die Quell-JSON des Lexems zurück und
## aktualisiert die In-Memory-Kopie. Gibt false zurück, wenn das Lexem, seine
## Quelldatei oder der Eintrag darin nicht gefunden/geschrieben werden kann.
## Hinweis: res:// ist nur im Editor/Dev-Run schreibbar (Authoring-Workflow).
func flag_lexeme(lexeme_id: String, comment: String, learnable_id: String) -> bool:
	if not lexemes.has(lexeme_id):
		push_warning("ContentRegistry: flag für unbekanntes Lexem '%s'" % lexeme_id)
		return false
	var file_path := source_file("lexemes", lexeme_id)
	if file_path.is_empty():
		push_warning("ContentRegistry: keine Quelldatei für Lexem '%s'" % lexeme_id)
		return false
	var text := FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("ContentRegistry: '%s' nicht lesbar/parsebar" % file_path)
		return false
	var flag := {
		"comment": comment,
		"learnable_id": learnable_id,
		"at": Time.get_datetime_string_from_system(),
	}
	# Datei kann ein einzelnes Objekt ODER ein Array von Objekten enthalten.
	var entries: Array = parsed if parsed is Array else [parsed]
	var found := false
	for entry in entries:
		if entry is Dictionary and str(entry.get("id", "")) == lexeme_id:
			entry["flag"] = flag
			found = true
			break
	if not found:
		push_warning("ContentRegistry: Lexem '%s' nicht in '%s'" % [lexeme_id, file_path])
		return false
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("ContentRegistry: '%s' nicht schreibbar (Export?)" % file_path)
		return false
	file.store_string(JSON.stringify(parsed, "\t"))
	file.close()
	# In-Memory-Kopie mitziehen, damit flagged_lexemes() ohne reload() stimmt.
	lexemes[lexeme_id]["flag"] = flag
	return true


func _scan_dir(path: String, target: Dictionary, category: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ContentRegistry: missing data folder '%s'" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := "%s/%s" % [path, file_name]
		if dir.current_is_dir():
			_scan_dir(full_path, target, category)
		elif file_name.ends_with(".json"):
			_load_file(full_path, target, category)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_file(file_path: String, target: Dictionary, category: String) -> void:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		push_warning("ContentRegistry: empty or unreadable '%s'" % file_path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("ContentRegistry: invalid JSON in '%s'" % file_path)
		return
	if parsed is Array:
		for entry in parsed:
			_register(entry, target, category, file_path)
	elif parsed is Dictionary:
		_register(parsed, target, category, file_path)
	else:
		push_error("ContentRegistry: '%s' must contain an object or array" % file_path)


func _register(entry: Variant, target: Dictionary, category: String, file_path: String) -> void:
	if not (entry is Dictionary) or not entry.has("id"):
		push_error("ContentRegistry: entry without 'id' in '%s'" % file_path)
		return
	var id: String = str(entry["id"])
	if target.has(id):
		push_warning("ContentRegistry: duplicate %s id '%s' (from %s)" % [category, id, file_path])
	target[id] = entry
	_source_files["%s|%s" % [category, id]] = file_path
