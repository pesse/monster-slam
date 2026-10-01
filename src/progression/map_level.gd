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
## Dazu kommt je Bonus der Unit ein Level zwischen Gesamt und Boss (ADR 0012): Formen
## älterer Wörter, die eine Lektion der Unit lehrt. Er zählt für sich (BonusLevel), nicht
## zur Festung, und lässt sich wie ein Teil mit anderen zusammen wählen.
##
## Hat die Unit weniger Teile, gibt es weniger T-Level; bei nur einem Teil wäre „Gesamt"
## dasselbe Level noch einmal und entfällt. Nichts davon wird gespeichert: welche Level es
## gibt, folgt aus dem Katalog, wie weit ein Level ist, aus der Meisterung
## (FortressTier.part_tiers / unit_tiers). Gesperrt ist keines.
##
## Gespielt wird eine Auswahl (`toggle`, `combine`): Teile lassen sich beliebig zusammen
## markieren, etwa nur Teil 2 und 3, auch mit Boni; Gesamt und Boss stehen nur allein.
##
## Reine Rechnung ohne Szene; die Teilzahl kommt als Argument, damit sie ohne Katalog
## prüfbar ist (tests/map_level_test.gd).

const KIND_PART := "part"
const KIND_ALL := "all"
const KIND_BOSS := "boss"
const KIND_BONUS := "bonus"


## Die Level einer Unit in Spielreihenfolge:
## [{ key, kind, book, unit, part, scope, label }]. `label` nennt den Teil, wie das Buch
## ihn nennt (BookNaming: „Teil 1", „Partie A", „Lektion 10").
##
## `key` ist der Name des Punkts auf der Karte („t1" … „t4" bzw. „t6", „all", „boss",
## „bonus/5/la_perfect") — derselbe Schlüssel wie in assets/maps/<book>/map.json. `scope`
## ist der Curriculum-Scope des Levels in der Form von ContentRegistry.lexemes_scoped.
##
## `bonuses` sind die Boni der Unit (ContentRegistry.bonuses_of), je mit `title`
## (BonusLevel.title); ein Bonus-Level trägt dazu `bonus`, den Scope-Schlüssel des Bonus.
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
## Ein Bonus zählt Aufgaben statt Wörter: `bonuses` ist Bonus-Schlüssel -> BonusLevel.counts.
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


## Die Auswahl (Schlüssel wie in `levels_for`) nach einem Klick auf den Ort `key`. Ein Teil
## oder Bonus kommt dazu oder geht wieder und nimmt Gesamt und Boss aus der Auswahl; Gesamt und Boss
## stehen allein — ein Klick darauf ersetzt die Auswahl, ein zweiter leert sie. Die
## Schlüssel kommen in Spielreihenfolge zurück.
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


## Das Level, das eine Auswahl spielt — leer ohne Auswahl. Ein einzelner Ort bleibt sein
## Level; mehrere Teile und Boni werden eines mit allen ihren Scopes. `keys` nennt immer
## alle gewählten Orte (für den Zoom zurück aus dem Kampf), `key` den ersten.
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
