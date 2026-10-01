extends GdUnitTestSuite
## Formen mit eigener Lektion (`unit`/`part` an lexeme_forms): das Lateinbuch lehrt das
## Perfekt erst in Lektion 11, für alle Verben davor mit. Eine solche Form gilt ab dieser
## Lektion als eingeführt (ADR 0011) und steht, weil sie später kommt als ihr Wort, in einem
## Bonus der lehrenden Lektion (ADR 0012) — als Aufgabe nur dort und in „Gesamt".
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
	_reindex()


func after_test() -> void:
	for id in [VERB, LATER]:
		ContentRegistry.lexemes.erase(id)
	for id in [PRESENT, PERFECT, GENDER]:
		ContentRegistry.lexeme_forms.erase(id)
	_reindex()


func _reindex() -> void:
	ContentRegistry._index_parts()
	ContentRegistry._index_bonuses()
	ContentRegistry._index_form_requirements()


const PERFECT_BONUS := "bonus:%s/2/5/la_perfect" % BOOK
const PRESENT_BONUS := "bonus:%s/1/3/la_present_1sg" % BOOK


func _ids(scope: Array) -> Array:
	return GENERATOR.new()._candidates({"scope": scope}).map(func(c): return c["learnable_id"])


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


func test_a_form_taught_later_than_its_word_is_a_bonus_of_the_teaching_lesson() -> void:
	assert_array(ContentRegistry.bonuses_of(BOOK, 1).map(func(b): return b["key"])) \
			.contains_exactly([PRESENT_BONUS])
	var perfect: Array = ContentRegistry.bonuses_of(BOOK, 2)
	assert_array(perfect.map(func(b): return b["key"])).contains_exactly([PERFECT_BONUS])
	assert_array(perfect[0]["lexeme_ids"]).contains_exactly([VERB])
	assert_array(perfect[0]["task_ids"]).contains_exactly(["forms:%s:la_perfect" % VERB])
	# Eine Form ohne eigene Lektion steht nie in einem Bonus.
	assert_str(ContentRegistry.bonus_of_form(ContentRegistry.lexeme_forms[GENDER])).is_empty()


func test_the_teaching_lesson_no_longer_pulls_old_words_into_the_pool() -> void:
	assert_array(ContentRegistry.lexemes_for_run(_scope("/2/5"), [])
			.map(func(lx): return lx["id"])).contains_exactly([LATER])
	assert_array(ContentRegistry.lexemes_for_run([PERFECT_BONUS], [])
			.map(func(lx): return lx["id"])).contains_exactly([VERB])
	# „Gesamt" spielt den Bonus mit, Festung, Statistik und Karte zählen das Verb weiter nur
	# in Lektion 1.
	assert_array(ContentRegistry.lexemes_for_run(_scope("/2"), [])
			.map(func(lx): return lx["id"])).contains_exactly_in_any_order([VERB, LATER])
	assert_array(ContentRegistry.lexemes_scoped(_scope("/2"), [])
			.map(func(lx): return lx["id"])).contains_exactly([LATER])


func test_the_bonus_asks_only_its_forms() -> void:
	assert_array(_ids([PERFECT_BONUS])).contains_exactly(["forms:%s:la_perfect" % VERB])
	assert_array(_ids([PRESENT_BONUS])).contains_exactly(["forms:%s:la_present_1sg" % VERB])


func test_whole_unit_plays_its_bonus_a_part_does_not() -> void:
	assert_array(_ids(_scope("/2"))).contains(["forms:%s:la_perfect" % VERB])
	assert_array(_ids(_scope("/2"))).not_contains(["translate:de_to_la:%s" % VERB,
			"forms:%s:la_present_1sg" % VERB])
	assert_array(_ids(_scope("/1"))).contains(["forms:%s:la_present_1sg" % VERB])
	assert_array(_ids(_scope("/1"))).not_contains(["forms:%s:la_perfect" % VERB])
	# Lektion 1 mit Lektion 4: die 1. Person ist eingeführt, aber als Aufgabe nur im Bonus.
	var parts := _ids([BOOK + "/1/1", BOOK + "/1/4"])
	assert_array(parts).contains(["translate:de_to_la:%s" % VERB])
	assert_array(parts).not_contains(["forms:%s:la_present_1sg" % VERB])
	# Ein Teil zusammen mit dem Bonus bringt beides.
	assert_array(_ids([BOOK + "/1/1", PRESENT_BONUS])).contains([
			"translate:de_to_la:%s" % VERB, "forms:%s:la_present_1sg" % VERB])


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
	# Im Bonus gilt, was bis zu seiner Lektion eingeführt ist.
	resolver.scope = [PERFECT_BONUS]
	assert_str(str(resolver.resolve(definition, verb)["meaning"])) \
			.is_equal("clāmō · Perf. clāmāvī")


func test_the_present_task_names_the_person() -> void:
	var task := TaskResolver.new().resolve(
			{"task_type": "forms", "direction": "la", "difficulty": 2},
			ContentRegistry.lexemes[VERB], {"form_type": "la_present_1sg"})
	assert_str(str(task["prompt"])).is_equal("clāmāre → 1. Person Singular")
	assert_array(task["accepted_answers"]).contains_exactly(["clāmō"])


func test_a_bonus_form_does_not_hold_back_the_mastery() -> void:
	ContentRegistry.lexemes[VERB]["irregular"] = true
	_reindex()
	var required: Array = ContentRegistry.form_requirements().get(VERB, [])
	ContentRegistry.lexemes[VERB].erase("irregular")
	_reindex()
	# Beide Formen kommen nach dem Wort (Lektion 3 und 11), beide sind Bonus — auch die aus
	# der eigenen Unit. Ohne zählende Form braucht das Verb nur seine Übersetzungen.
	assert_array(required).is_empty()
