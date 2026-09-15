class_name ConfirmDialog
extends Control
## Ein Overlay, das eine Frage stellt und zwei Antworten anbietet.
##
## Dasselbe Muster wie `update_dialog`: ein Control über dem ganzen Bild, darunter ein
## abdunkelnder `Dim`, in der Mitte die Tafel — und KEIN `Window`. Ein Godot-Popup ist ein
## eigenes Fenster und skaliert nicht mit `canvas_items`; bei 1152×648 stünde es in echten
## Bildschirmpixeln neben dem Spiel statt darin.
##
## Der Dialog weiß nichts von dem, was er fragt: er bekommt Text und Beschriftung über
## `ask()` und meldet `confirmed`. Was daraufhin geschieht, entscheidet der Aufrufer — so
## trägt derselbe Dialog das Lernen und das Umlernen, ohne beides zu kennen.

## Der Spieler hat bestätigt. `cancelled` meldet den anderen Ausgang — ein Aufrufer, der
## nur auf `confirmed` hört, muss den Abbruch nicht behandeln.
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


## Escape bricht ab — dieselbe Taste, mit der man überall im Spiel zurückgeht. Der Dialog
## fängt sie nur, solange er sichtbar ist; sonst käme der Screen dahinter nicht mehr
## zurück ins Startmenü.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		cancelled.emit()
		accept_event()


## Stellt die Frage. `action` ist die Beschriftung des bestätigenden Knopfes und benennt
## die TAT („Lernen", „Umlernen") statt „OK" zu sagen: was ein Klick tut, soll auf dem
## Knopf stehen und nicht nur in der Frage darüber.
func ask(title: String, body: String, action := "Ja") -> void:
	_title.text = title
	_body.text = body
	_action.text = action
	show()
	# Der Fokus liegt auf dem ABBRECHEN: mit der Eingabetaste soll man nicht versehentlich
	# Punkte ausgeben, die man gerade erst bekommen hat.
	_cancel.grab_focus()


func _close() -> void:
	hide()
