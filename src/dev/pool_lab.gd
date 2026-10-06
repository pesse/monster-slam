extends Control
## Werkbank für die Auswahl der Wellenaufgaben (scenes/dev/pool_lab.tscn): welche
## Kandidaten ein Pool hergibt, in welcher Reihenfolge WaveGenerator.pick() sie probiert,
## und welche Wörter eine Welle damit bringen würde.
##
## Wozu: Die Auswahl hängt am Lernstand und an der Uhr (fällig nach 10 Minuten, nach
## Tagen …). Ob ein Wort zu oft oder zu selten kommt, sieht man im Kampf erst nach vielen
## Wellen — hier auf einen Blick, und mit „+10 min" / „+1 Tag" auch für später.
##
## Gelesen wird der Lernstand des aktiven Profils, aber nichts geschrieben: die Fälligkeit
## wird aus ihm gerechnet (ADR 0018), die Uhr verstellt nur die Bezugszeit, und die
## Simulation beantwortet keine Aufgabe. Die Reihenfolge würfelt wie im Spiel (gewichtet,
## WaveGenerator.selection_weight) — jedes Neuzeichnen würfelt neu.
##
## Starten: `tools/godot.sh res://scenes/dev/pool_lab.tscn` (zum Ansehen mit
## GODOT_WINDOW=1). `-- --shoot [--scope=<buch/unit>] [--days=<n>]` speichert ein Bild nach
## reports/ und beendet.
##
## Die Werkbank zeigt Wörter aus dem Submodule — Bilder davon bleiben lokal (reports/).

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const ROW_SCENE := preload("res://scenes/dev/pool_row.tscn")
const SHOT_DIR := "res://reports/pool_lab"
## So viele Kandidaten zeigt die linke Liste; dahinter stehen nur noch die Summen.
const MAX_ROWS := 150

var _gen := WaveGenerator.new()
var _scopes: Array = []
## Verstellung der Uhr gegenüber jetzt, in Sekunden.
var _offset := 0
var _room: Window

@onready var _scope_select: OptionButton = %ScopeSelect
@onready var _clock: Label = %Clock
@onready var _summary: Label = %Summary
@onready var _order_title: Label = %OrderTitle
@onready var _order_list: VBoxContainer = %OrderList
@onready var _sim_list: VBoxContainer = %SimList
@onready var _sim_count: SpinBox = %SimCount


func _ready() -> void:
	_room = get_window()
	LabRoom.enlarge(_room)
	_fill_scopes()
	_scope_select.item_selected.connect(func(_i: int) -> void: _refresh())
	(%Plus10Min as Button).pressed.connect(_shift.bind(600))
	(%Plus1Hour as Button).pressed.connect(_shift.bind(3600))
	(%Plus1Day as Button).pressed.connect(_shift.bind(86400))
	(%Now as Button).pressed.connect(func() -> void:
		_offset = 0
		_refresh())
	(%Simulate as Button).pressed.connect(_simulate)
	(%BackButton as Button).pressed.connect(_back)
	if not _arg("days").is_empty():
		_offset = int(_arg("days")) * 86400
	_refresh()
	if _has_arg("shoot"):
		_simulate()
		_shoot.call_deferred()


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## Jede Unit jedes Buchs, dazu das ganze Buch. Vorgewählt: `--scope=` oder die erste Unit.
func _fill_scopes() -> void:
	for book in ContentRegistry.all_books():
		_scopes.append(book)
		_scope_select.add_item("%s (ganzes Buch)" % ContentRegistry.book_label(book))
		for unit in ContentRegistry.units_for(book):
			_scopes.append("%s/%d" % [book, unit])
			_scope_select.add_item("%s · Unit %d" % [ContentRegistry.book_label(book), unit])
	var wanted := _arg("scope")
	var index := _scopes.find(wanted) if not wanted.is_empty() else mini(1, _scopes.size() - 1)
	if index >= 0:
		_scope_select.select(index)


## Der Pool eines Levels: der Scope, alle Aufgaben- und Wortarten (RunRequest.task_pool).
func _pool() -> Dictionary:
	var index := _scope_select.selected
	var scope: Array = [] if index < 0 else [_scopes[index]]
	return {"task_types": [], "lexeme_types": [], "scope": scope, "tags": []}


func _now() -> int:
	return int(Time.get_unix_time_from_system()) + _offset


func _shift(seconds: int) -> void:
	_offset += seconds
	_refresh()


func _refresh() -> void:
	_clock.text = "Uhr: " + Time.get_datetime_string_from_unix_time(
			_now() + PlayerProgress.utc_offset, true) + ("" if _offset == 0 else " (verstellt)")
	var listing := _gen.listing(_pool(), {}, _now())
	var counts := {"due": 0, "new": 0, "rest": 0}
	for c in listing:
		counts[str(c["group"])] += 1
	_summary.text = "%d Kandidaten · fällig %d · neu %d · Rest %d — gewählt wird von oben; gezogen nach Gewicht (Bedarf × Dringlichkeit), neue mindestens 30 %%." % [
			listing.size(), counts["due"], counts["new"], counts["rest"]]
	_order_title.text = "Reihenfolge der Kandidaten" + (
			" (erste %d)" % MAX_ROWS if listing.size() > MAX_ROWS else "")
	_clear(_order_list)
	for i in mini(listing.size(), MAX_ROWS):
		var c: Dictionary = listing[i]
		var id := str(c["learnable_id"])
		var info := "c %.2f" % PlayerProgress.confidence(id) if PlayerProgress.has_seen(id) else "nie gesehen"
		var due_at := int(c.get("due_at", 0))
		if due_at > 0:
			info += " · fällig " + WaveGenerator.due_text(due_at, _now())
		if int(c.get("last_seen", 0)) > 0:
			info += " · zuletzt vor " + WaveGenerator.span_text(_now() - int(c["last_seen"]))
		info += " · Gewicht %.2f" % float(c.get("weight", 0.0))
		_add_row(_order_list, "%d. %s" % [i + 1, _group_label(c)], _prompt(c),
				"%s · %s" % [info, id])
	_clear(_sim_list)


## Spielt `SimCount` Spawns einer Welle durch: jeder Pick sieht die vorherigen als schon
## gezeigt (wie WaveRunner._wave_shown), beantwortet wird nichts.
func _simulate() -> void:
	_clear(_sim_list)
	var shown := {}
	for i in int(_sim_count.value):
		var plan := _gen.pick_with(_gen.listing(_pool(), shown, _now()))
		if plan.is_empty():
			_add_row(_sim_list, "—", "nichts Spielbares", "")
			return
		var task: Dictionary = plan["task"]
		shown[str(task.get("source_id", ""))] = i
		_add_row(_sim_list, "%d." % (i + 1), str(task.get("prompt", "")),
				WaveGenerator.describe_reason(task.get("pick", {}), _now()))


func _group_label(c: Dictionary) -> String:
	var label := str(WaveGenerator.GROUP_LABELS.get(str(c["group"]), c["group"]))
	return ("↻ " + label) if bool(c.get("repeat", false)) else label


## Der Prompt, wie das Monster ihn zeigen würde — ohne die Aufgabe aufzulösen, die Liste
## wäre sonst bei großen Pools zäh: die Quelle reicht zum Wiedererkennen.
func _prompt(c: Dictionary) -> String:
	var source: Dictionary = c["source"]
	var task_type := str(c["definition"].get("task_type", ""))
	return "%s  (%s)" % [str(source.get("lemma_de", source.get("id", ""))), task_type]


func _add_row(list: VBoxContainer, group: String, prompt: String, info: String) -> void:
	var row := ROW_SCENE.instantiate()
	list.add_child(row)
	(row.get_node("%Group") as Label).text = group
	(row.get_node("%Prompt") as Label).text = prompt
	(row.get_node("%Info") as Label).text = info


func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _shoot() -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := "%s/pool_lab.png" % dir
	get_viewport().get_texture().get_image().save_png(file)
	print("pool_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
