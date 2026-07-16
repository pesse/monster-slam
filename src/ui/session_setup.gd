extends Control
## Session-Setup: vor dem Kampf wählen, welche Vokabeln geübt werden.
##
## "▶ Spielen" im Startmenü öffnet diesen Screen (statt direkt in den Kampf zu
## springen). Drei Filter, alle pro Profil in UserSettings persistiert und vom
## WaveRunner gelesen:
##   • Aufgabentypen (task_type)  — Checkboxen, standardmäßig alle aktiv
##   • Vokabel-Typen (Lexem-type) — Checkboxen, standardmäßig alle aktiv
##   • Tags (Themen)              — Eingabefeld mit Auto-Vervollständigung, Badges
##
## Semantik: eine LEERE Auswahl bedeutet KEINE Einschränkung (= alle). Deshalb
## starten Checkboxen ohne gespeicherte Auswahl komplett aktiv ("alle vorausgewählt")
## und der Kampf läuft auch bei leerer Auswahl sauber. Der Screen ist bewusst
## eigenständig, damit hier künftig weitere Session-Einstellungen Platz finden.
##
## Das statische Layout liegt in session_setup.tscn; hier nur die datengetriebenen
## Inhalte (Muster wie profile_menu._refresh_words()).

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## Hübschere deutsche Beschriftungen für Aufgabentypen (Wert bleibt der rohe Typ).
const TASK_TYPE_LABELS := {
	"translate": "Übersetzen",
	"opposite": "Gegenteil",
	"synonym": "Synonym",
	"confusables": "Verwechslungen",
	"conjugation": "Konjugation",
	"tense": "Zeitform",
}

## Wie viele Auto-Vervollständigungs-Vorschläge maximal angezeigt werden.
const MAX_SUGGESTIONS := 10

@onready var _scope_list: VBoxContainer = %ScopeList
@onready var _task_type_list: GridContainer = %TaskTypeList
@onready var _lexeme_type_list: GridContainer = %LexemeTypeList
@onready var _tag_input: LineEdit = %TagInput
@onready var _tag_suggestions: VBoxContainer = %TagSuggestions
@onready var _tag_badges: HFlowContainer = %TagBadges

var _all_tags: PackedStringArray = PackedStringArray()
var _selected_tags: Array = []


func _ready() -> void:
	(%StartButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(BATTLE_SCENE))
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_build_scope()
	_build_task_types()
	_build_lexeme_types()
	_build_tags()
	# Alle Filterbereiche als aufklappbare Panels, standardmäßig zugeklappt.
	_setup_section(%ScopeHeader, _scope_list, "Bücher & Units")
	_setup_section(%TaskTypeHeader, _task_type_list, "Aufgabentypen")
	_setup_section(%LexemeTypeHeader, _lexeme_type_list, "Vokabel-Typen")


## Macht `header` zum Auf-/Zuklapp-Schalter für `content` (Pfeil ▸/▾), zugeklappt.
func _setup_section(header: Button, content: Control, title: String) -> void:
	header.focus_mode = Control.FOCUS_NONE
	content.visible = false
	header.text = "▸ " + title
	header.pressed.connect(func():
		content.visible = not content.visible
		header.text = ("▾ " if content.visible else "▸ ") + title
	)


# --- Curriculum-Scope: Bücher ▸ Units (hierarchisch) ----------------------------

## Baut pro Buch eine Überschrift + ein Raster von Unit-Checkboxen. Anders als die übrigen
## Filter starten die Checkboxen LEER: leere Scope-Auswahl = keine Einschränkung (auch Lexeme
## ohne Buch/Unit bleiben spielbar). Wert je Checkbox: "<book>/<unit>".
func _build_scope() -> void:
	var selected := UserSettings.selected_scope()
	for book in ContentRegistry.all_books():
		var label := Label.new()
		label.text = _book_label(book)
		label.add_theme_font_size_override("font_size", 18)
		_scope_list.add_child(label)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 2)
		_scope_list.add_child(grid)
		for unit in ContentRegistry.units_for(book):
			var key := "%s/%d" % [book, unit]
			# book-Schlüssel (ganzes Buch) im Scope hakt alle seine Units mit an.
			var on := key in selected or book in selected
			_add_check(grid, key, "Unit %d" % unit, on, _save_scope)


func _save_scope() -> void:
	UserSettings.set_selected_scope(_collect_scope())


## Sammelt die aktiven Unit-Werte aus allen Buch-Rastern unter %ScopeList.
func _collect_scope() -> PackedStringArray:
	var result := PackedStringArray()
	for child in _scope_list.get_children():
		if child is GridContainer:
			result.append_array(_collect(child))
	return result


## "access2" -> "Access 2": nachgestellte Ziffern mit Leerzeichen abtrennen, Rest als Titel.
func _book_label(book: String) -> String:
	var i := book.length()
	while i > 0 and book[i - 1] >= "0" and book[i - 1] <= "9":
		i -= 1
	var name := book.substr(0, i).capitalize()
	var num := book.substr(i)
	return name if num.is_empty() else "%s %s" % [name, num]


func _build_task_types() -> void:
	var selected := UserSettings.selected_task_types()
	for task_type in ContentRegistry.all_task_types():
		var label := String(TASK_TYPE_LABELS.get(task_type, task_type))
		# Leere gespeicherte Auswahl = alle -> Checkbox vorausgewählt.
		var on := selected.is_empty() or task_type in selected
		_add_check(_task_type_list, task_type, label, on, _save_task_types)


func _build_lexeme_types() -> void:
	var selected := UserSettings.selected_lexeme_types()
	for lexeme_type in ContentRegistry.all_lexeme_types():
		var label := String(WordTypePalette.LABELS.get(lexeme_type, lexeme_type))
		var on := selected.is_empty() or lexeme_type in selected
		_add_check(_lexeme_type_list, lexeme_type, label, on, _save_lexeme_types)


## Erzeugt einen CheckButton für eine Option. `value` (roher Tag/Typ) wird als
## Metadatum abgelegt, damit die Auswahl beim Speichern rekonstruierbar ist.
func _add_check(container: Container, value: String, label: String, on: bool, save: Callable) -> void:
	var check := CheckButton.new()
	check.text = label
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # gleichmäßige Grid-Spalten
	check.set_meta("value", value)
	check.toggled.connect(func(_pressed: bool): save.call())
	container.add_child(check)


## Sammelt die aktuell aktiven Werte eines Checkbox-Containers.
func _collect(container: Container) -> PackedStringArray:
	var result := PackedStringArray()
	for child in container.get_children():
		if child is CheckButton and child.button_pressed:
			result.append(str(child.get_meta("value")))
	return result


func _save_task_types() -> void:
	UserSettings.set_selected_task_types(_collect(_task_type_list))


func _save_lexeme_types() -> void:
	UserSettings.set_selected_lexeme_types(_collect(_lexeme_type_list))


# --- Tags: Auto-Vervollständigung + Badges --------------------------------------

func _build_tags() -> void:
	_all_tags = ContentRegistry.all_lexeme_tags()
	_selected_tags = Array(UserSettings.selected_tags())
	_tag_input.text_changed.connect(_on_tag_input_changed)
	_tag_input.text_submitted.connect(_on_tag_submitted)
	_refresh_badges()
	_clear_suggestions()


## Fügt einen Tag hinzu (falls bekannt und noch nicht gewählt), leert das Eingabefeld.
func _add_tag(tag: String) -> void:
	if tag.is_empty() or tag in _selected_tags:
		return
	_selected_tags.append(tag)
	UserSettings.set_selected_tags(PackedStringArray(_selected_tags))
	_refresh_badges()
	_tag_input.clear()
	_clear_suggestions()


func _remove_tag(tag: String) -> void:
	_selected_tags.erase(tag)
	UserSettings.set_selected_tags(PackedStringArray(_selected_tags))
	_refresh_badges()


## Baut die Badge-Leiste der gewählten Tags neu auf (je Tag "tag ✕", Klick entfernt).
func _refresh_badges() -> void:
	for child in _tag_badges.get_children():
		child.queue_free()
	for tag in _selected_tags:
		var badge := Button.new()
		badge.text = "%s  ✕" % tag
		badge.focus_mode = Control.FOCUS_NONE
		badge.pressed.connect(_remove_tag.bind(tag))
		_tag_badges.add_child(badge)


func _on_tag_input_changed(text: String) -> void:
	var query := text.strip_edges().to_lower()
	_clear_suggestions()
	if query.is_empty():
		return
	var shown := 0
	for tag in _all_tags:
		if shown >= MAX_SUGGESTIONS:
			break
		if tag in _selected_tags:
			continue
		if tag.to_lower().contains(query):
			var btn := Button.new()
			btn.text = tag
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_add_tag.bind(tag))
			_tag_suggestions.add_child(btn)
			shown += 1


## Enter im Eingabefeld: exakten Treffer übernehmen, sonst den ersten Vorschlag.
func _on_tag_submitted(text: String) -> void:
	var query := text.strip_edges()
	if query.is_empty():
		return
	if query in _all_tags:
		_add_tag(query)
	elif _tag_suggestions.get_child_count() > 0:
		_add_tag((_tag_suggestions.get_child(0) as Button).text)


func _clear_suggestions() -> void:
	for child in _tag_suggestions.get_children():
		child.queue_free()
