class_name SpellShop
extends Control
## Der Zauberladen (ADR 0014): oben Vorrat und Gold, darunter je Zauber eine Kachel
## (SpellTile). Öffnet als Fenster über `ProfileBadge.open_window`. Gekauft wird über
## `Inventory.buy`, weggeworfen (Klick auf einen Platz) über `Inventory.discard`.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const TILE_SCENE := preload("res://scenes/ui/spell_tile.tscn")
const SLOT_SCENE := preload("res://scenes/ui/spell_slot.tscn")
## Aufblenden des Fensters (s).
const FADE_IN := 0.15

## Das Fenster will zu.
signal closed()

@onready var _stock: GridContainer = %Stock
@onready var _gold: Label = %Gold
@onready var _offers: GridContainer = %Offers
@onready var _discard_confirm: ConfirmDialog = %DiscardConfirm

## Der Platz, dessen Stapel nach der Rückfrage weggeworfen wird (-1: keiner).
var _discard_index := -1


func _ready() -> void:
	(%CloseButton as BaseButton).pressed.connect(close)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	for spell: Dictionary in ContentRegistry.all("spells"):
		var tile := TILE_SCENE.instantiate() as SpellTile
		_offers.add_child(tile)
		tile.setup(spell)
		tile.buy_pressed.connect(_on_buy.bind(tile))
	_discard_confirm.confirmed.connect(func() -> void:
			Inventory.discard(_discard_index)
			_discard_index = -1)
	_discard_confirm.cancelled.connect(func() -> void: _discard_index = -1)
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
	if event.is_action_pressed("ui_cancel") and not _discard_confirm.visible:
		get_viewport().set_input_as_handled()
		close()


func _on_buy(spell: Dictionary, tile: SpellTile) -> void:
	if Inventory.buy(spell):
		tile.pulse()


## Ein Klick auf einen belegten Platz fragt, ob sein Stapel weg soll.
func _on_slot_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var entry := Inventory.slot(index)
	var spell := ContentRegistry.get_entry("spells", str(entry.get("id", "")))
	if spell.is_empty():
		return
	get_viewport().set_input_as_handled()
	_discard_index = index
	var count := int(entry.get("count", 0))
	_discard_confirm.ask("%s wegwerfen?" % str(spell.get("name", "")),
			"%s auf Platz %d %s weg. Gold gibt es dafür nicht zurück." % [
				"Der Zauber" if count == 1 else "Alle %d Zauber" % count, index + 1,
				"ist dann" if count == 1 else "sind dann"],
			"Wegwerfen", "Behalten")


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
		added.gui_input.connect(_on_slot_input.bind(_stock.get_child_count()))
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
					"%d× im Vorrat" % int(entry.get("count", 0)),
					"Taste %d im Kampf · Klick: wegwerfen" % (i + 1))
	for tile: SpellTile in _offers.get_children():
		tile.refresh()
