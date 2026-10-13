class_name MapLevel
extends RefCounted
## Die Level einer Unit auf der Gebietskarte (ADR 0006): T1 … Tn → Gesamt → Bonus → Boss.
## Die Teilzahl (AreaMap.part_count) kommt als Argument; bei nur einem Teil entfällt Gesamt.
## Je Bonus der Unit gibt es ein eigenes Level (ADR 0012). Nichts wird gespeichert; die Stufe
## eines Levels kommt aus FortressTier.part_tiers / unit_tiers.

const KIND_PART := "part"
const KIND_ALL := "all"
const KIND_BOSS := "boss"
const KIND_BONUS := "bonus"


## Die Level einer Unit in Spielreihenfolge: [{ key, kind, book, unit, part, scope, label }].
## `key` ist der Punkt in assets/maps/<book>/map.json („t1“, „all“, „boss“,
## „bonus/5/la_perfect“), `scope` hat die Form von ContentRegistry.lexemes_scoped, `label`
## kommt aus BookNaming. `bonuses` sind die Boni der Unit (ContentRegistry.bonuses_of) mit
## `title`; ein Bonus-Level trägt dazu `bonus`, den Scope-Schlüssel des Bonus.
static func levels_for(book: String, unit: int, part_count: int, bonuses: Array = []) -> Array:
	var out: Array = []
	if part_count <= 0:
		return out
	var unit_scope := "%s/%d" % [book, unit]
	for part in range(1, part_count + 1):
		out.append({
			"key": "t%d" % part, "kind": KIND_PART, "book": book, "unit": unit, "part": part,
			"scope": ["%s/%d" % [unit_scope, part]],
			"label": BookNaming.part_label(book, unit, part),
		})
	if part_count > 1:
		out.append({
			"key": "all", "kind": KIND_ALL, "book": book, "unit": unit, "part": 0,
			"scope": [unit_scope], "label": "Gesamt",
		})
	for bonus in bonuses:
		out.append({
			"key": BonusLevel.map_key(bonus), "kind": KIND_BONUS, "book": book, "unit": unit,
			"part": int(bonus["part"]), "scope": [str(bonus["key"])], "bonus": str(bonus["key"]),
			"label": str(bonus.get("title", "Bonus")),
		})
	out.append({
		"key": "boss", "kind": KIND_BOSS, "book": book, "unit": unit, "part": 0,
		"scope": [unit_scope], "label": "Boss",
	})
	return out


## Die Stufe 0..4 eines Levels. `units` ist FortressTier.unit_tiers, `parts`
## FortressTier.part_tiers. Der Boss zeigt Siege (BossRecord) und hat hier 0.
static func tier_of(level: Dictionary, units: Dictionary, parts: Dictionary) -> int:
	var unit_key := "%s/%d" % [level["book"], int(level["unit"])]
	match str(level["kind"]):
		KIND_PART:
			var key := "%s/%d" % [unit_key, int(level["part"])]
			return int((parts.get(key, {}) as Dictionary).get("tier", 0))
		KIND_ALL:
			return int((units.get(unit_key, {}) as Dictionary).get("tier", 0))
	return 0


## Gemeistert / gesamt eines Levels: { done, total }. Ein Bonus zählt Aufgaben statt Wörter:
## `bonuses` ist Bonus-Schlüssel -> BonusLevel.counts.
static func counts_of(level: Dictionary, units: Dictionary, parts: Dictionary,
		bonuses: Dictionary = {}) -> Dictionary:
	var unit_key := "%s/%d" % [level["book"], int(level["unit"])]
	var group: Dictionary = {}
	if str(level["kind"]) == KIND_BONUS:
		group = bonuses.get(str(level.get("bonus", "")), {})
	elif str(level["kind"]) == KIND_PART:
		group = parts.get("%s/%d" % [unit_key, int(level["part"])], {})
	else:
		group = units.get(unit_key, {})
	return {"done": int(group.get("done", 0)), "total": int(group.get("total", 0))}


## Die Auswahl nach einem Klick auf den Ort `key`, in Spielreihenfolge. Teile und Boni lassen
## sich zusammen wählen und nehmen Gesamt und Boss heraus; Gesamt und Boss stehen allein, ein
## zweiter Klick leert die Auswahl.
static func toggle(levels: Array, selected: Array, key: String) -> Array:
	var level := _find(levels, key)
	if level.is_empty():
		return selected.duplicate()
	if not _multi(level):
		return [] if selected == [key] else [key]
	var chosen := {}
	for other in selected:
		if _multi(_find(levels, str(other))):
			chosen[str(other)] = true
	if chosen.has(key):
		chosen.erase(key)
	else:
		chosen[key] = true
	var out: Array = []
	for each in levels:
		if chosen.has(str(each["key"])):
			out.append(str(each["key"]))
	return out


## Das Level, das eine Auswahl spielt, leer ohne Auswahl. Mehrere Teile und Boni werden eines
## mit allen ihren Scopes. `keys` nennt alle gewählten Orte, `key` den ersten.
static func combine(levels: Array, keys: Array) -> Dictionary:
	var chosen := levels.filter(func(l): return str(l["key"]) in keys)
	if chosen.is_empty():
		return {}
	var first: Dictionary = chosen[0]
	if chosen.size() == 1:
		var one := first.duplicate(true)
		one["keys"] = [str(first["key"])]
		return one
	var scope: Array = []
	var parts: Array = []
	var titles: Array = []
	var picked: Array = []
	for level in chosen:
		scope.append_array(level["scope"])
		picked.append(str(level["key"]))
		if str(level["kind"]) == KIND_BONUS:
			titles.append(str(level["label"]))
		else:
			parts.append(int(level["part"]))
	var labels: Array = []
	if not parts.is_empty():
		labels.append(BookNaming.parts_label(str(first["book"]), int(first["unit"]), parts))
	labels.append_array(titles)
	return {
		"key": str(first["key"]), "keys": picked,
		"kind": KIND_PART if not parts.is_empty() else KIND_BONUS,
		"book": first["book"], "unit": first["unit"], "part": 0, "parts": parts,
		"scope": scope, "label": " + ".join(labels),
	}


## Lässt sich der Ort mit anderen zusammen wählen? Teile und Boni ja, Gesamt und Boss nicht.
static func _multi(level: Dictionary) -> bool:
	return str(level.get("kind", "")) in [KIND_PART, KIND_BONUS]


static func _find(levels: Array, key: String) -> Dictionary:
	for level in levels:
		if str(level["key"]) == key:
			return level
	return {}
