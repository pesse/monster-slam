extends Control
## Buchauswahl: der erste Schritt nach „▶ Spielen" (ADR 0006).
##
## Je Buch eine Karte mit Titel und Stand: gemeisterte Wörter, die schwächste Festung und
## die Kronen besiegter Bosse. Ein Klick öffnet die Buchkarte. Die Zahlen kommen aus
## FortressTier.unit_tiers und BossRecord — derselben Zählung wie Karte und Kampf.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const CARD_SCENE := preload("res://scenes/ui/book_card.tscn")

@onready var _books: VBoxContainer = %Books
@onready var _empty_hint: Label = %EmptyHint


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_fill()


func _fill() -> void:
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes())
	var shelves := BookMap.book_units(tiers)
	var wins := BossRecord.wins(UserSettings.active_profile())
	_empty_hint.visible = shelves.is_empty()
	for book in ContentRegistry.all_books():
		if not shelves.has(book):
			continue
		var card := CARD_SCENE.instantiate() as Button
		_books.add_child(card)
		(card.get_node("%Title") as Label).text = ContentRegistry.book_label(book)
		(card.get_node("%Stats") as Label).text = summary(shelves[book], wins)
		card.pressed.connect(_open.bind(book))


## Die Zeile unter dem Titel: Units, gemeisterte Wörter, schwächste Festung, Bosskronen.
static func summary(units: Array, wins: Dictionary) -> String:
	var done := 0
	var total := 0
	var lowest := FortressTier.MAX_TIER
	var crowns := 0
	for unit in units:
		done += int(unit["done"])
		total += int(unit["total"])
		lowest = mini(lowest, int(unit["tier"]))
		if int(wins.get(str(unit["key"]), 0)) > 0:
			crowns += 1
	return "%d %s · %d von %d Wörtern gemeistert · 🏰 Stufe %d · 👑 %d von %d Bossen" % [
		units.size(), "Unit" if units.size() == 1 else "Units", done, total,
		lowest if not units.is_empty() else 0, crowns, units.size()]


func _open(book: String) -> void:
	MapSelection.book = book
	get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)
