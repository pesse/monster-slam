class_name LabSlider
extends HSlider
## Schieberegler einer Werkbank mit Zahl daneben (`readout`). Wer bei jedem Wert teuer
## umbaut, hört auf `settled` statt `value_changed`.

## Der Wert steht fest: nach dem Ziehen oder bei jeder Änderung ohne Ziehen (Rad, Tasten, Code).
signal settled(value: float)

@export var readout: Label

var _dragging := false


func _ready() -> void:
	drag_started.connect(func() -> void: _dragging = true)
	drag_ended.connect(func(changed: bool) -> void:
		_dragging = false
		if changed:
			settled.emit(value))
	value_changed.connect(func(v: float) -> void:
		if not _dragging:
			settled.emit(v))


# `set_value_no_signal` meldet sich nur über ein Neuzeichnen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and readout:
		readout.text = "%.*f" % [step_decimals(step), value]
