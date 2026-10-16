class_name RunSave
extends RefCounted
## Begonnene Läufe von der Karte, ein Platz je Unit (ADR 0020 mit Nachträgen). Ein Stand
## trägt nur Ursprungswerte; fest sitzt der Bereich (`keys`), nicht der Inhalt.
## Boni sind Beiwerk: sie stehen nie im Stand, ein Lauf nur aus Boni wird nicht gespeichert
## und lässt den begonnenen liegen.
## Ablage: user://progress/<profil>_runs.json als { "runs": { <book>/<unit>: <stand> } }.
## Statisch mit Profil-Argument, damit Tests auf einem `zz-`-Profil laufen.

const SAVE_DIR := "user://progress"
## Hebt sich, wenn ein Stand eines älteren Formats nicht mehr gelesen werden kann.
const FORMAT := 1


static func path(profile: String) -> String:
	return "%s/%s_runs.json" % [SAVE_DIR, profile]


## Alle begonnenen Läufe des Profils: "<book>/<unit>" -> Stand.
static func all(profile: String) -> Dictionary:
	var read := SaveStore.read(path(profile))
	if int(read["status"]) == SaveStore.Status.CORRUPT:
		# Ein begonnener Lauf hat keine Sicherung; die kaputte Datei geht in die Quarantäne,
		# damit wieder gerastet werden kann.
		push_warning("RunSave: %s unlesbar, in die Quarantäne" % path(profile))
		SaveStore.quarantine(path(profile), "user://quarantine/%s/runs-%d"
				% [profile, int(Time.get_unix_time_from_system())], ".corrupt")
	if int(read["status"]) != SaveStore.Status.OK:
		return {}
	var runs: Variant = (read["data"] as Dictionary).get("runs", {})
	if not runs is Dictionary:
		return {}
	var out := {}
	for key in runs:
		var state: Variant = runs[key]
		if not state is Dictionary:
			continue
		# Ältere Dateien schlüsseln nach Buch; der Stand kennt seine Unit selbst.
		var unit_key := str(key) if "/" in str(key) else key_of(state)
		if not unit_key.is_empty():
			out[unit_key] = state
	return out


## Der Platz eines Stands: "<book>/<unit>" wie RunRequest.unit_key(), oder "" ohne Buch.
static func key_of(state: Dictionary) -> String:
	var level: Dictionary = state.get("level", {})
	var book := str(level.get("book", ""))
	if book.is_empty():
		return ""
	return "%s/%d" % [book, int(level.get("unit", 0))]


static func of_unit(book: String, unit: int, profile: String) -> Dictionary:
	return all(profile).get("%s/%d" % [book, unit], {})


## Die begonnenen Läufe eines Buchs, der zuletzt gerastete zuerst.
static func of_book(book: String, profile: String) -> Array:
	var out: Array = []
	var runs := all(profile)
	for key in runs:
		if str(key).get_slice("/", 0) == book:
			out.append(runs[key])
	out.sort_custom(func(a, b): return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0)))
	return out


## Legt `state` auf den Platz seiner Unit (`key_of`) und ersetzt, was dort lag.
static func store(state: Dictionary, profile: String) -> void:
	var key := key_of(state)
	if key.is_empty():
		return
	var runs := all(profile)
	runs[key] = state
	_write(runs, profile)


static func discard(book: String, unit: int, profile: String) -> void:
	var runs := all(profile)
	var key := "%s/%d" % [book, unit]
	if not runs.has(key):
		return
	runs.erase(key)
	_write(runs, profile)


## Baut den Stand. Von `level` (RunRequest.level()) bleiben nur Buch, Unit und Orte.
## `next_wave` ist die Welle, mit der es weitergeht. Mitten in der Welle gerastet trägt
## `wave` deren bisherigen Stand, an der Wellengrenze bleibt es leer.
static func build(level: Dictionary, next_wave: int, difficulty: int, run: Dictionary,
		run_started_at: int, now: int, wave := {}) -> Dictionary:
	var state := {
		"format": FORMAT,
		"app_version": SemVer.app_version(),
		"level": {
			"book": str(level.get("book", "")),
			"unit": int(level.get("unit", 0)),
			"keys": main_keys(Array(level.get("keys", [level.get("key", "")]))),
		},
		"next_wave": next_wave,
		"difficulty": difficulty,
		"run": run,
		"run_started_at": run_started_at,
		"saved_at": now,
	}
	if not wave.is_empty():
		state["wave"] = wave
	return state


## Die angefangene Welle eines Stands, oder {}, wenn er an einer Wellengrenze gerastet
## wurde oder von der Welle nichts mehr übrig ist.
static func open_wave(state: Dictionary) -> Dictionary:
	var wave: Variant = state.get("wave", {})
	if not wave is Dictionary or int((wave as Dictionary).get("remaining", 0)) <= 0:
		return {}
	return wave


## Ob die Auswahl `keys` in Unit `unit` den begonnenen Lauf fortsetzt: sie muss jeden
## gespeicherten Ort enthalten und darf weitere dazunehmen. Gesamt deckt alle Teile ab.
## Ein Boss setzt nie fort. `levels` sind die heutigen Level der Unit (MapLevel.levels_for).
static func continues(state: Dictionary, unit: int, keys: Array, levels: Array) -> bool:
	if state.is_empty() or int((state.get("level", {}) as Dictionary).get("unit", 0)) != unit:
		return false
	var level := MapLevel.combine(levels, keys)
	if level.is_empty() or str(level.get("kind", "")) == MapLevel.KIND_BOSS or not keeps(level):
		return false
	var chosen := _covered(keys, levels)
	for key in _covered(_saved_keys(state), levels):
		if not chosen.has(key):
			return false
	return true


## Die Orte, die `keys` zum begonnenen Lauf dazunimmt, in Spielreihenfolge; Gesamt zählt
## als seine Teile.
static func added(state: Dictionary, keys: Array, levels: Array) -> Array:
	var saved := _covered(_saved_keys(state), levels)
	var chosen := _covered(keys, levels)
	var out: Array = []
	for level in levels:
		var key := str(level["key"])
		if chosen.has(key) and not saved.has(key):
			out.append(key)
	return out


static func _saved_keys(state: Dictionary) -> Array:
	return main_keys(Array((state.get("level", {}) as Dictionary).get("keys", [])))


## Die Orte ohne Boni: nur sie tragen einen begonnenen Lauf.
static func main_keys(keys: Array) -> Array:
	return keys.filter(func(k): return not BonusLevel.is_map_key(str(k)))


## Wird ein Lauf mit `level` (RunRequest.level()) gespeichert? Nicht, wenn er nur Boni spielt.
static func keeps(level: Dictionary) -> bool:
	return not main_keys(Array(level.get("keys", [level.get("key", "")]))).is_empty()


## Die Orte, die eine Auswahl abdeckt: jeder gewählte Ort, Gesamt als alle Teile der Unit.
static func _covered(keys: Array, levels: Array) -> Dictionary:
	var wanted := {}
	for key in keys:
		wanted[str(key)] = true
	var whole := false
	for level in levels:
		if str(level["kind"]) == MapLevel.KIND_ALL and wanted.has(str(level["key"])):
			whole = true
	var out := {}
	for level in levels:
		var kind := str(level["kind"])
		if kind == MapLevel.KIND_ALL:
			continue
		if wanted.has(str(level["key"])) or (whole and kind == MapLevel.KIND_PART):
			out[str(level["key"])] = true
	return out


## Das Level, mit dem der Lauf weitergeht, aus den heutigen `levels` der Unit. Leer bei
## anderem Format, neuerer App, verschwundenem Ort oder einer Auswahl ohne Wellenkampf.
static func resumable_level(state: Dictionary, levels: Array) -> Dictionary:
	if int(state.get("format", 0)) != FORMAT:
		return {}
	if SemVer.is_newer(str(state.get("app_version", "")), SemVer.app_version()):
		return {}
	var keys := _saved_keys(state)
	if keys.is_empty():
		return {}
	var known := {}
	for level in levels:
		known[str(level["key"])] = true
	for key in keys:
		if not known.has(str(key)):
			return {}
	var level := MapLevel.combine(levels, keys)
	if level.is_empty() or str(level.get("kind", "")) == MapLevel.KIND_BOSS:
		return {}
	return level


static func _write(runs: Dictionary, profile: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var target := path(profile)
	if runs.is_empty():
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		return
	SaveGuard.write(target, "_runs", {"runs": runs})
