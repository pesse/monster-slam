extends GdUnitTestSuite
## Die Reveal-Karte (RevealCard) zeigt die Wortart in der Palettenfarbe und blendet den
## Typ nur bei vorhandener Wortart ein. Trägt der Eintrag eine Bedeutung („bully =
## schikanieren"), steht sie im Lösungsteil — bei Formaufgaben sagt die Aufgabe selbst
## nicht, was das Wort heißt.

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


func test_card_shows_the_meaning_with_the_solution() -> void:
	var card := _make_card({
		"prompt": "bully → Past Participle", "answers": ["bullied"],
		"lexeme_type": "verb", "meaning": "bully = schikanieren",
	}, true)
	var meaning := card.get_node("%Meaning") as Label
	assert_bool(meaning.visible).is_true()
	assert_str(meaning.text).is_equal("bully = schikanieren")
	# Im Lösungsteil, damit sie bei Gegenteil/Synonym nicht vorab die Antwort verrät.
	assert_bool(card.solution().is_ancestor_of(meaning)).is_true()


func test_card_without_meaning_hides_the_meaning_label() -> void:
	# Übersetzungsaufgaben zeigen die Bedeutung schon als Antwort — keine zweite Zeile.
	var card := _make_card({"prompt": "die Katze", "answers": ["cat"], "lexeme_type": "noun"}, true)
	assert_bool((card.get_node("%Meaning") as Label).visible).is_false()
