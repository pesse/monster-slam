extends GdUnitTestSuite
## Aufgaben, die das Wort nur auf Englisch nennen („bully → Past Participle",
## „Gegenteil von big"), tragen die Bedeutung als task["meaning"] mit — im Reveal steht
## sonst eine Form oder ein Gegenwort da, das der Spieler nicht übersetzen kann.
## Übersetzungs- und Verwechslungsaufgaben zeigen das Deutsche schon selbst: dort bleibt
## das Feld leer.
##
## Die Testlexeme werden direkt in die ContentRegistry gelegt (der Resolver schlägt dort
## nach) und danach wieder entfernt — mit `zz-`Ids, damit sie mit echten Daten oder
## einem installierten Pack nicht kollidieren.

const SRC := "zz-lex.test.bully"
const TGT := "zz-lex.test.small"
const BIG := "zz-lex.test.big"

var _resolver: TaskResolver


func before_test() -> void:
	_resolver = TaskResolver.new()
	ContentRegistry.lexemes[SRC] = {
		"id": SRC, "type": "verb", "lemma_en": "bully", "lemma_de": "schikanieren",
		"lemma_de_alt": ["drangsalieren"], "lemma_en_alt": ["harass"],
	}
	ContentRegistry.lexemes[BIG] = {"id": BIG, "type": "adjective", "lemma_en": "big", "lemma_de": "groß"}
	ContentRegistry.lexemes[TGT] = {"id": TGT, "type": "adjective", "lemma_en": "small", "lemma_de": "klein"}
	ContentRegistry.lexeme_forms["zz-form.bully.pp"] = {
		"id": "zz-form.bully.pp", "lexeme_id": SRC, "form_type": "past_participle", "value": "bullied",
	}


func after_test() -> void:
	ContentRegistry.lexemes.erase(SRC)
	ContentRegistry.lexemes.erase(BIG)
	ContentRegistry.lexemes.erase(TGT)
	ContentRegistry.lexeme_forms.erase("zz-form.bully.pp")


func test_the_form_task_carries_the_meaning_of_the_word() -> void:
	var task := _resolver.resolve(
		{"task_type": "conjugation", "difficulty": 2}, ContentRegistry.lexemes[SRC],
		{"form_type": "past_participle"})
	assert_str(str(task.get("prompt", ""))).is_equal("bully → Past Participle")
	# Primäre Übersetzung plus Alternativen — die Auflösung ist der Ort, an dem man
	# die zweite Bedeutung sehen will.
	assert_str(str(task.get("meaning", ""))).is_equal("bully = schikanieren / drangsalieren")


func test_the_opposite_task_carries_the_meaning_of_the_answer() -> void:
	var task := _resolver.resolve(
		{"task_type": "opposite", "difficulty": 2}, ContentRegistry.lexemes[BIG],
		{"target_lexeme_id": TGT})
	# Gesucht ist „small" — die Bedeutung gehört also zur Antwort, nicht zur Frage.
	assert_str(str(task.get("meaning", ""))).is_equal("small = klein")


func test_the_translation_task_has_no_meaning() -> void:
	var task := _resolver.resolve(
		{"task_type": "translate", "direction": "de_to_en", "difficulty": 1},
		ContentRegistry.lexemes[BIG])
	assert_str(str(task.get("meaning", "MISSING"))).is_equal("")


## Das Reveal zeigt beide Seiten vollständig: zur Aufgabe ihre Alternativen, zur
## Antwort die ihren.
func test_the_translation_task_carries_the_alternatives_of_its_prompt() -> void:
	var de_to_en := _resolver.resolve(
		{"task_type": "translate", "direction": "de_to_en", "difficulty": 1},
		ContentRegistry.lexemes[SRC])
	assert_array(de_to_en.get("prompt_alt", [])).contains_exactly(["drangsalieren"])
	assert_array(de_to_en.get("accepted_answers", [])).contains_exactly(["bully", "harass"])
	var en_to_de := _resolver.resolve(
		{"task_type": "translate", "direction": "en_to_de", "difficulty": 1},
		ContentRegistry.lexemes[SRC])
	assert_array(en_to_de.get("prompt_alt", [])).contains_exactly(["harass"])
	assert_array(en_to_de.get("accepted_answers", [])).contains_exactly(["schikanieren", "drangsalieren"])
