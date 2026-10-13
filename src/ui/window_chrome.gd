class_name WindowChrome
extends Control
## Die Teile des Fensterrahmens, die ein `StyleBox` nicht zeichnen kann, für eine Karte, die
## mit ihrem Inhalt wächst. Ein `PanelContainer` zieht jedes Kind auf volle Größe, deshalb
## zeichnet dieser Knoten selbst: `SURFACE` (erstes Kind der Karte) die gekachelte, an den
## Ecken abgeschrägte Materialebene, `JOINTS` (erstes Kind des Titelbands) die zwei
## Anschlussplatten unter der Titelkante, unbeschnitten.

enum Part { SURFACE, JOINTS }

const SURFACE_TEXTURE := preload("res://assets/ui/windows/window_surface.webp")
const JOINT_LEFT := preload("res://assets/ui/windows/title_joint_left.webp")
const JOINT_RIGHT := preload("res://assets/ui/windows/title_joint_right.webp")
## Einzug und Abschrägung der inneren Fläche in px (`assets/ui/windows/README.md`).
const SURFACE_INSET := 9.0
const SURFACE_CHAMFER := 11.0
## Kachelgröße der Materialebene in px, die volle Texturgröße.
const SURFACE_TILE := 512.0
## Oberkante der Anschlussplatten im Titelband und ihre Größe, px.
const JOINT_TOP := 51.0
const JOINT_SIZE := Vector2(24, 24)

@export var part := Part.SURFACE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_repeat = TEXTURE_REPEAT_ENABLED
	resized.connect(queue_redraw)


func _draw() -> void:
	if part == Part.JOINTS:
		# Gemessen von der Kante des Titelbands, nicht vom eingerückten Knoten.
		var band := get_parent_control()
		var width := band.size.x if band != null else size.x
		var origin := -position
		draw_texture_rect(JOINT_LEFT, Rect2(origin + Vector2(0, JOINT_TOP), JOINT_SIZE), false)
		draw_texture_rect(JOINT_RIGHT, Rect2(
				origin + Vector2(width - JOINT_SIZE.x, JOINT_TOP), JOINT_SIZE), false)
		return
	var outline := surface_outline(size)
	var uvs := PackedVector2Array()
	for point in outline:
		uvs.append(point / SURFACE_TILE)
	draw_colored_polygon(outline, Color.WHITE, uvs, SURFACE_TEXTURE)


## Die innere Fläche als Achteck.
static func surface_outline(card: Vector2) -> PackedVector2Array:
	var a := SURFACE_INSET
	var c := SURFACE_CHAMFER
	var w := card.x
	var h := card.y
	return PackedVector2Array([
		Vector2(a + c, a), Vector2(w - a - c, a), Vector2(w - a, a + c),
		Vector2(w - a, h - a - c), Vector2(w - a - c, h - a), Vector2(a + c, h - a),
		Vector2(a, h - a - c), Vector2(a, a + c),
	])
