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
## Eine ENGE Auswahl kann dagegen leer ausgehen (die Filter kombinieren sich mit UND).
## Dann sperrt "Kampf starten" — siehe _refresh_start_gate().
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
@onready var _start_button: Button = %StartButton
@onready var _start_hint: Label = %StartHint

var _all_tags: PackedStringArray = PackedStringArray()
var _selected_tags: Array = []
## Je Unit ein {"key", "check", "parts"} — die Auswahl wird daraus gelesen und nicht
## aus dem Knotenbaum, weil die Teile in einer eigenen Zeile unter der Unit hängen.
var _scope_rows: Array = []
## Nur für die Verfügbarkeitsprüfung (has_playable) — der Kampf hat seinen eigenen.
var _generator := WaveGenerator.new()


func _ready() -> void:
	_start_button.pressed.connect(func(): get_tree().change_scene_to_file(BATTLE_SCENE))
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_build_scope()
	_build_task_types()
	_build_lexeme_types()
	_build_tags()
	# Alle Filterbereiche als aufklappbare Panels, standardmäßig zugeklappt.
	_setup_section(%ScopeHeader, _scope_list, "Bücher & Units")
	_setup_section(%TaskTypeHeader, _task_type_list, "Aufgabentypen")
	_setup_section(%LexemeTypeHeader, _lexeme_type_list, "Vokabel-Typen")
	_refresh_start_gate()


## Sperrt „Kampf starten", solange die Auswahl keine spielbare Aufgabe übrig lässt.
## Die Filter kombinieren sich (UND) und können sich gegenseitig ausschließen — dann
## fände der WaveRunner nichts zu spawnen, die Welle endete nie und das Schlachtfeld
## wäre leer. Lieber hier sagen, dass die Auswahl zu eng ist, als dort.
## Läuft nach jeder Änderung, weil jeder Filter das Ergebnis kippen kann.
func _refresh_start_gate() -> void:
	var pool := WaveGenerator.pool_from_settings(UserSettings.default_difficulty())
	var playable := _generator.has_playable(pool)
	_start_button.disabled = not playable
	_start_hint.visible = not playable


## Macht `header` zum Auf-/Zuklapp-Schalter für `content` (Pfeil ▸/▾), zugeklappt.
func _setup_section(header: Button, content: Control, title: String) -> void:
	header.focus_mode = Control.FOCUS_NONE
	content.visible = false
	header.text = "▸ " + title
	header.pressed.connect(func():
		content.visible = not content.visible
		header.text = ("▾ " if content.visible else "▸ ") + title
	)


# --- Curriculum-Scope: Bücher ▸ Units ▸ Teile (hierarchisch) --------------------

## Baut pro Buch eine Überschrift und darunter je Unit eine aufklappbare Zeile. Anders als
## die übrigen Filter starten die Checkboxen LEER: leere Scope-Auswahl = keine Einschränkung
## (auch Lexeme ohne Buch/Unit bleiben spielbar).
func _build_scope() -> void:
	var selected := UserSettings.selected_scope()
	for book in ContentRegistry.all_books():
		var label := Label.new()
		label.text = ContentRegistry.book_label(book)
		_scope_list.add_child(label)
		for unit in ContentRegistry.units_for(book):
			_add_unit_row(book, unit, selected)


## Eine Unit-Zeile: Checkbox für die ganze Unit ("<book>/<unit>") und, dahinter aufklappbar,
## die Teile ("<book>/<unit>/<teil>"). Die Teile sind positionsbasiert — Teil 1 sind die
## ersten Vokabeln der Unit, also die ersten Seiten (ContentRegistry._index_parts).
##
## Die beiden Ebenen hängen zusammen: Unit an hakt alle Teile an, alle Teile an hakt die
## Unit an. So bleibt die gespeicherte Auswahl immer die kürzeste, die dasselbe meint —
## und ein abgehakter Teil ist sichtbar ein abgehakter Teil, keine stille Ausnahme unter
## einer angehakten Unit.
func _add_unit_row(book: String, unit: int, selected: PackedStringArray) -> void:
	var unit_key := "%s/%d" % [book, unit]
	# book-Schlüssel (ganzes Buch) im Scope hakt alle seine Units mit an.
	var unit_on := unit_key in selected or book in selected

	var row := HBoxContainer.new()
	_scope_list.add_child(row)
	var check := CheckBox.new()
	check.text = "Unit %d" % unit
	check.focus_mode = Control.FOCUS_NONE
	check.set_meta("value", unit_key)
	row.add_child(check)

	# Eine Unit mit nur einem Teil hat nichts aufzuklappen — ihr Teil IST die Unit.
	var parts: Array[CheckBox] = []
	var part_row: HBoxContainer = null
	if ContentRegistry.parts_for(book, unit) > 1:
		part_row = HBoxContainer.new()
		part_row.visible = false
		_scope_list.add_child(part_row)
		# Einrückung: Abstand ist Knoten-Sache (das Theme kennt nur Container-Abstände).
		var indent := Control.new()
		indent.custom_minimum_size.x = 24
		part_row.add_child(indent)
		for part in range(1, ContentRegistry.parts_for(book, unit) + 1):
			var part_key := "%s/%d" % [unit_key, part]
			var part_check := CheckBox.new()
			part_check.text = str(part)
			part_check.focus_mode = Control.FOCUS_NONE
			part_check.set_meta("value", part_key)
			part_check.set_pressed_no_signal(unit_on or part_key in selected)
			part_row.add_child(part_check)
			parts.append(part_check)

	check.set_pressed_no_signal(unit_on or _all_checked(parts))
	check.toggled.connect(func(pressed: bool):
		for part_check in parts:
			part_check.set_pressed_no_signal(pressed)
		_save_scope()
	)
	for part_check in parts:
		part_check.toggled.connect(func(_pressed: bool):
			check.set_pressed_no_signal(_all_checked(parts))
			_save_scope()
		)

	_scope_rows.append({"key": unit_key, "check": check, "parts": parts})

	if part_row == null:
		return
	var toggle := Button.new()
	toggle.text = "▸"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(func():
		part_row.visible = not part_row.visible
		toggle.text = "▾" if part_row.visible else "▸"
	)
	row.add_child(toggle)


func _all_checked(checks: Array[CheckBox]) -> bool:
	if checks.is_empty():
		return false
	for check in checks:
		if not check.button_pressed:
			return false
	return true


func _save_scope() -> void:
	UserSettings.set_selected_scope(_collect_scope())
	_refresh_start_gate()


## Sammelt die Auswahl aus den Unit-Zeilen — je Zeile den Unit-Schlüssel ODER die einzeln
## angehakten Teile, nie beides: der Unit-Schlüssel deckt seine Teile schon ab
## (ContentRegistry._scope_keys).
func _collect_scope() -> PackedStringArray:
	var result := PackedStringArray()
	for row in _scope_rows:
		if (row["check"] as CheckBox).button_pressed:
			result.append(str(row["key"]))
			continue
		for part_check in row["parts"]:
			if (part_check as CheckBox).button_pressed:
				result.append(str(part_check.get_meta("value")))
	return result


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


## Erzeugt eine CheckBox für eine Option. `value` (roher Tag/Typ) wird als
## Metadatum abgelegt, damit die Auswahl beim Speichern rekonstruierbar ist.
## CheckBox (echtes Kästchen [ ]/[x] vor dem Label), nicht CheckButton (Toggle nach dem Label).
func _add_check(container: Container, value: String, label: String, on: bool, save: Callable) -> void:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.set_meta("value", value)
	check.toggled.connect(func(_pressed: bool): save.call())
	container.add_child(check)


## Sammelt die aktuell aktiven Werte eines Checkbox-Containers.
func _collect(container: Container) -> PackedStringArray:
	var result := PackedStringArray()
	for child in container.get_children():
		if child is CheckBox and child.button_pressed:
			result.append(str(child.get_meta("value")))
	return result


func _save_task_types() -> void:
	UserSettings.set_selected_task_types(_collect(_task_type_list))
	_refresh_start_gate()


func _save_lexeme_types() -> void:
	UserSettings.set_selected_lexeme_types(_collect(_lexeme_type_list))
	_refresh_start_gate()


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
	_refresh_start_gate()
	_tag_input.clear()
	_clear_suggestions()


func _remove_tag(tag: String) -> void:
	_selected_tags.erase(tag)
	UserSettings.set_selected_tags(PackedStringArray(_selected_tags))
	_refresh_badges()
	_refresh_start_gate()


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
