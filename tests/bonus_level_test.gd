extends GdUnitTestSuite
## Bonus-Level (ADR 0012): wie ein Bonus zählt und heißt (BonusLevel), wie er auf der
## Gebietskarte steht und gewählt wird (MapLevel), welche Festung er hat (FortressTier) und
## wie er in der Statistik steht (StatsScreen.with_bonus_rows). Was ein Bonus ist, prüft
## tests/form_lesson_test.gd an Testformen.
##
## Ohne Katalog und Lernstand: die Boni sind hier von Hand gebaut.

const STATS := preload("res://src/ui/stats_screen.gd")


func _bonus(part := 5, form_type := "la_perfect", tasks := ["forms:a:la_perfect",
		"forms:b:la_perfect", "forms:c:la_perfect", "forms:d:la_perfect"]) -> Dictionary:
	return {"key": ContentRegistry.bonus_key("b", 2, part, form_type), "book": "b", "unit": 2,
			"part": part, "form_type": form_type, "lexeme_ids": ["a", "b", "c", "d"],
			"task_ids": tasks}


func _mastered(ids: Array) -> Callable:
	return func(id: String) -> bool: return id in ids


func test_a_bonus_counts_its_tasks() -> void:
	var counted := BonusLevel.counts(_bonus(), _mastered(["forms:a:la_perfect", "forms:c:la_perfect"]))
	assert_dict(counted).is_equal({"done": 2, "total": 4})
	assert_float(BonusLevel.share(counted)).is_equal(0.5)
	assert_float(BonusLevel.share({"done": 0, "total": 0})).is_equal(0.0)


func test_the_title_comes_from_the_map_point() -> void:
	var layout := {"areas": {"2": {"bonus/5/la_perfect": {"x": 0.3, "y": 0.4,
			"title": "Perfekt der Verben aus Lektion 1–10"}}}}
	assert_str(BonusLevel.map_key(_bonus())).is_equal("bonus/5/la_perfect")
	assert_str(BonusLevel.title(_bonus(), layout)).is_equal("Perfekt der Verben aus Lektion 1–10")
	# Ohne Punkt benennt ihn seine Lektion.
	assert_str(BonusLevel.title(_bonus(), {})).is_equal("Bonus · %s" % BookNaming.part_label("b", 2, 5))


func _levels() -> Array:
	var bonus := _bonus()
	bonus["title"] = "Perfekt"
	return MapLevel.levels_for("b", 2, 2, [bonus])


func test_a_bonus_stands_between_whole_unit_and_boss() -> void:
	var levels := _levels()
	assert_array(levels.map(func(l): return l["key"])) \
			.is_equal(["t1", "t2", "all", "bonus/5/la_perfect", "boss"])
	var level: Dictionary = levels[3]
	assert_str(str(level["kind"])).is_equal(MapLevel.KIND_BONUS)
	assert_array(level["scope"]).is_equal([_bonus()["key"]])
	assert_str(str(level["label"])).is_equal("Perfekt")


func test_a_bonus_is_chosen_like_a_part() -> void:
	var levels := _levels()
	var picked := MapLevel.toggle(levels, ["t1"], "bonus/5/la_perfect")
	assert_array(picked).is_equal(["t1", "bonus/5/la_perfect"])
	var level := MapLevel.combine(levels, picked)
	assert_array(level["scope"]).is_equal(["b/2/1", _bonus()["key"]])
	assert_str(str(level["label"])).is_equal("%s + Perfekt" % BookNaming.parts_label("b", 2, [1]))
	# Gesamt und Boss stehen weiter allein.
	assert_array(MapLevel.toggle(levels, picked, "all")).is_equal(["all"])
	assert_array(MapLevel.toggle(levels, ["all"], "bonus/5/la_perfect")).is_equal(["bonus/5/la_perfect"])
	assert_str(str(MapLevel.combine(levels, ["bonus/5/la_perfect"])["kind"])).is_equal(MapLevel.KIND_BONUS)


func test_a_bonus_shows_its_own_count_and_no_tier() -> void:
	var levels := _levels()
	var counts := {str(_bonus()["key"]): {"done": 3, "total": 4}}
	var units := {"b/2": {"done": 9, "total": 10, "tier": 4}}
	assert_dict(MapLevel.counts_of(levels[3], units, {}, counts)).is_equal({"done": 3, "total": 4})
	assert_int(MapLevel.tier_of(levels[3], units, {})).is_equal(0)
	var nodes := AreaMap.nodes_for(levels, units, {}, 0, true, {}, counts)
	assert_str(str(nodes[3]["glyph"])).is_equal("+")
	var hint := AreaMap.hint_lines(nodes[3])
	assert_str(str(hint["title"])).contains("Bonus: Perfekt")
	assert_str(str(hint["body"])).contains("3 von 4 Aufgaben")


## Die Wörter eines Bonus stammen aus früheren Units — die Festung ist die der Unit, in
## der er steht.
func test_the_bonus_run_stands_with_the_fortress_of_its_unit() -> void:
	var tiers := {"b/1": {"tier": 4}, "b/2": {"tier": 1}}
	var old_words := [{"id": "a", "book": "b", "unit": 1}]
	assert_int(FortressTier.run_tier([], tiers, ["b/2"])).is_equal(1)
	assert_int(FortressTier.run_tier(old_words, tiers)).is_equal(4)
	assert_int(FortressTier.run_tier(old_words, tiers, ["b/2"])).is_equal(1)


func test_statistics_list_a_bonus_under_its_unit() -> void:
	var units := [{"key": "b/1", "label": "B, Unit 1", "done": 1, "total": 2},
			{"key": "b/2", "label": "B, Unit 2", "done": 5, "total": 9}]
	var bonuses_of := func(_book: String, unit: int) -> Array:
		return [_bonus()] if unit == 2 else []
	var rows := STATS.with_bonus_rows(units, bonuses_of, _mastered(["forms:a:la_perfect"]),
			func(_book): return {})
	assert_array(rows.map(func(r): return r["key"])).is_equal(["b/1", "b/2", _bonus()["key"]])
	assert_str(str(rows[2]["label"])).starts_with("Bonus: ")
	assert_int(int(rows[2]["done"])).is_equal(1)
	assert_int(int(rows[2]["total"])).is_equal(4)
	# Die Wörter der Unit bleiben, wie sie sind.
	assert_int(int(rows[1]["total"])).is_equal(9)
