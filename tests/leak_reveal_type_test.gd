extends GdUnitTestSuite
## Die Reveal-Card zeigt die Wortart in der Palettenfarbe an.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var found := _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func test_card_shows_word_type_in_palette_color() -> void:
	var reveal = auto_free(REVEAL_SCENE.instantiate())
	add_child(reveal)  # _ready baut das Layout auf
	var card := reveal._build_card({"prompt": "der Premierminister", "answers": ["prime minister"], "lexeme_type": "noun"}, true) as Control
	auto_free(card)

	var label := _find_label_with_text(card, "Nomen")
	assert_object(label).override_failure_message("Kein Wortart-Label 'Nomen' auf der Karte").is_not_null()
	assert_bool(label.get_theme_color("font_color").is_equal_approx(WordTypePalette.color_for("noun"))).is_true()


func test_card_without_type_has_no_type_label() -> void:
	var reveal = auto_free(REVEAL_SCENE.instantiate())
	add_child(reveal)
	var card := reveal._build_card({"prompt": "x", "answers": ["y"], "lexeme_type": ""}, true) as Control
	auto_free(card)
	# Keine der Wortart-Bezeichnungen darf auftauchen.
	for name in WordTypePalette.LABELS.values():
		assert_object(_find_label_with_text(card, str(name))).is_null()
