class_name BookSelect
extends Control
## Bibliothek: der erste Schritt nach „Lernen" (ADR 0006, Entwurf
## `assets/ui/library/concept/library-v6.webp`). Eine Seite des Start-Screens (ProfileMenu):
## rechts neben dem Hauptmenü, und die Kamera der Kulisse fährt dafür durch die Mauer in den
## Turm (MenuBackdrop, library_room.tscn). Diese Seite hat kein eigenes 3D — sie stellt ihre
## Bücher in den Raum der Kulisse und schaut durch deren Kamera.
##
## Die Bücher stehen in einer Reihe auf dem Lesepult, frontal und ein wenig gedreht, sodass
## links der Rücken zu sehen ist: Englisch vorn, die übrigen Sprachen dahinter
## (`shelf_rows`). Das Pult hat SLOTS Plätze; gibt es mehr Bücher, blättern die Pfeile am
## Rand — nur die Reihe rückt, der Raum bleibt stehen.
##
## Unter dem Zeiger — oder mit ←/→ — wird ein Buch vom Pult genommen: groß in der Bildmitte,
## gerade zur Kamera, und auf dem Cover erscheint sein Stand (Book3D). Ein Klick schlägt das Buch auf; die Doppelseite trägt
## die Buchkarte, und die Kamera fliegt in sie hinein, bis die Karte den Bildschirm füllt —
## dort steht die Buchkarte, und der Wechsel fällt nicht auf. Zurück geht es denselben Weg
## rückwärts (`return_from_book`).
##
## Die Zahlen kommen aus FortressTier.unit_tiers und BossRecord — derselben Zählung wie
## Karte und Kampf.

## „Zurück" (und Esc): ProfileMenu schiebt ins Hauptmenü.
signal back_requested
## „Profil wechseln" am Spielerschild: ProfileMenu schiebt zu „Wer spielt?".
signal switch_requested

const BOOK_SCENE := preload("res://scenes/ui/book_3d.tscn")

## So lang fliegt die Kamera in die Doppelseite hinein und wieder heraus.
const DIVE_TIME := 1.1
## Ab diesem Anteil des Flugs blendet die flache Buchkarte über die Karte im Buch.
const BLEND_FROM := 0.8
## Plätze auf dem Pult und ihr Abstand (Mitte zu Mitte, in Metern).
const SLOTS := 5
const SLOT_WIDTH := 1.1
## So lang rückt die Reihe beim Blättern um eine Seite.
const PAGE_TIME := 0.36

@onready var _stage: Control = %Stage
@onready var _ui: Control = %Ui
@onready var _dive: Control = %Dive
@onready var _dive_image: TextureRect = %Image
@onready var _empty_hint: Label = %EmptyHint
@onready var _prev: Button = %PrevButton
@onready var _next: Button = %NextButton

var _backdrop: MenuBackdrop
var _camera: Camera3D
var _books: Node3D
var _selected := -1
## Der erste sichtbare Platz der Reihe (ein Vielfaches von SLOTS).
var _first := 0
var _page_tween: Tween
## Der laufende Flug: Kamera von/nach, Anteil, Richtung, das Buch.
var _run := {}


func _ready() -> void:
	(%BackButton as Button).pressed.connect(back_requested.emit)
	(%ProfileBadge as ProfileBadge).switch_pressed.connect(switch_requested.emit)
	_prev.pressed.connect(func(): _page_to(_first - SLOTS))
	_next.pressed.connect(func(): _page_to(_first + SLOTS))
	Hints.attach(_prev, "Vorherige Bücher")
	Hints.attach(_next, "Weitere Bücher")
	_stage.gui_input.connect(_on_stage_input)


## Die Kulisse, in deren Turm die Bücher stehen. ProfileMenu ruft das einmal auf.
func setup(backdrop: MenuBackdrop) -> void:
	_backdrop = backdrop
	_camera = backdrop.camera()
	_books = backdrop.library_books()


## Stellt die Bücher neu auf, bevor die Seite hereinfährt — der Stand kann sich seit dem
## letzten Besuch geändert haben (anderes Profil, gespielte Runde). Aufgeschlagen ist die
## Seite mit dem zuletzt geöffneten Buch, herausgenommen ist keines: das tut erst die Maus
## (oder ←/→), sonst stünde nach dem Hereinfahren immer ein Buch im Vordergrund.
func enter() -> void:
	_fill()
	var book := _book_of(MapSelection.book)
	_page_to(0 if book == null else book.get_index(), true)
	(%ProfileBadge as ProfileBadge).refresh()


## Beim Hinausfahren: kein Buch bleibt in der Luft.
func leave() -> void:
	_select(-1)


## Aus der Buchkarte zurück: die Kamera steht im aufgeschlagenen Buch, die flache Karte
## deckt noch den Bildschirm wie eben auf der Buchkarte; dann geht es heraus.
func return_from_book() -> void:
	var book := _book_of(MapSelection.book)
	if book == null or book.texture() == null:
		return
	_select(book.get_index())
	book.show_open()
	_cover_screen(book.texture())
	_ui.modulate.a = 0.0
	# Erst wenn der Viewport seine Größe hat, lässt sich der Blick ins Buch rechnen.
	await get_tree().process_frame
	_start_dive(book, true)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _run.is_empty() or _books == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_step(1)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_step(-1)
	elif _selected >= 0 and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_open(_books.get_child(_selected) as Book3D)


func _fill() -> void:
	for child in _books.get_children():
		_books.remove_child(child)
		child.queue_free()
	_selected = -1
	var tiers := FortressTier.unit_tiers(ContentRegistry.lexemes.values(),
			PlayerProgress.mastered_lexemes())
	var shelves := BookMap.book_units(tiers)
	var wins := BossRecord.wins(UserSettings.active_profile())
	_empty_hint.visible = shelves.is_empty()
	var books := Array(ContentRegistry.all_books()).filter(func(b): return shelves.has(b))
	var order: Array = []
	for row: Array in shelf_rows(books, ContentRegistry.book_language):
		order.append_array(row)
	for i in order.size():
		_place_book(order[i], i, shelves, wins)
	# Jede Seite steht mittig auf dem Pult, auch die letzte, wenn sie nicht voll ist.
	for node: Book3D in _books.get_children():
		var i := node.get_index()
		var on_page := mini(SLOTS, order.size() - (i - i % SLOTS))
		node.position = Vector3(slot_x(i, on_page), Book3D.HEIGHT * 0.5, 0.0)


## Wo das Buch `index` auf dem Pult steht, wenn die Reihe bei 0 beginnt; `on_page` Bücher
## stehen auf seiner Seite, mittig.
static func slot_x(index: int, on_page: int) -> float:
	var page := index - index % SLOTS
	return (index - page - (on_page - 1) * 0.5) * SLOT_WIDTH + page * SLOT_WIDTH


func _place_book(book: String, i: int, shelves: Dictionary, wins: Dictionary) -> Book3D:
	var node := BOOK_SCENE.instantiate() as Book3D
	node.set_meta("book", book)
	_books.add_child(node)
	var info := stats(shelves[book], wins)
	info["language"] = Lexeme.language_name(ContentRegistry.book_language(book))
	# Bosse gibt es nur, wo die Unit Sätze hat — ein Buch ohne Sätze (Latein) hat keine.
	info["bosses"] = ContentRegistry.units_for(book).filter(
			func(u): return AreaMap.has_boss_sentences(book, int(u))).size()
	node.fill(ContentRegistry.book_label(book), MapLayout.book_texture(book), i, info)
	return node


## Die Bücher je Sprache: Englisch zuerst, die übrigen Sprachen alphabetisch danach.
## Innerhalb einer Sprache bleibt die Reihenfolge von `books`. `language_of` liefert die
## Sprache eines Buchs (ContentRegistry.book_language) — als Callable, damit die Regel ohne
## Autoload prüfbar bleibt.
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


## Der Stand eines Buchs: Units, gemeisterte Wörter, Bosskronen. Die Festungsstufe gilt je
## Unit und steht deshalb auf der Buchkarte, nicht hier.
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


## Blättert zur Seite, die bei `first` beginnt: die Reihe rückt, die Pfeile sperren an den
## Enden. `instant` ohne Bewegung (beim Hereinfahren der Seite).
func _page_to(first: int, instant := false) -> void:
	var count := _books.get_child_count()
	first = clampi(first, 0, maxi(count - 1, 0))
	first -= first % SLOTS
	_first = first
	_prev.disabled = first == 0
	_next.disabled = first + SLOTS >= count
	_prev.visible = count > SLOTS
	_next.visible = count > SLOTS
	if _selected >= 0 and (_selected < first or _selected >= first + SLOTS):
		_select(-1)
	var x := -first * SLOT_WIDTH
	# Die Bücher rücken zur Mitte des Bildes, nicht zur Mitte der Reihe.
	for node: Book3D in _books.get_children():
		node.center_x = -x
	if _page_tween != null:
		_page_tween.kill()
	if instant:
		_books.position.x = x
		return
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(_books, "position:x", x, PAGE_TIME)


## ←/→: zum nächsten Buch in `direction`; am Seitenrand wird geblättert.
func _step(direction: int) -> void:
	var count := _books.get_child_count()
	var index := _selected
	if index < 0:
		index = _first - 1 if direction > 0 else mini(_first + SLOTS, count)
	index += direction
	if index < 0 or index >= count:
		return
	if index < _first or index >= _first + SLOTS:
		_page_to(index)
	_select(index)


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
	if not _run.is_empty() or _books == null:
		return
	var motion := event as InputEventMouseMotion
	# Nur eine echte Bewegung zählt — ein Zeiger, der beim Hereinfahren zufällig über
	# einem Platz steht, nimmt noch kein Buch heraus.
	if motion != null and motion.relative != Vector2.ZERO:
		var index := book_at(motion.position)
		# Wer das herausgenommene Buch liest, lässt es nicht fallen, nur weil der Zeiger
		# dabei über keinem Platz steht.
		if index >= 0 or _selected < 0 or not _selected_body_at(motion.position):
			_select(index)
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var index := book_at(button.position)
		if index >= 0:
			_select(index)
			_open(_books.get_child(index) as Book3D)
		elif _selected >= 0 and _selected_body_at(button.position):
			_open(_books.get_child(_selected) as Book3D)


## Welches Buch seinen Platz unter `point` (Bildschirmkoordinaten) hat, sonst -1. Gezielt
## wird auf die Plätze in der Reihe (Book3D.hit), nicht auf das herausgenommene Buch.
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


## Liegt `point` auf dem herausgenommenen Buch? Ein Klick dort öffnet es, auch wo es über
## keinem Platz steht.
func _selected_body_at(point: Vector2) -> bool:
	var book := _books.get_child(_selected) as Book3D
	return book.hit_body(_camera.project_ray_origin(point),
			_camera.project_ray_normal(point)) < INF


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


# --- Flug ins Buch ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _run.is_empty():
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
	if bool(run["back"]):
		_dive.visible = false
		_backdrop.hold_camera = false
		(run["book"] as Book3D).hold_forward(false)
	else:
		get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)


## Fliegt die Kamera vom Pult in die Doppelseite, bis ihre Karte den Bildschirm füllt wie
## auf der Buchkarte (oder mit `back` von dort zurück). Am Ende blendet die flache Buchkarte
## darüber — sie steht genau da, wo die Karte im Buch steht.
func _start_dive(book: Book3D, back: bool) -> void:
	var screen := get_viewport_rect().size
	var inside := book.spread_view(_camera.fov, screen.x / maxf(screen.y, 1.0))
	# Die Kamera gehört der Kulisse; für den Flug hält sie still.
	_backdrop.hold_camera = true
	var home := _backdrop.global_transform * _backdrop.view_at(ProfileMenu.LIBRARY)
	_run = {"book": book, "back": back, "t": 0.0, "home": home, "inside": inside}
	_cover_screen(book.texture())
	_show_dive(1.0 if back else 0.0)


## Stellt den Flug bei `t` dar: 0 = Kamera vor dem Pult, 1 = in der Doppelseite. Sanft
## an- und auslaufend; die Kopfzeile geht früh, die flache Karte kommt erst am Ende.
func _show_dive(t: float) -> void:
	var k := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var home: Transform3D = _run["home"]
	var inside: Transform3D = _run["inside"]
	_camera.global_transform = home.interpolate_with(inside, k)
	_ui.modulate.a = 1.0 - smoothstep(0.0, 0.3, t)
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
