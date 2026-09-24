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
## gemeistert, wenn beide Übersetzungsrichtungen sitzen (PlayerProgress.mastered_lexemes),
## und Wörter ohne Übersetzungsaufgabe stehen nicht im Nenner (PlayerProgress.masterable).
## `StatsScreen.unit_rows` baut seine Zeilen aus `unit_tiers` — eine Zählregel, nicht zwei.
##
## Reine Rechnung ohne Zustand, Szene und Autoload, wie Experience und ChestReward (siehe
## tests/fortress_tier_test.gd). Wer die Stufe eines Laufs bestimmt, ist der WaveRunner.

const PROGRESS := preload("res://src/learning/player_progress.gd")

## Ab so viel Prozent gemeisterter Wörter einer Unit gilt Stufe 1, 2, 3, 4.
const THRESHOLDS_PERCENT := [10, 35, 60, 85]
const MAX_TIER := 4

## Festungs-HP je Stufe. Additiv auf den Grundwert, in dieselbe Summe wie die Skill-Boni
## (`max_health`, siehe WaveRunner._ready).
const HP_PER_TIER := 25


## Stufe 0..4 für `done` gemeisterte von `total` Wörtern. In Ganzzahlen verglichen
## (`done * 100 >= pct * total`): 3 von 30 sind genau 10 % und keine 9,999…
static func tier_for(done: int, total: int) -> int:
	if total <= 0:
		return 0
	var tier := 0
	for pct in THRESHOLDS_PERCENT:
		if done * 100 >= int(pct) * total:
			tier += 1
	return tier


## Der Unit-Schlüssel eines Lexems, „<book>/<unit>" — dieselbe Form wie der Scope-Schlüssel
## einer Unit (ContentRegistry._scope_keys). Leer, wenn das Lexem keine Unit hat
## (Grundwortschatz).
static func unit_key(entry: Dictionary) -> String:
	var book := str(entry.get("book", ""))
	if book.is_empty() or not entry.has("unit"):
		return ""
	return "%s/%d" % [book, int(entry["unit"])]


## Stand je Unit: „<book>/<unit>" -> { book, unit, done, total, tier, lexemes }.
##
## `lexemes` ist der Katalog (oder ein Teil davon), `mastered` die Menge aus
## PlayerProgress.mastered_lexemes. Nicht meisterbare Lexeme fallen hier heraus, damit
## kein Aufrufer das Filtern vergessen kann; Lexeme ohne Unit ebenso.
static func unit_tiers(lexemes: Array, mastered: Dictionary) -> Dictionary:
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
		group["tier"] = tier_for(int(group["done"]), int(group["total"]))
	return groups


## Zählt ein Lexem in die Gruppe `key`: eines mehr insgesamt, und eines mehr gemeistert,
## wenn es in der Menge steht. Die eine Zählregel für Units (hier) und Themen
## (StatsScreen.tag_rows).
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
## Kommt keine Unit vor (nur Grundwortschatz), ist die Stufe 0.
static func run_tier(scoped: Array, unit_stats: Dictionary) -> int:
	var lowest := -1
	for entry in scoped:
		var key := unit_key(entry)
		if key.is_empty():
			continue
		var tier := int((unit_stats.get(key, {}) as Dictionary).get("tier", 0))
		lowest = tier if lowest < 0 else mini(lowest, tier)
	return maxi(0, lowest)


## Zusätzliche Festungs-HP für `tier` Stufen.
static func health_bonus(tier: int) -> int:
	return maxi(0, tier) * HP_PER_TIER


## Was bis zur nächsten Stufe fehlt: { tier, needed } — `needed` Wörter mehr bringen Stufe
## `tier`. Leer, wenn die Unit schon auf der höchsten Stufe steht oder keine Wörter hat.
static func next_threshold(done: int, total: int) -> Dictionary:
	if total <= 0:
		return {}
	var tier := tier_for(done, total)
	if tier >= MAX_TIER:
		return {}
	var pct := int(THRESHOLDS_PERCENT[tier])
	# Aufgerundet und in Ganzzahlen: die kleinste Zahl `d` mit d * 100 >= pct * total.
	@warning_ignore("integer_division")
	var target := (pct * total + 99) / 100
	return {"tier": tier + 1, "needed": maxi(1, target - done)}
