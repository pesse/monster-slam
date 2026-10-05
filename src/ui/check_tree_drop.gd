class_name CheckTreeDrop
extends Control
## Ein aufklappender Baum mit Häkchen: Gruppen (Units) und ihre Einträge (Teile, Boni). Ein
## Häkchen an der Gruppe setzt alle ihre Einträge, ein Teil der Einträge zeigt die Gruppe
## halb gesetzt. Gezählt werden nur die Einträge; keiner gewählt heißt „keine Einschränkung".
##
## Ein Overlay über dem ganzen Screen wie ConfirmDialog, kein Godot-Fenster: der Baum hängt
## als Tafel unter seinem Knopf, ein Klick daneben oder Escape klappt ihn zu.

signal changed()

const GAP := 4.0

@onready var _panel: Control = %DropPanel
@onready var _tree: Tree = %DropTree

## Eintrags-Wert -> TreeItem.
var _leaves: Dictionary = {}


func _ready() -> void:
	hide()
	_tree.item_edited.connect(_on_edited)
	_tree.gui_input.connect(_on_tree_input)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			hide())


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


## Setzt den Baum neu: [{ text, children: [{ text, value }] }]. Gewählte Einträge, die es
## weiter gibt, bleiben gewählt.
func set_groups(groups: Array) -> void:
	var keep := {}
	for value in values():
		keep[value] = true
	_tree.clear()
	_leaves.clear()
	var root := _tree.create_item()
	for group in groups:
		var parent := _tree.create_item(root)
		_check_cell(parent, str(group["text"]))
		var any := false
		for child in group["children"]:
			var item := _tree.create_item(parent)
			_check_cell(item, str(child["text"]))
			item.set_checked(0, keep.has(child["value"]))
			any = any or keep.has(child["value"])
			_leaves[child["value"]] = item
		parent.collapsed = not any
		if any and not parent.get_children().is_empty():
			parent.get_first_child().propagate_check(0, false)


func _check_cell(item: TreeItem, text: String) -> void:
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_text(0, text)
	# Lange Bonus-Titel brechen um, statt abgeschnitten zu werden.
	item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)


## Die gewählten Einträge, leer ohne Wahl.
func values() -> Array:
	var out: Array = []
	for value in _leaves:
		if (_leaves[value] as TreeItem).is_checked(0):
			out.append(value)
	return out


## Was der Knopf zeigt: ganze Gruppen mit ihrem Namen, sonst die Einträge; `empty` ohne Wahl.
func summary(empty: String) -> String:
	var parts: Array = []
	if _tree.get_root() == null:
		return empty
	for item: TreeItem in _tree.get_root().get_children():
		var children := item.get_children()
		var chosen := children.filter(func(c): return c.is_checked(0))
		if chosen.is_empty():
			continue
		if chosen.size() == children.size():
			parts.append(item.get_text(0))
		else:
			for c in chosen:
				parts.append("%s · %s" % [item.get_text(0), c.get_text(0)])
	if parts.is_empty():
		return empty
	return str(parts[0]) if parts.size() == 1 else "%s +%d" % [parts[0], parts.size() - 1]


func clear_checks() -> void:
	for item: TreeItem in _leaves.values():
		item.set_checked(0, false)
	for group: TreeItem in _tree.get_root().get_children():
		group.set_checked(0, false)
		group.set_indeterminate(0, false)
	changed.emit()


## Klappt die Tafel unter `anchor` auf, im Bild gehalten.
func open_below(anchor: Control) -> void:
	show()
	var at := anchor.get_global_rect().position + Vector2(0.0, anchor.size.y + GAP)
	var room := get_global_rect().size
	at.x = clampf(at.x, 0.0, maxf(0.0, room.x - _panel.size.x))
	at.y = clampf(at.y, 0.0, maxf(0.0, room.y - _panel.size.y))
	_panel.global_position = at
	_tree.grab_focus()


## Leertaste setzt das Häkchen der gewählten Zeile — ohne Maus.
func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_SPACE:
		_tree.accept_event()
		var item := _tree.get_selected()
		if item != null:
			item.set_checked(0, not item.is_checked(0))
			item.propagate_check(0, false)
			changed.emit()


func _on_edited() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	item.propagate_check(0, false)
	changed.emit()
