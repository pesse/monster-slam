class_name MapLevel
extends RefCounted
## Die Level einer Unit auf der Gebietskarte (docs/adr/0006-buchzentrierte-karte.md).
##
## Eine Unit zerfällt in ihre Teile (ContentRegistry, PART_COUNT = 4), dazu ein Level mit
## der ganzen Unit und am Schluss der Boss:
##
##     T1 → T2 → T3 → T4 → Gesamt → Boss
##
## Ein Buch mit Lektionen als Teilen (Feld `part`, Latein: sechs je Unit) hat entsprechend
## mehr T-Level; wie viele, legt AreaMap.part_count aus Inhalt und Karte fest.
##
## Hat die Unit weniger Teile, gibt es weniger T-Level; bei nur einem Teil wäre „Gesamt"
## dasselbe Level noch einmal und entfällt. Nichts davon wird gespeichert: welche Level es
## gibt, folgt aus dem Katalog, wie weit ein Level ist, aus der Meisterung
## (FortressTier.part_tiers / unit_tiers). Gesperrt ist keines.
##
## Reine Rechnung ohne Szene; die Teilzahl kommt als Argument, damit sie ohne Katalog
## prüfbar ist (tests/map_level_test.gd).

const KIND_PART := "part"
const KIND_ALL := "all"
const KIND_BOSS := "boss"


## Die Level einer Unit in Spielreihenfolge:
## [{ key, kind, book, unit, part, scope, label }].
##
## `key` ist der Name des Punkts auf der Karte („t1" … „t4" bzw. „t6", „all", „boss") — derselbe
## Schlüssel wie in assets/maps/<book>/map.json. `scope` ist der Curriculum-Scope des
## Levels in der Form von ContentRegistry.lexemes_scoped.
static func levels_for(book: String, unit: int, part_count: int) -> Array:
	var out: Array = []
	if part_count <= 0:
		return out
	var unit_scope := "%s/%d" % [book, unit]
	for part in range(1, part_count + 1):
		out.append({
			"key": "t%d" % part, "kind": KIND_PART, "book": book, "unit": unit, "part": part,
			"scope": ["%s/%d" % [unit_scope, part]], "label": "Teil %d" % part,
		})
	if part_count > 1:
		out.append({
			"key": "all", "kind": KIND_ALL, "book": book, "unit": unit, "part": 0,
			"scope": [unit_scope], "label": "Gesamt",
		})
	out.append({
		"key": "boss", "kind": KIND_BOSS, "book": book, "unit": unit, "part": 0,
		"scope": [unit_scope], "label": "Boss",
	})
	return out


## Die Stufe 0..4 eines Levels aus den gezählten Ständen. `units` ist
## FortressTier.unit_tiers, `parts` FortressTier.part_tiers. Der Boss hat keine Stufe —
## er zeigt Siege (BossRecord), deshalb hier 0.
static func tier_of(level: Dictionary, units: Dictionary, parts: Dictionary) -> int:
	var unit_key := "%s/%d" % [level["book"], int(level["unit"])]
	match str(level["kind"]):
		KIND_PART:
			var key := "%s/%d" % [unit_key, int(level["part"])]
			return int((parts.get(key, {}) as Dictionary).get("tier", 0))
		KIND_ALL:
			return int((units.get(unit_key, {}) as Dictionary).get("tier", 0))
	return 0


## Gemeistert / gesamt eines Levels: { done, total } — für Hinweis und Fortschrittsring.
static func counts_of(level: Dictionary, units: Dictionary, parts: Dictionary) -> Dictionary:
	var unit_key := "%s/%d" % [level["book"], int(level["unit"])]
	var group: Dictionary = {}
	if str(level["kind"]) == KIND_PART:
		group = parts.get("%s/%d" % [unit_key, int(level["part"])], {})
	else:
		group = units.get(unit_key, {})
	return {"done": int(group.get("done", 0)), "total": int(group.get("total", 0))}
