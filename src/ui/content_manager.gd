extends Control
## Inhalte-Verwaltung: zeigt die verfügbaren Content-Packs, ihren Zustand und holt sie.
## Öffnet als Fenster über dem Hauptmenü; eine Zeile je Pack aus content_pack_row.tscn.

const PROFILE_SCENE := "res://scenes/ui/profile_menu.tscn"
## Einblenden des Fensters (s).
const FADE_IN := 0.15

## Das Fenster will zu; der Öffnende nimmt es weg. Ohne Verbindung geht es ins Startmenü.
signal closed()

## Vorlage einer Pack-Zeile.
@export var row_template: PackedScene
## Vorlage einer Zeile je Teil des Sprachmodells.
@export var part_template: PackedScene

@onready var _packs: VBoxContainer = %Packs
@onready var _status: Label = %Status
@onready var _install: Button = %InstallButton
@onready var _adopt: Button = %AdoptButton
@onready var _refresh: Button = %RefreshButton
@onready var _model_panel: Control = %Model
@onready var _model_button: Button = %ModelButton
@onready var _model_remove: Button = %ModelRemoveButton
@onready var _model_hint: Label = %ModelHint
@onready var _model_progress: ProgressBar = %ModelProgress
@onready var _model_parts: VBoxContainer = %ModelParts

## Auswahl je Pack, damit sie einen Neuaufbau der Liste übersteht.
var _selected: Dictionary = {}
## Erst nach dem ersten Verzeichnis vorbelegen — danach entscheidet der Nutzer.
var _preselected := false


func _ready() -> void:
	(%CloseButton as BaseButton).pressed.connect(close)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")
	_refresh.pressed.connect(func(): ContentService.refresh(true))
	_install.pressed.connect(_on_install)
	_adopt.pressed.connect(func(): ContentService.install_many(ContentService.needs_adopt, true))
	_model_button.pressed.connect(func(): ModelService.install())
	_model_remove.pressed.connect(func(): ModelService.remove())
	ContentService.changed.connect(_render)
	ModelService.changed.connect(_render_model)
	_render()
	_render_model()
	if ContentService.packs.is_empty():
		ContentService.refresh(true)
	if not ModelService.available():
		ModelService.refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)
	_refresh.grab_focus.call_deferred()


func close() -> void:
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file(PROFILE_SCENE)
		return
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_install() -> void:
	var ids: Array = []
	for id in _selected:
		if bool(_selected[id]):
			ids.append(id)
	if not ids.is_empty():
		ContentService.install_many(ids)


## Baut die Liste neu, Zeile für Zeile aus der Vorlage.
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
			# Was Aufmerksamkeit verlangt, ist vorgewählt, auch „Inhalt veraltet“.
			_selected[pack.id] = pack.wants_attention() \
				or pack.install == PackStatus.Install.AVAILABLE

	for child in _packs.get_children():
		child.queue_free()
	for pack in ContentService.packs:
		# Die alten Zeilen sind erst am Frame-Ende weg — gezählt wird deshalb die Liste.
		if pack != ContentService.packs[0]:
			var rule := HSeparator.new()
			rule.theme_type_variation = &"StatRule"
			_packs.add_child(rule)
		var row := row_template.instantiate()
		_packs.add_child(row)
		row.setup(pack, bool(_selected.get(pack.id, false)))
		row.selection_changed.connect(_on_row_selection.bind(row))
		row.redeem_requested.connect(func(code): ContentService.redeem(code))
		row.forget_requested.connect(ContentService.forget_code.bind(pack.id))

	_install.visible = not ContentService.packs.is_empty()


func _on_row_selection(row: Node) -> void:
	_selected[row.pack_id] = row.selected()


func _status_text() -> String:
	match ContentService.state:
		ContentService.State.LOADING:
			return "Verzeichnis wird geholt …"
		ContentService.State.WORKING:
			return ContentService.activity
		ContentService.State.ERROR:
			# Offline ist der Normalfall; die Meldung sagt, was trotzdem geht.
			return "%s Installierte Inhalte bleiben nutzbar." % ContentService.error
		_:
			return ContentService.message


## Der Zusatz für Bosskämpfe, ein Programm statt eines Packs (ADR 0004, Nachtrag „Stufe 1
## auf eigenen Beinen“).
func _render_model() -> void:
	var busy := ModelService.busy()
	var installed := ModelService.installed()
	var size := ModelService.humanized(ModelService.total_bytes())

	# Gibt es nichts anzubieten und liegt nichts da, ist der ganze Abschnitt weg.
	_model_panel.visible = busy or installed or ModelService.available() \
			or not ModelService.error.is_empty()
	if not _model_panel.visible:
		return

	_model_progress.visible = busy
	_model_progress.value = ModelService.progress
	_render_parts(busy or (not installed and ModelService.available()))
	_model_button.visible = not installed
	_model_button.disabled = busy or not ModelService.available()
	_model_remove.visible = installed and not busy

	if busy:
		_model_hint.text = "%s  (%d %%)" % [ModelService.activity, int(ModelService.progress * 100.0)]
	elif installed:
		_model_hint.text = "Einsatzbereit. Bei Sätzen, die der Schlüssel nicht kennt, " \
				+ "fragt das Spiel jetzt ein Modell auf DIESEM Rechner — nichts geht ins Netz."
	elif not ModelService.error.is_empty():
		_model_hint.text = ModelService.error
	else:
		_model_hint.text = "Optional. Erkennt bei Bosskämpfen auch richtige Sätze, die " \
				+ "so nicht hinterlegt sind. Läuft danach nur auf diesem Rechner, ohne " \
				+ "Netz. Einmalig %s." % size
	_model_hint.visible = not _model_hint.text.is_empty()

	Hints.attach(_model_button, ModelService.display_name(),
			"Lädt Programm und Sprachmodell hierher — einmalig %s." % size,
			"Ohne den Zusatz zeigt das Spiel bei unbekannten Formulierungen die "
			+ "Musterlösung, statt sie als falsch zu werten.")
	Hints.attach(_model_remove, "Sprachmodell entfernen",
			"Gibt %s wieder frei." % size,
			"Bosskämpfe laufen weiter — nur ohne die zweite Meinung.")


## Eine Zeile je Teil, angelegt, sobald das Manifest da ist, danach nur umbeschriftet.
func _render_parts(show: bool) -> void:
	var count := ModelService.parts().size()
	if _model_parts.get_child_count() != count:
		for child in _model_parts.get_children():
			_model_parts.remove_child(child)
			child.queue_free()
		for i in count:
			_model_parts.add_child(part_template.instantiate())
	for i in count:
		(_model_parts.get_child(i) as Label).text = ModelService.part_line(i)
	_model_parts.visible = show and count > 0
