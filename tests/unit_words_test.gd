extends GdUnitTestSuite
## Wörter der Unit in einem Schülertext (UnitWords) — mit erfundenen Lexemen.


func test_the_core_drops_placeholders_and_leading_be() -> void:
	assert_array(Array(UnitWords.core_of("annoyed (with sb./about sth.)"))).is_equal(["annoyed"])
	assert_array(Array(UnitWords.core_of("be attracted to sb."))).is_equal(["attracted", "to"])
	assert_array(Array(UnitWords.core_of("mean to do sth."))).is_equal(["mean", "to"])
	assert_array(Array(UnitWords.core_of("I reckon …"))).is_equal(["i", "reckon"])
	assert_array(Array(UnitWords.core_of("(sb.)"))).is_empty()


func test_regular_endings_count() -> void:
	var lexemes := [{"id": "lex.zz.carry", "lemma_en": "carry"},
			{"id": "lex.zz.stop", "lemma_en": "stop"},
			{"id": "lex.zz.smile", "lemma_en": "smile"},
			{"id": "lex.zz.box", "lemma_en": "box"}]
	var found := UnitWords.found("She carried two boxes, stopped and was smiling.", lexemes)
	assert_array(found.map(func(f): return f["id"])) \
			.is_equal(["lex.zz.carry", "lex.zz.box", "lex.zz.stop", "lex.zz.smile"])


func test_irregular_forms_come_from_the_lexeme_forms() -> void:
	var lexemes := [{"id": "lex.zz.fall_in_love", "lemma_en": "fall in love (with sb.)"}]
	assert_array(UnitWords.found("Then they fell in love.", lexemes)).is_empty()
	var found := UnitWords.found("Then they fell in love.", lexemes,
			{"lex.zz.fall_in_love": ["fall", "fell", "fallen"]})
	assert_int(found.size()).is_equal(1)
	assert_str("Then they fell in love.".substr(int(found[0]["from"]),
			int(found[0]["to"]) - int(found[0]["from"]))).is_equal("fell in love")


func test_each_lexeme_counts_once_and_only_whole_phrases() -> void:
	var lexemes := [{"id": "lex.zz.next_door", "lemma_en": "next door"},
			{"id": "lex.zz.rope", "lemma_en": "rope"}]
	var found := UnitWords.found("A rope, another rope, and the next day.", lexemes)
	assert_array(found.map(func(f): return f["id"])).is_equal(["lex.zz.rope"])
