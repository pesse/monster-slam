extends GdUnitTestSuite
## Wort-Bonus (ADR 0013): Lexeme mit dem Feld `bonus` sind zusätzlicher Stoff zu ihrer Unit.
## Sie spielen in ihrem Bonus und in „Gesamt" mit allen Aufgaben, zählen aber weder zur
## Festung noch zu einem Teil der Unit. Ein Wort, das schon anderswo steht, nennt den Bonus
## unter `also_bonus` und bleibt ein Wort seiner Unit.
##
## Testlexeme mit `zz-`Ids in einem eigenen Buch, danach wieder entfernt. Allerweltswörter
## als Beispiel, keine Wortliste.

const BOOK := "zz-wortbuch"
const OWN := "zz-lex.fr.test.maison"
const EXTRA := "zz-lex.fr.test.palmier"
const LATER := "zz-lex.fr.test.enquete"
const BONUS := "bonus:%s/1/0/zz-thema" % BOOK
const GENERATOR := preload("res://src/battle/wave_generator.gd")


func before_test() -> void:
	ContentRegistry.lexemes[OWN] = {"id": OWN, "language": "fr", "type": "noun",
			"book": BOOK, "unit": 1, "part": 1, "lemma_fr": "la maison", "lemma_de": "das Haus"}
	ContentRegistry.lexemes[EXTRA] = {"id": EXTRA, "language": "fr", "type": "noun",
			"book": BOOK, "unit": 1, "bonus": "zz-thema", "lemma_fr": "le palmier",
			"lemma_de": "die Palme"}
	ContentRegistry.lexemes[LATER] = {"id": LATER, "language": "fr", "type": "noun",
			"book": BOOK, "unit": 2, "part": 1, "also_bonus": [{"unit": 1, "bonus": "zz-thema"}],
			"lemma_fr": "l'enquête", "lemma_de": "die Umfrage"}
	_reindex()


func after_test() -> void:
	for id in [OWN, EXTRA, LATER]:
		ContentRegistry.lexemes.erase(id)
	_reindex()


func _reindex() -> void:
	ContentRegistry._index_parts()
	ContentRegistry._index_bonuses()
	ContentRegistry._index_form_requirements()


func _ids(entries: Array) -> Array:
	return entries.map(func(e): return str(e["id"]))


func _tasks(scope: Array) -> Array:
	return GENERATOR.new()._candidates({"scope": scope}).map(func(c): return str(c["learnable_id"]))


func test_the_words_form_one_bonus_of_their_unit() -> void:
	var bonuses := ContentRegistry.bonuses_of(BOOK, 1)
	assert_int(bonuses.size()).is_equal(1)
	var bonus: Dictionary = bonuses[0]
	assert_str(str(bonus["key"])).is_equal(BONUS)
	assert_array(bonus["lexeme_ids"]).contains_exactly_in_any_order([EXTRA, LATER])
	assert_array(bonus["task_ids"]).contains_exactly_in_any_order([
			"translate:de_to_fr:" + EXTRA, "translate:fr_to_de:" + EXTRA,
			"translate:de_to_fr:" + LATER, "translate:fr_to_de:" + LATER])
	assert_str(BonusLevel.map_key(bonus)).is_equal("bonus/0/zz-thema")
	assert_str(BonusLevel.title(bonus, {})).is_equal("Bonus · Unit 1")


func test_a_bonus_word_is_no_word_of_its_unit() -> void:
	assert_array(_ids(ContentRegistry.lexemes_scoped([BOOK + "/1"], []))).contains_exactly([OWN])
	assert_int(ContentRegistry.part_of(EXTRA)).is_equal(0)
	assert_int(ContentRegistry.parts_for(BOOK, 1)).is_equal(1)
	var tiers := FortressTier.unit_tiers([ContentRegistry.lexemes[OWN],
			ContentRegistry.lexemes[EXTRA]], {})
	assert_int(int(tiers[BOOK + "/1"]["total"])).is_equal(1)


func test_whole_unit_and_bonus_ask_the_words_a_part_does_not() -> void:
	var asked := "translate:de_to_fr:" + EXTRA
	assert_array(_tasks([BONUS])).contains([asked])
	assert_array(_tasks([BONUS])).not_contains(["translate:de_to_fr:" + OWN])
	assert_array(_tasks([BOOK + "/1"])).contains([asked, "translate:fr_to_de:" + EXTRA])
	assert_array(_tasks([BOOK + "/1/1"])).not_contains([asked])
	assert_array(ContentRegistry.bonus_units([BONUS])).contains_exactly([BOOK + "/1"])


func test_a_word_from_elsewhere_plays_in_the_bonus_and_stays_in_its_unit() -> void:
	var asked := "translate:de_to_fr:" + LATER
	assert_array(_tasks([BONUS])).contains([asked])
	assert_array(_tasks([BOOK + "/1"])).contains([asked])
	assert_array(_tasks([BOOK + "/2/1"])).contains([asked])
	assert_array(_ids(ContentRegistry.lexemes_scoped([BOOK + "/2"], []))).contains_exactly([LATER])
	assert_int(ContentRegistry.part_of(LATER)).is_equal(1)
	var tiers := FortressTier.unit_tiers([ContentRegistry.lexemes[LATER]], {})
	assert_int(int(tiers[BOOK + "/2"]["total"])).is_equal(1)


func test_a_bonus_word_can_stand_in_a_second_bonus() -> void:
	var twice := "zz-lex.fr.test.gris"
	ContentRegistry.lexemes[twice] = {"id": twice, "language": "fr", "type": "adjective",
			"book": BOOK, "unit": 2, "bonus": "zz-auftakt",
			"also_bonus": [{"unit": 1, "bonus": "zz-thema"}], "lemma_fr": "gris", "lemma_de": "grau"}
	_reindex()
	var auftakt := "bonus:%s/2/0/zz-auftakt" % BOOK
	assert_array(_ids(ContentRegistry.lexemes_scoped([auftakt], []))).contains([twice])
	assert_array(_ids(ContentRegistry.lexemes_scoped([BONUS], []))).contains([twice])
	assert_array(_ids(ContentRegistry.lexemes_scoped([BOOK + "/2"], []))).not_contains([twice])
	assert_array(_tasks([auftakt])).contains(["translate:de_to_fr:" + twice])
	ContentRegistry.lexemes.erase(twice)
