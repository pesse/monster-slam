@tool
class_name XpRing
extends Control
## Der Erfahrungsbogen im Porträtring der Kopfleiste: der Anteil am nächsten Aufstieg,
## im Uhrzeigersinn von oben. Keine Zahl daneben — der Ring ist die ganze Auskunft.
##
## Die Geometrie ist die der Ringgrafik (`portrait_xp_arc` in
## `assets/ui/gameplay/manifest.json`, gemessen auf 192 px) und wächst mit der Größe des
## Knotens. Er liegt zwischen Ring und Levelplakette.

const CANVAS := 192.0
const RADIUS := 61.2
const WIDTH := 9.6
const COLOR := Color(0.3, 0.78, 1.0)

@export_range(0.0, 1.0) var ratio := 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	if ratio <= 0.0:
		return
	var k := size.x / CANVAS
	var start := -PI / 2.0
	draw_arc(size / 2.0, RADIUS * k, start, start + TAU * ratio, 64, COLOR, WIDTH * k, true)
