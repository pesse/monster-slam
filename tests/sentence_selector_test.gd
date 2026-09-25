extends GdUnitTestSuite
## Welcher Satz drankommt (src/learning/sentence_selector.gd).
##
## Geprüft werden die REGELN an erfundenen Sätzen — was im Bestand steht, ist Sache von
## tests/sentence_data_test.gd. Das Netto-Maß hängt am Lernstand des aktiven Profils;
## dieser Test fragt es nur dort ab, wo es ohne Lexeme auf den Default fällt, und fasst
## PlayerProgress nicht an (das ist der echte Lernstand des Spielers).

const EASY := {"id": "sen.test.easy", "difficulty": 1, "grammar_tags": ["present_simple"]}
const HARD := {"id": "sen.test.hard", "difficulty": 4, "grammar_tags": ["past_perfect"]}


func test_an_empty_pool_takes_everything() -> void:
	var pool := {"scope": [], "tags": [], "grammar_tags": [], "difficulty_max": 0}
	assert_bool(SentenceSelector.matches(EASY, pool)).is_true()
	assert_bool(SentenceSelector.matches(HARD, pool)).is_true()


func test_the_difficulty_limit_holds() -> void:
	var pool := {"grammar_tags": [], "difficulty_max": 2}
	assert_bool(SentenceSelector.matches(EASY, pool)).is_true()
	assert_bool(SentenceSelector.matches(HARD, pool)).is_false()


func test_a_grammar_rule_selects() -> void:
	var pool := {"grammar_tags": ["past_perfect", "past_simple"], "difficulty_max": 0}
	assert_bool(SentenceSelector.matches(EASY, pool)).is_false()
	assert_bool(SentenceSelector.matches(HARD, pool)).is_true()


## Ein Satz zählt zum Scope, wenn EINES seiner Lexeme dazu zählt — er wird ja um dieses
## Wortes willen gestellt. Ein Satz ohne Lexeme fällt damit aus jedem eingeschränkten Pool.
func test_a_sentence_without_lexemes_is_out_of_any_scope() -> void:
	var pool := {"grammar_tags": [], "difficulty_max": 0}
	assert_bool(SentenceSelector.matches(EASY, pool, {"lex.test.a": true})).is_false()


## Ein Boss trägt seit ADR 0004 keine Sätze mehr selbst, sondern eine Auswahlregel.
func test_a_boss_rule_becomes_a_pool() -> void:
	var boss := {"id": "boss.test", "sentence_rule": {
		"grammar_tags": ["past_perfect"], "difficulty_max": 4}}
	var pool := SentenceSelector.pool_for_boss(boss)
	assert_array(pool["grammar_tags"] as Array).contains(["past_perfect"])
	assert_int(int(pool["difficulty_max"])).is_equal(4)
	assert_bool(SentenceSelector.matches(HARD, pool)).is_true()
	assert_bool(SentenceSelector.matches(EASY, pool)).is_false()


## Ein Boss ohne Regel schränkt nichts ein — sonst stünde ein neu angelegter Boss vor
## einem leeren Vorrat, ohne dass es jemand merkt.
func test_a_boss_without_a_rule_takes_everything() -> void:
	var pool := SentenceSelector.pool_for_boss({"id": "boss.test"})
	assert_bool(SentenceSelector.matches(EASY, pool)).is_true()
	assert_bool(SentenceSelector.matches(HARD, pool)).is_true()


## Das Netto-Maß ist dasselbe wie im WaveGenerator: Grundschwierigkeit minus Können. Ohne
## Lexeme steht der Lernstand auf dem neutralen Default, also entscheidet die
## Schwierigkeit — und zwar auf derselben Skala wie bei den Monstern.
func test_the_net_measure_is_difficulty_minus_confidence() -> void:
	assert_float(SentenceSelector.confidence("sen.test.easy")) \
			.is_equal(PlayerProgress.DEFAULT_CONFIDENCE)
	assert_float(SentenceSelector.net_difficulty(EASY)).is_equal(
			1.0 / float(WaveGenerator.DIFFICULTY_MAX) - PlayerProgress.DEFAULT_CONFIDENCE)
	assert_float(SentenceSelector.net_difficulty(HARD)) \
			.is_greater(SentenceSelector.net_difficulty(EASY))


## Die Skala ist die des Kampfes und keine zweite daneben.
func test_the_scale_is_the_one_the_waves_use() -> void:
	assert_int(SentenceSelector.DIFFICULTY_MAX).is_equal(WaveGenerator.DIFFICULTY_MAX)


## Ein Filter, der kein Lexem trifft, lässt keinen Satz übrig. Vorher hieß die leere
## Lexem-Menge „keine Einschränkung" — ein Tippfehler im Tag gab dem Boss alle Sätze.
func test_a_filter_matching_nothing_leaves_nothing(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var selector := SentenceSelector.new()
	assert_array(selector.candidates({})).is_not_empty()
	assert_array(selector.candidates({"tags": ["kein-tag-mit-diesem-namen"]})).is_empty()
	assert_array(selector.candidates({"scope": ["kein-buch/99"]})).is_empty()
