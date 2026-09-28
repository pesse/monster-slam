class_name BossRecord
extends RefCounted
## Die Siege über den Boss einer Unit (ADR 0006).
##
## Gespeichert wird der Ursprungswert — je Sieg ein Eintrag { unit, won_at } —, gezählt
## und in eine Medaille übersetzt wird beim Lesen. Kein Zähler daneben.
##
## Nur ein Sieg, der von der Karte gestartet wurde, trägt eine Unit und landet hier; ein
## Boss aus dem Expertenmodus mit beliebigem Bereich gehört zu keiner Unit. Gold,
## Erfahrung und Lernstand bleiben unberührt (ADR 0005, Entscheidung 6).
##
## Ablage: user://progress/<profil>_bosses.json, dieselbe wie Wallet und PlayerLevel.
## Statisch und mit Profil-Argument, damit Tests auf einem `zz-`-Profil laufen.

const SAVE_DIR := "user://progress"

## Ab so vielen Siegen gibt es Bronze, Silber, Gold.
const MEDAL_WINS := [1, 3, 5]
const MEDAL_NAMES := ["", "Bronze", "Silber", "Gold"]


static func path(profile: String) -> String:
	return "%s/%s_bosses.json" % [SAVE_DIR, profile]


## Alle Siege des Profils, in der Reihenfolge, in der sie errungen wurden.
static func entries(profile: String) -> Array:
	var text := FileAccess.get_file_as_string(path(profile))
	if text.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return []
	var wins: Variant = (parsed as Dictionary).get("wins", [])
	return wins if wins is Array else []


## Bucht einen Sieg. Eine leere Unit ist nichts zu buchen.
static func record_win(unit_key: String, profile: String) -> void:
	if unit_key.is_empty():
		return
	var all := entries(profile)
	all.append({"unit": unit_key, "won_at": int(Time.get_unix_time_from_system())})
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(path(profile), FileAccess.WRITE)
	if file == null:
		push_warning("BossRecord: %s nicht schreibbar" % path(profile))
		return
	file.store_string(JSON.stringify({"wins": all}, "\t"))
	file.close()


## Siege je Unit: „<book>/<unit>" -> Anzahl.
static func wins(profile: String) -> Dictionary:
	var out := {}
	for entry in entries(profile):
		if not entry is Dictionary:
			continue
		var unit := str((entry as Dictionary).get("unit", ""))
		if not unit.is_empty():
			out[unit] = int(out.get(unit, 0)) + 1
	return out


## Medaille 0..3 (keine, Bronze, Silber, Gold) für `count` Siege.
static func medal(count: int) -> int:
	var out := 0
	for threshold in MEDAL_WINS:
		if count >= int(threshold):
			out += 1
	return out
