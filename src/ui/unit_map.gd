extends Control
## Landkarte: je Buch ein Pfad aus Units, jede mit ihrer Festungsstufe (Issue #21).
##
## Die Grundlage für mehr — hier steht vorerst nur, was es schon gibt: Stufe, Fortschritt
## und der Weg zur nächsten Stufe. Kein Freischalten, keine Belohnungen auf der Karte.
##
## Das Layout liegt in unit_map.tscn, ein Buch in unit_book.tscn; der Pfad selbst ist
## gezeichnet (UnitPath). Die Zahlen kommen aus FortressTier.unit_tiers — derselben
## Zählung wie Kampf und Statistik. Ein Klick auf eine Unit setzt den Bereich auf sie und
## öffnet das Session-Setup.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const BOOK_SCENE := preload("res://scenes/ui/unit_book.tscn")

@onready var _books: VBoxContainer = %Books
@onready var _empty_hint: Label = %EmptyHint


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_fill()


func _fill() -> void:
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes())
	var shelves := book_units(tiers)
	_empty_hint.visible = shelves.is_empty()
	for book in ContentRegistry.all_books():
		if not shelves.has(book):
			continue
		var section := BOOK_SCENE.instantiate() as Control
		_books.add_child(section)
		(section.get_node("Title") as Label).text = ContentRegistry.book_label(book)
		var path := section.get_node("Path") as UnitPath
		path.setup(shelves[book], hint_lines.bind(ContentRegistry.book_label(book)))
		path.unit_selected.connect(_on_unit_selected)


## Ordnet den Stand aus FortressTier.unit_tiers nach Büchern: book -> Units nach Nummer,
## je { key, unit, done, total, tier }. Statisch, damit die Reihenfolge prüfbar bleibt.
static func book_units(tiers: Dictionary) -> Dictionary:
	var out := {}
	for key in tiers:
		var group: Dictionary = tiers[key]
		var book := str(group["book"])
		if not out.has(book):
			out[book] = []
		out[book].append({
			"key": str(key), "unit": int(group["unit"]),
			"done": int(group["done"]), "total": int(group["total"]),
			"tier": int(group["tier"]),
		})
	for book in out:
		(out[book] as Array).sort_custom(func(a, b): return int(a["unit"]) < int(b["unit"]))
	return out


## Die Karte am Zeiger für eine Unit: Stufe, Stand und was bis zur nächsten Stufe fehlt.
static func hint_lines(unit: Dictionary, book_name: String) -> Dictionary:
	var done := int(unit["done"])
	var total := int(unit["total"])
	var body := "🏰 Stufe %d · %d von %d Wörtern gemeistert" % [int(unit["tier"]), done, total]
	var next := FortressTier.next_threshold(done, total)
	if next.is_empty():
		body += "\nHöchste Stufe erreicht."
	else:
		var needed := int(next["needed"])
		body += "\nNoch %d %s bis Stufe %d (+%d HP)" % [needed,
				"Wort" if needed == 1 else "Wörter", int(next["tier"]), FortressTier.HP_PER_TIER]
	return {
		"title": "%s, Unit %d" % [book_name, int(unit["unit"])],
		"body": body,
		"note": "Klick: diese Unit spielen.",
	}


func _on_unit_selected(key: String) -> void:
	UserSettings.set_selected_scope(PackedStringArray([key]))
	get_tree().change_scene_to_file(SESSION_SETUP_SCENE)
