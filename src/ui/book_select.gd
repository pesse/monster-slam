extends Control
## Buchauswahl: der erste Schritt nach „Lernen" (ADR 0006).
##
## Die Bücher stehen mit dem Rücken nach vorn in einem Regal (3D, `%World`). Unter dem
## Zeiger — oder mit ←/→ — wird ein Buch herausgezogen und gedreht, bis sein Cover zur
## Kamera zeigt: oben die Buchkarte im Rahmen, unten der Stand (Book3D). Ein Klick schlägt
## das Buch auf; die Doppelseite trägt die Buchkarte, und die Kamera fliegt in sie hinein,
## bis die Karte den Bildschirm füllt — dort steht die Buchkarte, und der Wechsel fällt
## nicht auf. Zurück geht es denselben Weg rückwärts: aus dem Buch heraus, zu, ins Regal.
##
## Jede Sprache hat ihr eigenes Regalfach: oben Englisch, darunter die übrigen (Latein,
## Issue #31). Mit mehr Fächern rückt die Kamera zurück, bis alle ins Bild passen.
##
## Die Zahlen kommen aus FortressTier.unit_tiers und BossRecord — derselben Zählung wie
## Karte und Kampf.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const BOOK_SCENE := preload("res://scenes/ui/book_3d.tscn")

## So lang fliegt die Kamera in die Doppelseite hinein und wieder heraus.
const DIVE_TIME := 1.1
## Ab diesem Anteil des Flugs blendet die flache Buchkarte über die Karte im Buch.
const BLEND_FROM := 0.8
## Luft im Regal links und rechts der Bücher, und so schmal wird es höchstens.
const SHELF_PAD := 0.35
const MIN_SHELF := 1.6
## Breite der Rückwand und der Böden in book_select.tscn, bevor sie zugeschnitten werden.
const SHELF_MESH_WIDTH := 2.6
## Höhe der Rückwand und der Seitenwände in book_select.tscn, für ein Fach.
const SHELF_BACK_HEIGHT := 1.8
const SHELF_SIDE_HEIGHT := 1.76
## Von Boden zu Boden: ein Fach unter dem anderen.
const ROW_HEIGHT := 1.66
## So viel weiter zurück steht die Kamera je weiterem Fach.
const CAMERA_BACK_PER_ROW := 2.3

@onready var _stage: SubViewportContainer = %Stage
@onready var _camera: Camera3D = %Camera
@onready var _books: Node3D = %Books
@onready var _dive: Control = %Dive
@onready var _dive_image: TextureRect = %Image
@onready var _empty_hint: Label = %EmptyHint

var _selected := -1
## Der laufende Flug: Kamera von/nach, Anteil, Richtung, das Buch.
var _run := {}
## Wo die Kamera vor dem Regal steht — dorthin kehrt sie zurück.
var _camera_home := Transform3D()


func _ready() -> void:
	(%BackButton as Button).pressed.connect(_back)
	_stage.gui_input.connect(_on_stage_input)
	set_process(false)
	_fill()
	_camera_home = _camera.transform
	# Aus der Buchkarte zurück: die Kamera steht im aufgeschlagenen Buch, die flache Karte
	# deckt noch den Bildschirm wie eben auf der Buchkarte; dann geht es heraus.
	if MapSelection.to_shelf:
		MapSelection.to_shelf = false
		var book := _book_of(MapSelection.book)
		if book != null and book.texture() != null:
			_select(book.get_index())
			book.show_open()
			_cover_screen(book.texture())
			(%Margin as Control).modulate.a = 0.0
			# Erst wenn der Viewport seine Größe hat, lässt sich der Blick ins Buch rechnen.
			await get_tree().process_frame
			_start_dive(book, true)


func _unhandled_input(event: InputEvent) -> void:
	if not _run.is_empty():
		return
	var count := _books.get_child_count()
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif count > 0 and event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_select(0 if _selected < 0 else mini(_selected + 1, count - 1))
	elif count > 0 and event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_select(count - 1 if _selected < 0 else maxi(_selected - 1, 0))
	elif count > 0 and event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_select(_first_of_row(_row_of(_selected) + 1))
	elif count > 0 and event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_select(_first_of_row(_row_of(_selected) - 1))
	elif _selected >= 0 and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_open(_books.get_child(_selected) as Book3D)


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _fill() -> void:
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes())
	var shelves := BookMap.book_units(tiers)
	var wins := BossRecord.wins(UserSettings.active_profile())
	_empty_hint.visible = shelves.is_empty()
	var books := Array(ContentRegistry.all_books()).filter(func(b): return shelves.has(b))
	var rows := shelf_rows(books, ContentRegistry.book_language)
	var placed: Array = []
	var i := 0
	for r in rows.size():
		var row: Array[Book3D] = []
		for book: String in rows[r]:
			row.append(_place_book(book, i, r, shelves, wins))
			i += 1
		placed.append(row)
	# Je Fach nebeneinander, als Reihe mittig im Regal; jedes Buch so dick wie seine Units.
	var widest := 0.0
	for r in placed.size():
		var width := 0.0
		for node: Book3D in placed[r]:
			width += node.thickness + Book3D.GAP
		widest = maxf(widest, width - Book3D.GAP)
		var x := -(width - Book3D.GAP) * 0.5
		for node: Book3D in placed[r]:
			node.position = Vector3(x + node.thickness * 0.5,
					Book3D.HEIGHT * 0.5 - r * ROW_HEIGHT, 0.0)
			x += node.thickness + Book3D.GAP
	_fit_shelf(widest, maxi(rows.size(), 1))


func _place_book(book: String, i: int, row: int, shelves: Dictionary, wins: Dictionary) -> Book3D:
	var node := BOOK_SCENE.instantiate() as Book3D
	node.set_meta("book", book)
	node.set_meta("row", row)
	_books.add_child(node)
	var info := stats(shelves[book], wins)
	info["language"] = Lexeme.language_name(ContentRegistry.book_language(book))
	# Bosse gibt es nur, wo die Unit Sätze hat — ein Buch ohne Sätze (Latein) hat keine.
	info["bosses"] = ContentRegistry.units_for(book).filter(
			func(u): return AreaMap.has_boss_sentences(book, int(u))).size()
	node.fill(ContentRegistry.book_label(book), MapLayout.book_texture(book), i, info)
	return node


## Die Bücher je Regalfach, eine Sprache je Fach: Englisch oben, die übrigen Sprachen
## alphabetisch darunter. Innerhalb eines Fachs bleibt die Reihenfolge von `books`.
## `language_of` liefert die Sprache eines Buchs (ContentRegistry.book_language) — als
## Callable, damit die Regel ohne Autoload prüfbar bleibt.
static func shelf_rows(books: Array, language_of: Callable) -> Array:
	var by_language := {}
	for book in books:
		var lang := str(language_of.call(book))
		if not by_language.has(lang):
			by_language[lang] = []
		(by_language[lang] as Array).append(book)
	var languages: Array = by_language.keys()
	languages.sort_custom(func(a, b):
		if (a == Lexeme.DEFAULT_LANGUAGE) != (b == Lexeme.DEFAULT_LANGUAGE):
			return a == Lexeme.DEFAULT_LANGUAGE
		return str(a) < str(b))
	return languages.map(func(lang): return by_language[lang])


## Schneidet das Regal auf die Bücher zu: Rückwand, Böden und Seitenwände, und stellt es
## auf `rows` Fächer hoch. Je weiteres Fach ein Boden mehr darunter (eine Kopie von
## `%ShelfFloor`); die Kamera rückt so weit zurück, dass alle Fächer im Bild sind.
func _fit_shelf(books_width: float, rows: int) -> void:
	var inner := maxf(books_width + 2.0 * SHELF_PAD, MIN_SHELF)
	var floor := %ShelfFloor as Node3D
	var boards: Array[Node3D] = [%ShelfBack, floor, %ShelfTop]
	for r in range(1, rows):
		var extra := floor.duplicate() as Node3D
		extra.unique_name_in_owner = false
		extra.name = "ShelfFloor%d" % (r + 1)
		extra.position.y = floor.position.y - r * ROW_HEIGHT
		floor.get_parent().add_child(extra)
		boards.append(extra)
	for board in boards:
		board.scale.x = (inner + 0.2) / SHELF_MESH_WIDTH
	var drop := (rows - 1) * ROW_HEIGHT
	var back := %ShelfBack as Node3D
	back.scale.y = (SHELF_BACK_HEIGHT + drop) / SHELF_BACK_HEIGHT
	back.position.y -= drop * 0.5
	for side: Node3D in [%ShelfLeft, %ShelfRight]:
		side.scale.y = (SHELF_SIDE_HEIGHT + drop) / SHELF_SIDE_HEIGHT
		side.position.y -= drop * 0.5
	(%ShelfLeft as Node3D).position.x = -inner * 0.5 - 0.05
	(%ShelfRight as Node3D).position.x = inner * 0.5 + 0.05
	_camera.position += Vector3(0.0, -drop * 0.5, (rows - 1) * CAMERA_BACK_PER_ROW)
	($Stage/World/Lamp as Node3D).position.y -= drop * 0.5


## Das Fach eines Buchs (Index unter `%Books`), -1 ohne Auswahl.
func _row_of(index: int) -> int:
	if index < 0 or index >= _books.get_child_count():
		return -1
	return int(_books.get_child(index).get_meta("row", 0))


## Das erste Buch im Fach `row`, oder die bisherige Auswahl, wenn es das Fach nicht gibt.
func _first_of_row(row: int) -> int:
	for child in _books.get_children():
		if int(child.get_meta("row", 0)) == maxi(row, 0):
			return child.get_index()
	return _selected


## Der Stand eines Buchs: Units, gemeisterte Wörter, Bosskronen. Die Festungsstufe gilt je
## Unit und steht deshalb auf der Buchkarte, nicht auf dem Cover.
static func stats(units: Array, wins: Dictionary) -> Dictionary:
	var done := 0
	var total := 0
	var crowns := 0
	for unit in units:
		done += int(unit["done"])
		total += int(unit["total"])
		if int(wins.get(str(unit["key"]), 0)) > 0:
			crowns += 1
	return {"units": units.size(), "done": done, "total": total, "crowns": crowns}


func _book_of(book: String) -> Book3D:
	for child in _books.get_children():
		if str(child.get_meta("book", "")) == book:
			return child as Book3D
	return null


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	for child in _books.get_children():
		(child as Book3D).set_selected(child.get_index() == index)
	_stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 \
			else Control.CURSOR_ARROW


func _on_stage_input(event: InputEvent) -> void:
	if not _run.is_empty():
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_select(book_at(motion.position))
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var index := book_at(button.position)
		if index >= 0:
			_select(index)
			_open(_books.get_child(index) as Book3D)


## Welches Buch unter `point` (Koordinaten von `%Stage`) liegt, sonst -1. Das nächste gewinnt:
## ein herausgezogenes Buch liegt vor seinen Nachbarn.
func book_at(point: Vector2) -> int:
	var origin := _camera.project_ray_origin(point)
	var direction := _camera.project_ray_normal(point)
	var best := -1
	var nearest := INF
	for child in _books.get_children():
		var distance := (child as Book3D).hit(origin, direction)
		if distance < nearest:
			nearest = distance
			best = child.get_index()
	return best


func _open(book: Book3D) -> void:
	if not _run.is_empty():
		return
	MapSelection.book = str(book.get_meta("book"))
	if book.texture() == null:
		get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)
		return
	# Erst nach vorn, gerade drehen und aufschlagen, dann in die Doppelseite tauchen.
	book.open_book()
	_run = {"waiting": book}
	set_process(true)


# --- Flug ins Buch ---------------------------------------------------------------

## Fliegt die Kamera vom Regal in die Doppelseite, bis ihre Karte den Bildschirm füllt wie
## auf der Buchkarte (oder mit `back` von dort zurück). Am Ende blendet die flache Buchkarte
## darüber — sie steht genau da, wo die Karte im Buch steht.
func _start_dive(book: Book3D, back: bool) -> void:
	var aspect := _stage.size.x / maxf(_stage.size.y, 1.0)
	var inside := book.spread_view(_camera.fov, aspect)
	var home := _camera_home
	_run = {"book": book, "back": back, "t": 0.0, "home": home, "inside": inside}
	_cover_screen(book.texture())
	_show_dive(1.0 if back else 0.0)
	set_process(true)


func _process(delta: float) -> void:
	if _run.is_empty():
		set_process(false)
		return
	if _run.has("waiting"):
		var book := _run["waiting"] as Book3D
		if book.is_spread_open():
			_start_dive(book, false)
		return
	var t := minf(1.0, float(_run["t"]) + minf(delta, MapCanvas.MAX_ZOOM_STEP) / DIVE_TIME)
	_run["t"] = t
	_show_dive(1.0 - t if bool(_run["back"]) else t)
	if t < 1.0:
		return
	var run := _run
	_run = {}
	set_process(false)
	if bool(run["back"]):
		_dive.visible = false
		_camera.transform = _camera_home
		(run["book"] as Book3D).hold_forward(false)
	else:
		get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)


## Stellt den Flug bei `t` dar: 0 = Kamera vor dem Regal, 1 = in der Doppelseite. Sanft
## an- und auslaufend; die Kopfzeile geht früh, die flache Karte kommt erst am Ende.
func _show_dive(t: float) -> void:
	var k := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var home: Transform3D = _run["home"]
	var inside: Transform3D = _run["inside"]
	_camera.transform = home.interpolate_with(inside, k)
	(%Margin as Control).modulate.a = 1.0 - smoothstep(0.0, 0.3, t)
	var blend := smoothstep(BLEND_FROM, 1.0, t)
	_dive.modulate.a = blend
	_dive.visible = blend > 0.0


## Legt die flache Buchkarte über den ganzen Bildschirm, wie MapCanvas sie zeichnet.
func _cover_screen(texture: Texture2D) -> void:
	var screen := get_viewport_rect()
	_dive_image.texture = texture
	_place_dive(screen, MapCanvas.map_rect(screen.size, _ratio(texture), true))
	_dive.modulate.a = 1.0
	_dive.visible = true


func _place_dive(clip: Rect2, image: Rect2) -> void:
	_dive.position = clip.position
	_dive.size = clip.size
	_dive_image.position = image.position - clip.position
	_dive_image.size = image.size


static func _ratio(texture: Texture2D) -> float:
	return float(texture.get_width()) / float(maxi(texture.get_height(), 1))
