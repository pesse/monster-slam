extends Control
## Werkbank für die Landkarten (scenes/dev/map_lab.tscn, ADR 0006): Punkte aufs Bild setzen.
##
## Buch und Karte wählen (Buchkarte oder eine Gebietskarte). Die linke Maustaste wählt
## einen Ort, einen Wegpunkt oder eine Quelle (weißer Ring), Ziehen verschiebt sie,
## „Auswahl löschen" (Entf) nimmt sie weg. Die rechte setzt Neues: den oben gewählten Ort —
## und die Auswahl rückt zum nächsten weiter —, bei „path" einen Wegpunkt; ohne Wegpunkte
## verbindet die Karte die Orte direkt.
## „Speichern" schreibt assets/maps/<book>/map.json (MapLayout.save) — nur im Editor-Lauf,
## im Export ist res:// read-only und diese Werkbank ohnehin ausgeschlossen.
##
## Die Seitenleiste rechts gehört der Bewegung der Gebietskarte (map.json `ambience`,
## MapAmbience): oben einen Effekt wählen oder mit Art und „+ Effekt" anlegen. Eine Fläche
## (Wasser, Wasserfall, Nebel) malt man mit dem Pinsel in ihre Maske
## (assets/maps/<book>/unit<n>_<mask>.webp, MapLayout.mask_path; jede weitere Fläche einer
## Art bekommt eine eigene, `<kind>2` …): links malt, rechts
## radiert, „Rückgängig" (Strg+Z) nimmt den letzten Strich zurück. Eine Quelle (Rauch,
## Glut, Fackel) setzt die rechte Maustaste, die linke greift sie. Steht oben „Punkte
## setzen", gelten die Klicks wieder den Orten.
##
## Darunter steht, was zum gewählten Effekt passt: die Karte mit der Maske bzw. der
## Ausschnitt um die Quelle, Art, Intensität, Form (nur Wasser: Feld oder Ringe), Größe
## (nur Quellen) und der Pinsel (nur Flächen: Größe in Bildschirm-Pixeln, Härte des Randes,
## Stärke). Was dem Gewohnten entspricht, schreibt die Werkbank nicht in map.json. Neue
## Masken sieht das Spiel erst nach einem Import (`tools/godot.sh --import`).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/map_lab.tscn -- --shoot --book=aplusx --unit=1
##         speichert reports/map_ambience/aplusx_unit1.png und beendet sich (`--outline`
##         mit Umrissen, `--crop=x,y,w` nur der Ausschnitt ab x,y in w Bildbreite, doppelt
##         groß; `--later` ein zweites Bild eine halbe Sekunde später, zum Vergleich;
##         `--select=N` zeigt Effekt N in der Leiste, `--style=rings` probiert eine Form aus,
##         ohne zu speichern).
##
## Die Bilder selbst entstehen außerhalb dieses Repos und werden als
## assets/maps/<book>/book.webp bzw. unit<n>.webp abgelegt; danach einmal importieren.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const PARAM_SCENE := preload("res://scenes/dev/map_lab_param.tscn")
const PATH_KEY := "path"
const SHOT_DIR := "res://reports/map_ambience"
## So lange läuft die Bewegung, bevor das Bild für `--shoot` entsteht.
const SETTLE := 1.5
## Die Arten in der Auswahl, mit Namen für die Werkbank.
const KIND_LABELS := {"water": "Wasser", "falls": "Wasserfall", "mist": "Nebel",
		"smoke": "Rauch", "ember": "Glut", "torch": "Fackel"}
## So nah (px) muss ein Klick an einem Punkt liegen, um ihn zu treffen.
const HIT := 10.0
const HANDLE_COLOR := Color(1.0, 0.95, 0.75, 0.9)
const SELECTED_COLOR := Color(1.0, 1.0, 1.0)
const STYLE_LABELS := {"field": "Feld", "rings": "Ringe"}
## So viel Bild (Bildhöhen) zeigt die Box um eine Quelle.
const PREVIEW_SPOT := 0.14
## So viele Striche nimmt „Rückgängig" zurück.
const UNDO_DEPTH := 30
const BRUSH_COLOR := Color(1.0, 1.0, 1.0, 0.8)

@onready var _book_select: OptionButton = %BookSelect
@onready var _map_select: OptionButton = %MapSelect
@onready var _point_select: OptionButton = %PointSelect
@onready var _status: Label = %Status
@onready var _canvas: MapCanvas = %Canvas
@onready var _ambience_select: OptionButton = %AmbienceSelect
@onready var _kind_select: OptionButton = %KindSelect
@onready var _outline_toggle: CheckButton = %OutlineToggle
@onready var _handles_layer: Control = %Handles
@onready var _inspector_info: Label = %InspectorInfo
@onready var _shape_preview: Control = %ShapePreview
@onready var _kind_edit: OptionButton = %KindEdit
@onready var _intensity_slider: HSlider = %IntensitySlider
@onready var _intensity_value: Label = %IntensityValue
@onready var _style_select: OptionButton = %StyleSelect
@onready var _size_slider: HSlider = %SizeSlider
@onready var _size_value: Label = %SizeValue
@onready var _shape_mask: Control = %ShapeMask
@onready var _effect_group: Control = %EffectGroup
@onready var _style_group: Control = %StyleGroup
@onready var _size_group: Control = %SizeGroup
@onready var _param_group: Control = %ParamGroup
@onready var _brush_group: Control = %BrushGroup
@onready var _brush_slider: HSlider = %BrushSlider
@onready var _brush_value: Label = %BrushValue
@onready var _hardness_slider: HSlider = %HardnessSlider
@onready var _hardness_value: Label = %HardnessValue
@onready var _strength_slider: HSlider = %StrengthSlider
@onready var _strength_value: Label = %StrengthValue

var _room: Window
var _content: Dictionary = {}
## 0 = Buchkarte, sonst die Unit.
var _unit := 0
## Bonus-Schlüssel -> Titel, wie ihn die Karte ohne eigenen Eintrag zeigt — für einen neu
## gesetzten Bonus-Punkt, damit `title` in map.json gleich zum Anpassen dasteht.
var _titles: Dictionary = {}
## Was gewählt ist: { type: "point" (key) | "path" (index) | "spot" (entry) }, oder {}.
var _selection: Dictionary = {}
## Solange die Maus gedrückt ist, folgt die Auswahl ihr.
var _dragging := false
## Die Masken der gewählten Gebietskarte: mask -> { bytes: PackedByteArray (L8), size:
## Vector2i, texture: ImageTexture }. Die Bytes sind die Wahrheit, die Textur folgt ihnen.
var _masks: Dictionary = {}
## Vorige Stände der Masken, je Strich einer: [{ kind, bytes }] — Kopien, denn ein
## Packed-Array teilt sich in GDScript, statt beim Schreiben kopiert zu werden.
var _undo: Array = []
## Ein Strich läuft: so lange malt (oder radiert) jede Bewegung.
var _painting := false
var _stroke_erases := false
## Wo der letzte Abdruck saß (Pixel der Maske) — Bewegungen dazwischen füllt der Strich auf.
var _last_stamp := Vector2.INF
## Für welche Art und Form die Regler aus MapLayout.PARAMS gebaut sind, und je Schlüssel
## ihr Regler — gebaut wird nur neu, wenn sich das ändert, sonst risse es den Regler unter
## der Maus weg.
var _param_for := ""
var _param_rows: Dictionary = {}
## Wo die Maus über der Karte steht, für den Pinsel-Umriss; INF außerhalb.
var _cursor := Vector2.INF


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
	(%AddAmbienceButton as Button).pressed.connect(_add_ambience)
	(%UndoButton as Button).pressed.connect(_undo_stroke)
	(%DeleteAmbienceButton as Button).pressed.connect(_delete_ambience)
	(%DeleteSelectionButton as Button).pressed.connect(_delete_selection)
	_handles_layer.draw.connect(_draw_handles)
	_ambience_select.item_selected.connect(func(_i: int):
		_selection = {}
		_redraw())
	_shape_preview.draw.connect(_draw_shape)
	_shape_mask.draw.connect(_draw_shape_mask)
	_kind_edit.item_selected.connect(_on_kind_edited)
	_intensity_slider.value_changed.connect(func(value: float): _edit("intensity", value, 1.0))
	_size_slider.value_changed.connect(func(value: float): _edit("size", value, 1.0))
	_style_select.item_selected.connect(_on_style_edited)
	_canvas.mouse_exited.connect(func():
		_cursor = Vector2.INF
		_handles_layer.queue_redraw())
	for slider: HSlider in [_brush_slider, _hardness_slider, _strength_slider]:
		slider.value_changed.connect(func(_v: float): _show_brush())
	_show_brush()
	_outline_toggle.toggled.connect(func(on: bool): _canvas.ambience_layer().show_outline = on)
	for kind in KIND_LABELS:
		_kind_select.add_item(KIND_LABELS[kind])
	for book in ContentRegistry.all_books():
		_book_select.add_item(book)
	var wanted := Array(ContentRegistry.all_books()).find(_arg("book"))
	if wanted >= 0:
		_book_select.select(wanted)
	_load_book()
	if _has_arg("shoot"):
		_shoot.call_deferred()


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_Z and key.ctrl_pressed:
		_undo_stroke()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DELETE:
		_delete_selection()
		get_viewport().set_input_as_handled()


func _book() -> String:
	return _book_select.get_item_text(_book_select.selected) if _book_select.selected >= 0 else ""


func _load_book() -> void:
	_content = MapLayout.data(_book())
	_map_select.clear()
	_map_select.add_item("Buchkarte", 0)
	for unit in _map_units():
		_map_select.add_item("Unit %d" % unit, unit)
	_pick_map()


## Die Units mit Inhalt, dazu jede, für die es schon ein Gebietsbild gibt — die Bewegung
## lässt sich setzen, bevor der Inhalt da ist.
func _map_units() -> Array:
	var units: Array = ContentRegistry.units_for(_book()).map(func(u): return int(u))
	for key in MapLayout.unit_points(_content):
		if str(key).is_valid_int() and not int(key) in units \
				and MapLayout.unit_texture(_book(), int(key)) != null:
			units.append(int(key))
	units.sort()
	return units


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
	_load_masks()
	_fill_ambience_select(0)
	_selection = {}
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
	var effect := _selected_ambience()
	if str(effect.get("kind", "")) in MapLayout.AREA_KINDS:
		_paint_input(event, _mask_key(effect))
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and not _selection.is_empty():
		_move(_selection, MapLayout.to_json_point(_canvas.to_map_point(motion.position)))
		_redraw()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not button.pressed:
		_dragging = false
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		# Rechts setzt Neues — und hält es, solange die Taste unten ist.
		_select(_add_at(button.position))
		_dragging = not _selection.is_empty()
	else:
		var hit := _handle_at(button.position)
		_select(hit)
		_dragging = not hit.is_empty()
		if hit.is_empty():
			_status.text = "Nichts getroffen. Neues setzt die rechte Maustaste."
	_redraw()


## Setzt an `local` Neues, je nach Auswahl oben: eine Quelle, einen Wegpunkt oder den
## gewählten Ort. Gibt zurück, was entstanden ist.
func _add_at(local: Vector2) -> Dictionary:
	var at := MapLayout.to_json_point(_canvas.to_map_point(local))
	var effect := _selected_ambience()
	if not effect.is_empty():
		effect["x"] = at["x"]
		effect["y"] = at["y"]
		return {"type": "spot", "entry": _ambience_select.selected - 1}
	var key := _selected_key()
	if key.is_empty():
		return {}
	var points := _points()
	if key == PATH_KEY:
		if not points.get(PATH_KEY) is Array:
			points[PATH_KEY] = []
		(points[PATH_KEY] as Array).append(at)
		return {"type": "path", "index": (points[PATH_KEY] as Array).size() - 1}
	_move({"type": "point", "key": key}, at)
	# Weiter zum nächsten Punkt: so setzt man eine Karte in einem Zug.
	if _point_select.selected + 1 < _point_select.item_count:
		_point_select.select(_point_select.selected + 1)
	return {"type": "point", "key": key}


## Alles, was man greifen kann, mit seiner Lage im Bild: [{handle, at}].
func _handles() -> Array:
	var out: Array = []
	var points := _points()
	for key in points:
		if key == PATH_KEY:
			continue
		out.append({"handle": {"type": "point", "key": str(key)}, "at": MapLayout.point(points[key])})
	var path: Variant = points.get(PATH_KEY, [])
	if path is Array:
		for i in (path as Array).size():
			out.append({"handle": {"type": "path", "index": i}, "at": MapLayout.point(path[i])})
	var list := _ambience_list()
	for e in list.size():
		var entry: Variant = list[e]
		if entry is Dictionary and str(entry.get("kind", "")) in MapLayout.SPOT_KINDS:
			out.append({"handle": {"type": "spot", "entry": e}, "at": MapLayout.point(entry)})
	return out.filter(func(h): return (h["at"] as Vector2).is_finite())


## Das Greifbare unter `local`, das nächste zuerst; {} wenn nichts in HIT liegt. Bei
## Gleichstand gewinnt der gewählte Effekt — sonst bekäme man eine Quelle, die auf einem Ort
## liegt, nie zu fassen.
func _handle_at(local: Vector2) -> Dictionary:
	var best := {}
	var nearest := INF
	var current := _ambience_select.selected - 1
	for h in _handles():
		var d := local.distance_to(_canvas.to_local_point(h["at"]))
		var handle: Dictionary = h["handle"]
		if int(handle.get("entry", -2)) == current:
			d -= 2.0
		if d <= HIT and d < nearest:
			nearest = d
			best = handle
	return best


func _select(handle: Dictionary) -> void:
	_selection = handle
	if handle.is_empty():
		return
	match str(handle["type"]):
		"point":
			_ambience_select.select(0)
			_select_point_key(str(handle["key"]))
		"path":
			_ambience_select.select(0)
			_select_point_key(PATH_KEY)
		_:
			_ambience_select.select(int(handle["entry"]) + 1)
	_status.text = "Gewählt: %s — ziehen verschiebt, Entf löscht." % _describe(handle)


func _select_point_key(key: String) -> void:
	for i in _point_select.item_count:
		if _point_select.get_item_text(i) == key:
			_point_select.select(i)
			return


func _describe(handle: Dictionary) -> String:
	match str(handle["type"]):
		"point":
			return "Ort %s" % handle["key"]
		"path":
			return "Wegpunkt %d" % (int(handle["index"]) + 1)
	return "Effekt %d" % (int(handle["entry"]) + 1)


## Setzt `handle` auf `at` ({x, y} aus MapLayout.to_json_point).
func _move(handle: Dictionary, at: Dictionary) -> void:
	var points := _points()
	match str(handle["type"]):
		"point":
			# Ein Bonus-Punkt trägt seinen Titel (BonusLevel.title); Versetzen behält ihn.
			var key := str(handle["key"])
			var old: Variant = points.get(key)
			if old is Dictionary and (old as Dictionary).has("title"):
				at["title"] = old["title"]
			elif _titles.has(key):
				at["title"] = _titles[key]
			points[key] = at
		"path":
			(points[PATH_KEY] as Array)[int(handle["index"])] = at
		"spot":
			var entry: Dictionary = _ambience_list()[int(handle["entry"])]
			entry["x"] = at["x"]
			entry["y"] = at["y"]


func _delete_selection() -> void:
	if _selection.is_empty():
		_status.text = "Erst etwas anklicken, dann löschen."
		return
	var points := _points()
	match str(_selection["type"]):
		"point":
			points.erase(str(_selection["key"]))
		"path":
			(points[PATH_KEY] as Array).remove_at(int(_selection["index"]))
		"spot":
			var entry := int(_selection["entry"])
			_ambience_list().remove_at(entry)
			_fill_ambience_select(mini(entry + 1, _ambience_list().size()))
	_status.text = "Gelöscht: %s." % _describe(_selection)
	_selection = {}
	_redraw()


## Wegpunkte, die gewählte Quelle, die Auswahl und der Pinsel — was man greifen kann.
func _draw_handles() -> void:
	var current := _ambience_select.selected - 1
	for h in _handles():
		var handle: Dictionary = h["handle"]
		var at := _canvas.to_local_point(h["at"])
		if handle["type"] == "path" or int(handle.get("entry", -2)) == current:
			_handles_layer.draw_circle(at, 4.0, HANDLE_COLOR)
		if handle == _selection:
			_handles_layer.draw_arc(at, 9.0, 0.0, TAU, 24, SELECTED_COLOR, 2.0, true)
	if _cursor.is_finite() and str(_selected_ambience().get("kind", "")) in MapLayout.AREA_KINDS:
		var radius := _brush_slider.value * 0.5
		_handles_layer.draw_arc(_cursor, radius, 0.0, TAU, 48, BRUSH_COLOR, 1.5, true)
		_handles_layer.draw_arc(_cursor, radius * _hardness_slider.value, 0.0, TAU, 48,
				Color(BRUSH_COLOR, 0.35), 1.0, true)


func _clear_point() -> void:
	_selection = {}
	_points().erase(_selected_key())
	_redraw()


func _clear_path() -> void:
	_selection = {}
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
	_canvas.set_ambience(MapLayout.ambience({"ambience": {str(_unit): _ambience_list()}}, _unit),
			_mask_textures())
	_canvas.ambience_layer().show_outline = _outline_toggle.button_pressed
	_handles_layer.queue_redraw()
	_fill_inspector()
	if not _selection.is_empty():
		return
	_status.text = "%s — %s. %d von %d Punkten gesetzt." % [
		_book(), "kein Bild, Platzhalter" if texture == null else "Bild geladen",
		points.size(), _point_select.item_count - 1]


func _save() -> void:
	# Units ohne Bewegung tragen keinen leeren Eintrag in map.json.
	var all: Variant = _content.get("ambience")
	if all is Dictionary:
		for unit in (all as Dictionary).keys():
			if (all[unit] as Array).is_empty():
				(all as Dictionary).erase(unit)
		if (all as Dictionary).is_empty():
			_content.erase("ambience")
	var error := MapLayout.save(_book(), _content)
	if error == OK and _unit > 0:
		error = _save_masks()
	_status.text = "Gespeichert: %s — neue Masken sieht das Spiel nach `tools/godot.sh --import`." \
			% MapLayout.json_path(_book()) if error == OK \
			else "Speichern fehlgeschlagen (%s) — läuft das aus dem Editor?" % error_string(error)


## Die Einträge von `ambience` der gewählten Unit, wie sie in map.json stehen.
func _ambience_list() -> Array:
	if _unit == 0:
		return []
	if not _content.get("ambience") is Dictionary:
		_content["ambience"] = {}
	var all: Dictionary = _content["ambience"]
	if not all.get(str(_unit)) is Array:
		all[str(_unit)] = []
	return all[str(_unit)]


## Füllt die linke Auswahl: erst „Punkte setzen", dann je Effekt Art und Nummer.
func _fill_ambience_select(select: int) -> void:
	_ambience_select.clear()
	_ambience_select.add_item("Punkte setzen")
	var list := _ambience_list()
	for i in list.size():
		var label: String = KIND_LABELS.get(str(list[i].get("kind", "")), "?")
		if list[i] is Dictionary and list[i].get("kind") in MapLayout.AREA_KINDS:
			label = _mask_label(_mask_key(list[i]))
		_ambience_select.add_item("%d %s" % [i + 1, label])
	_ambience_select.select(clampi(select, 0, list.size()))
	_ambience_select.disabled = _unit == 0


## Der gewählte Effekt (der Eintrag in map.json selbst), oder {} bei „Punkte setzen".
func _selected_ambience() -> Dictionary:
	var i := _ambience_select.selected - 1
	var list := _ambience_list()
	return list[i] if i >= 0 and i < list.size() and list[i] is Dictionary else {}


func _add_ambience() -> void:
	if _unit == 0:
		_status.text = "Bewegung gibt es nur auf den Gebietskarten."
		return
	var kind: String = KIND_LABELS.keys()[_kind_select.selected]
	var list := _ambience_list()
	_selection = {}
	if kind in MapLayout.AREA_KINDS:
		var entry := {"kind": kind}
		list.append(entry)
		_mask_of(_name_mask(entry, kind))
	else:
		list.append({"kind": kind, "x": 0.5, "y": 0.5})
		_status.text = "%s steht in der Mitte — die rechte Maustaste setzt sie, wohin sie gehört." % KIND_LABELS[kind]
	_fill_ambience_select(list.size())
	_redraw()


func _delete_ambience() -> void:
	var i := _ambience_select.selected - 1
	var list := _ambience_list()
	if i < 0 or i >= list.size():
		return
	# Die Maske verschwindet mit dem Eintrag — die Datei erst beim Speichern.
	if list[i] is Dictionary and list[i].get("kind") in MapLayout.AREA_KINDS:
		_masks.erase(_mask_key(list[i]))
	list.remove_at(i)
	_fill_ambience_select(mini(i + 1, list.size()))
	_selection = {}
	_redraw()


func _shoot() -> void:
	var unit := int(_arg("unit")) if not _arg("unit").is_empty() else 1
	_map_select.select(maxi(0, _map_select.get_item_index(unit)))
	_pick_map()
	_outline_toggle.button_pressed = _has_arg("outline")
	if not _arg("select").is_empty():
		_ambience_select.select(int(_arg("select")))
		_redraw()
	var styles: Array = MapLayout.STYLES.get(str(_selected_ambience().get("kind", "")), [])
	if _arg("style") in styles:
		_on_style_edited(styles.find(_arg("style")))
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var tag := "%s/%s_unit%d%s" % [dir, _book(), unit, "_outline" if _has_arg("outline") else ""]
	_save_shot(tag + ".png")
	if _has_arg("later"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		_save_shot(tag + "_later.png")
	get_tree().quit()


func _save_shot(file: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var crop := _arg("crop").split_floats(",")
	if crop.size() == 3:
		var rect := MapCanvas.map_rect(_canvas.size, _canvas.aspect(), false)
		var at := _canvas.get_global_rect().position + rect.position + Vector2(crop[0], crop[1]) * rect.size
		var width := crop[2] * rect.size.x
		var region := Rect2i(Rect2(at, Vector2(width, width * 9.0 / 16.0))).intersection(
				Rect2i(Vector2i.ZERO, image.get_size()))
		image = image.get_region(region)
		image.resize(region.size.x * 2, region.size.y * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(file)
	print("map_lab: ", file)


func _arg(arg_name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % arg_name):
			return arg.get_slice("=", 1)
	return ""


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


## Die Leiste rechts: was der gewählte Effekt ist und wie er sich bewegt.
func _fill_inspector() -> void:
	var effect := _selected_ambience()
	var kind := str(effect.get("kind", ""))
	var on := not effect.is_empty()
	var area := kind in MapLayout.AREA_KINDS
	if not on:
		_inspector_info.text = "Einen Effekt wählen oder anlegen. Eine Quelle wählt auch ein Klick auf sie."
	elif area:
		_inspector_info.text = "Links malen, rechts radieren."
	else:
		_inspector_info.text = "Quelle bei %.3f, %.3f — links ziehen, rechts versetzen." \
				% [float(effect.get("x", 0.0)), float(effect.get("y", 0.0))]
	# Nur was zum Effekt passt: die Leiste hängt am Rand, ihre Höhe darf sich ändern.
	var styles: Array = MapLayout.STYLES.get(kind, [])
	_effect_group.visible = on
	_style_group.visible = not styles.is_empty()
	_size_group.visible = on and not area
	_brush_group.visible = area
	_kind_edit.clear()
	if on:
		var kinds: Array = MapLayout.AREA_KINDS if area else MapLayout.SPOT_KINDS
		for k in kinds:
			_kind_edit.add_item(KIND_LABELS[k])
		_kind_edit.select(kinds.find(kind))
	_intensity_slider.set_value_no_signal(float(effect.get("intensity", 1.0)))
	_intensity_value.text = "%.2f" % _intensity_slider.value
	_style_select.clear()
	for style in styles:
		_style_select.add_item(STYLE_LABELS.get(style, style))
	if not styles.is_empty():
		_style_select.select(maxi(0, styles.find(effect.get("style", styles[0]))))
	_fill_params(kind, str(effect.get("style", styles[0] if not styles.is_empty() else "")))
	for key in _param_rows:
		var row: Dictionary = _param_rows[key]
		(row["slider"] as HSlider).set_value_no_signal(float(effect.get(key, row["param"]["default"])))
		_show_param(row)
	_size_slider.set_value_no_signal(float(effect.get("size", 1.0)))
	_size_value.text = "%.2f" % _size_slider.value
	_shape_preview.queue_redraw()
	_shape_mask.queue_redraw()


## Setzt `key` am gewählten Effekt — oder nimmt es weg, wenn es dem Gewohnten entspricht.
func _edit(key: String, value: Variant, default: Variant) -> void:
	var effect := _selected_ambience()
	if effect.is_empty():
		return
	var same := false
	if value is float:
		value = snappedf(value, 0.01)
		same = is_equal_approx(value, default)
	else:
		same = value == default
	if same:
		effect.erase(key)
	else:
		effect[key] = value
	_redraw()


func _on_kind_edited(index: int) -> void:
	var effect := _selected_ambience()
	if effect.is_empty():
		return
	var old := str(effect["kind"])
	var area := old in MapLayout.AREA_KINDS
	var kinds: Array = MapLayout.AREA_KINDS if area else MapLayout.SPOT_KINDS
	var kind: String = kinds[index]
	if kind == old:
		return
	if area:
		# Die Maske zieht mit um, unter dem ersten freien Namen der neuen Art.
		var before := _mask_key(effect)
		var after := _name_mask(effect, kind)
		if _masks.has(before):
			_masks[after] = _masks[before]
			_masks.erase(before)
	effect["kind"] = kind
	# Eine Form, die die neue Art nicht kennt, fällt weg.
	if not effect.get("style") in MapLayout.STYLES.get(kind, []):
		effect.erase("style")
	_fill_ambience_select(_ambience_select.selected)
	_redraw()


func _on_style_edited(index: int) -> void:
	var styles: Array = MapLayout.STYLES.get(str(_selected_ambience().get("kind", "")), [])
	if index < styles.size():
		_edit("style", styles[index], styles[0])


## Für eine Fläche die ganze Karte (die Maske tönt `_draw_shape_mask` darüber), für eine
## Quelle der Ausschnitt um sie, mit ihrem Punkt.
func _draw_shape() -> void:
	var effect := _selected_ambience()
	var texture := MapLayout.unit_texture(_book(), _unit) if _unit > 0 else null
	if effect.is_empty() or texture == null:
		return
	var image := Vector2(texture.get_size())
	var room := _shape_preview.size
	if room.x <= 0.0 or room.y <= 0.0:
		return
	if str(effect["kind"]) in MapLayout.AREA_KINDS:
		_shape_preview.draw_texture_rect(texture, _preview_rect(image), false)
		return
	var at := MapLayout.point(effect)
	if not at.is_finite():
		return
	# Gerechnet in Pixeln des Bildes, damit der Ausschnitt das Seitenverhältnis der Box hat.
	var tall := PREVIEW_SPOT * image.y
	var box := Rect2(at * image - Vector2(tall * room.x / room.y, tall) * 0.5,
			Vector2(tall * room.x / room.y, tall))
	_shape_preview.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, room), box)
	var dot := (at * image - box.position) / box.size * room
	_shape_preview.draw_circle(dot, 3.0, HANDLE_COLOR)
	_shape_preview.draw_arc(dot, 7.0, 0.0, TAU, 24, SELECTED_COLOR, 2.0, true)


## Die Maske der gewählten Fläche über der Karte in der Box (mit map_mask_overlay).
func _draw_shape_mask() -> void:
	var effect := _selected_ambience()
	var kind := str(effect.get("kind", ""))
	var texture := MapLayout.unit_texture(_book(), _unit) if _unit > 0 else null
	if not kind in MapLayout.AREA_KINDS or not _masks.has(_mask_key(effect)) or texture == null:
		return
	_shape_mask.draw_texture_rect(_masks[_mask_key(effect)]["texture"],
			_preview_rect(Vector2(texture.get_size())), false, MapAmbience.MASK_TINT[kind])


## Wo die ganze Karte in der Box steht: eingepasst, mittig.
func _preview_rect(image: Vector2) -> Rect2:
	var room := _shape_preview.size
	var fit := minf(room.x / image.x, room.y / image.y)
	return Rect2((room - image * fit) * 0.5, image * fit)




func _show_brush() -> void:
	_brush_value.text = "%d px" % int(_brush_slider.value)
	_hardness_value.text = "%.2f" % _hardness_slider.value
	_strength_value.text = "%.2f" % _strength_slider.value
	_handles_layer.queue_redraw()


# --- Masken -------------------------------------------------------------------------------

## Wie groß eine Maske dieser Karte ist: MapLayout.MASK_WIDTH breit, so hoch wie das Bild es
## verlangt.
func _mask_size() -> Vector2i:
	var texture := MapLayout.unit_texture(_book(), _unit)
	var ratio := _canvas.aspect() if texture == null else float(texture.get_width()) / texture.get_height()
	return Vector2i(MapLayout.MASK_WIDTH, roundi(MapLayout.MASK_WIDTH / ratio))


## Liest die Masken der gewählten Karte von der Platte — direkt aus der Datei, nicht über den
## Import: eben gemalte und gespeicherte Masken hat noch niemand importiert.
func _load_masks() -> void:
	_masks.clear()
	_undo.clear()
	if _unit == 0:
		return
	for mask in _mask_files():
		var image := Image.load_from_file(ProjectSettings.globalize_path(MapLayout.mask_path(_book(), _unit, mask)))
		if image == null or image.is_empty():
			continue
		image.convert(Image.FORMAT_L8)
		var size := _mask_size()
		if image.get_size() != size:
			image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		_masks[mask] = {"bytes": image.get_data(), "size": size,
				"texture": ImageTexture.create_from_image(image)}


## Die Masken, die für die gewählte Karte auf der Platte liegen (ihre Namen, `water2` …).
func _mask_files() -> Array:
	var out: Array = []
	var prefix := "unit%d_" % _unit
	for file in DirAccess.get_files_at(MapLayout.dir_of(_book())):
		if not file.begins_with(prefix) or not file.ends_with(".webp"):
			continue
		var mask := file.trim_prefix(prefix).trim_suffix(".webp")
		if MapLayout.AREA_KINDS.any(func(kind): return MapLayout.is_mask_of(mask, kind)):
			out.append(mask)
	return out


## Wie die Maske eines Flächen-Eintrags heißt: `mask`, ohne Angabe die Art.
func _mask_key(entry: Dictionary) -> String:
	return str(entry.get("mask", entry.get("kind", "")))


## Gibt `entry` den ersten freien Masken-Namen der Art `kind` — die Art selbst, sonst mit
## Nummer; der Name der Art steht nicht in map.json. Gibt den Namen zurück.
func _name_mask(entry: Dictionary, kind: String) -> String:
	var used: Array = _ambience_list().filter(func(e): return e is Dictionary and not is_same(e, entry) \
			and e.get("kind") in MapLayout.AREA_KINDS).map(func(e): return _mask_key(e))
	var mask := kind
	var n := 2
	while mask in used:
		mask = "%s%d" % [kind, n]
		n += 1
	if mask == kind:
		entry.erase("mask")
	else:
		entry["mask"] = mask
	return mask


## Der Name einer Maske für die Werkbank: „Nebel 2".
func _mask_label(mask: String) -> String:
	for kind in MapLayout.AREA_KINDS:
		if MapLayout.is_mask_of(mask, kind):
			var number := mask.trim_prefix(kind)
			return KIND_LABELS[kind] + ("" if number.is_empty() else " " + number)
	return mask


## Die Maske `mask`, leer angelegt, wenn es sie noch nicht gibt.
func _mask_of(mask: String) -> Dictionary:
	if not _masks.has(mask):
		var size := _mask_size()
		var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)
		_masks[mask] = {"bytes": image.get_data(), "size": size,
				"texture": ImageTexture.create_from_image(image)}
	return _masks[mask]


## mask -> Texture2D für die Karte: nur Masken, die einen Eintrag haben.
func _mask_textures() -> Dictionary:
	var out := {}
	for entry in _ambience_list():
		if entry is Dictionary and entry.get("kind") in MapLayout.AREA_KINDS and _masks.has(_mask_key(entry)):
			out[_mask_key(entry)] = _masks[_mask_key(entry)]["texture"]
	return out


func _paint_input(event: InputEvent, mask: String) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_cursor = motion.position
		if _painting:
			_stroke_to(mask, motion.position)
		_handles_layer.queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not button.pressed:
		_painting = false
		return
	_undo.append({"mask": mask, "bytes": (_mask_of(mask)["bytes"] as PackedByteArray).duplicate()})
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_painting = true
	_stroke_erases = button.button_index == MOUSE_BUTTON_RIGHT
	_last_stamp = Vector2.INF
	_stroke_to(mask, button.position)
	_status.text = "%s: %s." % [_mask_label(mask), "radiert" if _stroke_erases else "gemalt"]


## Malt von der letzten Stelle des Strichs bis `local`, Abdruck an Abdruck.
func _stroke_to(mask: String, local: Vector2) -> void:
	var data: Dictionary = _masks[mask]
	var size: Vector2i = data["size"]
	var at := _canvas.to_map_point(local) * Vector2(size)
	# Der Pinsel ist in Bildschirm-Pixeln eingestellt; so viele Masken-Pixel sind das.
	var shown := _canvas.to_local_point(Vector2(1.0, 0.0)).x - _canvas.to_local_point(Vector2.ZERO).x
	var radius := maxf(1.0, _brush_slider.value * 0.5 * size.x / maxf(1.0, shown))
	var bytes: PackedByteArray = data["bytes"]
	var from := _last_stamp if _last_stamp.is_finite() else at
	var steps := maxi(1, ceili(from.distance_to(at) / maxf(1.0, radius * 0.25)))
	for i in steps:
		bytes = stamp(bytes, size, from.lerp(at, float(i + 1) / steps), radius,
				_hardness_slider.value, _strength_slider.value, _stroke_erases)
	data["bytes"] = bytes
	_last_stamp = at
	_show_mask(mask)


func _show_mask(mask: String) -> void:
	var data: Dictionary = _masks[mask]
	var size: Vector2i = data["size"]
	(data["texture"] as ImageTexture).update(
			Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, data["bytes"]))
	_shape_mask.queue_redraw()


## Ein Abdruck des Pinsels in `bytes` (L8, `size`) um `center` (Pixel): innen bis
## `radius * hardness` voll, nach außen weich. Malen hebt bis `strength`, Radieren senkt um
## sie — beides nie über das hinaus, was der Abdruck selbst gäbe: ein Strich mit halber
## Stärke bleibt halb, wie oft er auch über dieselbe Stelle geht.
static func stamp(bytes: PackedByteArray, size: Vector2i, center: Vector2, radius: float,
		hardness: float, strength: float, erase: bool) -> PackedByteArray:
	var inner := radius * clampf(hardness, 0.0, 0.99)
	var x0 := maxi(0, floori(center.x - radius))
	var x1 := mini(size.x - 1, ceili(center.x + radius))
	var y0 := maxi(0, floori(center.y - radius))
	var y1 := mini(size.y - 1, ceili(center.y + radius))
	for y in range(y0, y1 + 1):
		var dy := y + 0.5 - center.y
		var row := y * size.x
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - center.x
			var d := sqrt(dx * dx + dy * dy)
			if d >= radius:
				continue
			var f := 1.0 if d <= inner else 1.0 - smoothstep(inner, radius, d)
			var i := row + x
			if erase:
				var lower := int(255.0 * (1.0 - strength * f))
				if lower < bytes[i]:
					bytes[i] = lower
			else:
				var higher := int(255.0 * strength * f + 0.5)
				if higher > bytes[i]:
					bytes[i] = higher
	return bytes


func _undo_stroke() -> void:
	if _undo.is_empty():
		_status.text = "Nichts zum Zurücknehmen."
		return
	var last: Dictionary = _undo.pop_back()
	var mask := str(last["mask"])
	if not _masks.has(mask):
		return
	_masks[mask]["bytes"] = last["bytes"]
	_show_mask(mask)
	_status.text = "Letzten Strich zurückgenommen (%s)." % _mask_label(mask)


## Schreibt die Masken der Karte als verlustfreies WebP; eine Maske ohne Eintrag verliert
## ihre Datei (samt .import) — nur genau diese, einzeln benannt.
func _save_masks() -> Error:
	var masks := _mask_textures()
	for mask in masks:
		var data: Dictionary = _masks[mask]
		var size: Vector2i = data["size"]
		var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, data["bytes"])
		image.convert(Image.FORMAT_RGB8)
		var error := image.save_webp(ProjectSettings.globalize_path(MapLayout.mask_path(_book(), _unit, mask)), false)
		if error != OK:
			return error
	for mask in _mask_files():
		if masks.has(mask):
			continue
		var path := ProjectSettings.globalize_path(MapLayout.mask_path(_book(), _unit, mask))
		DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path + ".import"):
			DirAccess.remove_absolute(path + ".import")
	return OK


## Baut die Regler der Art `kind` in Form `style` (MapLayout.PARAMS), wenn es andere sind
## als die stehenden.
func _fill_params(kind: String, style: String) -> void:
	var wanted := "%s/%s" % [kind, style]
	if wanted == _param_for:
		return
	_param_for = wanted
	_param_rows.clear()
	for child in _param_group.get_children():
		_param_group.remove_child(child)
		child.queue_free()
	for param: Dictionary in MapLayout.PARAMS.get(kind, []):
		if param.has("style") and param["style"] != style:
			continue
		var row := PARAM_SCENE.instantiate()
		_param_group.add_child(row)
		(row.get_node("Caption") as Label).text = param["label"]
		var slider := row.get_node("Row/Slider") as HSlider
		slider.min_value = param["min"]
		slider.max_value = param["max"]
		slider.step = param["step"]
		var entry := {"param": param, "slider": slider, "value": row.get_node("Row/Value")}
		_param_rows[param["key"]] = entry
		slider.value_changed.connect(func(value: float):
			_show_param(entry)
			_edit(param["key"], value, param["default"]))
	_param_group.visible = not _param_rows.is_empty()


func _show_param(row: Dictionary) -> void:
	var value := (row["slider"] as HSlider).value
	(row["value"] as Label).text = "%d°" % roundi(value) if row["param"]["key"] == "direction" \
			else "%.2f" % value
