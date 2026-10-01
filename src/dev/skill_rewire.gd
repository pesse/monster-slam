extends RefCounted
## Werkbank: einen Knoten an einen anderen hängen (scenes/dev/skill_tree_lab.tscn).
##
## Die Vorstufe steht in den Daten (`requires`, `tier`, `branch`, `tree` in data/skills/),
## nicht im Layout — Umhängen ist deshalb eine Änderung an den JSON-Dateien und keine
## Übersteuerung wie das Verschieben (SkillLayout). Die Regeln stehen hier, ohne Szene,
## damit sie sich prüfen lassen (tests/skill_rewire_test.gd); die Werkbank klickt nur.
##
## Was mitgeht: der Knoten und jeder, der über ihn hängt (auch über Zwischenstufen). Der
## ganze Ast rückt um so viele Stufen, dass der Knoten eine Stufe hinter seiner neuen
## Vorstufe steht, und wechselt mit ihr den Baum. So bleiben die Regeln aus
## tests/skill_data_test.gd erfüllt: Vorstufe im selben Baum und auf einer niedrigeren
## Stufe, kein Platz doppelt.

const SKILLS_DIR := "res://data/skills/"


## Hängt `id` an `parent_id`: `requires` wird genau [parent_id]. Ändert `entries` an Ort und
## Stelle. Gibt { ok, error, moved } zurück — `moved` sind die Ids, deren Stufe, Ast oder
## Baum sich geändert hat (ihre gesetzten Plätze stimmen danach nicht mehr).
static func reparent(entries: Array, id: String, parent_id: String) -> Dictionary:
	var node := SkillTree.node_by_id(entries, id)
	var parent := SkillTree.node_by_id(entries, parent_id)
	if node.is_empty() or str(node.get("kind", "")) != "skill":
		return _fail("kein Skill: " + id)
	if parent.is_empty() or str(parent.get("kind", "")) != "skill":
		return _fail("kein Skill: " + parent_id)
	if id == parent_id:
		return _fail("ein Knoten hängt nicht an sich selbst")
	if (node.get("requires", []) as Array).is_empty():
		return _fail("%s ist der Anfang seines Baums" % id)
	var branch_ids := subtree(entries, id)
	if parent_id in branch_ids:
		return _fail("%s hängt schon über %s" % [parent_id, id])
	if Array(node.get("requires", [])) == [parent_id]:
		return _fail("%s hängt schon an %s" % [id, parent_id])

	var tree := str(parent.get("tree", ""))
	# In einen anderen Baum geht ein Ast nur, wenn keiner seiner Knoten auch an etwas
	# außerhalb hängt — sonst zöge die Vorstufe quer über zwei Bäume.
	if tree != str(node.get("tree", "")):
		for each_id in branch_ids:
			if each_id == id:
				continue
			for required in SkillTree.node_by_id(entries, each_id).get("requires", []):
				if not str(required) in branch_ids:
					return _fail("%s hängt auch an %s" % [each_id, required])
	var shift := int(parent.get("tier", 1)) + 1 - int(node.get("tier", 1))
	node["requires"] = [parent_id]
	var moved: Array[String] = []
	for entry in entries:
		var each := entry as Dictionary
		if not str(each.get("id", "")) in branch_ids:
			continue
		var before := [each.get("tree"), int(each.get("tier", 1)), int(each.get("branch", 0))]
		each["tree"] = tree
		each["tier"] = int(each.get("tier", 1)) + shift
		if before != [each["tree"], int(each["tier"]), int(each.get("branch", 0))]:
			moved.append(str(each.get("id", "")))
	# Ein Knoten des Asts, der auch an etwas außerhalb hängt, muss hinter BEIDEN stehen.
	for each_id in branch_ids:
		var each := SkillTree.node_by_id(entries, each_id)
		var floor_tier := 1
		for required in each.get("requires", []):
			floor_tier = maxi(floor_tier,
					int(SkillTree.node_by_id(entries, str(required)).get("tier", 0)) + 1)
		if int(each["tier"]) < floor_tier:
			each["tier"] = floor_tier
			if not each_id in moved:
				moved.append(each_id)
	_free_places(entries, branch_ids, int(parent.get("branch", 0)), moved)
	return {"ok": true, "error": "", "moved": moved}


## `id` und alles, was über ihn hängt, auch über Zwischenstufen.
static func subtree(entries: Array, id: String) -> Array[String]:
	var out: Array[String] = [id]
	var grew := true
	while grew:
		grew = false
		for entry in entries:
			var each := entry as Dictionary
			var each_id := str(each.get("id", ""))
			if each_id in out:
				continue
			for required in each.get("requires", []):
				if str(required) in out:
					out.append(each_id)
					grew = true
					break
	return out


## Ein Ast-Knoten, der nach dem Rücken auf dem Platz (Baum, Stufe, Ast) eines anderen
## steht, bekommt einen freien: den Ast seiner neuen Vorstufe, wenn der frei ist, sonst
## den nächsten freien dahinter.
static func _free_places(entries: Array, branch_ids: Array[String], parent_branch: int,
		moved: Array[String]) -> void:
	var taken := {}
	for entry in entries:
		var each := entry as Dictionary
		if str(each.get("kind", "")) == "skill" and not str(each.get("id", "")) in branch_ids:
			taken[_place(each, int(each.get("branch", 0)))] = true
	for each_id in branch_ids:
		var each := SkillTree.node_by_id(entries, each_id)
		var branch := int(each.get("branch", 0))
		if taken.has(_place(each, branch)):
			branch = parent_branch
			while taken.has(_place(each, branch)):
				branch += 1
			each["branch"] = branch
			if not each_id in moved:
				moved.append(each_id)
		taken[_place(each, branch)] = true


static func _place(node: Dictionary, branch: int) -> String:
	return "%s/%d/%d" % [node.get("tree", ""), int(node.get("tier", 1)), branch]


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "moved": []}


# --- Dateien ----------------------------------------------------------------------

## Die Skill-Dateien, wie sie im Repo liegen: Pfad -> Array der Einträge. Bewusst nicht die
## Registry — die trägt, was an Packs installiert ist, und geschrieben wird ins Repo.
static func load_files(dir: String = SKILLS_DIR) -> Dictionary:
	var out := {}
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for file: String in names:
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + file))
		if parsed is Array:
			out[dir + file] = _whole_numbers(parsed)
	return out


## Alle Einträge aller Dateien in einer Liste — dieselben Dictionaries, eine Änderung
## daran ist eine Änderung an der Datei.
static func all_entries(files: Dictionary) -> Array:
	var out: Array = []
	for path in files:
		out.append_array(files[path])
	return out


## Der Text einer Datei im Format des Repos: Tabs, Schlüssel in ihrer Reihenfolge,
## Zeilenende am Schluss.
static func to_text(entries: Array) -> String:
	return JSON.stringify(entries, "\t", false) + "\n"


## Schreibt jede Datei, deren Text sich geändert hat. Gibt die geschriebenen Pfade zurück,
## oder bei einem Fehler { error }.
static func save_files(files: Dictionary) -> Dictionary:
	var written: Array[String] = []
	for path: String in files:
		var text := to_text(files[path])
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text:
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return {"error": "%s: %s" % [path, error_string(FileAccess.get_open_error())]}
		file.store_string(text)
		file.close()
		written.append(path)
	return {"written": written}


## JSON kennt nur Zahlen; Godot liest jede als float. Ganze Zahlen werden wieder int,
## sonst schriebe das Speichern „"cost": 1.0".
static func _whole_numbers(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1e15:
		return int(value)
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_whole_numbers(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _whole_numbers(value[key])
		return out
	return value
