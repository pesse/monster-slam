extends GdUnitTestSuite
## Die Level einer Unit auf der Gebietskarte und ihre Stufe (MapLevel, FortressTier.part_tiers).


func _keys(levels: Array) -> Array:
	return levels.map(func(l): return l["key"])


func test_four_parts_give_six_levels() -> void:
	var levels := MapLevel.levels_for("access4", 2, 4)
	assert_array(_keys(levels)).is_equal(["t1", "t2", "t3", "t4", "all", "boss"])
	assert_array(levels[0]["scope"]).is_equal(["access4/2/1"])
	assert_array(levels[4]["scope"]).is_equal(["access4/2"])
	assert_array(levels[5]["scope"]).is_equal(["access4/2"])


func test_two_parts_keep_the_whole_unit_level() -> void:
	assert_array(_keys(MapLevel.levels_for("access4", 2, 2))).is_equal(["t1", "t2", "all", "boss"])


## Bei nur einem Teil wäre „Gesamt" dasselbe Level noch einmal.
func test_one_part_drops_the_whole_unit_level() -> void:
	assert_array(_keys(MapLevel.levels_for("access4", 2, 1))).is_equal(["t1", "boss"])


func test_no_words_no_levels() -> void:
	assert_array(MapLevel.levels_for("access4", 2, 0)).is_empty()


func _lexeme(id: String, unit: int) -> Dictionary:
	return {"id": id, "book": "b", "unit": unit, "tags": []}


## Teil 1 hat 4 Wörter, 2 gemeistert (50 % -> Stufe 2), Teil 2 hat 4, keines gemeistert.
func test_part_tiers_count_each_part_on_its_own() -> void:
	var lexemes: Array = []
	var parts := {}
	for i in 8:
		var id := "w%d" % i
		lexemes.append(_lexeme(id, 1))
		parts[id] = 1 if i < 4 else 2
	var mastered := {"w0": true, "w1": true}
	var tiers := FortressTier.part_tiers(lexemes, mastered, func(id): return int(parts.get(id, 0)))
	assert_int(int(tiers["b/1/1"]["done"])).is_equal(2)
	assert_int(int(tiers["b/1/1"]["tier"])).is_equal(2)
	assert_int(int(tiers["b/1/2"]["tier"])).is_equal(0)
	assert_int(int(tiers["b/1/2"]["total"])).is_equal(4)


func test_part_tiers_skip_words_without_translation_and_without_part() -> void:
	var lexemes := [
		_lexeme("a", 1),
		{"id": "x", "book": "b", "unit": 1, "tags": [], "excluded_task_types": ["translate"]},
		_lexeme("loose", 1),
	]
	var parts := {"a": 1, "x": 1}
	var tiers := FortressTier.part_tiers(lexemes, {}, func(id): return int(parts.get(id, 0)))
	assert_int(int(tiers["b/1/1"]["total"])).is_equal(1)


## Gesamt ist die Unit selbst; der Boss hat keine Stufe.
func test_tier_of_reads_part_unit_and_boss() -> void:
	var levels := MapLevel.levels_for("b", 1, 2)
	var units := {"b/1": {"tier": 3, "done": 7, "total": 10}}
	var parts := {"b/1/2": {"tier": 1, "done": 1, "total": 5}}
	assert_int(MapLevel.tier_of(levels[0], units, parts)).is_equal(0)
	assert_int(MapLevel.tier_of(levels[1], units, parts)).is_equal(1)
	assert_int(MapLevel.tier_of(levels[2], units, parts)).is_equal(3)
	assert_int(MapLevel.tier_of(levels[3], units, parts)).is_equal(0)
	assert_dict(MapLevel.counts_of(levels[2], units, parts)).is_equal({"done": 7, "total": 10})
