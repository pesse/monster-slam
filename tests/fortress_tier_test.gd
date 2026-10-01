extends GdUnitTestSuite
## Die Festungsstufe je Unit (Issue #21): Schwellen, Zählung und die Stufe eines Laufs.
##
## Reine Rechnung über erfundene Lexeme — ohne Autoload, Profil und Sprachdaten.


func _lexeme(id: String, book: String, unit: int, tags := [], excluded := []) -> Dictionary:
	var entry := {"id": id, "tags": tags}
	if not book.is_empty():
		entry["book"] = book
		entry["unit"] = unit
	if not excluded.is_empty():
		entry["excluded_task_types"] = excluded
	return entry


## `count` Lexeme einer Unit, die ersten `mastered` davon gemeistert (in `into`).
func _unit(book: String, unit: int, count: int, mastered: int, into: Dictionary) -> Array:
	var out: Array = []
	for i in count:
		var id := "%s-%d-%d" % [book, unit, i]
		out.append(_lexeme(id, book, unit))
		if i < mastered:
			into[id] = true
	return out


# --- Schwellen ----------------------------------------------------------------

func test_thresholds_hold_exactly_at_the_percentages() -> void:
	# 20 Wörter: 10 % = 2, 32 % = 6,4, 53 % = 10,6, 75 % = 15.
	assert_int(FortressTier.tier_for(0, 20)).is_equal(0)
	assert_int(FortressTier.tier_for(1, 20)).is_equal(0)
	assert_int(FortressTier.tier_for(2, 20)).is_equal(1)
	assert_int(FortressTier.tier_for(6, 20)).is_equal(1)
	assert_int(FortressTier.tier_for(7, 20)).is_equal(2)
	assert_int(FortressTier.tier_for(10, 20)).is_equal(2)
	assert_int(FortressTier.tier_for(11, 20)).is_equal(3)
	assert_int(FortressTier.tier_for(14, 20)).is_equal(3)
	assert_int(FortressTier.tier_for(15, 20)).is_equal(4)
	assert_int(FortressTier.tier_for(20, 20)).is_equal(4)


## In Ganzzahlen verglichen: 32 von 100 sind genau 32 % und nicht knapp darunter.
func test_the_comparison_has_no_rounding_gap() -> void:
	assert_int(FortressTier.tier_for(32, 100)).is_equal(2)
	assert_int(FortressTier.tier_for(31, 100)).is_equal(1)
	assert_int(FortressTier.tier_for(3, 30)).is_equal(1)


## Schneller Erbauer (`drop` 5): Stufe 4 bei 70 %, die anderen im selben Verhältnis früher.
func test_a_drop_pulls_every_threshold_forward() -> void:
	# 20 Wörter, Schwellen ×70/75: 9,3 % = 1,9, 29,9 % = 6,0, 49,5 % = 9,9, 70 % = 14.
	assert_int(FortressTier.tier_for(1, 20, 5)).is_equal(0)
	assert_int(FortressTier.tier_for(2, 20, 5)).is_equal(1)
	assert_int(FortressTier.tier_for(6, 20, 5)).is_equal(2)
	assert_int(FortressTier.tier_for(9, 20, 5)).is_equal(2)
	assert_int(FortressTier.tier_for(10, 20, 5)).is_equal(3)
	assert_int(FortressTier.tier_for(13, 20, 5)).is_equal(3)
	assert_int(FortressTier.tier_for(14, 20, 5)).is_equal(4)
	assert_int(FortressTier.tier_for(70, 100, 5)).is_equal(4)
	assert_int(FortressTier.tier_for(69, 100, 5)).is_equal(3)
	assert_dict(FortressTier.next_threshold(10, 20, 5)).is_equal({"tier": 4, "needed": 4})


func test_a_drop_never_gives_the_top_tier_away() -> void:
	assert_int(FortressTier.tier_for(49, 100, 100)).is_equal(3)
	assert_int(FortressTier.tier_for(50, 100, 100)).is_equal(4)
	assert_int(FortressTier.tier_for(15, 20, -10)).is_equal(4)


func test_the_drop_comes_from_the_skill_bonuses() -> void:
	assert_int(FortressTier.drop_of({"fortress_tier_drop": 5.0})).is_equal(5)
	assert_int(FortressTier.drop_of({})).is_equal(0)


func test_unit_tiers_count_with_the_drop() -> void:
	var unit: Array = []
	var mastered := {}
	for i in 20:
		unit.append(_lexeme("w%d" % i, "access1", 1))
		if i < 14:
			mastered["w%d" % i] = true
	assert_int(int(FortressTier.unit_tiers(unit, mastered)["access1/1"]["tier"])).is_equal(3)
	assert_int(int(FortressTier.unit_tiers(unit, mastered, 5)["access1/1"]["tier"])).is_equal(4)


func test_a_unit_without_words_is_tier_zero() -> void:
	assert_int(FortressTier.tier_for(0, 0)).is_equal(0)
	assert_dict(FortressTier.next_threshold(0, 0)).is_empty()


func test_health_bonus_is_flat_per_tier() -> void:
	assert_int(FortressTier.health_bonus(0)).is_equal(0)
	assert_int(FortressTier.health_bonus(1)).is_equal(FortressTier.HP_PER_TIER)
	assert_int(FortressTier.health_bonus(4)).is_equal(4 * FortressTier.HP_PER_TIER)
	assert_int(FortressTier.health_bonus(-1)).is_equal(0)


func test_next_threshold_names_the_missing_words() -> void:
	# 40 Wörter: 10 % = 4, 32 % = 12,8, 53 % = 21,2, 75 % = 30.
	assert_dict(FortressTier.next_threshold(0, 40)).is_equal({"tier": 1, "needed": 4})
	assert_dict(FortressTier.next_threshold(12, 40)).is_equal({"tier": 2, "needed": 1})
	assert_dict(FortressTier.next_threshold(13, 40)).is_equal({"tier": 3, "needed": 9})
	# 75 % von 30 sind 22,5 — aufgerundet 23.
	assert_dict(FortressTier.next_threshold(18, 30)).is_equal({"tier": 4, "needed": 5})
	assert_dict(FortressTier.next_threshold(30, 40)).is_empty()


# --- Zählung ------------------------------------------------------------------

func test_unit_tiers_counts_each_unit() -> void:
	var mastered := {}
	var lexemes := _unit("access2", 6, 10, 4, mastered) + _unit("access2", 7, 10, 0, mastered)
	var tiers := FortressTier.unit_tiers(lexemes, mastered)
	assert_int(tiers.size()).is_equal(2)
	assert_int(int(tiers["access2/6"]["done"])).is_equal(4)
	assert_int(int(tiers["access2/6"]["total"])).is_equal(10)
	assert_int(int(tiers["access2/6"]["tier"])).is_equal(2)
	assert_int(int(tiers["access2/7"]["tier"])).is_equal(0)


## Ein Wort ohne Übersetzungsaufgabe erreicht die Meisterung nie und steht deshalb nicht
## im Nenner — sonst hinge die Unit dauerhaft unter 100 %.
func test_unmasterable_lexemes_are_not_in_the_denominator() -> void:
	var mastered := {}
	var lexemes := _unit("access2", 6, 9, 9, mastered)
	lexemes.append(_lexeme("nie", "access2", 6, [], ["translate"]))
	var tiers := FortressTier.unit_tiers(lexemes, mastered)
	assert_int(int(tiers["access2/6"]["total"])).is_equal(9)
	assert_int(int(tiers["access2/6"]["tier"])).is_equal(4)


func test_lexemes_without_unit_have_no_tier() -> void:
	var tiers := FortressTier.unit_tiers([_lexeme("a", "", 0)], {"a": true})
	assert_dict(tiers).is_empty()


# --- Die Stufe eines Laufs ----------------------------------------------------

## Im Kampf gilt die schwächste Unit des Bereichs.
func test_the_run_uses_the_weakest_unit() -> void:
	var mastered := {}
	var strong := _unit("access2", 6, 10, 9, mastered)
	var weak := _unit("access2", 7, 10, 4, mastered)
	var tiers := FortressTier.unit_tiers(strong + weak, mastered)
	assert_int(FortressTier.run_tier(strong, tiers)).is_equal(4)
	assert_int(FortressTier.run_tier(weak, tiers)).is_equal(2)
	assert_int(FortressTier.run_tier(strong + weak, tiers)).is_equal(2)


## Ein Viertel einer Unit (oder ein Thema daraus) wertet trotzdem die GANZE Unit: wer nur
## die gekonnten Wörter spielt, zieht die Festung damit nicht hoch.
func test_a_part_of_a_unit_is_rated_as_the_whole_unit() -> void:
	var mastered := {}
	var unit := _unit("access2", 6, 10, 3, mastered)
	var tiers := FortressTier.unit_tiers(unit, mastered)
	# Nur die drei gemeisterten Wörter im Bereich — gewertet werden trotzdem 3 von 10.
	var part := unit.slice(0, 3)
	assert_int(FortressTier.run_tier(part, tiers)).is_equal(1)


func test_a_tag_filter_is_rated_as_the_whole_unit() -> void:
	var mastered := {"a": true, "b": true}
	var lexemes := [
		_lexeme("a", "access2", 6, ["body"]), _lexeme("b", "access2", 6, ["body"]),
		_lexeme("c", "access2", 6), _lexeme("d", "access2", 6), _lexeme("e", "access2", 6),
		_lexeme("f", "access2", 6), _lexeme("g", "access2", 6), _lexeme("h", "access2", 6),
	]
	var tiers := FortressTier.unit_tiers(lexemes, mastered)
	var body := lexemes.filter(func(lx): return "body" in lx["tags"])
	# 2 von 8 = 25 % -> Stufe 1, nicht 2 von 2 = Stufe 4.
	assert_int(FortressTier.run_tier(body, tiers)).is_equal(1)


## Wörter ohne Buch/Unit bringen keine Stufe — und heben auch keine.
func test_unbound_vocabulary_is_tier_zero() -> void:
	var tiers := FortressTier.unit_tiers([_lexeme("a", "", 0)], {"a": true})
	assert_int(FortressTier.run_tier([_lexeme("a", "", 0)], tiers)).is_equal(0)
	assert_int(FortressTier.run_tier([], tiers)).is_equal(0)


## Wörter ohne Unit ziehen die schwächste Unit nicht auf 0.
func test_words_without_unit_do_not_count_in_the_minimum() -> void:
	var mastered := {}
	var unit := _unit("access2", 6, 10, 9, mastered)
	var tiers := FortressTier.unit_tiers(unit, mastered)
	assert_int(FortressTier.run_tier(unit + [_lexeme("x", "", 0)], tiers)).is_equal(4)
