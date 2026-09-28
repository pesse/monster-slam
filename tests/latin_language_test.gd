extends GdUnitTestSuite
## Eine zweite Fremdsprache neben Englisch (Issue #31): die Sprache steht am Lexem und an
## der task_definition (`language`, ohne Feld englisch), die fremde Seite in
## `lemma_<language>`, die Richtungen tragen die Sprache im Namen (`de_to_la`).
##
## Die Testlexeme liegen mit `zz-`Ids direkt in der ContentRegistry und werden danach
## wieder entfernt. Ein Allerweltswort als Beispiel, keine Wortliste.

const LA := "zz-lex.la.test.amicus"
const EN := "zz-lex.en.test.friend"
const GEN := "zz-form.la.test.amicus.gen"
const GENDER := "zz-form.la.test.amicus.gender"
const GENERATOR := preload("res://src/battle/wave_generator.gd")
const PROGRESS := preload("res://src/learning/player_progress.gd")
const STATS := preload("res://src/ui/stats_screen.gd")

const DEF_DE_LA := {"id": "zz-def.de_la", "language": "la", "task_type": "translate",
		"direction": "de_to_la", "difficulty": 1}
const DEF_LA_DE := {"id": "zz-def.la_de", "language": "la", "task_type": "translate",
		"direction": "la_to_de", "difficulty": 2}
const DEF_DE_EN := {"id": "zz-def.de_en", "task_type": "translate", "direction": "de_to_en",
		"difficulty": 1}

var _resolver: TaskResolver


func before_test() -> void:
	_resolver = TaskResolver.new()
	ContentRegistry.lexemes[LA] = {"id": LA, "language": "la", "type": "noun",
			"lemma_la": "amīcus", "lemma_de": "der Freund", "lemma_de_alt": ["der Kamerad"]}
	ContentRegistry.lexemes[EN] = {"id": EN, "type": "noun", "lemma_en": "friend",
			"lemma_de": "der Freund"}
	ContentRegistry.lexeme_forms[GEN] = {"id": GEN, "lexeme_id": LA, "language": "la",
			"form_type": "la_genitive", "value": "amīcī"}
	ContentRegistry.lexeme_forms[GENDER] = {"id": GENDER, "lexeme_id": LA, "language": "la",
			"form_type": "la_gender", "value": "m"}


func after_test() -> void:
	ContentRegistry.lexemes.erase(LA)
	ContentRegistry.lexemes.erase(EN)
	ContentRegistry.lexeme_forms.erase(GEN)
	ContentRegistry.lexeme_forms.erase(GENDER)


func test_a_lexeme_without_language_is_english() -> void:
	assert_str(Lexeme.language(ContentRegistry.lexemes[EN])).is_equal("en")
	assert_str(Lexeme.foreign(ContentRegistry.lexemes[EN])).is_equal("friend")
	assert_str(Lexeme.foreign(ContentRegistry.lexemes[LA])).is_equal("amīcus")


func test_the_language_comes_back_out_of_a_direction() -> void:
	assert_str(Lexeme.language_of_direction("de_to_la")).is_equal("la")
	assert_str(Lexeme.language_of_direction("la_to_de")).is_equal("la")
	assert_str(Lexeme.language_of_direction("en_to_de")).is_equal("en")
	assert_str(Lexeme.language_of_direction("en_to_en")).is_empty()
	assert_str(Lexeme.language_of_direction("en")).is_empty()
	assert_str(Lexeme.direction_label("de_to_la", "→")).is_equal("de→la")


func test_latin_to_german_asks_the_latin_word() -> void:
	var task := _resolver.resolve(DEF_LA_DE, ContentRegistry.lexemes[LA])
	assert_str(str(task["prompt"])).is_equal("amīcus")
	assert_array(task["accepted_answers"]).contains_exactly(["der Freund", "der Kamerad"])
	assert_str(str(task["learnable_id"])).is_equal("translate:la_to_de:%s" % LA)


func test_german_to_latin_expects_the_latin_word_and_shows_its_dictionary_form() -> void:
	var task := _resolver.resolve(DEF_DE_LA, ContentRegistry.lexemes[LA])
	assert_str(str(task["prompt"])).is_equal("der Freund")
	assert_array(task["accepted_answers"]).contains_exactly(["amīcus"])
	assert_str(str(task["meaning"])).is_equal("Gen. amīcī · m")


func test_an_english_translation_keeps_an_empty_meaning() -> void:
	var task := _resolver.resolve(DEF_DE_EN, ContentRegistry.lexemes[EN])
	assert_str(str(task["meaning"])).is_empty()


func test_the_gender_task_accepts_the_letter_and_the_word() -> void:
	var task := _resolver.resolve({"task_type": "forms", "direction": "la", "difficulty": 2},
			ContentRegistry.lexemes[LA], {"form_type": "la_gender"})
	assert_str(str(task["prompt"])).is_equal("amīcus → Genus")
	var evaluator := AnswerEvaluator.new()
	for typed in ["m", "m.", "maskulin", "Maskulinum"]:
		assert_bool(evaluator.evaluate_answers(task["accepted_answers"], typed)) \
				.override_failure_message(typed).is_true()
	assert_bool(evaluator.evaluate_answers(task["accepted_answers"], "f")).is_false()


func test_macrons_are_never_required() -> void:
	var evaluator := AnswerEvaluator.new()
	assert_bool(evaluator.evaluate_answers(["amīcus"], "amicus")).is_true()
	assert_bool(evaluator.evaluate_answers(["amīcus"], "amīcus")).is_true()
	# Umlaute sind keine Längenzeichen.
	assert_bool(evaluator.evaluate_answers(["müde"], "mude")).is_false()


func test_a_definition_only_pairs_with_lexemes_of_its_language() -> void:
	var generator := GENERATOR.new()
	assert_array(generator._instances(DEF_DE_LA, ContentRegistry.lexemes[LA])).is_not_empty()
	assert_array(generator._instances(DEF_DE_LA, ContentRegistry.lexemes[EN])).is_empty()
	assert_array(generator._instances(DEF_DE_EN, ContentRegistry.lexemes[LA])).is_empty()
	assert_array(generator._instances(DEF_DE_EN, ContentRegistry.lexemes[EN])).is_not_empty()


func test_a_latin_word_is_mastered_with_both_latin_directions() -> void:
	var sure := {"confidence": 0.9}
	var records := {
		"translate:de_to_la:%s" % LA: sure,
		"translate:la_to_de:%s" % LA: sure,
	}
	assert_bool(PROGRESS.mastered_lexemes_in(records).has(LA)).is_true()
	assert_str(PROGRESS.mastered_lexeme_in(records, "translate:la_to_de:%s" % LA)).is_equal(LA)


func test_directions_of_two_languages_do_not_add_up() -> void:
	var sure := {"confidence": 0.9}
	var records := {
		"translate:de_to_la:%s" % LA: sure,
		"translate:en_to_de:%s" % LA: sure,
	}
	assert_bool(PROGRESS.mastered_lexemes_in(records).has(LA)).is_false()
	assert_str(PROGRESS.mastered_lexeme_in(records, "translate:de_to_la:%s" % LA)).is_empty()


func test_the_word_row_of_a_latin_word_uses_the_latin_directions() -> void:
	var rows := STATS.word_rows([ContentRegistry.lexemes[LA]], func(_id): return -1.0)
	var directions: Array = rows[0]["directions"].map(func(d): return d["direction"])
	assert_array(directions).contains_exactly(["de_to_la", "la_to_de"])
	assert_str(str(rows[0]["label"])).is_equal("amīcus — der Freund")
