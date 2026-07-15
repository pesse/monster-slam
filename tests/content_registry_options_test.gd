extends GdUnitTestSuite
## Tests für die Auswahl-Helfer der ContentRegistry, die den Session-Setup-Screen
## datengetrieben füllen (all_lexeme_tags / all_task_types).


func test_all_lexeme_tags_contains_known_tags() -> void:
	var tags := ContentRegistry.all_lexeme_tags()
	assert_bool("basics" in tags).is_true()
	assert_bool("core" in tags).is_true()


func test_all_lexeme_tags_sorted_and_distinct() -> void:
	var tags := ContentRegistry.all_lexeme_tags()
	var seen := {}
	var prev := ""
	for tag in tags:
		assert_bool(seen.has(tag)).is_false()  # keine Duplikate
		seen[tag] = true
		assert_bool(prev <= tag).is_true()  # aufsteigend sortiert
		prev = tag


func test_all_lexeme_types_contains_known_types() -> void:
	var types := ContentRegistry.all_lexeme_types()
	assert_bool("noun" in types).is_true()
	assert_bool("verb" in types).is_true()
	assert_bool("adjective" in types).is_true()


func test_all_task_types_contains_known_types() -> void:
	var types := ContentRegistry.all_task_types()
	assert_bool("translate" in types).is_true()
	assert_bool("opposite" in types).is_true()
	assert_bool("synonym" in types).is_true()
	assert_bool("confusables" in types).is_true()
