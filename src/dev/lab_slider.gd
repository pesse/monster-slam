class_name LabSlider
extends HSlider
## Schieberegler einer Werkbank mit Zahl daneben (`readout`).

@export var readout: Label


# `set_value_no_signal` meldet sich nur über ein Neuzeichnen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and readout:
		readout.text = "%.*f" % [step_decimals(step), value]
