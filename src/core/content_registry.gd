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

## category name -> { id: Dictionary }
var _catalog: Dictionary = {}

## Convenience accessors (populated in _ready).
var vocabulary: Dictionary : get: return _catalog.get("vocabulary", {})
var monsters: Dictionary : get: return _catalog.get("monsters", {})
var bosses: Dictionary : get: return _catalog.get("bosses", {})
var skills: Dictionary : get: return _catalog.get("skills", {})
var waves: Dictionary : get: return _catalog.get("waves", {})


func _ready() -> void:
	reload()


## Rescans the whole data tree. Safe to call at runtime (e.g. after adding files).
func reload() -> void:
	_catalog.clear()
	for category in ["vocabulary", "monsters", "bosses", "skills", "waves"]:
		var target: Dictionary = {}
		_scan_dir("%s/%s" % [DATA_ROOT, category], target, category)
		_catalog[category] = target


## Returns all entries of a category as an Array of Dictionaries.
func all(category: String) -> Array:
	return _catalog.get(category, {}).values()


## Returns a single entry by id, or {} if not found.
func get_entry(category: String, id: String) -> Dictionary:
	return _catalog.get(category, {}).get(id, {})


## Returns vocabulary entries whose "tags" intersect the requested tags.
func vocabulary_by_tags(tags: Array) -> Array:
	var result: Array = []
	for entry in vocabulary.values():
		for tag in entry.get("tags", []):
			if tag in tags:
				result.append(entry)
				break
	return result


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
