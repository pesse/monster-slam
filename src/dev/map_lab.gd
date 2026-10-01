extends Control
## Werkbank für die Landkarten (scenes/dev/map_lab.tscn, ADR 0006): Punkte aufs Bild setzen.
##
## Buch und Karte wählen (Buchkarte oder eine Gebietskarte), links den Punkt wählen, ins
## Bild klicken — der Punkt sitzt, und die Auswahl rückt zum nächsten weiter. „path" hängt
## mit jedem Klick einen Wegpunkt an, auf beiden Kartenarten; ohne Wegpunkte verbindet die
## Karte die Orte direkt.
## „Speichern" schreibt assets/maps/<book>/map.json (MapLayout.save) — nur im Editor-Lauf,
## im Export ist res:// read-only und diese Werkbank ohnehin ausgeschlossen.
##
## Die Bilder selbst entstehen außerhalb dieses Repos und werden als
## assets/maps/<book>/book.webp bzw. unit<n>.webp abgelegt; danach einmal importieren.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const PATH_KEY := "path"

@onready var _book_select: OptionButton = %BookSelect
@onready var _map_select: OptionButton = %MapSelect
@onready var _point_select: OptionButton = %PointSelect
@onready var _status: Label = %Status
@onready var _canvas: MapCanvas = %Canvas

var _room: Window
var _content: Dictionary = {}
## 0 = Buchkarte, sonst die Unit.
var _unit := 0
## Bonus-Schlüssel -> Titel, wie ihn die Karte ohne eigenen Eintrag zeigt — für einen neu
## gesetzten Bonus-Punkt, damit `title` in map.json gleich zum Anpassen dasteht.
var _titles: Dictionary = {}


func _ready() -> void:
	_room = get_window()
	LabRoom.enlarge(_room)
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	(%SaveButton as Button).pressed.connect(_save)
	(%ClearButton as Button).pressed.connect(_clear_point)
	(%ClearPathButton as Button).pressed.connect(_clear_path)
	_book_select.item_selected.connect(func(_i: int): _load_book())
	_map_select.item_selected.connect(func(_i: int): _pick_map())
	_canvas.gui_input.connect(_on_canvas_input)
	for book in ContentRegistry.all_books():
		_book_select.add_item(book)
	_load_book()


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)


func _book() -> String:
	return _book_select.get_item_text(_book_select.selected) if _book_select.selected >= 0 else ""


func _load_book() -> void:
	_content = MapLayout.data(_book())
	_map_select.clear()
	_map_select.add_item("Buchkarte", 0)
	for unit in ContentRegistry.units_for(_book()):
		_map_select.add_item("Unit %d" % int(unit), int(unit))
	_pick_map()


func _pick_map() -> void:
	_unit = _map_select.get_selected_id() if _map_select.selected >= 0 else 0
	_point_select.clear()
	if _unit == 0:
		for unit in ContentRegistry.units_for(_book()):
			_point_select.add_item(str(int(unit)))
	else:
		for level in AreaMap.levels_of(_book(), _unit, _content):
			_point_select.add_item(str(level["key"]))
			if str(level["kind"]) == MapLevel.KIND_BONUS:
				_titles[str(level["key"])] = str(level["label"])
	_point_select.add_item(PATH_KEY)
	_redraw()


## Der Teil von map.json, in den die gewählte Karte schreibt.
func _points() -> Dictionary:
	var section := "units" if _unit == 0 else "areas"
	if not _content.get(section) is Dictionary:
		_content[section] = {}
	if _unit == 0:
		return _content["units"]
	var areas: Dictionary = _content["areas"]
	if not areas.get(str(_unit)) is Dictionary:
		areas[str(_unit)] = {}
	return areas[str(_unit)]


func _selected_key() -> String:
	return _point_select.get_item_text(_point_select.selected) if _point_select.selected >= 0 else ""


func _on_canvas_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var key := _selected_key()
	if key.is_empty():
		return
	var at := MapLayout.to_json_point(_canvas.to_map_point(button.position))
	var points := _points()
	if key == PATH_KEY:
		if not points.get(PATH_KEY) is Array:
			points[PATH_KEY] = []
		(points[PATH_KEY] as Array).append(at)
	else:
		# Ein Bonus-Punkt trägt seinen Titel (BonusLevel.title); Versetzen behält ihn.
		var old: Variant = points.get(key)
		if old is Dictionary and (old as Dictionary).has("title"):
			at["title"] = old["title"]
		elif _titles.has(key):
			at["title"] = _titles[key]
		points[key] = at
		# Weiter zum nächsten Punkt: so setzt man eine Karte in einem Zug.
		if _point_select.selected + 1 < _point_select.item_count:
			_point_select.select(_point_select.selected + 1)
	_redraw()


func _clear_point() -> void:
	_points().erase(_selected_key())
	_redraw()


func _clear_path() -> void:
	_points().erase(PATH_KEY)
	_redraw()


func _redraw() -> void:
	var texture := MapLayout.book_texture(_book()) if _unit == 0 \
			else MapLayout.unit_texture(_book(), _unit)
	var points := MapLayout.unit_points(_content) if _unit == 0 \
			else MapLayout.area_points(_content, _unit)
	var nodes: Array = []
	for key in points:
		nodes.append({"key": key, "pos": points[key], "glyph": key, "caption": key,
				"boss": key == "boss"})
	var path := MapLayout.book_path(_content) if _unit == 0 else MapLayout.area_path(_content, _unit)
	# Wie im Spiel: auf der Gebietskarte kleine Orte; den Weg zeigt die Werkbank immer, sonst
	# sähe man die gesetzten Wegpunkte nicht.
	_canvas.node_radius = MapCanvas.NODE_RADIUS if _unit == 0 else MapCanvas.AREA_NODE_RADIUS
	_canvas.setup(texture, nodes, path, func(node: Dictionary) -> Dictionary:
		return {"title": str(node["key"])})
	_status.text = "%s — %s. %d von %d Punkten gesetzt." % [
		_book(), "kein Bild, Platzhalter" if texture == null else "Bild geladen",
		points.size(), _point_select.item_count - 1]


func _save() -> void:
	var error := MapLayout.save(_book(), _content)
	_status.text = "Gespeichert: %s" % MapLayout.json_path(_book()) if error == OK \
			else "Speichern fehlgeschlagen (%s) — läuft das aus dem Editor?" % error_string(error)
