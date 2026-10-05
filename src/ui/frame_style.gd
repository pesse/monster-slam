@tool
class_name FrameStyle
extends StyleBox
## Ein 9-Slice-Rahmen, der seine Grafik VERKLEINERT zeichnet.
##
## `StyleBoxTexture` zeichnet die Slice-Ränder in Texturpixeln: ein Rahmen aus
## `assets/ui/gameplay/frames/` (101 px hoch, 40 px Ecken) sähe in der HUD-Höhe von 60 px
## klobig aus. Hier wird die ganze Rahmengeometrie mit `scale` verkleinert und erst dann das
## gerade Mittelstück gestreckt — so verlangt es das Paket (README „Skalierung"). Die Grafik
## bleibt in voller Auflösung: bei größeren Fenstern (canvas_items dehnt die UI) wird sie
## nicht hochgerechnet, sondern nur weniger verkleinert.
##
## Die Innenabstände sind die normalen `content_margin_*` des StyleBox, in Bildschirmpixeln.

@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
## Slice-Ränder in Texturpixeln, wie `slice_ltrb` in `assets/ui/gameplay/manifest.json`.
@export var slice_left := 0.0:
	set(value):
		slice_left = value
		emit_changed()
@export var slice_top := 0.0:
	set(value):
		slice_top = value
		emit_changed()
@export var slice_right := 0.0:
	set(value):
		slice_right = value
		emit_changed()
@export var slice_bottom := 0.0:
	set(value):
		slice_bottom = value
		emit_changed()
## Bildschirmpixel je Texturpixel für Ecken und Kanten.
@export var scale := 1.0:
	set(value):
		scale = value
		emit_changed()
@export var modulate := Color.WHITE:
	set(value):
		modulate = value
		emit_changed()
## Fläche hinter einem Rahmen mit leerer Mitte (`assets/ui/frames/silver_gold`): ein
## Rechteck, `fill_inset` Texturpixel vom Rand eingerückt, also unter die Schiene. Unsichtbar
## (Alpha 0) wird nichts gezeichnet.
@export var fill := Color(0, 0, 0, 0):
	set(value):
		fill = value
		emit_changed()
@export var fill_inset := 0.0:
	set(value):
		fill_inset = value
		emit_changed()
## Das Mittelstück einer Kante nicht stauchen, sondern nur so viel aus seiner Mitte nehmen,
## wie hineinpasst. Für einen Rahmen, der kürzer ist als seine Grafik (die breite
## Festungsleiste als quadratische Zauberkachel): gestaucht verschmiert die Metallstruktur.
@export var crop_middle := false:
	set(value):
		crop_middle = value
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var tex := texture.get_size()
	# Ein Rahmen, der schmaler ist als seine beiden Ecken, verkleinert die Ecken weiter statt
	# sie zu überlappen.
	var s := scale
	if slice_left + slice_right > 0.0:
		s = minf(s, rect.size.x / (slice_left + slice_right))
	if slice_top + slice_bottom > 0.0:
		s = minf(s, rect.size.y / (slice_top + slice_bottom))
	var src_x := [0.0, slice_left, tex.x - slice_right, tex.x]
	var src_y := [0.0, slice_top, tex.y - slice_bottom, tex.y]
	var dst_x := [rect.position.x, rect.position.x + slice_left * s,
			rect.end.x - slice_right * s, rect.end.x]
	var dst_y := [rect.position.y, rect.position.y + slice_top * s,
			rect.end.y - slice_bottom * s, rect.end.y]
	# Das Mittelstück je Achse: ganz (gestreckt oder gestaucht) oder ausgeschnitten.
	var mid_x := _middle(src_x, dst_x, s)
	var mid_y := _middle(src_y, dst_y, s)
	if fill.a > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(-fill_inset * s), fill)
	var rid := texture.get_rid()
	for i in 3:
		for j in 3:
			var sx: Vector2 = mid_x if i == 1 else Vector2(src_x[i], src_x[i + 1])
			var sy: Vector2 = mid_y if j == 1 else Vector2(src_y[j], src_y[j + 1])
			var src := Rect2(sx.x, sy.x, sx.y - sx.x, sy.y - sy.x)
			var dst := Rect2(dst_x[i], dst_y[j], dst_x[i + 1] - dst_x[i], dst_y[j + 1] - dst_y[j])
			if src.size.x <= 0.0 or src.size.y <= 0.0 or dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			RenderingServer.canvas_item_add_texture_rect_region(
					to_canvas_item, dst, rid, src, modulate)


## Anfang und Ende des Mittelstücks in der Quelle. Mit `crop_middle` und einem Ziel, das
## bei `s` weniger braucht, als da ist, nur so viel um die Mitte herum — die Ecken bleiben.
func _middle(src: Array, dst: Array, s: float) -> Vector2:
	var whole := Vector2(src[1], src[2])
	if not crop_middle:
		return whole
	var need: float = (dst[2] - dst[1]) / s
	if need <= 0.0 or need >= whole.y - whole.x:
		return whole
	var mid := (whole.x + whole.y) * 0.5
	return Vector2(mid - need * 0.5, mid + need * 0.5)
