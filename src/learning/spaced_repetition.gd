class_name SpacedRepetition
extends RefCounted
## Lightweight SM-2-style scheduler for spaced repetition.
##
## Tracks per-item review state and decides when an item is due again.
## Kept intentionally minimal and self-contained so it can be swapped or
## extended without touching gameplay code. Persistence (save/load of the
## `_items` dictionary as JSON) is the caller's responsibility.
##
## Zeitbasis sind Unix-Sekunden (`now`). Ein Fehler setzt die Aufgabe nach
## RELEARN_SECONDS wieder auf fällig — noch in derselben Sitzung, nicht erst morgen.
## Richtige Antworten rechnen in Tagen und werden zu Beginn des lokalen Tages fällig
## (`utc_offset`): wer abends übt, hat das Wort am nächsten Nachmittag schon wieder,
## nicht erst um dieselbe Uhrzeit.
##
## Nur eine FÄLLIGE Aufgabe rückt im Plan vor. Ein Wort kommt auch außer der Reihe dran
## (der Pool ist klein), und drei richtige Antworten an einem Nachmittag hießen sonst
## 1 → 3 → 8 Tage, ohne dass ein einziger Tag dazwischen lag. Ein Fehler zählt immer.

const DAY := 86400
## Abstand nach einer falschen Antwort.
const RELEARN_SECONDS := 600

## Abstand der lokalen Zeit zu UTC in Sekunden; setzt der Besitzer (PlayerProgress).
var utc_offset: int = 0

## item_id -> { ease: float, interval: int (Tage), reps: int, due_at: int (unix) }
var _items: Dictionary = {}


func register(item_id: String) -> void:
	if not _items.has(item_id):
		_items[item_id] = {"ease": 2.5, "interval": 0, "reps": 0, "due_at": 0}


## Records a review outcome. `quality` in 0..5 (SM-2 scale); >= 3 is a pass.
## `now` in Unix-Sekunden.
func review(item_id: String, quality: int, now: int) -> void:
	register(item_id)
	var it: Dictionary = _items[item_id]
	if quality < 3:
		it["reps"] = 0
		it["interval"] = 0
		it["due_at"] = now + RELEARN_SECONDS
		return
	if now < int(it["due_at"]):
		return
	it["reps"] += 1
	if it["reps"] == 1:
		it["interval"] = 1
	elif it["reps"] == 2:
		it["interval"] = 3
	else:
		it["interval"] = int(round(it["interval"] * it["ease"]))
	it["ease"] = max(1.3, it["ease"] + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
	it["due_at"] = _day_start(now) + int(it["interval"]) * DAY


## Item ids that are due at or before `now`, most-overdue first.
func due_items(now: int) -> Array:
	var due: Array = []
	for id in _items:
		if int(_items[id]["due_at"]) <= now:
			due.append(id)
	due.sort_custom(func(a, b): return _items[a]["due_at"] < _items[b]["due_at"])
	return due


## Fälligkeit (unix) eines Items; 0 für ein unbekanntes.
func due_at(item_id: String) -> int:
	return int(_items.get(item_id, {}).get("due_at", 0))


func to_dict() -> Dictionary:
	return _items.duplicate(true)


## Ältere Stände tragen `due` als UTC-Tageszähler statt `due_at`: fällig ab Mitternacht
## UTC dieses Tages — umgerechnet ist das derselbe Zeitpunkt.
func from_dict(data: Dictionary) -> void:
	_items = data.duplicate(true)
	for it in _items.values():
		if it.has("due"):
			if not it.has("due_at"):
				it["due_at"] = int(it["due"]) * DAY
			it.erase("due")


## Beginn des lokalen Tages, in den `now` fällt (unix).
func _day_start(now: int) -> int:
	return int(floor(float(now + utc_offset) / DAY)) * DAY - utc_offset
