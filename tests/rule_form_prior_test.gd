extends GdUnitTestSuite
## Formaufgaben nach der Regel starten mit hoher Confidence (WaveGenerator.RULE_FORM_PRIOR):
## ein Verb ohne `irregular` mit Vergangenheit auf -ed kommt ein-, zweimal und steht dann
## als gemeistert hinten. Schreibfallen (Verdopplung, y → ied) starten etwas tiefer,
## unregelmäßige Verben mit dem Prior des Lexems.
##
## Testlexeme mit `zz-`Ids, danach wieder entfernt. Allerweltswörter als Beispiel.

const GENERATOR := preload("res://src/battle/wave_generator.gd")
const PLAIN := "zz-lex.en.test.walk"
const SPELLING := "zz-lex.en.test.stop"
const IRREGULAR := "zz-lex.en.test.go"
const PAST := {"requires_form": "past_simple", "task_type": "conjugation", "direction": "en"}
const PARTICIPLE := {"requires_form": "past_participle", "task_type": "conjugation", "direction": "en"}


func before_test() -> void:
	_verb(PLAIN, "walk", "walked", "walked", false)
	_verb(SPELLING, "stop", "stopped", "stopped", false)
	_verb(IRREGULAR, "go", "went", "gone", true)


func after_test() -> void:
	for id in [PLAIN, SPELLING, IRREGULAR]:
		ContentRegistry.lexemes.erase(id)
		for suffix in [".base", ".past", ".pp"]:
			ContentRegistry.lexeme_forms.erase(id + suffix)


func _verb(id: String, base: String, past: String, pp: String, irregular: bool) -> void:
	ContentRegistry.lexemes[id] = {"id": id, "type": "verb", "lemma_en": base + " sth.",
			"lemma_de": "-", "irregular": irregular}
	for entry in [[".base", "base", base], [".past", "past_simple", past],
			[".pp", "past_participle", pp]]:
		ContentRegistry.lexeme_forms[id + entry[0]] = {"id": id + entry[0], "lexeme_id": id,
				"language": "en", "form_type": entry[1], "value": entry[2]}


func test_plain_ed_forms_are_rule_forms() -> void:
	assert_str(GENERATOR.rule_form_kind("settle", "settled")).is_equal("plain")
	assert_str(GENERATOR.rule_form_kind("discuss", "discussed")).is_equal("plain")
	assert_str(GENERATOR.rule_form_kind("bump into", "bumped into")).is_equal("plain")


func test_doubling_and_y_are_spelling_traps() -> void:
	assert_str(GENERATOR.rule_form_kind("prefer", "preferred")).is_equal("spelling")
	assert_str(GENERATOR.rule_form_kind("snorkel", "snorkelled")).is_equal("spelling")
	assert_str(GENERATOR.rule_form_kind("bully", "bullied")).is_equal("spelling")
	assert_str(GENERATOR.rule_form_kind("rely on", "relied on")).is_equal("spelling")


func test_other_forms_follow_no_rule() -> void:
	assert_str(GENERATOR.rule_form_kind("take a break", "took a break")).is_equal("")
	assert_str(GENERATOR.rule_form_kind("dig", "dug")).is_equal("")
	assert_str(GENERATOR.rule_form_kind("hand over", "handed out")).is_equal("")


func test_prior_by_kind() -> void:
	var generator: WaveGenerator = GENERATOR.new()
	var plain: Dictionary = ContentRegistry.lexemes[PLAIN]
	assert_float(generator._rule_form_prior(PAST, plain)).is_equal(GENERATOR.RULE_FORM_PRIOR)
	assert_float(generator._rule_form_prior(PARTICIPLE, plain)).is_equal(GENERATOR.RULE_FORM_PRIOR)
	assert_float(generator._rule_form_prior(PAST, ContentRegistry.lexemes[SPELLING])) \
			.is_equal(GENERATOR.SPELLING_FORM_PRIOR)


func test_irregular_verbs_and_translations_keep_the_lexeme_prior() -> void:
	var generator: WaveGenerator = GENERATOR.new()
	assert_float(generator._rule_form_prior(PAST, ContentRegistry.lexemes[IRREGULAR])).is_equal(-1.0)
	assert_float(generator._rule_form_prior({"task_type": "translate"}, ContentRegistry.lexemes[PLAIN])) \
			.is_equal(-1.0)


## Die Absicht hinter den Zahlen: nach zwei bzw. drei Treffern in einer Sitzung gemeistert,
## nicht nach einem (die Treffer liegen hier Sekunden auseinander, ADR 0018).
func test_priors_need_two_and_three_hits() -> void:
	assert_int(_hits_to_mastery(GENERATOR.RULE_FORM_PRIOR)).is_equal(2)
	assert_int(_hits_to_mastery(GENERATOR.SPELLING_FORM_PRIOR)).is_equal(3)


func _hits_to_mastery(start: float) -> int:
	var progress: Node = load("res://src/learning/player_progress.gd").new()
	progress.player_id = "zz-rule-form-prior"
	var hits := 0
	while not progress.is_mastered("zz-task") and hits < 10:
		progress.record("zz-task", true, 0, start)
		hits += 1
	progress.free()
	return hits
