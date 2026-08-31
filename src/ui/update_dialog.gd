extends Control
## Overlay des App-Kanals: zeigt an, was UpdateService gerade weiß, und löst die zwei
## Schritte aus (laden, installieren).
##
## Das Layout liegt in update_dialog.tscn; hier wird nur bedient und angezeigt. Geöffnet
## wird über `open()` (Klick auf das Abzeichen im Startmenü) — die Startprüfung selbst
## drängt sich nicht auf.

## Bezeichnung des Aktionsknopfes je Zustand. Zustände ohne Eintrag haben keine Aktion.
const ACTION_LABEL := {
	UpdateService.State.AVAILABLE: "Herunterladen",
	UpdateService.State.READY: "Neu starten & ersetzen",
}

const STATUS_TEXT := {
	UpdateService.State.CHECKING: "Suche nach einer neuen Fassung …",
	UpdateService.State.DOWNLOADING: "Wird heruntergeladen …",
	UpdateService.State.VERIFYING: "Prüfsumme und Signatur werden geprüft …",
	UpdateService.State.READY: "Geprüft. Das Spiel startet nach dem Ersetzen neu.",
	UpdateService.State.INSTALLING: "Wird ersetzt, das Spiel startet neu …",
}

@onready var _title: Label = %Title
@onready var _notes: RichTextLabel = %Notes
@onready var _status: Label = %Status
@onready var _progress: ProgressBar = %Progress
@onready var _later: Button = %LaterButton
@onready var _action: Button = %ActionButton


func _ready() -> void:
	hide()
	UpdateService.changed.connect(_render)
	_notes.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	_later.pressed.connect(_close)
	_action.pressed.connect(_on_action)
	_render()


func _input(event: InputEvent) -> void:
	if not visible or _busy():
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		accept_event()


func open() -> void:
	_render()
	show()


func _close() -> void:
	hide()


## Während Laden/Prüfen/Ersetzen bleibt der Dialog stehen: ein weggeklickter Download
## liefe unsichtbar weiter und die Ersetzung ist nicht abbrechbar.
func _busy() -> bool:
	return UpdateService.state in [
		UpdateService.State.CHECKING,
		UpdateService.State.DOWNLOADING,
		UpdateService.State.VERIFYING,
		UpdateService.State.INSTALLING,
	]


func _on_action() -> void:
	match UpdateService.state:
		UpdateService.State.AVAILABLE:
			UpdateService.download()
		UpdateService.State.READY:
			UpdateService.install()


func _render() -> void:
	var state: UpdateService.State = UpdateService.state
	var version := UpdateService.version

	_title.text = "Update auf %s" % version if not version.is_empty() else "Update"
	if state == UpdateService.State.ERROR:
		_title.text = "Update fehlgeschlagen"

	_notes.text = MarkdownToBbcode.convert(UpdateService.notes)
	_notes.visible = not UpdateService.notes.is_empty()

	_status.text = UpdateService.error if state == UpdateService.State.ERROR \
		else str(STATUS_TEXT.get(state, ""))
	_status.visible = not _status.text.is_empty()

	var loading := state == UpdateService.State.DOWNLOADING
	_progress.visible = loading
	# -1 heißt „Gesamtgröße unbekannt": dann zeigt der Balken nichts vor, was er nicht weiß.
	_progress.indeterminate = loading and UpdateService.progress < 0.0
	_progress.value = maxf(UpdateService.progress, 0.0)

	_action.visible = ACTION_LABEL.has(state)
	_action.text = str(ACTION_LABEL.get(state, ""))
	_action.disabled = _busy()
	_later.disabled = _busy()
	_later.text = "Schließen" if state == UpdateService.State.ERROR else "Später"
