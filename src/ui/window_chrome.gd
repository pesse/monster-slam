class_name WindowChrome
extends Control
## Die Teile des Fensterrahmens, die ein `StyleBox` nicht zeichnen kann, für eine Karte, die
## so groß ist wie ihr Inhalt (Wellenabschluss, Auflösung, Rückfrage).
##
## Die großen Fenster (Statistik, Fähigkeiten) füllen das Bild und legen Fläche und Gelenke
## als eigene Knoten mit Anker und Versatz an (`assets/ui/windows/README.md`). In einem
## `PanelContainer`, der mit seinem Inhalt wächst, geht das nicht: er zieht jedes Kind auf
## seine volle Größe. Deshalb zeichnet dieser Knoten selbst, und zwar genau eines:
##
## - `SURFACE`, als erstes Kind der Karte: die gekachelte Materialebene, auf die innere Fläche
##   beschnitten — 9 px Einzug, Ecken 11 px abgeschrägt wie der Rahmen. Ein Rechteck stäche
##   an den Ecken über das Metall hinaus.
## - `JOINTS`, als erstes Kind des Titelbands: die zwei Anschlussplatten unter der
##   Titeltrennkante. Sie reichen unter das Band hinaus; gezeichnet wird ohne Beschneiden.

enum Part { SURFACE, JOINTS }

const SURFACE_TEXTURE := preload("res://assets/ui/windows/window_surface.webp")
const JOINT_LEFT := preload("res://assets/ui/windows/title_joint_left.webp")
const JOINT_RIGHT := preload("res://assets/ui/windows/title_joint_right.webp")
## Einzug und Abschrägung der inneren Fläche (README des Fensterpakets).
const SURFACE_INSET := 9.0
const SURFACE_CHAMFER := 11.0
## Kachelgröße der Materialebene: die Textur in ihrer vollen Größe, nicht gedehnt.
const SURFACE_TILE := 512.0
## Oberkante der Anschlussplatten im Titelband und ihre Größe.
const JOINT_TOP := 51.0
const JOINT_SIZE := Vector2(24, 24)

@export var part := Part.SURFACE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_repeat = TEXTURE_REPEAT_ENABLED
	resized.connect(queue_redraw)


func _draw() -> void:
	if part == Part.JOINTS:
		# Das Titelband setzt seine Kinder um seinen Innenabstand ein; gemessen wird von
		# seiner Kante aus, nicht von der eigenen.
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


## Die innere Fläche als Achteck — für Tests, und damit die Form an einer Stelle steht.
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
