class_name WaveGenerator
extends RefCounted
## Wählt für einen Spawn eine konkrete Aufgabe und deren Darstellung.
##
## Ablauf (siehe docs/ARCHITECTURE.md, "Nutzung im Spiel"):
##   1. Kandidaten aus dem Wave-Pool erzeugen: task_definitions × passende Lexeme
##      (allowed_types / requires_relation / requires_form), gefiltert nach
##      task_types/direction/difficulty_max und den Lexem-tags.
##   2. Fällige (SpacedRepetition) bevorzugen, dann neue, dann beliebige.
##   3. Aufgabe über TaskResolver auflösen (prompt + accepted_answers).
##   4. monster_task_rules mappt (task_type, direction) -> monster_type + Basiswerte.
##   5. Tempo = Schwierigkeit: aus Aufgaben-Grundschwierigkeit + Confidence (+ Wellenfaktor).
##
## pick(pool) -> {
##   "task": Dictionary,          # aufgelöste Laufzeit-Aufgabe
##   "monster_def": Dictionary,   # reine Darstellung (monsters-Eintrag)
##   "speed": float, "damage": int, "reward": int,
## }  oder {} wenn nichts Spielbares gefunden wurde.

var _resolver := TaskResolver.new()

## Referenztempo = Nullpunkt der Schwierigkeitsskala (Netto-Können e = 0): die Confidence
## deckt die Grundschwierigkeit der Aufgabe genau. KEIN kosmetisches Attribut — Geschwindigkeit
## IST Schwierigkeit und entsteht ausschließlich hieraus. REFERENCE_SPEED zu ändern verschiebt
## die gesamte Skala für alle Aufgaben gleichzeitig; mit Vorsicht behandeln.
const REFERENCE_SPEED := 50.0
## Empfindlichkeit: wie stark das Netto-Können (c - t) das Tempo auslenkt. Klein halten,
## da jede Tempo-Änderung eine Schwierigkeits-Änderung ist.
const SPEED_SENSITIVITY := 0.3
## Obergrenze der difficulty-Skala für die Normalisierung auf 0..1.
const DIFFICULTY_MAX := 5

## Globaler Tempo-Multiplikator, vom WaveRunner aus der gewählten Wellen-Schwierigkeit gesetzt
## (1.0 = neutral, >1 schneller/schwerer, <1 langsamer/leichter). Ist selbst eine
## Schwierigkeits-Quelle und wirkt daher multiplikativ auf das Referenztempo.
var speed_scale: float = 1.0


func pick(pool: Dictionary) -> Dictionary:
	var candidates := _candidates(pool)
	if candidates.is_empty():
		return {}
	# Reihenfolge: fällige zuerst, dann neue, dann der Rest — innerhalb gemischt.
	var due := PlayerProgress.due_task_ids()
	var buckets := {"due": [], "new": [], "rest": []}
	for c in candidates:
		var id: String = c["learnable_id"]
		if id in due:
			buckets["due"].append(c)
		elif not PlayerProgress.has_seen(id):
			buckets["new"].append(c)
		else:
			buckets["rest"].append(c)

	# Erste nicht-leere Priorität durchprobieren, bis eine Aufgabe auflösbar ist.
	for key in ["due", "new", "rest"]:
		var pool_list: Array = buckets[key]
		pool_list.shuffle()
		for candidate in pool_list:
			var plan := _build_plan(candidate)
			if not plan.is_empty():
				return plan
	return {}


## Erzeugt alle spielbaren Kandidaten (Definition × Lexeme [× Form/Relation]) für den
## Wave-Pool. Jeder Kandidat kennt bereits seinen learnable_id für die Bucket-Zuordnung.
func _candidates(pool: Dictionary) -> Array:
	var task_types: Array = pool.get("task_types", [])
	var tags: Array = pool.get("tags", [])
	var direction := str(pool.get("direction", "")) # "" = beliebige Richtung
	var difficulty_max: int = int(pool.get("difficulty_max", 0)) # 0 = kein Limit
	var lexemes := ContentRegistry.lexemes_by_tags(tags) # leere tags -> alle Lexeme
	var result: Array = []
	for definition in ContentRegistry.task_definitions.values():
		var task_type := str(definition.get("task_type", ""))
		if not task_types.is_empty() and not (task_type in task_types):
			continue
		if direction != "" and str(definition.get("direction", "")) != direction:
			continue
		if difficulty_max > 0 and int(definition.get("difficulty", 1)) > difficulty_max:
			continue
		_expand(definition, lexemes, result)
	return result


## Verbindet eine Definition mit allen kompatiblen Lexemen und hängt die Kandidaten an.
## Relations-/Formaufgaben expandieren über die tatsächlich vorhandenen Relationen/Formen,
## sodass nie eine unauflösbare Instanz entsteht.
func _expand(definition: Dictionary, lexemes: Array, result: Array) -> void:
	var allowed: Array = definition.get("allowed_types", ["*"])
	var relation_req := str(definition.get("requires_relation", ""))
	var form_req := str(definition.get("requires_form", ""))
	for source in lexemes:
		if not _type_allowed(source, allowed):
			continue
		var source_id := str(source.get("id", ""))
		if relation_req != "":
			for rel in ContentRegistry.relations_of(source_id, relation_req):
				var target_id := str(rel.get("to_lexeme_id", ""))
				if target_id != "":
					result.append(_candidate(definition, source, {"target_lexeme_id": target_id}))
		elif form_req != "":
			if not ContentRegistry.forms_for(source_id, form_req).is_empty():
				result.append(_candidate(definition, source, {"form_type": form_req}))
		else:
			result.append(_candidate(definition, source, {}))


## Normalisiert die Aufgaben-Grundschwierigkeit (task_definition.difficulty,
## 1..DIFFICULTY_MAX) auf 0..1 — damit sie mit der Confidence vergleichbar ist.
func _difficulty_norm(difficulty: int) -> float:
	return clampf(float(difficulty - 1) / float(DIFFICULTY_MAX - 1), 0.0, 1.0)


## True, wenn der Lexem-Typ zur Definition passt (["*"] oder leer = alle Typen).
func _type_allowed(source: Dictionary, allowed: Array) -> bool:
	if allowed.is_empty() or "*" in allowed:
		return true
	return str(source.get("type", "")) in allowed


func _candidate(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var lid := _resolver.learnable_id(
		str(definition.get("task_type", "")),
		str(definition.get("direction", "")),
		str(source.get("id", "")),
		extra)
	return {"definition": definition, "source": source, "extra": extra, "learnable_id": lid}


func _build_plan(candidate: Dictionary) -> Dictionary:
	var task := _resolver.resolve(candidate["definition"], candidate["source"], candidate["extra"])
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

	# Tempo = wie weit die Confidence die Grundschwierigkeit der Aufgabe übersteigt.
	# Geschwindigkeit IST Schwierigkeit und entsteht ausschließlich hieraus:
	#   t = Grundschwierigkeit der Aufgaben-Art (task_definition.difficulty, 0..1)
	#   c = Confidence des Spielers für diese konkrete Aufgabe (0..1)
	#   e = c - t   (Netto-Können; e<0 -> langsamer, e=0 -> Referenztempo, e>0 -> schneller)
	# Nur wenn die Confidence die Grundschwierigkeit übersteigt, wird das Monster schneller.
	# speed_scale trägt zusätzlich die gewählte Wellen-Schwierigkeit.
	var t := _difficulty_norm(int(task.get("difficulty", 1)))
	var c := PlayerProgress.confidence(task["learnable_id"])
	var factor := clampf(1.0 + SPEED_SENSITIVITY * (c - t), 0.7, 1.3)
	var speed := REFERENCE_SPEED * factor * speed_scale
	return {
		"task": task,
		"monster_def": monster_def,
		"speed": speed,
		"damage": int(rule.get("base_damage", 10)),
		"reward": int(rule.get("base_reward", 10)),
	}
