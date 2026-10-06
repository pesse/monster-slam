extends Control
## Das Handbuch-Fenster: links die Kapitel, rechts die Seite (ADR 0019).
##
## Geöffnet wird es nur über `Handbook.open`, das es in eine eigene Zeichenschicht über
## allem hängt — es kommt aus dem Startmenü genauso wie aus der Statistik oder einer Karte,
## und was darunter liegt, bleibt, wie es war. Rahmen, Titelband und Schließen-X sind die
## der anderen Fenster.
##
## Bedienung ohne Maus: ↑/↓ wechseln das Kapitel (der Fokus bleibt in der Liste), Bild↑/Bild↓
## und Pos1/Ende blättern die Seite, Esc oder F1 schließt. Alle übrigen Tasten schluckt das
## Fenster, damit darunter nichts weiterläuft.
##
## Die Seite wird bei jedem Kapitelwechsel aus Vorlagen neu gebaut (`Handbook.blocks`);
## ein Kapitel hat höchstens ein paar Dutzend Blöcke.

## Das Fenster will zu; `Handbook` nimmt seine Schicht weg.
signal closed()

const FADE_IN := 0.15
const CHAPTER_SCENE := preload("res://scenes/ui/handbook_chapter.tscn")
const HEADING_SCENE := preload("res://scenes/ui/handbook_heading.tscn")
const TEXT_SCENE := preload("res://scenes/ui/handbook_text.tscn")
const ITEM_SCENE := preload("res://scenes/ui/handbook_item.tscn")
const HEADING_ROLES := {1: &"HandbookTitle", 2: &"HandbookHeading"}
const HEADING_ROLE_DEEPER := &"HandbookSubheading"
## Einzug eines Unterpunkts, eine Stufe der Abstands-Skala.
const SUB_INDENT := 24
## Bild↑/Bild↓ blättert um diesen Anteil der sichtbaren Höhe — ein Rest der alten Seite
## bleibt stehen, damit man den Anschluss findet.
const PAGE_STEP := 0.85

@onready var _chapter_list: VBoxContainer = %ChapterList
@onready var _page: VBoxContainer = %Page
@onready var _page_scroll: ScrollContainer = %PageScroll

var _file := ""
## Datei → Knopf in der Kapitelliste.
var _buttons := {}
## Anker → Überschrift auf der aktuellen Seite.
var _anchors := {}
## Was vor dem Öffnen den Fokus hatte; bekommt ihn beim Schließen zurück.
var _previous_focus: Control = null
## Zählt Seitenaufbauten, damit ein verspätetes Scrollen nicht in eine neuere Seite fährt.
var _build := 0


func _ready() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	(%CloseButton as BaseButton).pressed.connect(closed.emit)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	var group := ButtonGroup.new()
	var chapters := Handbook.chapters()
	for i in chapters.size():
		var chapter: Dictionary = chapters[i]
		var button: Button = CHAPTER_SCENE.instantiate()
		button.text = chapter.title if i == 0 else "%d. %s" % [i, chapter.title]
		button.button_group = group
		_chapter_list.add_child(button)
		_buttons[chapter.file] = button
		button.focus_entered.connect(func() -> void:
			if _file != chapter.file:
				show_chapter(chapter.file))
		button.pressed.connect(func() -> void: show_chapter(chapter.file))
	_trap_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


## ↑/↓ laufen im Kreis durch die Liste, ←/→ und Tab bleiben darin.
func _trap_focus() -> void:
	var buttons := _chapter_list.get_children()
	for i in buttons.size():
		var button: Button = buttons[i]
		var up: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var down: Button = buttons[(i + 1) % buttons.size()]
		button.focus_neighbor_top = button.get_path_to(up)
		button.focus_neighbor_bottom = button.get_path_to(down)
		button.focus_previous = button.get_path_to(up)
		button.focus_next = button.get_path_to(down)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


## Zeigt ein Kapitel, auf Wunsch an einer Überschrift (ihr Text oder ihr Anker).
func show_chapter(file: String, section := "") -> void:
	if not _buttons.has(file):
		push_warning("Handbuch: kein Kapitel %s" % file)
		file = Handbook.INDEX
	var button: Button = _buttons[file]
	button.set_pressed_no_signal(true)
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not _chapter_list.is_ancestor_of(focus):
		button.grab_focus.call_deferred()
	if file != _file:
		_file = file
		_fill(Handbook.blocks(Handbook.read(file)))
	_scroll_to(Handbook.anchor(section))


func _fill(blocks: Array[Dictionary]) -> void:
	_build += 1
	_anchors.clear()
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	for block in blocks:
		match block.kind:
			"heading":
				var heading: Label = HEADING_SCENE.instantiate()
				heading.theme_type_variation = HEADING_ROLES.get(block.level, HEADING_ROLE_DEEPER)
				heading.text = block.text
				_page.add_child(heading)
				_anchors[block.anchor] = heading
			"text", "table":
				var text: RichTextLabel = TEXT_SCENE.instantiate()
				text.text = block.bbcode
				text.meta_clicked.connect(_on_link)
				_page.add_child(text)
			"item":
				var item: HBoxContainer = ITEM_SCENE.instantiate()
				var indent: Control = item.get_node("Indent")
				indent.visible = block.depth > 0
				indent.custom_minimum_size.x = SUB_INDENT * block.depth
				(item.get_node("Marker") as Label).text = block.marker
				var body: RichTextLabel = item.get_node("Text")
				body.text = block.bbcode
				body.meta_clicked.connect(_on_link)
				_page.add_child(item)


## Fährt die Seite an eine Überschrift, "" an den Anfang, und holt das Kapitel in der Liste
## ins Bild. Erst nach dem Layout: vorher haben die umbrechenden Absätze noch keine Höhe.
func _scroll_to(anchor: String) -> void:
	var build := _build
	_page_scroll.scroll_vertical = 0
	if anchor != "" and not _anchors.has(anchor):
		push_warning("Handbuch: keine Überschrift %s in %s" % [anchor, _file])
		anchor = ""
	await get_tree().process_frame
	await get_tree().process_frame
	if build != _build or not is_inside_tree():
		return
	(%ChapterScroll as ScrollContainer).ensure_control_visible(_buttons[_file])
	if anchor != "":
		var target: Control = _anchors[anchor]
		_page_scroll.scroll_vertical = int(target.global_position.y - _page.global_position.y)


func _on_link(meta: Variant) -> void:
	var url := str(meta)
	var target := Handbook.resolve(url, _file)
	if target.is_empty():
		OS.shell_open(url)
	else:
		show_chapter(target.file, target.section)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed
			and not event.echo and (event as InputEventKey).keycode == KEY_F1):
		get_viewport().set_input_as_handled()
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed:
		var page := int(_page_scroll.size.y * PAGE_STEP)
		match key.keycode:
			KEY_PAGEDOWN:
				_page_scroll.scroll_vertical += page
			KEY_PAGEUP:
				_page_scroll.scroll_vertical -= page
			KEY_HOME:
				_page_scroll.scroll_vertical = 0
			KEY_END:
				_page_scroll.scroll_vertical = int(_page.size.y)
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
