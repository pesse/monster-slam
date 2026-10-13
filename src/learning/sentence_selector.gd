class_name SentenceSelector
extends RefCounted
## Welcher Satz drankommt (ADR 0004). Maß ist `t - c`: `difficulty` des Satzes minus die
## mittlere Confidence seiner Lexeme (`sentence_lexemes`). Ein Satz zählt zum Scope des
## Laufs, wenn eines seiner Lexeme dazu zählt.
##
## Pool (leere Einträge = keine Einschränkung):
##   { "scope": Array, "tags": Array, "grammar_tags": Array, "difficulty_max": int }

## Obergrenze der difficulty-Skala für die Normalisierung auf 0..1.
const DIFFICULTY_MAX := WaveGenerator.DIFFICULTY_MAX

## Die Richtung, in der ein Satz übt: deutscher Satz, englische Antwort.
const DIRECTION := "de_to_en"

## Untergrenze des Gewichts: auch ein längst sitzender Satz darf drankommen.
const MIN_WEIGHT := 0.05


## Der Pool über einem Bereich aus Scope und Themen.
static func pool_for_scope(scope: Array, tags: Array, difficulty: int = 0) -> Dictionary:
	return {
		"scope": scope.duplicate(),
		"tags": tags.duplicate(),
		"grammar_tags": [],
		"difficulty_max": clampi(difficulty, 0, DIFFICULTY_MAX),
	}


## Der Pool aus dem Bereich des Laufs (RunRequest).
static func pool_from_settings(difficulty: int = 0) -> Dictionary:
	return pool_for_scope(RunRequest.scope(), RunRequest.tags(), difficulty)


## Der Pool eines Bosses: seine `sentence_rule` über dem Bereich; ohne `base` der des Laufs.
static func pool_for_boss(boss: Dictionary, difficulty: int = 0, base: Dictionary = {}) -> Dictionary:
	var pool := base.duplicate(true) if not base.is_empty() else pool_from_settings(difficulty)
	var rule: Dictionary = boss.get("sentence_rule", {})
	pool["grammar_tags"] = Array(rule.get("grammar_tags", []))
	var limit := int(rule.get("difficulty_max", 0))
	if limit > 0:
		pool["difficulty_max"] = limit
	return pool


## Alle Satz-Lexem-Verknüpfungen in einem Durchlauf: Satz-id -> [Lexem-ids].
static func links() -> Dictionary:
	var out := {}
	for entry in ContentRegistry.sentence_lexemes.values():
		var sentence_id := str((entry as Dictionary).get("sentence_id", ""))
		var lexeme_id := str((entry as Dictionary).get("lexeme_id", ""))
		if sentence_id.is_empty() or lexeme_id.is_empty():
			continue
		if not out.has(sentence_id):
			out[sentence_id] = []
		if not lexeme_id in out[sentence_id]:
			(out[sentence_id] as Array).append(lexeme_id)
	return out


## Die Lexeme, um derentwillen ein Satz gestellt wird.
static func lexeme_ids(sentence_id: String) -> Array:
	var out: Array = []
	for entry in ContentRegistry.sentence_lexemes.values():
		if str((entry as Dictionary).get("sentence_id", "")) != sentence_id:
			continue
		var lexeme_id := str((entry as Dictionary).get("lexeme_id", ""))
		if not lexeme_id.is_empty() and not (lexeme_id in out):
			out.append(lexeme_id)
	return out


## Der Lernstand zu einem Satz: das Mittel der Confidence über seine Lexeme in DIRECTION.
## Ohne Lexeme PlayerProgress.DEFAULT_CONFIDENCE.
static func confidence(sentence_id: String) -> float:
	var ids := lexeme_ids(sentence_id)
	if ids.is_empty():
		return PlayerProgress.DEFAULT_CONFIDENCE
	var sum := 0.0
	for lexeme_id in ids:
		sum += PlayerProgress.confidence("translate:%s:%s" % [DIRECTION, lexeme_id])
	return sum / float(ids.size())


## Das Netto-Maß `t - c`, `t` auf 0..1 normalisiert. Größer heißt: noch etwas zu holen.
static func net_difficulty(sentence: Dictionary) -> float:
	var t := clampf(float(sentence.get("difficulty", 1)) / float(DIFFICULTY_MAX), 0.0, 1.0)
	return t - confidence(str(sentence.get("id", "")))


## Alle Sätze, die zum Pool passen.
func candidates(pool: Dictionary) -> Array:
	var scope: Array = pool.get("scope", [])
	var tags: Array = pool.get("tags", [])
	var in_scope := {}
	if not scope.is_empty() or not tags.is_empty():
		for lexeme in ContentRegistry.lexemes_scoped(scope, tags):
			in_scope[str((lexeme as Dictionary).get("id", ""))] = true
		# Trifft der Filter kein Lexem, bleibt nichts; für `matches` hieße {} „alles“.
		if in_scope.is_empty():
			return []
	var out: Array = []
	var linked := links() if not in_scope.is_empty() else {}
	for sentence in ContentRegistry.sentences.values():
		if matches(sentence, pool, in_scope, linked):
			out.append(sentence)
	return out


## Passt ein Satz zum Pool? `in_scope` ist die vorberechnete Lexem-Menge des Scopes, leer
## heißt „keine Einschränkung“. `linked` ist `links()`; ohne wird je Satz gesucht.
static func matches(sentence: Dictionary, pool: Dictionary, in_scope: Dictionary = {},
		linked: Dictionary = {}) -> bool:
	var difficulty_max := int(pool.get("difficulty_max", 0))
	if difficulty_max > 0 and int(sentence.get("difficulty", 1)) > difficulty_max:
		return false
	var wanted: Array = pool.get("grammar_tags", [])
	if not wanted.is_empty():
		var hit := false
		for tag in sentence.get("grammar_tags", []):
			if str(tag) in wanted:
				hit = true
				break
		if not hit:
			return false
	if in_scope.is_empty():
		return true
	var id := str(sentence.get("id", ""))
	for lexeme_id in (linked.get(id, []) if not linked.is_empty() else lexeme_ids(id)):
		if in_scope.has(lexeme_id):
			return true
	return false


## Zieht einen Satz aus dem Pool. `exclude` (Satz-id -> true) hält die Sätze heraus, die in
## diesem Kampf schon gestellt wurden.
func pick(pool: Dictionary, exclude: Dictionary = {}) -> Dictionary:
	return pick_from(candidates(pool).filter(
			func(s): return not exclude.has(str((s as Dictionary).get("id", "")))))


## Zieht aus einer fertigen Liste, gewichtet nach dem Netto-Maß (mindestens MIN_WEIGHT).
static func pick_from(pickable: Array) -> Dictionary:
	if pickable.is_empty():
		return {}
	var weights: Array = []
	var total := 0.0
	for sentence in pickable:
		var weight := maxf(MIN_WEIGHT, net_difficulty(sentence) + MIN_WEIGHT)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in pickable.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return pickable[i]
	return pickable[pickable.size() - 1]
