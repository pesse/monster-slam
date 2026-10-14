class_name TestLists
extends RefCounted
## Die Testlisten eines Profils: Wörter eines Buchs, die ein Kind gezielt für eine Arbeit übt.
##     { id, name, book, lexeme_ids, form_bonuses, direction, round_started_at, created_at }
## `form_bonuses` sind Scope-Schlüssel von Form-Boni (ADR 0012). `direction`: "" alle,
## "from_de" Deutsch gefragt, "to_de" Fremdsprache gefragt. `round_started_at` ist der
## Beginn der laufenden Runde (TestPlaylist).
## Ablage: user://progress/<profil>_test_lists.json, statisch mit Profil-Argument.

const SAVE_DIR := "user://progress"

const DIRECTION_ALL := ""
const DIRECTION_FROM_DE := "from_de"
const DIRECTION_TO_DE := "to_de"


static func path(profile: String) -> String:
	return "%s/%s_test_lists.json" % [SAVE_DIR, profile]


## Alle Listen des Profils, in der Reihenfolge, in der sie angelegt wurden.
static func lists(profile: String) -> Array:
	var read := SaveStore.read(path(profile))
	if int(read["status"]) != SaveStore.Status.OK:
		return []
	var all: Variant = (read["data"] as Dictionary).get("lists", [])
	return (all as Array).filter(func(l): return l is Dictionary) if all is Array else []


## Die Listen eines Buchs.
static func lists_of(book: String, profile: String) -> Array:
	return lists(profile).filter(func(l): return str(l.get("book", "")) == book)


static func find(id: String, profile: String) -> Dictionary:
	for list in lists(profile):
		if str(list.get("id", "")) == id:
			return list
	return {}


## Eine neue, leere Liste (noch nicht gespeichert).
static func blank(book: String, name := "") -> Dictionary:
	return {
		"id": "", "name": name, "book": book, "lexeme_ids": [], "form_bonuses": [],
		"direction": DIRECTION_ALL, "round_started_at": 0, "created_at": 0,
	}


## Speichert `list` (neu oder ersetzt die mit derselben id) und gibt sie mit id zurück.
static func store(list: Dictionary, profile: String) -> Dictionary:
	var out := list.duplicate(true)
	var all := lists(profile)
	if str(out.get("id", "")).is_empty():
		out["created_at"] = int(Time.get_unix_time_from_system())
		out["id"] = "t%d_%d" % [int(out["created_at"]), randi() % 10000]
		all.append(out)
	else:
		var replaced := false
		for i in all.size():
			if str(all[i].get("id", "")) == str(out["id"]):
				all[i] = out
				replaced = true
		if not replaced:
			all.append(out)
	_write(all, profile)
	return out


static func remove(id: String, profile: String) -> void:
	_write(lists(profile).filter(func(l): return str(l.get("id", "")) != id), profile)


## Nie über eine unlesbare Datei (SaveGuard).
static func _write(all: Array, profile: String) -> void:
	SaveGuard.write(path(profile), "_test_lists", {"lists": all})


## Der Curriculum-Scope eines Laufs über die Liste: je Wort sein engster Schlüssel (Teil,
## Wort-Bonus oder Unit) und die gewählten Form-Boni. Formen eines Bonus kommen nur mit,
## wenn er gewählt ist (ContentRegistry.bonus_in_scope).
static func run_scope(list: Dictionary, lexemes: Dictionary, narrowest: Callable) -> Array:
	var out: Array = []
	for id in list.get("lexeme_ids", []):
		var entry: Dictionary = lexemes.get(str(id), {})
		if entry.is_empty():
			continue
		var key := str(narrowest.call(entry))
		if not key.is_empty() and not key in out:
			out.append(key)
	for key in list.get("form_bonuses", []):
		if not str(key) in out:
			out.append(str(key))
	return out


## Die Unit, aus der die meisten Wörter der Liste stammen.
static func main_unit(list: Dictionary, lexemes: Dictionary) -> int:
	var counts := {}
	for id in list.get("lexeme_ids", []):
		var entry: Dictionary = lexemes.get(str(id), {})
		if entry.has("unit"):
			counts[int(entry["unit"])] = int(counts.get(int(entry["unit"]), 0)) + 1
	var best := 0
	var most := 0
	for unit in counts:
		if int(counts[unit]) > most:
			most = int(counts[unit])
			best = int(unit)
	return best


## Lässt der Richtungsfilter einer Liste die Richtung einer task_definition zu?
## "from_de" nimmt alles außer „<fremd>_to_de", "to_de" nur „<fremd>_to_de".
static func direction_allows(mode: String, direction: String) -> bool:
	match mode:
		DIRECTION_FROM_DE:
			return not direction.ends_with("_to_de")
		DIRECTION_TO_DE:
			return direction.ends_with("_to_de")
	return true
