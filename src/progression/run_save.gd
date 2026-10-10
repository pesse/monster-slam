class_name RunSave
extends RefCounted
## Begonnene Läufe von der Karte (docs/adr/0020-rasten-und-fortsetzen.md).
##
## Ein Platz je Buch: Englisch und Latein nebeneinander dürfen sich nicht gegenseitig den
## Lauf verwerfen. Expertenmodus und Testvorbereitung rasten nicht (ADR 0020, „Bewusst
## nicht"), sie kommen hier nie an.
##
## Ein Speicherstand trägt nur Ursprungswerte (`GameState.run_snapshot()` plus Wellennummer,
## Schwierigkeit und die gewählten Orte). Das Maximum der Festung, Tempo, Schaden und die
## Wörter hinter dem Scope werden beim Fortsetzen neu gerechnet. Fest sitzt der BEREICH
## (`keys`), nicht der Inhalt: ein Pack-Update kommt beim Fortsetzen an. Erweitern darf
## man ihn innerhalb der Unit (`continues`), verkleinern nicht.
##
## Ablage: user://progress/<profil>_runs.json als { "runs": { <book>: <stand> } },
## geschrieben über SaveStore (temporäre Datei, Prüfsumme), damit ein Absturz beim Schreiben
## nicht die Läufe der anderen Bücher mitnimmt. Statisch und mit Profil-Argument wie BossRecord,
## damit Tests auf einem `zz-`-Profil laufen.

const SAVE_DIR := "user://progress"
## Hebt sich, wenn ein Stand eines älteren Formats nicht mehr gelesen werden kann.
const FORMAT := 1


static func path(profile: String) -> String:
	return "%s/%s_runs.json" % [SAVE_DIR, profile]


## Alle begonnenen Läufe des Profils: Buch -> Stand.
static func all(profile: String) -> Dictionary:
	var read := SaveStore.read(path(profile))
	if int(read["status"]) == SaveStore.Status.CORRUPT:
		# Ein begonnener Lauf hat keine Sicherung (SaveCoordinator.PROFILE_SUFFIXES). Die
		# kaputte Datei geht in die Quarantäne, damit wieder gerastet werden kann.
		push_warning("RunSave: %s unlesbar, in die Quarantäne" % path(profile))
		SaveStore.quarantine(path(profile), "user://quarantine/%s/runs-%d"
				% [profile, int(Time.get_unix_time_from_system())], ".corrupt")
	if int(read["status"]) != SaveStore.Status.OK:
		return {}
	var runs: Variant = (read["data"] as Dictionary).get("runs", {})
	return runs if runs is Dictionary else {}


## Der begonnene Lauf eines Buchs, oder {}.
static func of_book(book: String, profile: String) -> Dictionary:
	var state: Variant = all(profile).get(book, {})
	return state if state is Dictionary else {}


## Legt `state` auf den Platz seines Buchs (`state.level.book`) und ersetzt, was dort lag.
static func store(state: Dictionary, profile: String) -> void:
	var book := str((state.get("level", {}) as Dictionary).get("book", ""))
	if book.is_empty():
		return
	var runs := all(profile)
	runs[book] = state
	_write(runs, profile)


## Verwirft den Lauf eines Buchs. Ohne Lauf ein No-op.
static func discard(book: String, profile: String) -> void:
	var runs := all(profile)
	if not runs.has(book):
		return
	runs.erase(book)
	_write(runs, profile)


## Baut den Stand am Wellenende. `level` ist RunRequest.level() (MapLevel.combine),
## gespeichert werden davon nur Buch, Unit und Orte — der Scope wird beim Fortsetzen aus
## den Orten neu gebaut. `next_wave` ist die Welle, mit der es weitergeht.
static func build(level: Dictionary, next_wave: int, difficulty: int, run: Dictionary,
		run_started_at: int, now: int) -> Dictionary:
	return {
		"format": FORMAT,
		"app_version": SemVer.app_version(),
		"level": {
			"book": str(level.get("book", "")),
			"unit": int(level.get("unit", 0)),
			"keys": Array(level.get("keys", [level.get("key", "")])),
		},
		"next_wave": next_wave,
		"difficulty": difficulty,
		"run": run,
		"run_started_at": run_started_at,
		"saved_at": now,
	}


## Ob die Auswahl `keys` in Unit `unit` den begonnenen Lauf fortsetzt: sie muss jeden
## gespeicherten Ort enthalten und darf weitere dazunehmen (erweitern, ADR 0020 Punkt 6).
## Fehlt einer, ist es ein neuer Lauf. Gesamt deckt alle Teile der Unit ab, ein Lauf über
## Teil 1 und 2 geht also mit Gesamt weiter. Ein Boss setzt nie fort, er gehört zu keinem
## Lauf. `levels` sind die heutigen Level der Unit (MapLevel.levels_for).
static func continues(state: Dictionary, unit: int, keys: Array, levels: Array) -> bool:
	if state.is_empty() or int((state.get("level", {}) as Dictionary).get("unit", 0)) != unit:
		return false
	var level := MapLevel.combine(levels, keys)
	if level.is_empty() or str(level.get("kind", "")) == MapLevel.KIND_BOSS:
		return false
	var chosen := _covered(keys, levels)
	for key in _covered(_saved_keys(state), levels):
		if not chosen.has(key):
			return false
	return true


## Die Orte, die die Auswahl `keys` zum begonnenen Lauf dazunimmt, in Spielreihenfolge —
## leer, wenn sie genau ihn spielt. Gesamt zählt hier als seine Teile.
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
	return Array((state.get("level", {}) as Dictionary).get("keys", []))


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


## Das Level, mit dem der Lauf weitergeht, gebaut aus den HEUTIGEN Leveln der Unit
## (`levels`, MapLevel.levels_for) — oder {}, wenn er sich nicht mehr spielen lässt: ein
## anderes Format, eine neuere App als diese, ein Ort, den es nicht mehr gibt, oder eine
## Auswahl, die keinen Wellenkampf mehr ergibt.
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
