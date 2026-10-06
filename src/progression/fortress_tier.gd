class_name FortressTier
extends RefCounted
## Die Regeln der Festungsstufe: eine Stufe je Unit, gemessen am Anteil gemeisterter
## Wörter, und was sie im Kampf wert ist (Issue #21).
##
## Früher gab es EINE Stufe fürs ganze Profil, gezählt in gemeisterten Aufgaben gegen
## [1, 3, 6, 10] — nach zehn Aufgaben war die Festung fertig und danach nichts mehr zu
## holen. Jetzt hängt die Stufe an der Unit und wächst mit ihrem Anteil gemeisterter
## Wörter; jede neue Unit ist wieder eine Baustelle.
##
## Gezählt wird mit derselben Regel wie der Fortschrittsbalken der Statistik: ein Wort ist
## gemeistert, wenn beide Übersetzungsrichtungen sitzen und bei einem unregelmäßigen Verb
## auch seine Formen (PlayerProgress.mastered_lexemes), und Wörter ohne Übersetzungsaufgabe
## stehen nicht im Nenner (PlayerProgress.masterable).
## `StatsScreen.unit_rows` baut seine Zeilen aus `unit_tiers` — eine Zählregel, nicht zwei.
##
## Reine Rechnung ohne Zustand, Szene und Autoload, wie Experience und ChestReward (siehe
## tests/fortress_tier_test.gd). Wer die Stufe eines Laufs bestimmt, ist der WaveRunner.

const PROGRESS := preload("res://src/learning/player_progress.gd")

## Ab so viel Prozent gemeisterter Wörter einer Unit gilt Stufe 1, 2, 3, 4 — linear von
## 10 bis 75 % (ADR 0009). Stufe 4 bringt das Wachkatapult; sie kommt bei drei Vierteln,
## damit das letzte Viertel nicht für die Festung, sondern für die goldenen Sterne der
## Karte gelernt wird (MapCanvas, 20 % je Stern) — ohne die schon sitzenden Wörter noch
## einmal anfassen zu müssen.
const THRESHOLDS_PERCENT := [10, 32, 53, 75]
const MAX_TIER := 4

## Der Skill „Schneller Erbauer" (Bollwerk, `fortress_tier_drop`) zieht die Schwellen vor:
## `drop` Prozentpunkte früher Stufe 4, die anderen Stufen im SELBEN Verhältnis
## (bei 5: rund 9,3 / 29,9 / 49,5 / 70 %). Ein Skalieren und kein Abziehen, damit Stufe 1 nicht
## schon bei 5 % steht. Jede Zählung bekommt `drop` übergeben, damit Karte, Statistik und
## Kampf dieselbe Stufe sehen; der Wert kommt aus SkillBook.bonuses (`drop_of`).
## Nie unter MIN_TOP_PERCENT, sonst wäre Stufe 4 geschenkt.
const MIN_TOP_PERCENT := 50

## Festungs-HP je Stufe. Additiv auf den Grundwert, in dieselbe Summe wie die Skill-Boni
## (`max_health`, siehe WaveRunner._ready).
const HP_PER_TIER := 25


## Stufe 0..4 für `done` gemeisterte von `total` Wörtern, mit `drop` vorgezogenen
## Prozentpunkten (siehe MIN_TOP_PERCENT). In Ganzzahlen verglichen (`words_for`): 3 von 30
## sind genau 10 % und keine 9,999…
static func tier_for(done: int, total: int, drop: int = 0) -> int:
	if total <= 0:
		return 0
	var tier := 0
	for i in THRESHOLDS_PERCENT.size():
		if done >= words_for(i + 1, total, drop):
			tier += 1
	return tier


## So viele von `total` Wörtern braucht Stufe `tier` (1..4) mindestens — aufgerundet und in
## Ganzzahlen: das kleinste `d` mit d * 100 * top >= pct * (top - drop) * total.
static func words_for(tier: int, total: int, drop: int = 0) -> int:
	var top := int(THRESHOLDS_PERCENT[-1])
	var scale := top - clampi(drop, 0, top - MIN_TOP_PERCENT)
	var pct := int(THRESHOLDS_PERCENT[clampi(tier, 1, MAX_TIER) - 1])
	var den := 100 * top
	@warning_ignore("integer_division")
	return (pct * scale * total + den - 1) / den


## Wie viele Prozentpunkte die Schwellen vorgezogen sind, aus den Skill-Boni
## (SkillBook.bonuses()).
static func drop_of(bonuses: Dictionary) -> int:
	return maxi(0, int(round(float(bonuses.get("fortress_tier_drop", 0.0)))))


## Der Unit-Schlüssel eines Lexems, „<book>/<unit>" — dieselbe Form wie der Scope-Schlüssel
## einer Unit (ContentRegistry._scope_keys). Leer, wenn das Lexem keine Unit hat
## (Grundwortschatz) oder in einem Wort-Bonus steht: der zählt nicht zur Festung (ADR 0013).
static func unit_key(entry: Dictionary) -> String:
	var book := str(entry.get("book", ""))
	if book.is_empty() or not entry.has("unit") or not Lexeme.bonus(entry).is_empty():
		return ""
	return "%s/%d" % [book, int(entry["unit"])]


## Stand je Unit: „<book>/<unit>" -> { book, unit, done, total, tier, lexemes }.
##
## `lexemes` ist der Katalog (oder ein Teil davon), `mastered` die Menge aus
## PlayerProgress.mastered_lexemes. Nicht meisterbare Lexeme fallen hier heraus, damit
## kein Aufrufer das Filtern vergessen kann; Lexeme ohne Unit ebenso.
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


## Stand je Teil einer Unit: „<book>/<unit>/<teil>" -> { book, unit, part, done, total,
## tier, lexemes } — dieselbe Zählung und dieselben Schwellen wie `unit_tiers`, nur feiner
## gruppiert. Für die Level T1–T4 der Gebietskarte (ADR 0006); das Level „Gesamt" ist die
## Unit selbst und liest `unit_tiers`.
##
## `part_of` bildet eine Lexem-Id auf ihren Teil ab (ContentRegistry.part_of); 0 heißt:
## ohne Teil, fällt heraus.
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


## Zählt ein Lexem in die Gruppe `key`: eines mehr insgesamt, und eines mehr gemeistert,
## wenn es in der Menge steht. Die eine Zählregel für Units.
static func count_into(groups: Dictionary, key: String, entry: Dictionary, mastered: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = {"done": 0, "total": 0, "lexemes": []}
	groups[key]["total"] += 1
	groups[key]["lexemes"].append(entry)
	if mastered.has(str(entry.get("id", ""))):
		groups[key]["done"] += 1


## Die Stufe eines Laufs: die SCHWÄCHSTE Unit, die im gespielten Bereich vorkommt.
##
## `scoped` sind die Lexeme des Bereichs (Scope und Themen aus dem Session-Setup),
## `unit_stats` das Ergebnis von `unit_tiers` über den GANZEN Katalog. Aus `scoped` kommt
## nur, WELCHE Units dabei sind — gewertet wird jede als Ganzes, auch wenn nur ein Viertel
## oder ein Thema daraus gespielt wird. Sonst ließe sich die Festung hochziehen, indem man
## den Bereich auf die schon gekonnten Wörter einengt.
##
## `units` nennt Units, die dazu ohne eigene Wörter im Bereich stehen: die eines Bonus
## (ContentRegistry.bonus_units). Seine Wörter stammen aus früheren Units, die Festung ist
## aber immer die der Unit, in der er steht (ADR 0012).
##
## Kommt keine Unit vor, ist die Stufe 0.
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


## Zusätzliche Festungs-HP für `tier` Stufen.
static func health_bonus(tier: int) -> int:
	return maxi(0, tier) * HP_PER_TIER


## Was bis zur nächsten Stufe fehlt: { tier, needed } — `needed` Wörter mehr bringen Stufe
## `tier`. Leer, wenn die Unit schon auf der höchsten Stufe steht oder keine Wörter hat.
static func next_threshold(done: int, total: int, drop: int = 0) -> Dictionary:
	if total <= 0:
		return {}
	var tier := tier_for(done, total, drop)
	if tier >= MAX_TIER:
		return {}
	return {"tier": tier + 1, "needed": maxi(1, words_for(tier + 1, total, drop) - done)}
