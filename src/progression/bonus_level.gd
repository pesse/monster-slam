class_name BonusLevel
extends RefCounted
## Bonus-Level: Formen älterer Wörter, die eine spätere Lektion lehrt (ADR 0012) — das
## Perfekt der Verben aus Lektion 1–10 in Lektion 11 —, oder zusätzliche Wörter zu einer
## Unit (Wort-Bonus, ADR 0013).
##
## WAS ein Bonus ist, leitet ContentRegistry aus den Daten ab (_index_bonuses,
## bonuses_of). Hier steht, wie er gezählt und benannt wird. Er zählt nicht zur Festung
## und nicht zu den Wörtern seiner Unit, sondern für sich: gemeisterte von allen seinen
## Aufgaben. Die eine Stelle dafür — Karte und Statistik zählen hier.
##
## Reine Rechnung ohne Zustand, wie FortressTier (tests/bonus_level_test.gd).

## Der Name des Punkts auf der Gebietskarte (assets/maps/<book>/map.json, unter `areas`):
## „bonus/<lektion>/<formart>", beim Wort-Bonus „bonus/0/<thema>". Der Punkt trägt neben x
## und y den `title`.
static func map_key(bonus: Dictionary) -> String:
	return "bonus/%d/%s" % [int(bonus["part"]), str(bonus.get("topic", bonus.get("form_type", "")))]


## Der Titel eines Bonus — was er enthält, etwa „Perfekt der Verben aus Lektion 1–10". Steht
## am Punkt in map.json (`layout` ist MapLayout.data); ohne ihn „Bonus · <Lektion>", beim
## Wort-Bonus „Bonus · <Unit>".
static func title(bonus: Dictionary, layout: Dictionary) -> String:
	var areas: Dictionary = layout.get("areas", {}) if layout.get("areas") is Dictionary else {}
	var area: Dictionary = areas.get(str(int(bonus["unit"])), {}) \
			if areas.get(str(int(bonus["unit"]))) is Dictionary else {}
	var point: Variant = area.get(map_key(bonus))
	if point is Dictionary and not str((point as Dictionary).get("title", "")).is_empty():
		return str(point["title"])
	if int(bonus["part"]) <= 0:
		return "Bonus · %s" % BookNaming.unit_label(str(bonus["book"]), int(bonus["unit"]))
	return "Bonus · %s" % BookNaming.part_label(str(bonus["book"]), int(bonus["unit"]),
			int(bonus["part"]))


## Gemeistert / gesamt eines Bonus: { done, total } über seine Aufgaben (`task_ids`).
## `is_mastered` sagt für eine learnable_id, ob sie sitzt (PlayerProgress.is_mastered).
static func counts(bonus: Dictionary, is_mastered: Callable) -> Dictionary:
	var ids: Array = bonus.get("task_ids", [])
	var done := 0
	for id in ids:
		if bool(is_mastered.call(str(id))):
			done += 1
	return {"done": done, "total": ids.size()}


## Der Anteil 0..1 eines Bonus aus `counts` — für den Stern unter dem Unit-Ort.
static func share(counted: Dictionary) -> float:
	var total := int(counted.get("total", 0))
	if total <= 0:
		return 0.0
	return clampf(float(counted.get("done", 0)) / float(total), 0.0, 1.0)


## Die Anteile aller Boni einer Liste in ihrer Reihenfolge — `node["bonus"]` für MapCanvas.
static func shares(bonuses: Array, is_mastered: Callable) -> Array:
	return bonuses.map(func(b): return share(counts(b, is_mastered)))
