class_name FortressTier
extends RefCounted
## Die Regeln der Festungsstufe: eine Stufe je Unit und was sie im Kampf wert ist (Issue #21).
## Die Regeln stehen in docs/CONVENTIONS.md „Festung“; gezählt wird nur hier. Reine
## Rechnung ohne Zustand.

const PROGRESS := preload("res://src/learning/player_progress.gd")

## Anteil gemeisterter Wörter einer Unit für Stufe 1, 2, 3, 4, in Prozent.
const THRESHOLDS_PERCENT := [10, 32, 53, 75]
const MAX_TIER := 4

## Der Skill `fortress_tier_drop` zieht Stufe 4 um `drop` Prozentpunkte vor und die anderen
## Stufen im selben Verhältnis (bei 5: rund 9,3 / 29,9 / 49,5 / 70 %). Jede Zählung bekommt
## `drop` übergeben (`drop_of`). Stufe 4 liegt nie unter MIN_TOP_PERCENT.
const MIN_TOP_PERCENT := 50

## Festungs-HP je Stufe, additiv in dasselbe `max_health` wie die Skill-Boni.
const HP_PER_TIER := 25


## Stufe 0..4 für `done` gemeisterte von `total` Wörtern, mit `drop` vorgezogenen
## Prozentpunkten. In Ganzzahlen verglichen, damit 3 von 30 genau 10 % sind.
static func tier_for(done: int, total: int, drop: int = 0) -> int:
	if total <= 0:
		return 0
	var tier := 0
	for i in THRESHOLDS_PERCENT.size():
		if done >= words_for(i + 1, total, drop):
			tier += 1
	return tier


## So viele von `total` Wörtern braucht Stufe `tier` (1..4) mindestens, aufgerundet: das
## kleinste `d` mit d * 100 * top >= pct * (top - drop) * total.
static func words_for(tier: int, total: int, drop: int = 0) -> int:
	var top := int(THRESHOLDS_PERCENT[-1])
	var scale := top - clampi(drop, 0, top - MIN_TOP_PERCENT)
	var pct := int(THRESHOLDS_PERCENT[clampi(tier, 1, MAX_TIER) - 1])
	var den := 100 * top
	@warning_ignore("integer_division")
	return (pct * scale * total + den - 1) / den


## Vorgezogene Prozentpunkte aus den Skill-Boni (SkillBook.bonuses()).
static func drop_of(bonuses: Dictionary) -> int:
	return maxi(0, int(round(float(bonuses.get("fortress_tier_drop", 0.0)))))


## Der Unit-Schlüssel eines Lexems, „<book>/<unit>“ wie ContentRegistry._scope_keys. Leer
## ohne Unit oder in einem Wort-Bonus, der nicht zur Festung zählt (ADR 0013).
static func unit_key(entry: Dictionary) -> String:
	var book := str(entry.get("book", ""))
	if book.is_empty() or not entry.has("unit") or not Lexeme.bonus(entry).is_empty():
		return ""
	return "%s/%d" % [book, int(entry["unit"])]


## Stand je Unit: „<book>/<unit>“ -> { book, unit, done, total, tier, lexemes }.
## `mastered` kommt aus PlayerProgress.mastered_lexemes. Nicht meisterbare Lexeme und
## solche ohne Unit fallen heraus.
static func unit_tiers(lexemes: Array, mastered: Dictionary, drop: int = 0) -> Dictionary:
	var groups := {}
	for entry in lexemes:
		if not PROGRESS.masterable(entry):
			continue
		var key := unit_key(entry)
		if key.is_empty():
			continue
		count_into(groups, key, entry, mastered)
		groups[key]["book"] = str(entry["book"])
		groups[key]["unit"] = int(entry["unit"])
	for key in groups:
		var group: Dictionary = groups[key]
		group["tier"] = tier_for(int(group["done"]), int(group["total"]), drop)
	return groups


## Stand je Teil einer Unit: „<book>/<unit>/<teil>“ -> { book, unit, part, done, total,
## tier, lexemes }, gezählt wie `unit_tiers`. Für die Level T1–T4 der Gebietskarte (ADR 0006).
## `part_of` bildet eine Lexem-Id auf ihren Teil ab (ContentRegistry.part_of); 0 fällt heraus.
static func part_tiers(lexemes: Array, mastered: Dictionary, part_of: Callable,
		drop: int = 0) -> Dictionary:
	var groups := {}
	for entry in lexemes:
		if not PROGRESS.masterable(entry):
			continue
		var unit := unit_key(entry)
		var part := int(part_of.call(str(entry.get("id", ""))))
		if unit.is_empty() or part <= 0:
			continue
		var key := "%s/%d" % [unit, part]
		count_into(groups, key, entry, mastered)
		groups[key]["book"] = str(entry["book"])
		groups[key]["unit"] = int(entry["unit"])
		groups[key]["part"] = part
	for key in groups:
		var group: Dictionary = groups[key]
		group["tier"] = tier_for(int(group["done"]), int(group["total"]), drop)
	return groups


## Zählt ein Lexem in die Gruppe `key`, als gemeistert, wenn es in `mastered` steht.
static func count_into(groups: Dictionary, key: String, entry: Dictionary, mastered: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = {"done": 0, "total": 0, "lexemes": []}
	groups[key]["total"] += 1
	groups[key]["lexemes"].append(entry)
	if mastered.has(str(entry.get("id", ""))):
		groups[key]["done"] += 1


## Die Stufe eines Laufs: die schwächste Unit im gespielten Bereich, 0 ohne Unit.
## `scoped` bestimmt nur, welche Units dabei sind; gewertet wird jede ganz aus `unit_stats`
## (`unit_tiers` über den ganzen Katalog). `units` ergänzt Units ohne eigene Wörter im
## Bereich, etwa die eines Bonus (ADR 0012).
static func run_tier(scoped: Array, unit_stats: Dictionary, units: Array = []) -> int:
	var keys := units.duplicate()
	for entry in scoped:
		var key := unit_key(entry)
		if not key.is_empty() and not key in keys:
			keys.append(key)
	var lowest := -1
	for key in keys:
		var tier := int((unit_stats.get(key, {}) as Dictionary).get("tier", 0))
		lowest = tier if lowest < 0 else mini(lowest, tier)
	return maxi(0, lowest)


static func health_bonus(tier: int) -> int:
	return maxi(0, tier) * HP_PER_TIER


## Was bis zur nächsten Stufe fehlt: { tier, needed }. Leer auf der höchsten Stufe oder
## ohne Wörter.
static func next_threshold(done: int, total: int, drop: int = 0) -> Dictionary:
	if total <= 0:
		return {}
	var tier := tier_for(done, total, drop)
	if tier >= MAX_TIER:
		return {}
	return {"tier": tier + 1, "needed": maxi(1, words_for(tier + 1, total, drop) - done)}
