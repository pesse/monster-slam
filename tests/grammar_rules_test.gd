extends GdUnitTestSuite
## Der Regelkatalog für den Erklärer (src/learning/grammar_rules.gd, ADR 0005).


## Jeder Tag, nach dem der Golem fragt, hat eine Regel — sonst erklärt Aufruf 2 genau die
## Sätze ohne Regel, um die es im Bosskampf geht. Fragt er nach keinem Tag, zieht er alle
## Sätze der Auswahl; dass deren Tags im Katalog stehen, hält tests/sentence_data_test.gd.
func test_every_golem_tag_has_a_rule() -> void:
	var golem: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/bosses/grammar_golem.json"))
	for tag in (golem["sentence_rule"] as Dictionary).get("grammar_tags", []):
		assert_str(GrammarRules.rule_for(str(tag))).override_failure_message(
				"Keine Regel für %s" % tag).is_not_empty()


## Ein anderer Name für dieselbe Grammatik zeigt auf denselben Eintrag.
func test_an_alias_shares_its_rule() -> void:
	assert_str(GrammarRules.rule_for("simple_past")).is_equal(GrammarRules.rule_for("past_simple"))
	for target in GrammarRules.ALIASES.values():
		assert_bool(GrammarRules.RULES.has(target)).is_true()


## Eine Zeile je Regel, mit Spiegelstrich wie in der Werkstatt; unbekannte Tags fallen weg
## und zwei Namen derselben Regel ergeben eine Zeile.
func test_focus_is_one_line_per_rule() -> void:
	var focus := GrammarRules.focus({"grammar_tags": ["simple_past", "past_simple", "unbekannt", "passive"]})
	var lines := focus.split("\n")
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).starts_with("- Simple Past")
	assert_str(lines[1]).starts_with("- Passiv")
	assert_str(GrammarRules.focus({})).is_empty()
