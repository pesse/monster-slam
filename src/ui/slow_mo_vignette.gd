extends ColorRect
## Macht die Tipp-Slow-Motion sichtbar (siehe SlowMotion). Bei Intensität 0
## unsichtbar, damit kein bildschirmfüllendes transparentes Rect gezeichnet wird.


func _ready() -> void:
	visible = false
	EventBus.slow_motion_changed.connect(_on_slow_motion_changed)


func _on_slow_motion_changed(intensity: float) -> void:
	visible = intensity > 0.0
	if visible:
		(material as ShaderMaterial).set_shader_parameter("strength", intensity)
