extends GdUnitTestSuite
## Der Zauberladen (ADR 0014): je Zauber eine Kachel; Name, Wirkung und Preis (Münze mit
## Zahl) stehen im Hinweis, nicht auf der Kachel. Liest nur — gekauft wird hier nichts.

const SHOP_SCENE := "res://scenes/ui/spell_shop.tscn"


func test_every_spell_has_a_tile_with_price_and_description() -> void:
	var shop: Control = auto_free((load(SHOP_SCENE) as PackedScene).instantiate())
	add_child(shop)
	var tiles := (shop.get_node("%Offers") as Control).get_children()
	var spells := ContentRegistry.all("spells")
	assert_int(tiles.size()).is_equal(spells.size())
	for tile: SpellTile in tiles:
		var hint := tile.hint()
		assert_bool(tile.get_meta(Hints.META) is Callable).is_true()
		assert_str(str(hint.get("title", ""))).is_equal(str(tile.spell.get("name", "")))
		assert_str(str(hint.get("body", ""))).is_equal(str(tile.spell.get("description", "")))
		var prices: Array = hint.get("prices", [])
		assert_int(prices.size()).is_equal(1)
		assert_str(str(prices[0][1])).is_equal(Wallet.digits(int(tile.spell.get("price", 0))))
