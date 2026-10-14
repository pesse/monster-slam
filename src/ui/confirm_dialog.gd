class_name ConfirmDialog
extends Control
## Ein Overlay, das eine Frage stellt und zwei Antworten anbietet; kein Godot-`Window`
## (siehe CONVENTIONS „Oberfläche“). Was nach `confirmed` geschieht, entscheidet der Aufrufer.

## Der Spieler hat bestätigt; `cancelled` meldet den anderen Ausgang.
signal confirmed()
signal cancelled()

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _action: Button = %ActionButton
@onready var _cancel: Button = %CancelButton


func _ready() -> void:
	hide()
	_action.pressed.connect(func() -> void:
			_close()
			confirmed.emit())
	_cancel.pressed.connect(func() -> void:
			_close()
			cancelled.emit())


## Escape bricht ab, nur solange der Dialog sichtbar ist.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		cancelled.emit()
		accept_event()


## Stellt die Frage. `action` und `keep` beschriften die Knöpfe; sie benennen die Tat
## („Lernen“, „Weiterspielen“), nicht „OK“.
func ask(title: String, body: String, action := "Ja", keep := "Abbrechen") -> void:
	_title.text = title
	_body.text = body
	_action.text = action
	_cancel.text = keep
	_cancel.visible = true
	show()
	# Der Fokus liegt auf dem Abbrechen, damit Enter nichts versehentlich bestätigt.
	_cancel.grab_focus()


## Teilt etwas mit: nur ein Knopf, der `confirmed` meldet.
func inform(title: String, body: String, action := "OK") -> void:
	_title.text = title
	_body.text = body
	_action.text = action
	_cancel.visible = false
	show()
	_action.grab_focus()


func _close() -> void:
	hide()
