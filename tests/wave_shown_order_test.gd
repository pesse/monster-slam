extends GdUnitTestSuite
## „In dieser Welle schon gezeigt" dominiert die Auswahl (Issue #24).
##
## Geprüft an WaveGenerator.ordered(), der Reihenfolge, die pick() durchprobiert — statisch
## und mit erfundenen Kandidaten, damit weder Sprachdaten noch der Lernstand des
## Entwicklungsprofils mitspielen und keine Welle gefahren wird.

const GENERATOR := preload("res://src/battle/wave_generator.gd")


func _cand(source_id: String, learnable_id: String) -> Dictionary:
	return {"source": {"id": source_id}, "learnable_id": learnable_id,
		"definition": {}, "extra": {}}


func _sources(ordered: Array) -> Array:
	return ordered.map(func(c): return str(c["source"]["id"]))


func _never_seen(_id: String) -> bool:
	return false


func _all_seen(_id: String) -> bool:
	return true


## Ohne gezeigte Wörter bleibt es bei fällig → neu → Rest.
func test_without_shown_words_due_comes_before_new_before_rest() -> void:
	var seen := func(id: String) -> bool: return id != "new"
	var cands := [_cand("c", "rest"), _cand("b", "new"), _cand("a", "due")]
	var order := GENERATOR.ordered(cands, ["due"], seen, {})
	assert_array(_sources(order)).is_equal(["a", "b", "c"])


## Ein schon gezeigtes Wort kommt nach jedem ungezeigten — auch wenn es fällig ist und
## die anderen nur „Rest" sind.
func test_a_shown_word_loses_even_when_it_is_due() -> void:
	var cands := [_cand("shown", "shown.due"), _cand("x", "x.rest"), _cand("y", "y.rest")]
	var order := GENERATOR.ordered(cands, ["shown.due"], _all_seen, {"shown": 0})
	assert_array(_sources(order)).has_size(3)
	assert_str(str(_sources(order)[2])).is_equal("shown")


## Die Sperre sitzt am Grundwort: eine andere Richtung oder Aufgabenart desselben Worts
## ist ebenfalls „schon gezeigt".
func test_every_task_of_a_shown_word_waits() -> void:
	var cands := [
		_cand("w", "translate.de_to_en.w"),
		_cand("w", "translate.en_to_de.w"),
		_cand("v", "translate.de_to_en.v"),
	]
	var order := GENERATOR.ordered(cands, [], _never_seen, {"w": 0})
	assert_str(str(_sources(order)[0])).is_equal("v")


## Ist der Pool erschöpft, kommt zuerst das Wort, das am längsten nicht dran war.
func test_the_longest_unshown_word_repeats_first() -> void:
	var cands := [_cand("late", "l"), _cand("early", "e"), _cand("mid", "m")]
	var shown := {"late": 7, "early": 1, "mid": 4}
	var order := GENERATOR.ordered(cands, [], _all_seen, shown)
	assert_array(_sources(order)).is_equal(["early", "mid", "late"])


## Kein Kandidat fällt weg: die Rückfallebene in pick() braucht auch die Wiederholungen.
func test_nothing_is_dropped_when_all_words_were_shown() -> void:
	var cands := [_cand("a", "a1"), _cand("a", "a2"), _cand("b", "b1")]
	var order := GENERATOR.ordered(cands, [], _all_seen, {"a": 0, "b": 1})
	assert_array(order).has_size(3)
	assert_array(_sources(order)).is_equal(["a", "a", "b"])


## Die Verdrahtung in pick(): mit echten Daten wiederholt sich über mehrere Züge kein
## Grundwort, solange der Pool mehr hergibt. Nur lesend — der Lernstand bleibt unberührt.
func test_pick_does_not_repeat_a_shown_word(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var generator := WaveGenerator.new()
	var shown := {}
	for i in 4:
		var plan := generator.pick({}, {}, shown)
		var source_id := str(plan["task"].get("source_id", ""))
		assert_bool(shown.has(source_id)) \
			.override_failure_message("'%s' kam in Zug %d erneut" % [source_id, i]).is_false()
		shown[source_id] = i
