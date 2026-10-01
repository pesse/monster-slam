extends GdUnitTestSuite
## Der Grund, warum WaveGenerator ein Wort gewählt hat: Gruppe und „schon gezeigt" kommen
## aus derselben Sortierung (ordered()), die Summen zählen die Kandidaten je Gruppe.
## Statisch und mit erfundenen Kandidaten — keine Sprachdaten, kein Lernstand.

const GENERATOR := preload("res://src/battle/wave_generator.gd")
const NOW := 1790877600


func _cand(source_id: String, learnable_id: String) -> Dictionary:
	return {"source": {"id": source_id}, "learnable_id": learnable_id,
		"definition": {}, "extra": {}}


func _ordered() -> Array:
	var seen := func(id: String) -> bool: return id != "new"
	return GENERATOR.ordered(
			[_cand("a", "due"), _cand("b", "new"), _cand("c", "rest"), _cand("d", "shown")],
			["due"], seen, {"d": 0})


func test_ordered_marks_the_group_of_every_candidate() -> void:
	var groups := _ordered().map(func(c): return [c["group"], c["repeat"]])
	assert_array(groups).is_equal(
			[["due", false], ["new", false], ["rest", false], ["rest", true]])


func test_the_reason_names_group_position_and_counts() -> void:
	var why: Dictionary = GENERATOR.pick_reason(_ordered(), 1, false, 0.25, 0)
	assert_str(why["group"]).is_equal("new")
	assert_int(why["pos"]).is_equal(1)
	assert_int(why["pool"]).is_equal(4)
	assert_dict(why["counts"]).is_equal({"due": 1, "new": 1, "rest": 1, "repeat": 1})


func test_the_description_reads_as_one_line() -> void:
	var why: Dictionary = GENERATOR.pick_reason(_ordered(), 0, false, -0.47, NOW - 2 * 86400)
	assert_str(GENERATOR.describe_reason(why, NOW)).is_equal(
			"fällig (seit 2 T) · Platz 1 von 4 · fällig 1 / neu 1 / Rest 1 / schon gezeigt 1 · t−c -0.47")


func test_a_repeat_and_the_fallback_are_named() -> void:
	var why: Dictionary = GENERATOR.pick_reason(_ordered(), 3, true, 0.0, NOW + 480)
	var text: String = GENERATOR.describe_reason(why, NOW)
	assert_str(text).starts_with("Wiederholung, Rest (in 8 min)")
	assert_str(text).ends_with("trotz Wort auf dem Feld")


## Der Rest nach Abstand: vor einer Minute Beantwortetes kommt nie vor dem, was eine
## Stunde her ist, auch mit Zufall; der Abstand gilt am Grundwort, über alle Richtungen.
func test_the_rest_comes_by_staleness() -> void:
	var last := {"old.de": NOW - 3600, "old.en": NOW - 3600, "fresh.de": NOW - 60,
			"fresh.en": NOW - 30000}
	var seen := func(_id: String) -> bool: return true
	var at := func(id: String) -> int: return int(last.get(id, 0))
	for i in 20:
		var order: Array = GENERATOR.ordered(
				[_cand("fresh", "fresh.de"), _cand("fresh", "fresh.en"), _cand("mid", "mid.de"),
				_cand("old", "old.de")], [], seen, {}, at, NOW)
		# „fresh" hat über seine andere Richtung (vor 30000 s) den jüngsten Abstand
		# nicht — am Grundwort zählt die letzte Antwort: vor 60 s.
		assert_str(str(order[-1]["source"]["id"])).is_equal("fresh")
		assert_str(str(order[-2]["source"]["id"])).is_equal("fresh")
		assert_int(int(order[-1]["last_seen"])).is_equal(NOW - 60)
		# Nie beantwortet (mid) steht vorn.
		assert_str(str(order[0]["source"]["id"])).is_equal("mid")


func test_the_reason_names_when_the_word_was_last_answered() -> void:
	var c := _cand("a", "a.de")
	c["group"] = "rest"
	c["last_seen"] = NOW - 7200
	var why: Dictionary = GENERATOR.pick_reason([c], 0, false, 0.0, NOW + 86400)
	assert_str(GENERATOR.describe_reason(why, NOW)).starts_with("Rest (in 1 T), zuletzt vor 2 h ·")
