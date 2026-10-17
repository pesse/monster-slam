extends GdUnitTestSuite
## Sätze aus dem Buch (ADR 0026): Ein Lexem trägt unter `examples` Sätze, die als ganze
## Übersetzung gefragt werden, nur im Bonus „Sätze aus dem Buch“ seiner Unit. Lange
## Antworten bremsen ihr Monster und halten den nächsten Spawn zurück.
##
## Testlexeme mit `zz-`Ids in einem eigenen Buch, danach wieder entfernt. Eigene Sätze.

const BOOK := "zz-satzbuch"
const WORD := "zz-lex.en.test.garden"
const PLAIN := "zz-lex.en.test.tree"
const BONUS := "bonus:%s/1/0/examples" % BOOK
const GENERATOR := preload("res://src/battle/wave_generator.gd")
const SENTENCE := "My grandmother works in her garden every morning."


func before_test() -> void:
	ContentRegistry.lexemes[WORD] = {"id": WORD, "type": "noun", "book": BOOK, "unit": 1,
			"lemma_en": "garden", "lemma_de": "der Garten", "examples": [
				{"key": "1", "de": "Meine Oma arbeitet jeden Morgen in ihrem Garten.",
					"en": SENTENCE,
					"en_alt": ["Every morning my grandmother works in her garden."]},
				{"key": "2", "de": "Der Garten ist groß.", "en": "The garden is big."},
				{"de": "Ohne Key zählt der Satz nicht.", "en": "No key."},
			]}
	ContentRegistry.lexemes[PLAIN] = {"id": PLAIN, "type": "noun", "book": BOOK, "unit": 1,
			"lemma_en": "tree", "lemma_de": "der Baum"}
	_reindex()


func after_test() -> void:
	for id in [WORD, PLAIN]:
		ContentRegistry.lexemes.erase(id)
	_reindex()


func _reindex() -> void:
	ContentRegistry._index_parts()
	ContentRegistry._index_bonuses()
	ContentRegistry._index_form_requirements()


func _tasks(scope: Array) -> Array:
	return GENERATOR.new()._candidates({"scope": scope}).map(func(c): return str(c["learnable_id"]))


func _example_candidate() -> Dictionary:
	for c in GENERATOR.new()._candidates({"scope": [BONUS]}):
		if str(c["learnable_id"]) == "example:%s:1" % WORD:
			return c
	return {}


func test_the_sentences_form_one_bonus_of_their_unit() -> void:
	var bonuses := ContentRegistry.bonuses_of(BOOK, 1)
	assert_int(bonuses.size()).is_equal(1)
	var bonus: Dictionary = bonuses[0]
	assert_str(str(bonus["key"])).is_equal(BONUS)
	assert_array(bonus["lexeme_ids"]).contains_exactly([WORD])
	assert_array(bonus["task_ids"]).contains_exactly(["example:%s:1" % WORD, "example:%s:2" % WORD])
	assert_str(BonusLevel.map_key(bonus)).is_equal("bonus/0/examples")


func test_sentences_come_only_where_their_bonus_is_chosen() -> void:
	var asked := "example:%s:1" % WORD
	assert_array(_tasks([BONUS])).contains_exactly_in_any_order([asked, "example:%s:2" % WORD])
	assert_array(_tasks([BOOK + "/1"])).not_contains([asked])
	assert_array(_tasks([BOOK + "/1"])).contains(["translate:de_to_en:" + WORD])
	assert_array(_tasks([BOOK])).not_contains([asked])
	assert_bool(ContentRegistry.bonus_in_scope(BONUS, [BOOK + "/1"])).is_false()
	assert_array(_tasks([BOOK + "/1", BONUS])).contains([asked, "translate:de_to_en:" + WORD])


func test_the_whole_unit_takes_the_sentences_when_the_switch_is_on() -> void:
	var levels := MapLevel.levels_for(BOOK, 1, 2, ContentRegistry.bonuses_of(BOOK, 1))
	var whole := MapLevel.combine(levels, ["all"])
	var part := MapLevel.combine(levels, ["t1"])
	assert_array(RunRequest.level_scope(whole, true)).contains_exactly([BOOK + "/1", BONUS])
	assert_array(RunRequest.level_scope(whole, false)).contains_exactly([BOOK + "/1"])
	assert_array(RunRequest.level_scope(part, true)).not_contains([BONUS])
	assert_array(_tasks(RunRequest.level_scope(whole, true))) \
			.contains(["example:%s:1" % WORD, "translate:de_to_en:" + WORD])


func test_the_switch_is_no_part_of_a_saved_run() -> void:
	var levels := MapLevel.levels_for(BOOK, 1, 2, ContentRegistry.bonuses_of(BOOK, 1))
	var saved := RunSave.build(MapLevel.combine(levels, ["all"]), 3, 1, {}, 0, 0)
	assert_array(saved["level"].keys()).contains_exactly_in_any_order(["book", "unit", "keys"])
	assert_bool(RunSave.continues(saved, 1, ["all"], levels)).is_true()


func test_the_bonus_does_not_count_for_the_fortress() -> void:
	var tiers := FortressTier.unit_tiers([ContentRegistry.lexemes[WORD],
			ContentRegistry.lexemes[PLAIN]], {})
	assert_int(int(tiers[BOOK + "/1"]["total"])).is_equal(2)
	assert_array(ContentRegistry.form_requirements().get(WORD, [])).is_empty()


func test_a_sentence_asks_the_german_and_takes_the_whole_english() -> void:
	var c := _example_candidate()
	var task := TaskResolver.new().resolve(c["definition"], c["source"], c["extra"])
	assert_str(str(task["prompt"])).is_equal("Meine Oma arbeitet jeden Morgen in ihrem Garten.")
	assert_str(str(task["accepted_answers"][0])).is_equal(SENTENCE)
	assert_array(task["prompt_alt"]).contains_exactly(["garden"])
	assert_str(str(task["alt_label"])).is_equal("Wort")
	var evaluator := AnswerEvaluator.new()
	var answers: Array = task["accepted_answers"]
	assert_bool(bool(evaluator.evaluate(answers, "every morning, my grandmother works in her garden",
			true)["matched"])).is_true()
	assert_bool(bool(evaluator.evaluate(answers, "My grandmother works in her yard every morning.",
			true)["matched"])).is_false()
	assert_str(TaskResolver.new().describe_learnable("example:%s:1" % WORD)) \
			.is_equal("garden (Buchsatz 1)")


func test_the_spell_reveals_the_word() -> void:
	assert_str(WordPlate.alt_line(["garden"], "Wort")).is_equal("Wort: garden")


func test_long_answers_slow_the_monster_and_hold_the_next_spawn() -> void:
	assert_float(GENERATOR.typing_pace(12)).is_equal(1.0)
	assert_float(GENERATOR.typing_gap(12)).is_equal(0.0)
	assert_float(GENERATOR.typing_pace(60)).is_equal_approx(0.5, 0.001)
	assert_float(GENERATOR.typing_gap(40)).is_equal_approx(20.0, 0.001)
	assert_float(GENERATOR.typing_pace(400)).is_equal(GENERATOR.MIN_TYPING_PACE)
	assert_int(GENERATOR.answer_chars(["The garden is big.", "A garden"])).is_equal(8)
	# Artikel und Klammergruppe muss niemand tippen.
	assert_int(GENERATOR.answer_chars(["das (Garten-)Haus"])).is_equal(4)
	var plan := GENERATOR.new()._build_plan(_example_candidate())
	var pace := GENERATOR.typing_pace(SENTENCE.length())
	assert_float(float(plan["speed"])).is_less_equal(GENERATOR.REFERENCE_SPEED * 1.3 * pace)
	assert_float(float(plan["gap"])).is_greater(0.0)


func test_a_long_card_stays_longer_in_the_reveal() -> void:
	var reveal := preload("res://src/ui/leak_reveal.gd")
	assert_float(reveal.hold_time({"prompt": "der Garten", "answers": ["garden"]})) \
			.is_equal(reveal.HOLD_TIME)
	var long := reveal.hold_time({"prompt": "Meine Oma arbeitet jeden Morgen in ihrem Garten.",
			"answers": [SENTENCE, "Every morning my grandmother works in her garden."]})
	assert_float(long).is_equal_approx(reveal.HOLD_TIME + (48 + 49 - 40) / 15.0, 0.01)
