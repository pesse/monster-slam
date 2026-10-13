class_name SkillLayout
extends RefCounted
## Von Hand gesetzte Plätze im Fähigkeiten-Netz: Id -> Position in den Koordinaten von
## `SkillTree.layout()` (Ursprung in der Mitte, schon gestreckt). Fehlende Ids rechnet das
## Layout. Gesetzt in scenes/dev/skill_tree_lab.tscn; speichern geht nur im Editor-Lauf.

const PATH := "res://assets/ui/skill_tree/layout.json"


## Die gesetzten Plätze; leer, wenn es die Datei nicht gibt oder sie kaputt ist.
static func overrides(path: String = PATH) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("SkillLayout: %s ist kein Objekt" % path)
		return out
	for id: String in parsed:
		var pair: Variant = (parsed as Dictionary)[id]
		if pair is Array and (pair as Array).size() == 2:
			out[id] = Vector2(float(pair[0]), float(pair[1]))
	return out


## Schreibt die Plätze nach Id sortiert und auf ganze Punkte gerundet, eine Zeile je Knoten.
static func save(places: Dictionary, path: String = PATH) -> Error:
	var ids: Array = places.keys()
	ids.sort()
	var lines: PackedStringArray = []
	for id: String in ids:
		var at: Vector2 = places[id]
		lines.append('  %s: [%d, %d]' % [JSON.stringify(id), roundi(at.x), roundi(at.y)])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("{\n" + ",\n".join(lines) + ("\n" if not lines.is_empty() else "") + "}\n")
	file.close()
	return OK
