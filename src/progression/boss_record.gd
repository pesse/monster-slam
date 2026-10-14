class_name BossRecord
extends RefCounted
## Die Siege über den Boss einer Unit (ADR 0006). Gespeichert wird je Sieg { unit, won_at };
## gezählt wird beim Lesen. Nur Siege von der Karte tragen eine Unit.
## Ablage: user://progress/<profil>_bosses.json. Statisch mit Profil-Argument, damit Tests
## auf einem `zz-`-Profil laufen.

const SAVE_DIR := "user://progress"

## Ab so vielen Siegen gibt es Bronze, Silber, Gold.
const MEDAL_WINS := [1, 3, 5]
const MEDAL_NAMES := ["", "Bronze", "Silber", "Gold"]


static func path(profile: String) -> String:
	return "%s/%s_bosses.json" % [SAVE_DIR, profile]


## Alle Siege des Profils, in der Reihenfolge, in der sie errungen wurden.
static func entries(profile: String) -> Array:
	var read := SaveStore.read(path(profile))
	if int(read["status"]) != SaveStore.Status.OK:
		return []
	var wins: Variant = (read["data"] as Dictionary).get("wins", [])
	return wins if wins is Array else []


## Bucht einen Sieg, nie über eine unlesbare Datei (SaveGuard). Leere Unit: nichts zu tun.
static func record_win(unit_key: String, profile: String) -> void:
	if unit_key.is_empty():
		return
	var all := entries(profile)
	all.append({"unit": unit_key, "won_at": int(Time.get_unix_time_from_system())})
	SaveGuard.write(path(profile), "_bosses", {"wins": all})


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
