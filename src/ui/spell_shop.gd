class_name SpellShop
extends Control
## Der Zauberladen (scenes/ui/spell_shop.tscn, docs/adr/0014-zauber-zum-verbrauchen.md):
## oben der Vorrat mit seinen Plätzen und das Gold, darunter je Zauber eine Kachel (SpellTile).
##
## Öffnet als Fenster wie Fähigkeiten und Statistik (`ProfileBadge.open_window`): über den
## Knopf im Hauptmenü und über die Knopfreihe der kompakten Plakette — überall außer im
## Kampf, dort wird nur eingesetzt. Derselbe Rahmen, dasselbe Schließen-X, Escape schließt.
##
## Gekauft wird über `Inventory.buy`, das auch das Gold abbucht; der Laden zeigt nur an
## und hängt an `Inventory.changed` und `Wallet.changed`.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const TILE_SCENE := preload("res://scenes/ui/spell_tile.tscn")
const SLOT_SCENE := preload("res://scenes/ui/spell_slot.tscn")
## So lange blendet das Fenster auf (s) — wie die anderen Fenster.
const FADE_IN := 0.15

## Das Fenster will zu (siehe settings_menu.gd).
signal closed()

@onready var _stock: GridContainer = %Stock
@onready var _gold: Label = %Gold
@onready var _offers: GridContainer = %Offers


func _ready() -> void:
	(%CloseButton as BaseButton).pressed.connect(close)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	for spell: Dictionary in ContentRegistry.all("spells"):
		var tile := TILE_SCENE.instantiate() as SpellTile
		_offers.add_child(tile)
		tile.setup(spell)
		tile.buy_pressed.connect(_on_buy.bind(tile))
	Inventory.changed.connect(_refresh)
	Wallet.changed.connect(func(_gold_now: int) -> void: _refresh())
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	if _offers.get_child_count() > 0:
		(_offers.get_child(0) as SpellTile).grab_focus.call_deferred()


func close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_buy(spell: Dictionary, tile: SpellTile) -> void:
	if Inventory.buy(spell):
		tile.pulse()


func _refresh() -> void:
	_gold.text = Wallet.digits()
	var count := Inventory.slot_count()
	_stock.columns = count
	while _stock.get_child_count() > count:
		var last := _stock.get_child(_stock.get_child_count() - 1)
		_stock.remove_child(last)
		last.queue_free()
	while _stock.get_child_count() < count:
		var added := SLOT_SCENE.instantiate() as Control
		# Im Kampf lässt der Platz die Maus durch; hier trägt er einen Hinweis.
		added.mouse_filter = Control.MOUSE_FILTER_PASS
		_stock.add_child(added)
	for i in count:
		var slot := _stock.get_child(i) as SpellSlot
		var entry := Inventory.slot(i)
		slot.show_entry(entry, i + 1)
		var spell := ContentRegistry.get_entry("spells", str(entry.get("id", "")))
		if spell.is_empty():
			Hints.attach(slot, "Platz %d frei" % (i + 1), "Taste %d im Kampf" % (i + 1))
		else:
			Hints.attach(slot, str(spell.get("name", "")),
					"%d× im Vorrat" % int(entry.get("count", 0)), "Taste %d im Kampf" % (i + 1))
	for tile: SpellTile in _offers.get_children():
		tile.refresh()
