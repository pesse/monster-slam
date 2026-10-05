class_name CheckMenu
extends MenuButton
## Ein Dropdown mit Häkchen: mehrere Werte zugleich, keiner gewählt heißt „keine
## Einschränkung" — deshalb gibt es keinen Eintrag „Alle …". Das Menü bleibt beim Anklicken
## offen, damit sich mehrere Häkchen nacheinander setzen lassen.
##
## Die Beschriftung nennt die Wahl („Unit 1 +2"), ohne Wahl den Namen des Filters (`label`).
## Der Knopf ist schmal und schneidet ab (clip_text in der Szene): die Breite ändert sich mit
## der Wahl nicht.

signal changed()

## Name des Filters, steht ohne Wahl auf dem Knopf.
@export var label := ""

## [{ text, value }] in Anzeigereihenfolge.
var _options: Array = []
var _checked: Dictionary = {}


func _ready() -> void:
	var popup := get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.id_pressed.connect(_on_id_pressed)
	_render()


## Setzt die Einträge neu. Gewählte Werte, die es weiter gibt, bleiben gewählt.
func set_options(options: Array) -> void:
	_options = options.duplicate()
	var still := {}
	for option in _options:
		if _checked.has(option["value"]):
			still[option["value"]] = true
	_checked = still
	var popup := get_popup()
	popup.clear()
	for i in _options.size():
		popup.add_check_item(str(_options[i]["text"]), i)
		popup.set_item_checked(i, _checked.has(_options[i]["value"]))
	disabled = _options.is_empty()
	_render()


## Die gewählten Werte, leer ohne Wahl.
func values() -> Array:
	return _options.map(func(o): return o["value"]).filter(func(v): return _checked.has(v))


func clear_checks() -> void:
	_checked.clear()
	for i in get_popup().item_count:
		get_popup().set_item_checked(i, false)
	_render()
	changed.emit()


func _on_id_pressed(id: int) -> void:
	var value: Variant = _options[id]["value"]
	if _checked.has(value):
		_checked.erase(value)
	else:
		_checked[value] = true
	get_popup().set_item_checked(id, _checked.has(value))
	_render()
	changed.emit()


func _render() -> void:
	var chosen := _options.filter(func(o): return _checked.has(o["value"]))
	if chosen.is_empty():
		text = label + " ▾"
	elif chosen.size() == 1:
		text = str(chosen[0]["text"]) + " ▾"
	else:
		text = "%s +%d ▾" % [chosen[0]["text"], chosen.size() - 1]
