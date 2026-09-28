class_name OrnateFrame
extends Control
## Ein verschnörkelter Goldrahmen um das Bild auf dem Buchcover (Book3D): doppelte Linie,
## Schnecken in den Ecken, ein Zierstück in der Mitte jeder Kante. Das Bild liegt als Kind
## darin, `INSET` vom Rand.

const GOLD := Color(0.88, 0.7, 0.34)
const GOLD_DARK := Color(0.52, 0.36, 0.14)
## So weit liegt das Bild innen; die Schnecken greifen darüber hinaus nach außen.
const INSET := 10.0
const CURL := 13.0


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size).grow(-2.0)
	var inner := Rect2(Vector2.ZERO, size).grow(-INSET + 2.0)
	# Schatten, dann die beiden Linien.
	draw_rect(outer.grow(1.0), GOLD_DARK, false, 4.0)
	draw_rect(outer, GOLD, false, 3.0)
	draw_rect(inner, GOLD, false, 1.5)
	var corners := [
		[outer.position, Vector2(1, 1)], [Vector2(outer.end.x, outer.position.y), Vector2(-1, 1)],
		[outer.end, Vector2(-1, -1)], [Vector2(outer.position.x, outer.end.y), Vector2(1, -1)],
	]
	for corner: Array in corners:
		_draw_corner(corner[0], corner[1])
	var mid_top := Vector2(outer.get_center().x, outer.position.y)
	var mid_bottom := Vector2(outer.get_center().x, outer.end.y)
	var mid_left := Vector2(outer.position.x, outer.get_center().y)
	var mid_right := Vector2(outer.end.x, outer.get_center().y)
	_draw_mid(mid_top, Vector2.RIGHT, Vector2.DOWN)
	_draw_mid(mid_bottom, Vector2.RIGHT, Vector2.UP)
	_draw_mid(mid_left, Vector2.DOWN, Vector2.RIGHT)
	_draw_mid(mid_right, Vector2.DOWN, Vector2.LEFT)


## Eine Ecke: ein Knopf auf der Ecke und zwei Schnecken, die sich an den Kanten entlang
## einrollen. `inward` zeigt von der Ecke ins Bild.
func _draw_corner(at: Vector2, inward: Vector2) -> void:
	draw_circle(at, 5.0, GOLD_DARK)
	draw_circle(at, 4.0, GOLD)
	for along: Vector2 in [Vector2(inward.x, 0), Vector2(0, inward.y)]:
		var across := inward - along
		var center := at + along * CURL * 1.4 - across * CURL * 0.35
		_draw_curl(center, CURL * 0.55, along, across)


## Eine Schnecke um `center`: ein Bogen, der kleiner werdend einrollt.
func _draw_curl(center: Vector2, radius: float, along: Vector2, across: Vector2) -> void:
	var start := atan2(-across.y, -across.x)
	var spin := signf(along.cross(-across))
	if spin == 0.0:
		spin = 1.0
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var s := float(i) / float(steps)
		var angle := start + spin * s * TAU * 1.1
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 - 0.7 * s))
	draw_polyline(points, GOLD_DARK, 3.0, true)
	draw_polyline(points, GOLD, 2.0, true)
	draw_circle(points[points.size() - 1], 1.8, GOLD)


## Das Zierstück in der Mitte einer Kante: eine Raute mit zwei Bögen zu den Seiten.
func _draw_mid(at: Vector2, along: Vector2, inward: Vector2) -> void:
	var r := 6.0
	var diamond := PackedVector2Array([at - along * r, at - inward * r * 0.8, at + along * r,
			at + inward * r * 0.8])
	draw_colored_polygon(diamond, GOLD)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), GOLD_DARK, 1.0, true)
	for side: float in [-1.0, 1.0]:
		var center := at + along * side * r * 2.2
		var points := PackedVector2Array()
		for i in 13:
			var s := float(i) / 12.0
			var angle := PI * s
			points.append(center + along * side * cos(angle) * r * 1.1 * -1.0 - inward * sin(angle) * r * 0.9)
		draw_polyline(points, GOLD, 1.5, true)
