class_name SpacedRepetition
extends RefCounted
## Lightweight SM-2-style scheduler for spaced repetition.
##
## Tracks per-item review state and decides when an item is due again.
## Kept intentionally minimal and self-contained so it can be swapped or
## extended without touching gameplay code. Persistence (save/load of the
## `_items` dictionary as JSON) is the caller's responsibility.

## item_id -> { ease: float, interval: int, reps: int, due: int }
var _items: Dictionary = {}


func register(item_id: String) -> void:
	if not _items.has(item_id):
		_items[item_id] = {"ease": 2.5, "interval": 0, "reps": 0, "due": 0}


## Records a review outcome. `quality` in 0..5 (SM-2 scale); >= 3 is a pass.
## `now` is a monotonically increasing session/day counter supplied by caller.
func review(item_id: String, quality: int, now: int) -> void:
	register(item_id)
	var it: Dictionary = _items[item_id]
	if quality < 3:
		it["reps"] = 0
		it["interval"] = 1
	else:
		it["reps"] += 1
		if it["reps"] == 1:
			it["interval"] = 1
		elif it["reps"] == 2:
			it["interval"] = 3
		else:
			it["interval"] = int(round(it["interval"] * it["ease"]))
		it["ease"] = max(1.3, it["ease"] + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
	it["due"] = now + it["interval"]


## Item ids that are due at or before `now`, most-overdue first.
func due_items(now: int) -> Array:
	var due: Array = []
	for id in _items:
		if _items[id]["due"] <= now:
			due.append(id)
	due.sort_custom(func(a, b): return _items[a]["due"] < _items[b]["due"])
	return due


func to_dict() -> Dictionary:
	return _items.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_items = data.duplicate(true)
