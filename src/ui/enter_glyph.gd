@tool
extends Control
## Das Enter-Zeichen (↵) auf der Taste im Antwortfeld. Gezeichnet statt aus der Schrift:
## Fira Sans hat den Pfeil nicht, und ein Ersatz aus der Systemschrift sähe auf jedem
## Rechner anders aus.

@export var color := Color(0.92, 0.94, 0.98):
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var line := maxf(2.0, h * 0.14)
	var tip := Vector2(w * 0.08, h * 0.68)
	# Senkrecht hoch am rechten Rand, waagerecht nach links, dort die Pfeilspitze.
	draw_polyline(PackedVector2Array([Vector2(w * 0.86, h * 0.18), Vector2(w * 0.86, h * 0.68),
			tip + Vector2(h * 0.2, 0.0)]), color, line, true)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(h * 0.34, -h * 0.28),
			tip + Vector2(h * 0.34, h * 0.28)]), color)
