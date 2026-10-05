class_name PauseOverlay
extends Control
## Die Pause des Wellenkampfs: Strg+P überall, ein nacktes P bei geschlossener Eingabe
## (in der offenen gehört jedes „p" ins Wort). Dazu der Knopf unter „Schnell auflösen".
##
## Läuft mit process_mode ALWAYS: in der Pause steht der Baum, und die Taste, die sie
## beendet, muss trotzdem ankommen. Ob gerade pausiert werden DARF, weiß der WaveRunner —
## hier wird nur die Taste erkannt und das Bild gezeigt. Das Bild ist abgedunkelt, damit
## die Pause keine Bedenkzeit für die Wörter auf dem Feld ist.

## Strg+P oder (wo erlaubt) P. `bare`: ohne Strg gedrückt.
signal toggle_requested(bare: bool)
## Esc in der Pause: der Kampf soll enden wie mit Esc im laufenden Kampf.
signal leave_requested

## In der Pause ist die Eingabe weg, das nackte P beendet sie also immer.
const KEYS := "P: weiter · Esc: Kampf beenden"

@onready var _dim: ColorRect = %Dim
@onready var _keys: Label = %Keys


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_shown() -> bool:
	return _dim.visible


func show_pause() -> void:
	_keys.text = KEYS
	_dim.visible = true


func hide_pause() -> void:
	_dim.visible = false


## `_input`, weil die Antwortzeile den Fokus hält und ein „p" sonst als Buchstabe ankäme.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_P and not key.alt_pressed and not key.shift_pressed:
		toggle_requested.emit(not key.ctrl_pressed)
	elif is_shown() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_requested.emit()


## Für den Aufrufer: die Taste ist verbraucht (der Buchstabe soll nicht ins Feld).
func consume() -> void:
	get_viewport().set_input_as_handled()
