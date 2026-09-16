class_name SentenceSelector
extends RefCounted
## Welcher Satz drankommt (docs/adr/0004-satzbewertung-ohne-modell.md).
##
## Die Auswahl benutzt das VORHANDENE Schwierigkeitsmaß und baut kein zweites daneben —
## aus demselben Grund, aus dem Punkte und Erfahrung sich eines teilen (WaveGenerator):
## Grundschwierigkeit der Aufgabe minus Confidence des Spielers. Für einen Satz ist die
## Grundschwierigkeit sein `difficulty`, und die Confidence der Durchschnitt über die
## Lexeme, um derentwillen er gestellt wird (`sentence_lexemes`).
##
## Der Weg vom Satz zum Lehrplan geht ebenfalls über `sentence_lexemes`: Satz -> Lexem ->
## `book`/`unit` gegen `UserSettings.selected_scope()`. Ein Satz zählt zum Scope, wenn
## EINES seiner Lexeme dazu zählt — er wird ja um dieses Wortes willen gestellt.
##
## Pool (wie WaveGenerator.pool_from_settings, leere Einträge = keine Einschränkung):
##   { "scope": Array, "tags": Array, "grammar_tags": Array, "difficulty_max": int }

## Obergrenze der difficulty-Skala für die Normalisierung auf 0..1 — dieselbe wie in
## WaveGenerator, damit „schwer" in beiden Aufgabenarten dasselbe heißt.
const DIFFICULTY_MAX := WaveGenerator.DIFFICULTY_MAX

## Die Richtung, in der ein Satz übt: deutscher Satz, englische Antwort. Also dieselbe
## Richtung, deren Confidence der Lernstand für das einzelne Wort führt.
const DIRECTION := "de_to_en"

## Untergrenze des Gewichts. Auch ein längst sitzender Satz darf drankommen — sonst würde
## der Vorrat mit jedem gelernten Wort kleiner statt bunter.
const MIN_WEIGHT := 0.05


## Der Pool aus der Auswahl des aktiven Profils (Session-Setup) — EINE Quelle mit dem
## Kampf, damit ein Boss nicht in einem Buch fragt, das der Spieler abgewählt hat.
static func pool_from_settings(difficulty: int = 0) -> Dictionary:
	return {
		"scope": Array(UserSettings.selected_scope()),
		"tags": Array(UserSettings.selected_tags()),
		"grammar_tags": [],
		"difficulty_max": clampi(difficulty, 0, DIFFICULTY_MAX),
	}


## Der Pool eines Bosses: seine Auswahlregel über der Auswahl des Spielers. Ein Boss trägt
## seit ADR 0004 keine Sätze mehr selbst — er sagt, WELCHE Sätze zu ihm passen, und der
## Vorrat kommt aus dem Content (data/bosses/grammar_golem.json).
static func pool_for_boss(boss: Dictionary, difficulty: int = 0) -> Dictionary:
	var pool := pool_from_settings(difficulty)
	var rule: Dictionary = boss.get("sentence_rule", {})
	pool["grammar_tags"] = Array(rule.get("grammar_tags", []))
	var limit := int(rule.get("difficulty_max", 0))
	if limit > 0:
		pool["difficulty_max"] = limit
	return pool


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


## Der Lernstand zu einem Satz: das Mittel der Confidence über seine Lexeme, in der
## Richtung, die der Satz übt. Ohne Lexeme (oder ohne Lernstand) der neutrale Default —
## derselbe Nullpunkt, mit dem auch ein neues Monster startet.
static func confidence(sentence_id: String) -> float:
	var ids := lexeme_ids(sentence_id)
	if ids.is_empty():
		return PlayerProgress.DEFAULT_CONFIDENCE
	var sum := 0.0
	for lexeme_id in ids:
		sum += PlayerProgress.confidence("translate:%s:%s" % [DIRECTION, lexeme_id])
	return sum / float(ids.size())


## Das Netto-Maß `t - c`: Grundschwierigkeit minus Können, auf 0..1 normalisiert wie im
## WaveGenerator. Größer heißt: hier ist noch etwas zu holen.
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
	var out: Array = []
	for sentence in ContentRegistry.sentences.values():
		if matches(sentence, pool, in_scope):
			out.append(sentence)
	return out


## Passt ein Satz zum Pool? `in_scope` ist die vorberechnete Lexem-Menge des Scopes; eine
## LEERE Menge heißt „keine Einschränkung" (dieselbe Semantik wie im Wave-Pool).
static func matches(sentence: Dictionary, pool: Dictionary, in_scope: Dictionary = {}) -> bool:
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
	for lexeme_id in lexeme_ids(str(sentence.get("id", ""))):
		if in_scope.has(lexeme_id):
			return true
	return false


## Zieht einen Satz aus dem Pool. `exclude` (Satz-id -> true) hält die Sätze heraus, die in
## diesem Kampf schon gestellt wurden.
func pick(pool: Dictionary, exclude: Dictionary = {}) -> Dictionary:
	return pick_from(candidates(pool).filter(
			func(s): return not exclude.has(str((s as Dictionary).get("id", "")))))


## Zieht aus einer FERTIGEN Liste. Gewichtet nach dem Netto-Maß: was noch nicht sitzt,
## kommt öfter dran, aber nichts ist ausgeschlossen (MIN_WEIGHT).
##
## Getrennt von pick(), weil nicht jeder Aufrufer den Pool als Filter ausdrücken kann: die
## Werkbank siebt ihre Liste selbst (nur Sätze mit Schlüssel) und soll trotzdem ziehen wie
## das Spiel. Ein zweiter Ziehen-Code daneben wäre eine zweite Gewichtung.
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
