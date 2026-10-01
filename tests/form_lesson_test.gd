extends GdUnitTestSuite
## Formen mit eigener Lektion (`unit`/`part` an lexeme_forms): das Lateinbuch lehrt das
## Perfekt erst in Lektion 11, für alle Verben davor mit. Eine solche Form gilt ab dieser
## Lektion als eingeführt und zieht ihr Lexem genau dort als Wiederholung in den Pool.
##
## Testlexeme mit `zz-`Ids in einem eigenen Buch, danach wieder entfernt. Ein
## Allerweltswort als Beispiel, keine Wortliste.

const BOOK := "zz-buch"
const VERB := "zz-lex.la.test.clamare"
const LATER := "zz-lex.la.test.cena"
const PRESENT := "zz-form.la.test.clamare.1sg"
const PERFECT := "zz-form.la.test.clamare.perf"
const GENDER := "zz-form.la.test.cena.gender"
const GENERATOR := preload("res://src/battle/wave_generator.gd")


func before_test() -> void:
	# Lektion 1 (Unit 1, Teil 1) und Lektion 11 (Unit 2, Teil 5).
	ContentRegistry.lexemes[VERB] = {"id": VERB, "language": "la", "type": "verb",
			"book": BOOK, "unit": 1, "part": 1, "lemma_la": "clāmāre", "lemma_de": "schreien"}
	ContentRegistry.lexemes[LATER] = {"id": LATER, "language": "la", "type": "noun",
			"book": BOOK, "unit": 2, "part": 5, "lemma_la": "cēna", "lemma_de": "das Essen"}
	ContentRegistry.lexeme_forms[PRESENT] = {"id": PRESENT, "lexeme_id": VERB, "language": "la",
			"form_type": "la_present_1sg", "value": "clāmō", "unit": 1, "part": 3}
	ContentRegistry.lexeme_forms[PERFECT] = {"id": PERFECT, "lexeme_id": VERB, "language": "la",
			"form_type": "la_perfect", "value": "clāmāvī", "unit": 2, "part": 5}
	ContentRegistry.lexeme_forms[GENDER] = {"id": GENDER, "lexeme_id": LATER, "language": "la",
			"form_type": "la_gender", "value": "f"}
	ContentRegistry._index_parts()


func after_test() -> void:
	for id in [VERB, LATER]:
		ContentRegistry.lexemes.erase(id)
	for id in [PRESENT, PERFECT, GENDER]:
		ContentRegistry.lexeme_forms.erase(id)
	ContentRegistry._index_parts()


func _scope(key: String) -> Array:
	return [BOOK + key]


func test_a_form_without_lesson_follows_its_lexeme() -> void:
	var form: Dictionary = ContentRegistry.lexeme_forms[GENDER]
	assert_bool(ContentRegistry.form_in_scope(form, _scope("/2/5"))).is_true()
	assert_bool(ContentRegistry.form_in_scope(form, _scope("/2"))).is_true()
	assert_bool(ContentRegistry.form_in_scope(form, _scope("/2/6"))).is_true()
	assert_bool(ContentRegistry.form_in_scope(form, _scope("/2/4"))).is_false()


func test_a_form_counts_from_the_lesson_that_teaches_it() -> void:
	var form: Dictionary = ContentRegistry.lexeme_forms[PERFECT]
	for key in ["/1/1", "/1", "/2/4"]:
		assert_bool(ContentRegistry.form_in_scope(form, _scope(key))) \
				.override_failure_message(key).is_false()
	# Danach gilt sie in jeder späteren Lektion mit.
	for key in ["/2/5", "/2/6", "/2", "/3", "/3/1", ""]:
		assert_bool(ContentRegistry.form_in_scope(form, _scope(key))) \
				.override_failure_message(key).is_true()
	assert_bool(ContentRegistry.form_in_scope(form, [])).is_true()


func test_the_teaching_lesson_pulls_the_lexeme_into_the_pool_but_not_into_its_unit() -> void:
	var run := ContentRegistry.lexemes_for_run(_scope("/2/5"), [])
	assert_array(run.map(func(lx): return lx["id"])).contains_exactly_in_any_order([VERB, LATER])
	# Festung, Statistik und Karte zählen das Verb weiter nur in Lektion 1.
	assert_array(ContentRegistry.lexemes_scoped(_scope("/2/5"), [])
			.map(func(lx): return lx["id"])).contains_exactly([LATER])
	assert_array(ContentRegistry.lexemes_for_run(_scope("/2/4"), [])).is_empty()
	# Spätere Lektionen holen es nicht noch einmal.
	assert_array(ContentRegistry.lexemes_for_run(_scope("/2/6"), [])).is_empty()


func test_the_review_brings_the_translations_and_every_form_taught_so_far() -> void:
	var generator := GENERATOR.new()
	var ids: Array = generator._candidates({"scope": _scope("/2/5")}) \
			.map(func(c): return c["learnable_id"])
	assert_array(ids).contains([
		"translate:de_to_la:%s" % VERB, "translate:la_to_de:%s" % VERB,
		"forms:%s:la_perfect" % VERB, "forms:%s:la_present_1sg" % VERB,
	])


func test_the_first_lesson_asks_neither_present_nor_perfect() -> void:
	var generator := GENERATOR.new()
	var ids: Array = generator._candidates({"scope": _scope("/1/1")}) \
			.map(func(c): return c["learnable_id"])
	assert_array(ids).contains(["translate:de_to_la:%s" % VERB])
	assert_array(ids).not_contains([
		"forms:%s:la_present_1sg" % VERB, "forms:%s:la_perfect" % VERB,
	])


func test_the_reveal_shows_only_the_forms_taught_so_far() -> void:
	var resolver := TaskResolver.new()
	var definition := {"language": "la", "task_type": "translate", "direction": "de_to_la",
			"difficulty": 1}
	var verb: Dictionary = ContentRegistry.lexemes[VERB]
	assert_str(str(resolver.resolve(definition, verb)["meaning"])) \
			.is_equal("clāmō · Perf. clāmāvī")
	resolver.scope = _scope("/1/1")
	assert_str(str(resolver.resolve(definition, verb)["meaning"])).is_empty()
	resolver.scope = _scope("/1/2")
	assert_str(str(resolver.resolve(definition, verb)["meaning"])).is_empty()
	resolver.scope = _scope("/1")
	assert_str(str(resolver.resolve(definition, verb)["meaning"])).is_equal("clāmō")
	resolver.scope = _scope("/1/4")
	assert_str(str(resolver.resolve(definition, verb)["meaning"])).is_equal("clāmō")
	resolver.scope = _scope("/2/5")
	assert_str(str(resolver.resolve(definition, verb)["meaning"])) \
			.is_equal("clāmō · Perf. clāmāvī")


func test_the_present_task_names_the_person() -> void:
	var task := TaskResolver.new().resolve(
			{"task_type": "forms", "direction": "la", "difficulty": 2},
			ContentRegistry.lexemes[VERB], {"form_type": "la_present_1sg"})
	assert_str(str(task["prompt"])).is_equal("clāmāre → 1. Person Singular")
	assert_array(task["accepted_answers"]).contains_exactly(["clāmō"])


func test_a_form_taught_in_another_unit_does_not_hold_back_the_mastery() -> void:
	ContentRegistry.lexemes[VERB]["irregular"] = true
	ContentRegistry._index_form_requirements()
	var required: Array = ContentRegistry.form_requirements().get(VERB, [])
	ContentRegistry.lexemes[VERB].erase("irregular")
	ContentRegistry._index_form_requirements()
	# Die 1. Person lehrt Unit 1 selbst (Lektion 3), das Perfekt erst Unit 2.
	assert_array(required).contains(["forms:%s:la_present_1sg" % VERB])
	assert_array(required).not_contains(["forms:%s:la_perfect" % VERB])
