extends GdUnitTestSuite
## Die UI-Legende baut je Wortart genau einen Eintrag (Farb-Swatch + Name) aus
## WordTypePalette. Sichert, dass Legende und Palette konsistent bleiben.

const LEGEND_SCENE := preload("res://scenes/ui/word_type_legend.tscn")


func test_one_entry_per_word_type() -> void:
	var legend := auto_free(LEGEND_SCENE.instantiate()) as HBoxContainer
	add_child(legend)  # löst _ready aus
	assert_int(legend.get_child_count()).is_equal(WordTypePalette.LABELS.size())


func test_first_entry_matches_palette() -> void:
	var legend := auto_free(LEGEND_SCENE.instantiate()) as HBoxContainer
	add_child(legend)
	var first_type: String = WordTypePalette.LABELS.keys()[0]
	var entry := legend.get_child(0) as HBoxContainer
	var swatch := entry.get_child(0) as ColorRect
	var label := entry.get_child(1) as Label
	assert_bool(swatch.color.is_equal_approx(WordTypePalette.color_for(first_type))).is_true()
	assert_str(label.text).is_equal(str(WordTypePalette.LABELS[first_type]))
