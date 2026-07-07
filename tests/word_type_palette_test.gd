extends GdUnitTestSuite
## Wortart-Farbpalette für die Monster-Outline (reine Logik, kein SceneTree nötig).

func test_known_types_are_distinct() -> void:
	assert_bool(WordTypePalette.color_for("verb") == WordTypePalette.color_for("noun")).is_false()
	assert_bool(WordTypePalette.color_for("adjective") == WordTypePalette.color_for("noun")).is_false()


func test_all_documented_types_have_a_color() -> void:
	for type in ["noun", "verb", "adjective", "adverb", "phrase", "connector", "expression"]:
		assert_bool(WordTypePalette.color_for(type) == WordTypePalette.FALLBACK).override_failure_message(
			"Wortart '%s' hat keine eigene Farbe (fällt auf FALLBACK zurück)" % type
		).is_false()


func test_unknown_and_empty_type_fall_back() -> void:
	assert_bool(WordTypePalette.color_for("") == WordTypePalette.FALLBACK).is_true()
	assert_bool(WordTypePalette.color_for("gibtsnicht") == WordTypePalette.FALLBACK).is_true()
