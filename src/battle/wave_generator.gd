class_name WaveGenerator
extends RefCounted
## Wählt für einen Spawn eine konkrete Aufgabe und deren Darstellung.
##
## Ablauf (siehe docs/ARCHITECTURE.md, "Nutzung im Spiel"):
##   1. Kandidaten-task_templates aus dem Wave-Pool (task_types/tags/difficulty).
##   2. Fällige (SpacedRepetition) bevorzugen, dann neue, dann beliebige.
##   3. Aufgabe über TaskResolver auflösen (prompt + accepted_answers).
##   4. monster_task_rules mappt (task_type, direction) -> monster_type + Basiswerte.
##   5. Tempo/Schwierigkeit aus PlayerProgress.confidence skalieren.
##
## pick(pool) -> {
##   "task": Dictionary,          # aufgelöste Laufzeit-Aufgabe
##   "monster_def": Dictionary,   # reine Darstellung (monsters-Eintrag)
##   "speed": float, "damage": int, "reward": int,
## }  oder {} wenn nichts Spielbares gefunden wurde.

var _resolver := TaskResolver.new()


func pick(pool: Dictionary) -> Dictionary:
	var candidates := _candidates(pool)
	if candidates.is_empty():
		return {}
	# Reihenfolge: fällige zuerst, dann neue, dann der Rest — innerhalb gemischt.
	var due := PlayerProgress.due_task_ids()
	var buckets := {"due": [], "new": [], "rest": []}
	for t in candidates:
		var id := str(t.get("id", ""))
		if id in due:
			buckets["due"].append(t)
		elif not PlayerProgress.has_seen(id):
			buckets["new"].append(t)
		else:
			buckets["rest"].append(t)

	# Erste nicht-leere Priorität durchprobieren, bis eine Aufgabe auflösbar ist.
	for key in ["due", "new", "rest"]:
		var pool_list: Array = buckets[key]
		pool_list.shuffle()
		for template in pool_list:
			var plan := _build_plan(template)
			if not plan.is_empty():
				return plan
	return {}


func _candidates(pool: Dictionary) -> Array:
	var task_types: Array = pool.get("task_types", [])
	var tags: Array = pool.get("tags", [])
	var direction := str(pool.get("direction", "")) # "" = beliebige Richtung
	var difficulty_max: int = int(pool.get("difficulty_max", 0)) # 0 = kein Limit
	var result: Array = []
	for template in ContentRegistry.task_templates.values():
		if str(template.get("review_status", "approved")) != "approved":
			continue
		if not task_types.is_empty() and not (template.get("task_type", "") in task_types):
			continue
		if direction != "" and str(template.get("direction", "")) != direction:
			continue
		if difficulty_max > 0 and int(template.get("difficulty", 1)) > difficulty_max:
			continue
		if not tags.is_empty() and not _matches_tags(template, tags):
			continue
		result.append(template)
	return result


## True, wenn das Quell-Lexem der Aufgabe mindestens einen der Tags trägt.
func _matches_tags(template: Dictionary, tags: Array) -> bool:
	var lexeme := ContentRegistry.get_entry("lexemes", str(template.get("source_lexeme_id", "")))
	for tag in lexeme.get("tags", []):
		if tag in tags:
			return true
	return false


func _build_plan(template: Dictionary) -> Dictionary:
	var task := _resolver.resolve(template)
	if task.is_empty():
		return {}
	var rule := ContentRegistry.monster_rule_for(task["task_type"], task["direction"])
	if rule.is_empty():
		push_warning("WaveGenerator: keine monster_task_rule für (%s, %s)" % [task["task_type"], task["direction"]])
		return {}
	var monster_def := ContentRegistry.get_entry("monsters", str(rule.get("monster_type", "")))
	if monster_def.is_empty():
		push_warning("WaveGenerator: unbekannter monster_type '%s'" % rule.get("monster_type", ""))
		return {}

	# Confidence skaliert das Tempo: gut gekonnt -> schneller (mehr Druck),
	# neu/unsicher -> langsamer (mehr Zeit zum Abrufen).
	var conf := PlayerProgress.confidence(task["template_id"])
	var speed := float(rule.get("base_speed", 40.0)) * (0.7 + 0.6 * conf)
	return {
		"task": task,
		"monster_def": monster_def,
		"speed": speed,
		"damage": int(rule.get("base_damage", 10)),
		"reward": int(rule.get("base_reward", 10)),
	}
