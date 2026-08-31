extends Control
## Inhalte-Verwaltung: zeigt die verfügbaren Content-Packs, ihren Zustand und holt sie.
##
## Das Layout liegt in content_manager.tscn, eine Zeile in content_pack_row.tscn; hier wird
## nur bedient und angezeigt. Die Zeilen entstehen zur Laufzeit aus der Vorlage, weil ihre
## Anzahl aus dem Verzeichnis kommt.

const PROFILE_SCENE := "res://scenes/ui/profile_menu.tscn"

## Vorlage einer Pack-Zeile, im Editor gesetzt (siehe content_manager.tscn).
@export var row_template: PackedScene

@onready var _packs: VBoxContainer = %Packs
@onready var _status: Label = %Status
@onready var _install: Button = %InstallButton
@onready var _adopt: Button = %AdoptButton
@onready var _refresh: Button = %RefreshButton

## Auswahl je Pack, damit sie einen Neuaufbau der Liste übersteht.
var _selected: Dictionary = {}
## Erst nach dem ersten Verzeichnis vorbelegen — danach entscheidet der Nutzer.
var _preselected := false


func _ready() -> void:
	(%BackButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(PROFILE_SCENE)
	)
	_refresh.pressed.connect(func(): ContentService.refresh())
	_install.pressed.connect(_on_install)
	_adopt.pressed.connect(func(): ContentService.install_many(ContentService.needs_adopt, true))
	ContentService.changed.connect(_render)
	_render()
	if ContentService.packs.is_empty():
		ContentService.refresh()


func _on_install() -> void:
	var ids: Array = []
	for id in _selected:
		if bool(_selected[id]):
			ids.append(id)
	if not ids.is_empty():
		ContentService.install_many(ids)


## Baut die Liste neu. Zeilen werden verworfen und neu erzeugt, statt einzeln nachgeführt:
## die Liste ist kurz, und ein Zustandswechsel betrifft ohnehin fast jede Zeile.
func _render() -> void:
	var busy := ContentService.state in [ContentService.State.LOADING, ContentService.State.WORKING]
	_status.text = _status_text()
	_status.visible = not _status.text.is_empty()
	_refresh.disabled = busy
	_install.disabled = busy
	_adopt.visible = not busy and not ContentService.needs_adopt.is_empty()

	if not _preselected and not ContentService.packs.is_empty():
		_preselected = true
		for pack in ContentService.packs:
			# Was Aufmerksamkeit verlangt, ist vorgewählt — auch „Inhalt veraltet", obwohl
			# es als installiert gilt: sonst müsste der Nutzer erst verstehen, dass
			# Neuziehen die fehlende Mechanik nachliefert.
			_selected[pack.id] = pack.wants_attention() \
				or pack.install == PackStatus.Install.AVAILABLE

	for child in _packs.get_children():
		child.queue_free()
	for pack in ContentService.packs:
		var row := row_template.instantiate()
		_packs.add_child(row)
		row.setup(pack, bool(_selected.get(pack.id, false)))
		row.selection_changed.connect(_on_row_selection.bind(row))
		row.redeem_requested.connect(func(code): ContentService.redeem(code))
		row.forget_requested.connect(ContentService.forget_code.bind(pack.id))

	var count := _packs.get_child_count()
	_install.visible = count > 0


func _on_row_selection(row: Node) -> void:
	_selected[row.pack_id] = row.selected()


func _status_text() -> String:
	match ContentService.state:
		ContentService.State.LOADING:
			return "Verzeichnis wird geholt …"
		ContentService.State.WORKING:
			return ContentService.activity
		ContentService.State.ERROR:
			# Offline ist der Normalfall, nicht der Ausnahmefall — deshalb erklärt die
			# Meldung, was trotzdem funktioniert.
			return "%s Installierte Inhalte bleiben nutzbar." % ContentService.error
		_:
			return ContentService.message
