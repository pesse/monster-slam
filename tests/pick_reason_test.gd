extends GdUnitTestSuite
## Der Grund, warum WaveGenerator ein Wort gewählt hat, und das Gewicht, nach dem gezogen
## wird (ADR 0018): Gruppe, Gewicht und „schon gezeigt" kommen aus derselben Rechnung
## (ordered()), die Summen zählen die Kandidaten je Gruppe.
## Statisch und mit erfundenen Kandidaten — keine Sprachdaten, kein Lernstand.

const GENERATOR := preload("res://src/battle/wave_generator.gd")
const NOW := 1790877600
const DAY := 86400

## Erfundener Lernstand je learnable_id, wie PlayerProgress.state_of ihn liefert.
const STATES := {
	"due": {"confidence": 0.5, "last_seen": NOW - 2 * DAY, "due_at": NOW - DAY},
	"rest": {"confidence": 0.5, "last_seen": NOW - 3600, "due_at": NOW + 8 * 3600},
	"shown": {"confidence": 0.5, "last_seen": NOW - 3600, "due_at": NOW + 480},
}


func _cand(source_id: String, learnable_id: String) -> Dictionary:
	return {"source": {"id": source_id}, "learnable_id": learnable_id,
		"definition": {}, "extra": {}}


func _state(id: String) -> Dictionary:
	return STATES.get(id, {})


func _ordered() -> Array:
	return GENERATOR.ordered(
			[_cand("a", "due"), _cand("b", "new"), _cand("c", "rest"), _cand("d", "shown")],
			_state, {"d": 0}, NOW)


func _find(order: Array, id: String) -> int:
	for i in order.size():
		if order[i]["learnable_id"] == id:
			return i
	return -1


func test_ordered_marks_the_group_of_every_candidate() -> void:
	var order := _ordered()
	var groups := {}
	for c in order:
		groups[c["learnable_id"]] = [c["group"], c["repeat"]]
	assert_dict(groups).is_equal({"due": ["due", false], "new": ["new", false],
			"rest": ["rest", false], "shown": ["rest", true]})
	# Das schon gezeigte Wort steht hinten, gleich wie es gewichtet ist.
	assert_str(str(order[-1]["learnable_id"])).is_equal("shown")


func test_the_reason_names_group_position_and_counts() -> void:
	var order := _ordered()
	var i := _find(order, "new")
	var why: Dictionary = GENERATOR.pick_reason(order, i, false, 0.25, 0)
	assert_str(why["group"]).is_equal("new")
	assert_int(why["pos"]).is_equal(i)
	assert_int(why["pool"]).is_equal(4)
	assert_dict(why["counts"]).is_equal({"due": 1, "new": 1, "rest": 1, "repeat": 1})
	assert_float(why["weight"]).is_greater(0.0)


func test_the_description_reads_as_one_line() -> void:
	var c := _cand("a", "due")
	c["group"] = "due"
	c["weight"] = 0.75
	var why: Dictionary = GENERATOR.pick_reason([c], 0, false, -0.47, NOW - 2 * DAY)
	assert_str(GENERATOR.describe_reason(why, NOW)).is_equal(
			"fällig (seit 2 T) · Platz 1 von 1 · fällig 1 / neu 0 / Rest 0 / schon gezeigt 0 · t−c -0.47 · Gewicht 0.75")


func test_a_repeat_and_the_fallback_are_named() -> void:
	var order := _ordered()
	var why: Dictionary = GENERATOR.pick_reason(order, 3, true, 0.0, NOW + 480)
	var text: String = GENERATOR.describe_reason(why, NOW)
	assert_str(text).starts_with("Wiederholung, Rest (in 8 min)")
	assert_str(text).ends_with("trotz Wort auf dem Feld")


func test_the_reason_names_when_the_word_was_last_answered() -> void:
	var c := _cand("a", "a.de")
	c["group"] = "rest"
	c["last_seen"] = NOW - 7200
	var why: Dictionary = GENERATOR.pick_reason([c], 0, false, 0.0, NOW + DAY)
	assert_str(GENERATOR.describe_reason(why, NOW)).starts_with("Rest (in 1 T), zuletzt vor 2 h ·")


# --- Gewichte (selection_weight) ------------------------------------------------

func _weight(confidence: float, last_seen: int, due_at: int, word_seen := 0) -> float:
	return GENERATOR.selection_weight(
			{"confidence": confidence, "last_seen": last_seen, "due_at": due_at},
			maxi(word_seen, last_seen), NOW)


## Gemeistert heißt selten: ein gemeistertes, fälliges Wort wiegt ein Mehrfaches weniger
## als ein unsicheres, fälliges — aber nicht null.
func test_a_mastered_word_weighs_less_but_not_nothing() -> void:
	var unsure := _weight(0.5, NOW - DAY, NOW)
	var mastered := _weight(0.9, NOW - 3 * DAY, NOW)
	assert_float(mastered).is_less(unsure / 3.0)
	assert_float(mastered).is_greater(0.0)
	assert_float(_weight(1.0, NOW - 3 * DAY, NOW)).is_greater(0.0)


## Ein Fehler kommt schnell wieder: zwanzig Minuten danach wiegt die Aufgabe mehr als ein
## neues Wort.
func test_a_failed_word_outweighs_a_new_one_soon() -> void:
	var failed := _weight(0.4, NOW - 1200, NOW - 600)
	assert_float(failed).is_greater(GENERATOR.NEW_WEIGHT)


## Eben beantwortet wiegt fast nichts, auch in der anderen Richtung desselben Worts.
func test_a_word_just_answered_waits() -> void:
	assert_float(_weight(0.5, NOW - 60, NOW + DAY)).is_less(0.01)
	var other_direction := _weight(0.5, NOW - 2 * DAY, NOW - DAY, NOW - 60)
	assert_float(other_direction).is_less(0.01)


## Die Dringlichkeit ist gedeckelt: ein Wort, das seit Wochen liegt, verdrängt nicht alles.
func test_urgency_is_capped() -> void:
	var long_ago := _weight(0.5, NOW - 60 * DAY, NOW - 59 * DAY)
	assert_float(long_ago).is_equal_approx(0.5 * GENERATOR.URGENCY_CAP, 1e-6)


## Viele fällige Wiederholungen verdrängen ein neues Wort nicht: die neuen tragen zusammen
## mindestens NEW_SHARE des Gewichts.
func test_new_words_keep_their_share() -> void:
	var cands: Array = []
	var states := {}
	for i in 30:
		var id := "old%d" % i
		cands.append(_cand(id, id))
		states[id] = {"confidence": 0.3, "last_seen": NOW - 5 * DAY, "due_at": NOW - 4 * DAY}
	cands.append(_cand("fresh", "fresh"))
	var order := GENERATOR.ordered(cands, func(id): return states.get(id, {}), {}, NOW)
	var total := 0.0
	var fresh := 0.0
	for c in order:
		total += float(c["weight"])
		if c["group"] == "new":
			fresh += float(c["weight"])
	assert_float(fresh / total).is_equal_approx(GENERATOR.NEW_SHARE, 1e-6)


## Gezogen wird nach Gewicht: das schwere Wort steht fast immer vor dem leichten, nicht
## immer — und keins fällt weg.
func test_the_order_follows_the_weights() -> void:
	var first_heavy := 0
	for i in 200:
		var order := GENERATOR.weighted_order([
			{"learnable_id": "light", "weight": 0.1}, {"learnable_id": "heavy", "weight": 0.9}])
		assert_int(order.size()).is_equal(2)
		if order[0]["learnable_id"] == "heavy":
			first_heavy += 1
	assert_int(first_heavy).is_between(160, 196)
