extends Control
## Werkbank für die Orte der Landkarten (scenes/dev/map_ring_lab.tscn): goldener
## Fortschrittsring, Leuchten bei 100 %, Bonus-Sterne unter einer Unit, Bonus-Level auf der
## Gebietskarte und der Pfeil über einem markierten Ort.
##
## Gezeigt werden die echten Bilder und Punkte eines Buches mit ausgedachten Ständen
## (`PresetSelect`); der Regler füllt den ersten Ort, damit man den Sprung auf 100 % sieht.
## Ein Klick auf der Buchkarte geht ins Gebiet wie im Spiel; dort wählt ein Klick aus wie
## im Spiel (MapLevel.toggle): Teile und Boni mehrfach, Gesamt und Boss allein.
## Die Bonus-Level stehen noch in keiner map.json und kennt MapLevel noch nicht — die
## Werkbank legt sie zwischen „Gesamt" und Boss und lässt sie wie Teile wählen.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/map_ring_lab.tscn -- --shoot
##         speichert reports/map_rings/book.png und beendet sich.
##     … -- --shoot --area        die Gebietskarte der ersten Unit (area.png)
##     … -- --shoot --big         große Orte mit Beschriftung (…_big.png)
##     … -- --shoot --select      mit markiertem ersten Ort und erstem Bonus (nur --area)
##     … -- --shoot --crop        nur die ersten beiden Orte, doppelt groß
##
## Liest nur Katalog und Karte, schreibt nichts — kein Profil wird berührt.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const SHOT_DIR := "res://reports/map_rings"
## So lange läuft das Bild, bevor es gespeichert wird: Aufspringen vorbei, Funken unterwegs.
const SETTLE := 1.5
## Anteile in Prozent für „Gemischt", der Reihe nach über die Orte.
const MIXED := [60, 100, 35, 82, 0, 100, 15, 55]
## Bonus-Anteile je Unit für „Gemischt", der Reihe nach: einer gemeistert, zwei davon einer,
## keiner, einer offen.
const MIXED_BONUS := [[1.0], [1.0, 0.4], [], [0.0]]
## Bonus-Level auf der Gebietskarte — ein Bonus je Lernthema, mit dem Titel, den der
## Hinweis zeigt.
const BONUS_TITLES := ["Perfekt der Verben aus Lektion 1–10", "1. Person der Verben aus Lektion 1–2"]
## Ihr Anteil für „Gemischt": einer gemeistert, einer offen.
const BONUS_SHARES := [1.0, 0.4]

@onready var _book_select: OptionButton = %BookSelect
@onready var _map_select: OptionButton = %MapSelect
@onready var _preset_select: OptionButton = %PresetSelect
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress: HSlider = %ProgressSlider
@onready var _bonus_toggle: CheckButton = %BonusToggle
@onready var _big_toggle: CheckButton = %BigToggle
@onready var _status: Label = %Status
@onready var _canvas: MapCanvas = %Canvas

var _room: Window
## 0 = Buchkarte, sonst die Unit.
var _unit := 0
## Die markierten Orte (Schlüssel), nur auf der Gebietskarte.
var _selected: Array = []
## Die Level der Gebietskarte, samt den Boni (als Teile, damit MapLevel.toggle sie mehrfach
## wählen lässt).
var _levels: Array = []


func _ready() -> void:
	_room = get_window()
	LabRoom.enlarge(_room)
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	(%AppearButton as Button).pressed.connect(func(): _canvas.appear())
	_canvas.node_selected.connect(_on_node_selected)
	_book_select.item_selected.connect(func(_i: int): _load_book())
	_map_select.item_selected.connect(func(_i: int): _pick_map())
	_preset_select.item_selected.connect(func(_i: int): _redraw())
	_progress.value_changed.connect(func(_v: float): _redraw())
	_bonus_toggle.toggled.connect(func(_on: bool): _redraw())
	_big_toggle.toggled.connect(func(_on: bool): _redraw())
	var books := ContentRegistry.all_books()
	for book in books:
		_book_select.add_item(book)
	# Latein zuerst: dort gibt es die Boni, um die es geht.
	var latin := Array(books).find("latein")
	if latin >= 0:
		_book_select.select(latin)
	_load_book()
	if _has_arg("shoot"):
		_shoot.call_deferred()


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)


func _book() -> String:
	return _book_select.get_item_text(_book_select.selected) if _book_select.selected >= 0 else ""


func _load_book() -> void:
	_map_select.clear()
	_map_select.add_item("Buchkarte", 0)
	for unit in ContentRegistry.units_for(_book()):
		_map_select.add_item("Unit %d" % int(unit), int(unit))
	_pick_map()


func _pick_map() -> void:
	_unit = _map_select.get_selected_id() if _map_select.selected >= 0 else 0
	_selected = []
	_redraw()
	_canvas.appear()


## Der Anteil in Prozent für den Ort `index`: der erste vom Regler, die übrigen aus der
## Vorgabe.
func _percent(index: int) -> int:
	if index == 0:
		return int(_progress.value)
	match _preset_select.selected:
		1:
			return 0
		2:
			return 100
	return int(MIXED[index % MIXED.size()])


func _bonus(index: int) -> Array:
	var shares: Array = (MIXED_BONUS[index % MIXED_BONUS.size()] as Array).duplicate()
	for s in shares.size():
		if _bonus_toggle.button_pressed or _preset_select.selected == 2:
			shares[s] = 1.0
		elif _preset_select.selected == 1:
			shares[s] = 0.0
	return shares


func _redraw() -> void:
	_progress_label.text = "Erster Ort: %d %%" % int(_progress.value)
	var big := _big_toggle.button_pressed
	# Wie im Spiel kleine Orte, die unter dem Zeiger wachsen; „Große Orte" zum Hinsehen.
	_canvas.node_radius = MapCanvas.NODE_RADIUS if big else MapCanvas.AREA_NODE_RADIUS
	_canvas.hover_radius = 0.0 if big else MapCanvas.NODE_RADIUS
	_canvas.show_captions = big
	_canvas.path_over_image = _unit == 0
	var nodes := _book_nodes() if _unit == 0 else _area_nodes()
	var layout := MapLayout.data(_book())
	var texture := MapLayout.book_texture(_book()) if _unit == 0 \
			else MapLayout.unit_texture(_book(), _unit)
	var path := MapLayout.book_path(layout) if _unit == 0 else MapLayout.area_path(layout, _unit)
	_canvas.setup(texture, nodes, path, _hint)
	_canvas.set_selected(_selected)
	_status.text = "%s — %s. %d Orte, %d leuchten." % [_book(),
			"Buchkarte" if _unit == 0 else "Unit %d" % _unit, nodes.size(),
			nodes.filter(MapCanvas.shines).size()]


func _book_nodes() -> Array:
	var units: Array = []
	var index := 0
	for unit in ContentRegistry.units_for(_book()):
		var done := _percent(index)
		units.append({"key": "%s/%d" % [_book(), int(unit)], "unit": int(unit),
				"done": done, "total": 100, "tier": FortressTier.tier_for(done, 100)})
		index += 1
	var points := MapLayout.unit_points(MapLayout.data(_book()))
	var nodes := BookMap.nodes_for(_book(), units, points, {})
	for i in nodes.size():
		if not bool(nodes[i].get("missing", false)):
			nodes[i]["bonus"] = _bonus(i)
	return nodes


func _area_nodes() -> Array:
	var book := _book()
	var layout := MapLayout.data(book)
	var levels := MapLevel.levels_for(book, _unit, AreaMap.part_count(book, _unit, layout))
	_levels = levels.duplicate()
	var unit_key := "%s/%d" % [book, _unit]
	var parts := {}
	var index := 0
	var sum := 0
	for level in levels:
		if str(level["kind"]) != MapLevel.KIND_PART:
			continue
		var done := _percent(index)
		sum += done
		parts["%s/%d" % [unit_key, int(level["part"])]] = {"done": done, "total": 100,
				"tier": FortressTier.tier_for(done, 100)}
		index += 1
	var total := 100 * maxi(index, 1)
	var units := {unit_key: {"done": sum, "total": total, "tier": FortressTier.tier_for(sum, total)}}
	var points := MapLayout.area_points(layout, _unit)
	var nodes := AreaMap.nodes_for(levels, units, parts, 2, true, points)
	var boss_at := nodes.size() - 1
	var from: Vector2 = points.get("all", Vector2.INF)
	var to: Vector2 = points.get("boss", Vector2.INF)
	for b in BONUS_TITLES.size():
		# Zwischen Gesamt und Boss, etwas abseits des Weges.
		var t := float(b + 1) / float(BONUS_TITLES.size() + 1)
		var pos := from.lerp(to, t) + Vector2(0.0, -0.09) if from.is_finite() and to.is_finite() \
				else Vector2.INF
		var share := float(BONUS_SHARES[b % BONUS_SHARES.size()])
		if _bonus_toggle.button_pressed or _preset_select.selected == 2:
			share = 1.0
		elif _preset_select.selected == 1:
			share = 0.0
		var key := "bonus%d" % (b + 1)
		nodes.insert(boss_at + b, {"key": key, "kind": "bonus", "unit": _unit, "glyph": "+",
				"caption": "Bonus", "title": str(BONUS_TITLES[b]), "pos": pos,
				"done": roundi(share * 40.0), "total": 40})
		_levels.insert(boss_at + b, {"key": key, "kind": MapLevel.KIND_PART})
	return nodes


func _hint(node: Dictionary) -> Dictionary:
	if str(node.get("kind", "")) == "bonus":
		return {"title": "Bonus: %s" % str(node["title"]),
				"body": "%d von %d Aufgaben gemeistert\nZählt nicht zur Festung." % [
					int(node["done"]), int(node["total"])]}
	if _unit == 0:
		return BookMap.hint_lines(node, _book())
	return AreaMap.hint_lines(node)


func _on_node_selected(key: String) -> void:
	if _unit == 0:
		var unit := int(key.get_slice("/", 1))
		for i in _map_select.item_count:
			if _map_select.get_item_id(i) == unit:
				_map_select.select(i)
		_pick_map()
		return
	_selected = MapLevel.toggle(_levels, _selected, key)
	_canvas.set_selected(_selected)


func _shoot() -> void:
	var tag := "book"
	if _has_arg("area"):
		_map_select.select(1)
		_pick_map()
		tag = "area"
	if _has_arg("big"):
		_big_toggle.button_pressed = true
		tag += "_big"
	if _has_arg("select") and _unit != 0:
		_selected = ["t1", "bonus1"]
		_redraw()
		tag += "_select"
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	if _has_arg("crop"):
		image = _crop(image)
		tag += "_crop"
	var file := "%s/%s.png" % [dir, tag]
	image.save_png(file)
	print("map_ring_lab: ", file)
	get_tree().quit()


## Der Ausschnitt um die ersten beiden Orte, doppelt groß — die Sterne sind klein.
func _crop(image: Image) -> Image:
	var scale := Vector2(image.get_size()) / get_viewport_rect().size
	var a := _canvas.global_position + _canvas.node_position(0)
	var b := _canvas.global_position + _canvas.node_position(1)
	var area := Rect2(a, Vector2.ZERO).expand(b).grow(110.0)
	area = Rect2(area.position * scale, area.size * scale).intersection(Rect2(Vector2.ZERO, Vector2(image.get_size())))
	var region := image.get_region(Rect2i(area))
	region.resize(region.get_width() * 2, region.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	return region


func _arg(arg_name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % arg_name):
			return arg.get_slice("=", 1)
	return ""


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)
