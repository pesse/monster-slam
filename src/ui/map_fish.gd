class_name MapFish
extends Control
## Ein Fisch springt, wo man auf das Wasser einer Gebietskarte klickt; ein zweiter Klick auf
## ihn im Sprung fängt ihn (EventBus.secret_found "fish"). Wasser ist, was die Maske der
## Fläche hell malt. Ebene in MapAmbience, gezeichnet mit map_fish.gdshader.

const SHADER := preload("res://assets/shaders/map_fish.gdshader")
## Weite eines Sprungs, in Bildhöhen; Höhe des Bogens und Rand um den Sprung (Ripples), in
## Sprungweiten. Gleich den Uniforms `rise` und `margin` des Shaders.
const SPAN := 0.085
const RISE := 0.7
const MARGIN := 0.4
## Dauer eines Sprungs und danach des Nachplätscherns oder des Fang-Funkelns (s).
const JUMP_TIME := 0.85
const AFTER_TIME := 0.7
## Fangen geht nur in der Luft: Anteil des Sprungs von/bis. Kurz nach dem Auftauchen noch
## nicht, sonst finge ein zweiter Klick auf dieselbe Stelle ihn aus Versehen.
const CATCH_FROM := 0.25
const CATCH_TO := 0.9
## Trefferradius um die Mitte des Fisches in Sprungweiten (etwa seine halbe Länge),
## mindestens MIN_HIT px.
const HIT := 0.25
const MIN_HIT := 10.0
## So hell ist Wasser in der Maske mindestens (0..1).
const WATER := 0.5
## Mehr Fische auf einmal springen nicht.
const MAX_FISH := 3
## Wie der Shader den Fangzeitpunkt aus COLOR.b liest (siehe `_draw`).
const CAUGHT_SCALE := 0.49

## Uhr (s); Tests setzen sie fest, sonst die Laufzeit.
var now_override := -1.0

var _canvas: MapCanvas
var _mask: Image
## Die Fische: { at (Anteil des Bildes), dir (1 rechts, -1 links), start, caught (Zeit oder -1),
## caught_t (Anteil des Sprungs beim Fang) }.
var _fish: Array = []


func _init(canvas: MapCanvas, mask: Texture2D) -> void:
	_canvas = canvas
	name = "Fish"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("rise", RISE)
	mat.set_shader_parameter("margin", MARGIN)
	mat.set_shader_parameter("jump_share", JUMP_TIME / (JUMP_TIME + AFTER_TIME))
	material = mat
	_mask = mask.get_image() if mask != null else null
	if _mask != null and _mask.is_compressed():
		_mask.decompress()


## Ist an `at` (Anteil des Bildes) Wasser?
func water_at(at: Vector2) -> bool:
	if _mask == null or at.x < 0.0 or at.y < 0.0 or at.x > 1.0 or at.y > 1.0:
		return false
	var px := Vector2i(mini(int(at.x * _mask.get_width()), _mask.get_width() - 1),
			mini(int(at.y * _mask.get_height()), _mask.get_height() - 1))
	return _mask.get_pixelv(px).r >= WATER


## Fängt einen Fisch in der Luft unter `local` (Koordinaten des Canvas). True, wenn ja.
func catch_at(local: Vector2) -> bool:
	var now := _now()
	var rect := _map_rect()
	var point := _canvas.view_transform().affine_inverse() * local
	for fish: Dictionary in _fish:
		if float(fish["caught"]) >= 0.0:
			continue
		var t := (now - float(fish["start"])) / JUMP_TIME
		if t < CATCH_FROM or t > CATCH_TO:
			continue
		var span := SPAN * rect.size.y
		if fish_point(fish, t, rect).distance_to(point) <= maxf(HIT * span, MIN_HIT):
			fish["caught"] = now
			fish["caught_t"] = t
			EventBus.secret_found.emit("fish")
			queue_redraw()
			return true
	return false


## Lässt einen Fisch an `local` springen, wenn dort Wasser ist. True, wenn er springt.
func jump_at(local: Vector2) -> bool:
	var rect := _map_rect()
	if rect.size.x <= 0.0:
		return false
	var at := (_canvas.view_transform().affine_inverse() * local - rect.position) / rect.size
	if not water_at(at) or _fish.size() >= MAX_FISH:
		return false
	# Springt dorthin, wo auch Wasser ist; lieber in die Richtung, die der Zufall nennt.
	var dir := 1.0 if randf() < 0.5 else -1.0
	var reach := Vector2(SPAN * rect.size.y / rect.size.x, 0.0)
	if not water_at(at + reach * dir) and water_at(at - reach * dir):
		dir = -dir
	_fish.append({"at": at, "dir": dir, "start": _now(), "caught": -1.0, "caught_t": 0.0})
	queue_redraw()
	return true


## Springt oder funkelt noch ein Fisch? Räumt fertige ab.
func is_busy() -> bool:
	var now := _now()
	_fish = _fish.filter(func(fish: Dictionary) -> bool:
		var end := float(fish["caught"]) if float(fish["caught"]) >= 0.0 \
				else float(fish["start"]) + JUMP_TIME
		return now < end + AFTER_TIME)
	return not _fish.is_empty()


## Wo der Fisch beim Anteil `t` seines Sprungs ist, auf dem Canvas vor dem Zoom. Derselbe Bogen
## wie in map_fish.gdshader.
static func fish_point(fish: Dictionary, t: float, rect: Rect2) -> Vector2:
	var span := SPAN * rect.size.y
	var start: Vector2 = rect.position + (fish["at"] as Vector2) * rect.size
	return start + Vector2(t * span * float(fish["dir"]), -4.0 * t * (1.0 - t) * RISE * span)


func _draw() -> void:
	var rect := _map_rect()
	if rect.size.x <= 0.0:
		return
	draw_set_transform_matrix(_canvas.view_transform())
	# Ein unsichtbarer Fisch übersetzt den Shader, bevor der erste springt.
	draw_rect(Rect2(rect.position, Vector2.ONE), Color(1.0, 0.0, 0.0, 1.0))
	var now := _now()
	var span := SPAN * rect.size.y
	var life := JUMP_TIME + AFTER_TIME
	for fish: Dictionary in _fish:
		var start: Vector2 = rect.position + (fish["at"] as Vector2) * rect.size
		var box := Rect2(start - Vector2(MARGIN, RISE + MARGIN) * span,
				Vector2(1.0 + 2.0 * MARGIN, RISE + 2.0 * MARGIN) * span)
		if float(fish["dir"]) < 0.0:
			box.position.x -= span
		var caught := float(fish["caught"])
		# r: Anteil des Lebens (Sprung und danach), g: Fang 0..1 (0 = nicht gefangen),
		# b: 0.5 für gespiegelt plus der Anteil des Sprungs beim Fang mal CAUGHT_SCALE. Alpha
		# bleibt dem Ausblenden der Karte (modulate).
		var r := clampf((now - float(fish["start"])) / life, 0.0, 1.0)
		var g := 0.0
		if caught >= 0.0:
			g = clampf((now - caught) / AFTER_TIME, 0.001, 1.0)
		var b := (0.5 if float(fish["dir"]) < 0.0 else 0.0) + float(fish["caught_t"]) * CAUGHT_SCALE
		draw_rect(box, Color(r, g, b, 1.0))
	draw_set_transform_matrix(Transform2D())


func _map_rect() -> Rect2:
	return MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)


func _now() -> float:
	return now_override if now_override >= 0.0 else Time.get_ticks_msec() / 1000.0
