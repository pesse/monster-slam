extends GdUnitTestSuite
## Konjugation im Französischen (ADR 0008): je Person eine Form mit Subjekt (die gezeigte)
## und eine ohne (getippt reicht das Verb), dazu das Passé composé. Die Prüfung ist
## nachsichtig wie bei der Übersetzung, die Akzente blendet der Kampf ein.
##
## Die Testlexeme liegen mit `zz-`Ids direkt in der ContentRegistry und werden danach
## wieder entfernt. Ein Allerweltsverb als Beispiel, keine Wortliste.

const FR := "zz-lex.fr.test.recevoir"
const FORMS := {
	"zz-form.fr.test.recevoir.pres_3pl": "ils reçoivent",
	"zz-form.fr.test.recevoir.pres_3pl.2": "elles reçoivent",
	"zz-form.fr.test.recevoir.pres_3pl.3": "reçoivent",
}
const GENERATOR := preload("res://src/battle/wave_generator.gd")
const DEF := {"id": "zz-def.conj.fr_pres_3pl", "language": "fr", "task_type": "conjugation",
		"direction": "fr", "requires_form": "fr_pres_3pl", "allowed_types": ["verb"],
		"difficulty": 2}

var _resolver: TaskResolver


func before_test() -> void:
	_resolver = TaskResolver.new()
	ContentRegistry.lexemes[FR] = {"id": FR, "language": "fr", "type": "verb",
			"lemma_fr": "recevoir qn", "lemma_de": "jdn empfangen"}
	for id in FORMS:
		ContentRegistry.lexeme_forms[id] = {"id": id, "lexeme_id": FR, "language": "fr",
				"form_type": "fr_pres_3pl", "value": FORMS[id]}


func after_test() -> void:
	ContentRegistry.lexemes.erase(FR)
	for id in FORMS:
		ContentRegistry.lexeme_forms.erase(id)


func test_the_prompt_names_the_person() -> void:
	var task := _resolver.resolve(DEF, ContentRegistry.lexemes[FR], {"form_type": "fr_pres_3pl"})
	assert_str(str(task["prompt"])).is_equal("recevoir qn → Präsens, ils/elles")
	assert_str(str(task["meaning"])).contains("jdn empfangen")


func test_with_or_without_subject_and_without_accents() -> void:
	var task := _resolver.resolve(DEF, ContentRegistry.lexemes[FR], {"form_type": "fr_pres_3pl"})
	var evaluator := AnswerEvaluator.new()
	for typed in ["ils reçoivent", "elles reçoivent", "reçoivent", "ils recoivent"]:
		var verdict := evaluator.evaluate(task["accepted_answers"], typed, true)
		assert_bool(bool(verdict["matched"]) and bool(verdict["complete"])) \
				.override_failure_message(typed).is_true()
	# Ohne Cédille gilt es, die richtige Schreibweise wird eingeblendet.
	assert_bool(evaluator.evaluate(task["accepted_answers"], "recoivent", true)["exact"]).is_false()
	assert_bool(evaluator.evaluate(task["accepted_answers"], "ils recevent", true)["matched"]).is_false()


func test_only_a_verb_with_that_form_gets_the_task() -> void:
	var generator := GENERATOR.new()
	assert_array(generator._instances(DEF, ContentRegistry.lexemes[FR])).is_not_empty()
	var without := {"id": "zz-lex.fr.test.parler", "language": "fr", "type": "verb",
			"lemma_fr": "parler", "lemma_de": "sprechen"}
	assert_array(generator._instances(DEF, without)).is_empty()


func test_every_french_form_type_has_a_label() -> void:
	for definition in ContentRegistry.task_definitions.values():
		if str(definition.get("language", "")) == "fr" and definition.has("requires_form"):
			assert_bool(TaskResolver.FORM_LABELS.has(str(definition["requires_form"]))) \
					.override_failure_message(str(definition["id"])).is_true()
