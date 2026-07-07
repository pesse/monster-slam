extends GdUnitTestSuite
## Die Reveal-Karte (RevealCard) zeigt die Wortart in der Palettenfarbe und blendet den
## Typ nur bei vorhandener Wortart ein.

const CARD_SCENE := preload("res://scenes/ui/reveal_card.tscn")


func _make_card(item: Dictionary, revealed: bool) -> RevealCard:
	var card := auto_free(CARD_SCENE.instantiate()) as RevealCard
	add_child(card)          # _ready -> onready-Knoten
	card.setup(item, revealed)
	return card


func test_card_shows_word_type_in_palette_color() -> void:
	var card := _make_card({"prompt": "der Premierminister", "answers": ["prime minister"], "lexeme_type": "noun"}, true)
	var type_label := card.get_node("%Type") as Label
	assert_bool(type_label.visible).is_true()
	assert_str(type_label.text).is_equal("Nomen")
	assert_bool(type_label.get_theme_color("font_color").is_equal_approx(WordTypePalette.color_for("noun"))).is_true()


func test_card_without_type_hides_type_label() -> void:
	var card := _make_card({"prompt": "x", "answers": ["y"], "lexeme_type": ""}, true)
	assert_bool((card.get_node("%Type") as Label).visible).is_false()
