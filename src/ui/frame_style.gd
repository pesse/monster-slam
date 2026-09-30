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
	var rid := texture.get_rid()
	for i in 3:
		for j in 3:
			var src := Rect2(src_x[i], src_y[j], src_x[i + 1] - src_x[i], src_y[j + 1] - src_y[j])
			var dst := Rect2(dst_x[i], dst_y[j], dst_x[i + 1] - dst_x[i], dst_y[j + 1] - dst_y[j])
			if src.size.x <= 0.0 or src.size.y <= 0.0 or dst.size.x <= 0.0 or dst.size.y <= 0.0:
				continue
			RenderingServer.canvas_item_add_texture_rect_region(
					to_canvas_item, dst, rid, src, modulate)
