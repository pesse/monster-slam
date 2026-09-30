@tool
class_name Diamond
extends Control
## Eine Farbraute, z. B. für die Wortart-Legende. Gezeichnet statt ein gedrehtes ColorRect:
## ein Container setzt die Drehung seiner Kinder beim Layout zurück.

@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, 0.0), Vector2(size.x, c.y),
			Vector2(c.x, size.y), Vector2(0.0, c.y)]), color)
