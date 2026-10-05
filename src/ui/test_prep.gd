class_name TestPrep
extends Control
## „Für eine Arbeit üben": Wörter eines Buchs auswählen, als Liste speichern und spielen.
##
## Ausgewählt werden Wörter, keine Aufgaben. Form-Boni (ADR 0012) stehen als eigene Zeile in
## der Tabelle: ihre Formen kommen nur mit, wenn die Zeile markiert ist. Gespielt wird die
## Liste über RunRequest.start_test; welches Wort wann dran ist, entscheidet TestPlaylist.
##
## Die Tabelle ist ein `Tree` als flache Liste: Filter blenden Zeilen aus, ein Klick auf eine
## Spaltenüberschrift sortiert. Layout in test_prep.tscn, hier wird nur befüllt.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

enum Col { MARK, FOREIGN, GERMAN, PLACE, TYPE, STATE }

const STATE_ALL := 0
const STATE_NEW := 1
const STATE_UNSURE := 2
const STATE_MASTERED := 3

## Die zuletzt offene Liste — der Rückweg aus dem Kampf öffnet sie wieder.
static var open_id := ""

@onready var _tree: Tree = %Words
@onready var _list_pick: OptionButton = %ListPick
@onready var _name_edit: LineEdit = %NameEdit
@onready var _search: LineEdit = %Search
@onready var _places: CheckTreeDrop = %PlaceDrop
@onready var _places_button: Button = %PlacesButton
@onready var _type_pick: CheckMenu = %TypePick
@onready var _state_pick: CheckMenu = %StatePick
@onready var _only_marked: CheckBox = %OnlyMarked
@onready var _count: Label = %Count
@onready var _direction_pick: OptionButton = %DirectionPick
@onready var _play: Button = %PlayButton
@onready var _confirm: ConfirmDialog = %Confirm

var _book := ""
var _list: Dictionary = {}
## Alle Zeilen des Buchs: { kind ("word" | "bonus"), id, unit, place, place_label, type,
## foreign, german, order, state, state_label, item }.
var _rows: Array = []
var _marked: Dictionary = {}
var _sort_col := -1
var _sort_desc := false
var _saved_lists: Array = []
var _generator := WaveGenerator.new()
## Stand der Runde der gespeicherten Liste (beim Öffnen gerechnet), leer ohne Runde.
var _round_label := ""


func _ready() -> void:
	_book = MapSelection.book
	var books := ContentRegistry.all_books()
	if not _book in books and not books.is_empty():
		_book = books[0]
	(%BackButton as Button).pressed.connect(_back)
	(%SaveButton as Button).pressed.connect(_save)
	(%DeleteButton as Button).pressed.connect(_ask_delete)
	(%MarkVisible as Button).pressed.connect(_mark_visible.bind(true))
	(%UnmarkVisible as Button).pressed.connect(_mark_visible.bind(false))
	(%RoundButton as Button).pressed.connect(_new_round)
	_play.pressed.connect(_start)
	_confirm.confirmed.connect(_delete)
	_list_pick.item_selected.connect(_on_list_picked)
	_search.text_changed.connect(func(_t): _apply_filter())
	_places_button.pressed.connect(_places.open_below.bind(_places_button))
	_places.changed.connect(_apply_filter)
	for pick: CheckMenu in [_type_pick, _state_pick]:
		pick.changed.connect(_apply_filter)
	_only_marked.toggled.connect(func(_on): _apply_filter())
	_direction_pick.item_selected.connect(func(_i): _update_count())
	_tree.item_edited.connect(_on_item_edited)
	_tree.item_activated.connect(_on_item_activated)
	_tree.column_title_clicked.connect(_on_title_clicked)
	_tree.gui_input.connect(_on_tree_input)
	Hints.attach(%RoundButton, "Neue Runde",
			"Alle Wörter der Liste kommen wieder in den Beutel.",
			"Sonst geht die Runde weiter, wo sie aufgehört hat — auch über mehrere Tage.")
	Hints.attach(_direction_pick, "Richtung", "Welche Aufgaben die Liste abfragt.")
	Hints.attach(_state_pick, "Stand", "Nach dem Lernstand der Wörter filtern.")
	Hints.attach(_count, "Auswahl", "Markierte Wörter und Form-Boni; mit gespeicherter Liste "
			+ "dazu, wie viele Wörter in der laufenden Runde schon richtig waren.")
	_title_text()
	_setup_tree()
	_build_rows()
	_fill_filters()
	_fill_direction_pick()
	_load_lists(open_id)
	_search.grab_focus()


func _title_text() -> void:
	(%Title as Label).text = "Für eine Arbeit üben · %s" % ContentRegistry.book_label(_book)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _confirm.visible and not _places.visible:
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	get_tree().change_scene_to_file(MapSelection.BOOK_SCENE)


# --- Tabelle ---------------------------------------------------------------------------

func _setup_tree() -> void:
	var lang := Lexeme.language_name(ContentRegistry.book_language(_book))
	var titles := ["✓", lang, "Deutsch", "Wo", "Wortart", "Stand"]
	for i in titles.size():
		_tree.set_column_title(i, titles[i])
		_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	_tree.set_column_expand(Col.MARK, false)
	_tree.set_column_custom_minimum_width(Col.MARK, 40)
	_tree.set_column_expand_ratio(Col.FOREIGN, 3)
	_tree.set_column_expand_ratio(Col.GERMAN, 3)
	_tree.set_column_expand_ratio(Col.PLACE, 2)
	_tree.set_column_expand_ratio(Col.TYPE, 1)
	_tree.set_column_expand_ratio(Col.STATE, 1)


## Liest das Buch einmal: je Wort und je Form-Bonus eine Zeile.
func _build_rows() -> void:
	_rows.clear()
	var mastered := PlayerProgress.mastered_lexemes()
	var layout := MapLayout.data(_book)
	var order := 0
	for id in ContentRegistry.lexemes:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		if str(entry.get("book", "")) != _book or not entry.has("unit"):
			continue
		var unit := int(entry["unit"])
		var place := ""
		var place_label := ""
		var topic := Lexeme.bonus(entry)
		var bonus_order := 0
		if not topic.is_empty():
			var key := ContentRegistry.word_bonus_key(entry)
			var bonus: Dictionary = ContentRegistry.bonuses().get(key, {})
			place = key
			place_label = BonusLevel.title(bonus, layout) if not bonus.is_empty() else "Bonus"
			bonus_order = 1
		else:
			var part := ContentRegistry.part_of(str(id))
			place = "%d/part/%d" % [unit, part]
			# Wörter vor dem ersten Teil (aplus: der Auftakt eines Dossiers) haben keinen.
			place_label = BookNaming.part_label(_book, unit, part) if part > 0 \
					else "Vor %s" % BookNaming.part_label(_book, unit, 1)
		order += 1
		var row := {
			"kind": "word", "id": str(id), "unit": unit, "place": place,
			"place_label": "%s · %s" % [BookNaming.unit_label(_book, unit), place_label],
			"type": str(entry.get("type", "")), "foreign": Lexeme.foreign(entry),
			"german": str(entry.get("lemma_de", "")),
			"order": [unit, bonus_order, ContentRegistry.part_of(str(id)), order],
		}
		_word_state(row, entry, mastered)
		_rows.append(row)
	for unit in ContentRegistry.units_for(_book):
		for bonus in ContentRegistry.bonuses_of(_book, int(unit)):
			if int(bonus["part"]) <= 0:
				continue # Wort-Boni sind echte Wörter und stehen oben als Zeilen
			var counted := BonusLevel.counts(bonus, PlayerProgress.is_mastered)
			var title := BonusLevel.title(bonus, layout)
			order += 1
			_rows.append({
				"kind": "bonus", "id": str(bonus["key"]), "unit": int(unit),
				"place": str(bonus["key"]),
				"place_label": "%s · %s" % [BookNaming.unit_label(_book, int(unit)), title],
				"type": "", "foreign": "★ " + title,
				"german": "%d Formen" % (bonus.get("task_ids", []) as Array).size(),
				"order": [int(unit), 2, int(bonus["part"]), order],
				"state": STATE_MASTERED if BonusLevel.share(counted) >= 1.0 else STATE_UNSURE,
				"state_label": "%d / %d" % [int(counted["done"]), int(counted["total"])],
				"confidence": BonusLevel.share(counted),
			})


## Stand eines Wortes: gemeistert, neu (nie beantwortet) oder unsicher mit der mittleren
## Confidence seiner Übersetzungen.
func _word_state(row: Dictionary, entry: Dictionary, mastered: Dictionary) -> void:
	if mastered.has(row["id"]):
		row["state"] = STATE_MASTERED
		row["state_label"] = "✓ gemeistert"
		row["confidence"] = 1.0
		return
	var seen := 0
	var sum := 0.0
	for learnable in _generator.learnables_of(entry):
		if PlayerProgress.has_seen(learnable):
			seen += 1
			sum += PlayerProgress.confidence(learnable)
	if seen == 0:
		row["state"] = STATE_NEW
		row["state_label"] = "neu"
		row["confidence"] = -1.0
	else:
		row["state"] = STATE_UNSURE
		row["confidence"] = sum / seen
		row["state_label"] = "%d %%" % roundi(100.0 * sum / seen)


## Baut die Zeilen des Trees in der aktuellen Sortierung neu auf.
func _rebuild_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	for row in _sorted_rows():
		var item := _tree.create_item(root)
		item.set_cell_mode(Col.MARK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(Col.MARK, true)
		item.set_checked(Col.MARK, _marked.has(row["id"]))
		item.set_text(Col.FOREIGN, str(row["foreign"]))
		item.set_text(Col.GERMAN, str(row["german"]))
		item.set_text(Col.PLACE, str(row["place_label"]))
		item.set_text(Col.TYPE, str(WordTypePalette.LABELS.get(row["type"], row["type"])))
		item.set_text(Col.STATE, str(row["state_label"]))
		item.set_metadata(Col.MARK, row)
		row["item"] = item
	_apply_filter()


func _sorted_rows() -> Array:
	var rows := _rows.duplicate()
	var key := func(row: Dictionary) -> Variant:
		match _sort_col:
			Col.FOREIGN: return str(row["foreign"]).to_lower()
			Col.GERMAN: return _without_article(str(row["german"])).to_lower()
			Col.TYPE: return str(row["type"])
			Col.STATE: return float(row.get("confidence", -1.0))
			Col.MARK: return 0 if _marked.has(row["id"]) else 1
		return 0
	rows.sort_custom(func(a, b):
		if _sort_col >= 0:
			var ka: Variant = key.call(a)
			var kb: Variant = key.call(b)
			if ka != kb:
				return (ka > kb) if _sort_desc else (ka < kb)
		return _order_less(a["order"], b["order"]))
	return rows


static func _order_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


static func _without_article(text: String) -> String:
	for article in ["der ", "die ", "das ", "sich "]:
		if text.begins_with(article):
			return text.substr(article.length())
	return text


func _on_title_clicked(column: int, _mouse_button: int) -> void:
	if column == Col.PLACE:
		_sort_col = -1 # „Wo" ist die Buchreihenfolge
		_sort_desc = false
	elif _sort_col == column:
		_sort_desc = not _sort_desc
	else:
		_sort_col = column
		_sort_desc = false
	_rebuild_tree()


# --- Filter ----------------------------------------------------------------------------

func _fill_filters() -> void:
	_fill_places()
	var types: Array = []
	for row in _rows:
		if not str(row["type"]).is_empty() and not row["type"] in types:
			types.append(row["type"])
	_type_pick.set_options(types.map(func(type):
		return {"text": str(WordTypePalette.LABELS.get(type, type)), "value": str(type)}))
	_state_pick.set_options([
		{"text": "neu", "value": STATE_NEW},
		{"text": "unsicher", "value": STATE_UNSURE},
		{"text": "gemeistert", "value": STATE_MASTERED},
	])


## Der Baum Unit → Teile und Boni, in Buchreihenfolge.
func _fill_places() -> void:
	var rows := _rows.duplicate()
	rows.sort_custom(func(a, b): return _order_less(a["order"], b["order"]))
	var groups: Array = []
	var by_unit := {}
	var seen := {}
	for row in rows:
		var unit := int(row["unit"])
		if not by_unit.has(unit):
			by_unit[unit] = {"text": BookNaming.unit_label(_book, unit), "children": []}
			groups.append(by_unit[unit])
		if seen.has(row["place"]):
			continue
		seen[row["place"]] = true
		by_unit[unit]["children"].append({"text": str(row["place_label"]).get_slice(" · ", 1),
				"value": str(row["place"])})
	_places.set_groups(groups)
	_places_button.text = _places.summary("Units, Teile") + " ▾"


func _apply_filter() -> void:
	var needle := _search.text.strip_edges().to_lower()
	var places := _places.values()
	_places_button.text = _places.summary("Units, Teile") + " ▾"
	var types := _type_pick.values()
	var states := _state_pick.values()
	for row in _rows:
		var item: TreeItem = row.get("item")
		if item == null:
			continue
		var show := true
		if not places.is_empty() and not str(row["place"]) in places:
			show = false
		elif not types.is_empty() and not str(row["type"]) in types:
			show = false
		elif not states.is_empty() and not int(row["state"]) in states:
			show = false
		elif _only_marked.button_pressed and not _marked.has(row["id"]):
			show = false
		elif not needle.is_empty() and not (str(row["foreign"]).to_lower().contains(needle) \
				or str(row["german"]).to_lower().contains(needle)):
			show = false
		item.visible = show
	_update_count()


# --- Markieren -------------------------------------------------------------------------

func _set_mark(row: Dictionary, on: bool) -> void:
	if on:
		_marked[row["id"]] = row["kind"]
	else:
		_marked.erase(row["id"])
	var item: TreeItem = row.get("item")
	if item != null:
		item.set_checked(Col.MARK, on)


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	_set_mark(item.get_metadata(Col.MARK), item.is_checked(Col.MARK))
	_update_count()


func _on_item_activated() -> void:
	_toggle_selected()


## Leertaste kreuzt die gewählte Zeile an oder ab — markiert wird ohne Maus.
func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_SPACE:
		_tree.accept_event()
		_toggle_selected()


func _toggle_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var row: Dictionary = item.get_metadata(Col.MARK)
	_set_mark(row, not _marked.has(row["id"]))
	_update_count()


func _mark_visible(on: bool) -> void:
	for row in _rows:
		var item: TreeItem = row.get("item")
		if item != null and item.visible:
			_set_mark(row, on)
	_update_count()


func _update_count() -> void:
	var words := 0
	var bonuses := 0
	for id in _marked:
		if str(_marked[id]) == "bonus":
			bonuses += 1
		else:
			words += 1
	var text := "%d %s" % [words, "Wort" if words == 1 else "Wörter"]
	if bonuses > 0:
		text += " · %d Bonus" % bonuses if bonuses == 1 else " · %d Boni" % bonuses
	var missing := _missing_ids().size()
	if missing > 0:
		text += " · %d fehlen" % missing
	var round := _round_text()
	if not round.is_empty():
		text += " · " + round
	_count.text = text
	_play.disabled = words == 0 and bonuses == 0
	Hints.attach(_play, "Spielen",
			"Jedes Wort kommt einmal, dann erst wieder — wie eine Zufalls-Playlist."
			if not _play.disabled else "Erst Wörter markieren.",
			"Ein Fehler legt das Wort zurück in den Beutel.")


## Ids der gespeicherten Liste, die der Inhalt nicht mehr kennt.
func _missing_ids() -> Array:
	return Array(_list.get("lexeme_ids", [])).filter(func(id):
		return not ContentRegistry.lexemes.has(str(id)))


## Wie weit die laufende Runde der gespeicherten Liste ist — nur, solange die Auswahl
## nicht verändert wurde.
func _round_text() -> String:
	if _round_label.is_empty():
		return ""
	var list := _current_list()
	if list["lexeme_ids"] != _list.get("lexeme_ids", []) \
			or list["form_bonuses"] != _list.get("form_bonuses", []) \
			or list["direction"] != _list.get("direction", ""):
		return ""
	return _round_label


func _count_round() -> void:
	_round_label = ""
	if str(_list.get("id", "")).is_empty() or int(_list.get("round_started_at", 0)) <= 0:
		return
	var words := _words_of(_list)
	var open := TestPlaylist.unplayed(words, PlayerProgress.last_seen_at,
			PlayerProgress.last_correct, int(_list["round_started_at"]))
	_round_label = "Runde %d/%d" % [words.size() - open.size(), words.size()]


## Grundwort -> learnable_ids, wie der Kampf sie für die Liste spielt.
func _words_of(list: Dictionary) -> Dictionary:
	var pool := {
		"task_types": [], "lexeme_types": [], "tags": [],
		"scope": TestLists.run_scope(list, ContentRegistry.lexemes, ContentRegistry.narrowest_scope),
		"lexeme_ids": list["lexeme_ids"], "direction_mode": list["direction"],
	}
	var words := {}
	for c in _generator.candidates(pool):
		var source := str(c["source"].get("id", ""))
		if not words.has(source):
			words[source] = []
		words[source].append(c["learnable_id"])
	return words


# --- Listen ----------------------------------------------------------------------------

func _fill_direction_pick() -> void:
	var lang := Lexeme.language_name(ContentRegistry.book_language(_book))
	_direction_pick.clear()
	_direction_pick.add_item("Alle Aufgaben")
	_direction_pick.set_item_metadata(0, TestLists.DIRECTION_ALL)
	_direction_pick.add_item("Deutsch → %s" % lang)
	_direction_pick.set_item_metadata(1, TestLists.DIRECTION_FROM_DE)
	_direction_pick.add_item("%s → Deutsch" % lang)
	_direction_pick.set_item_metadata(2, TestLists.DIRECTION_TO_DE)


func _load_lists(select_id: String) -> void:
	_saved_lists = TestLists.lists_of(_book, UserSettings.active_profile())
	_list_pick.clear()
	_list_pick.add_item("＋ Neue Liste")
	var index := 0
	for i in _saved_lists.size():
		_list_pick.add_item(str(_saved_lists[i].get("name", "Liste")))
		if str(_saved_lists[i].get("id", "")) == select_id:
			index = i + 1
	_list_pick.select(index)
	_open(_saved_lists[index - 1] if index > 0 else TestLists.blank(_book))


func _on_list_picked(index: int) -> void:
	_open(_saved_lists[index - 1] if index > 0 else TestLists.blank(_book))


func _open(list: Dictionary) -> void:
	_list = list
	open_id = str(list.get("id", ""))
	_name_edit.text = str(list.get("name", ""))
	_marked.clear()
	for id in list.get("lexeme_ids", []):
		if ContentRegistry.lexemes.has(str(id)):
			_marked[str(id)] = "word"
	for key in list.get("form_bonuses", []):
		_marked[str(key)] = "bonus"
	for i in _direction_pick.item_count:
		if str(_direction_pick.get_item_metadata(i)) == str(list.get("direction", "")):
			_direction_pick.select(i)
	(%DeleteButton as Button).disabled = open_id.is_empty()
	(%RoundButton as Button).disabled = open_id.is_empty()
	_count_round()
	_rebuild_tree()


## Die Auswahl im Screen als Liste (noch nicht gespeichert).
func _current_list() -> Dictionary:
	var list := _list.duplicate(true)
	var words: Array = []
	var bonuses: Array = []
	# In Buchreihenfolge, damit die Datei lesbar bleibt.
	var rows := _rows.filter(func(r): return _marked.has(r["id"]))
	rows.sort_custom(func(a, b): return _order_less(a["order"], b["order"]))
	for row in rows:
		(bonuses if row["kind"] == "bonus" else words).append(str(row["id"]))
	list["lexeme_ids"] = words
	list["form_bonuses"] = bonuses
	list["direction"] = str(_direction_pick.get_item_metadata(maxi(0, _direction_pick.selected)))
	var name := _name_edit.text.strip_edges()
	if name.is_empty():
		name = "Arbeit vom %s" % Time.get_date_string_from_system().right(5)
	list["name"] = name
	list["book"] = _book
	return list


func _save() -> Dictionary:
	var list := TestLists.store(_current_list(), UserSettings.active_profile())
	_load_lists(str(list["id"]))
	return list


func _ask_delete() -> void:
	if open_id.is_empty():
		return
	_confirm.ask("Liste löschen?", "„%s" % str(_list.get("name", "")) + "“ wird gelöscht. "
			+ "Der Lernstand der Wörter bleibt.", "Löschen")


func _delete() -> void:
	TestLists.remove(open_id, UserSettings.active_profile())
	_load_lists("")


func _new_round() -> void:
	if open_id.is_empty():
		return
	_list["round_started_at"] = 0
	TestLists.store(_list, UserSettings.active_profile())
	_round_label = ""
	_update_count()


func _start() -> void:
	if _play.disabled:
		return
	var list := _save()
	RunRequest.start_test(list)
	get_tree().change_scene_to_file(BATTLE_SCENE)
