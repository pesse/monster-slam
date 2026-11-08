class_name MapBirds
extends Control
## Ein Klick auf eine Fläche der Art "birds" (Bäume, Wiese; die Maske bleibt unsichtbar)
## scheucht einen Schwarm auf, der flatternd zur Seite und nach oben aus der Karte fliegt.
## Meldet EventBus.secret_found "birds". Ebene in MapAmbience, gezeichnet mit map_bird.gdshader.

const SHADER := preload("res://assets/shaders/map_bird.gdshader")
## Spannweite eines Vogels (Bildhöhen); das Rechteck ist etwas größer.
const SIZE := 0.04
## So viele Vögel bei Intensität 1 (MapLayout.INTENSITY_MAX verdoppelt), mindestens MIN_BIRDS.
const BIRDS := 6
const MIN_BIRDS := 3
## Sie fliegen gestaffelt los, bis zu STAGGER s nach dem Klick, aus einem Kreis von SPREAD
## (Bildhöhen) um ihn.
const STAGGER := 0.35
const SPREAD := 0.025
## Flugzeit eines Vogels (s); am Ende ist er ausgeblendet.
const FLY_TIME := 3.0
## Anfangstempo und Beschleunigung (Bildhöhen je s, je s²); x zeigt in die Flugrichtung.
const SPEED := Vector2(0.06, -0.1)
const PULL := Vector2(0.05, -0.02)
## Flügelschläge je s.
const FLAP := 7.0
const MAX_FLOCKS := 2

## Uhr (s); Tests setzen sie fest, sonst die Laufzeit.
var now_override := -1.0

var _canvas: MapCanvas
## Die Masken der Vogelflächen, mit ihrer Stärke: [{ image, intensity }].
var _masks: Array = []
## Die Schwärme: { start, birds: [{ at (Anteil des Bildes), delay, dir, speed, seed }] }.
var _flocks: Array = []


func _init(canvas: MapCanvas) -> void:
	_canvas = canvas
	name = "Birds"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


## Nimmt eine weitere Vogelfläche auf.
func add_mask(mask: Texture2D, intensity: float) -> void:
	var image := MapAmbience.mask_image(mask)
	if image != null:
		_masks.append({"image": image, "intensity": intensity})


## Die Stärke der Vogelfläche an `at` (Anteil des Bildes), 0 wo keine ist.
func birds_at(at: Vector2) -> float:
	for mask: Dictionary in _masks:
		if MapAmbience.mask_at(mask["image"], at):
			return float(mask["intensity"])
	return 0.0


## Scheucht an `local` (Koordinaten des Canvas) einen Schwarm auf. True, wenn er auffliegt.
func scare_at(local: Vector2) -> bool:
	var rect := _map_rect()
	if rect.size.x <= 0.0 or _flocks.size() >= MAX_FLOCKS:
		return false
	var at := (_canvas.view_transform().affine_inverse() * local - rect.position) / rect.size
	var intensity := birds_at(at)
	if intensity <= 0.0:
		return false
	# Weg von der näheren Seite, damit sie über die Karte und nicht gleich hinaus fliegen.
	var dir := 1.0 if at.x < 0.5 else -1.0
	var aspect := rect.size.x / rect.size.y
	var birds: Array = []
	for i in maxi(MIN_BIRDS, roundi(BIRDS * intensity)):
		var off := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * SPREAD
		birds.append({"at": at + Vector2(off.x / aspect, off.y * 0.6), "delay": randf() * STAGGER,
				"dir": dir if randf() < 0.85 else -dir, "speed": randf_range(0.8, 1.25),
				"seed": randf()})
	_flocks.append({"start": _now(), "birds": birds})
	EventBus.secret_found.emit("birds")
	queue_redraw()
	return true


## Fliegt noch ein Schwarm? Räumt fertige ab.
func is_busy() -> bool:
	var now := _now()
	_flocks = _flocks.filter(func(flock: Dictionary) -> bool:
		return now < float(flock["start"]) + STAGGER + FLY_TIME)
	return not _flocks.is_empty()


## Die Schwärme, die gerade fliegen — für Tests.
func flocks() -> Array:
	return _flocks


## Wo der Vogel `t` s nach seinem Abflug ist, auf dem Canvas vor dem Zoom.
static func bird_point(bird: Dictionary, t: float, rect: Rect2) -> Vector2:
	var speed := float(bird["speed"])
	var dir := Vector2(float(bird["dir"]), 1.0)
	var path := (SPEED * speed * t + PULL * speed * 0.5 * t * t) * dir
	# Ein wenig auf und ab, je Vogel versetzt.
	path.y += sin(t * 9.0 + float(bird["seed"]) * TAU) * 0.002
	return rect.position + (bird["at"] as Vector2) * rect.size + path * rect.size.y


func _draw() -> void:
	var rect := _map_rect()
	if rect.size.x <= 0.0:
		return
	draw_set_transform_matrix(_canvas.view_transform())
	# Ein unsichtbarer Vogel übersetzt den Shader, bevor der erste fliegt.
	draw_rect(Rect2(rect.position, Vector2.ONE), Color(0.0, 0.0, 0.0, 1.0))
	var now := _now()
	var side := SIZE * 1.25 * rect.size.y
	for flock: Dictionary in _flocks:
		for bird: Dictionary in flock["birds"]:
			var t := now - float(flock["start"]) - float(bird["delay"])
			if t <= 0.0 or t >= FLY_TIME:
				continue
			var u := t / FLY_TIME
			# Wächst beim Auffliegen kurz heran und blendet am Ende aus.
			var grow := lerpf(0.5, 1.0, smoothstep(0.0, 0.12, u))
			var at := bird_point(bird, t, rect)
			# r: Phase des Flügelschlags, g: Deckung, b: 0.5 wenn er nach links fliegt.
			# Alpha bleibt dem Ausblenden der Karte (modulate).
			var flap := fposmod(t * FLAP * (1.0 + 0.15 * float(bird["seed"])) + float(bird["seed"]), 1.0)
			draw_rect(Rect2(at - Vector2.ONE * side * grow * 0.5, Vector2.ONE * side * grow),
					Color(flap, 1.0 - smoothstep(0.7, 1.0, u), 0.5 if float(bird["dir"]) < 0.0 else 0.0, 1.0))
	draw_set_transform_matrix(Transform2D())


func _map_rect() -> Rect2:
	return MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)


func _now() -> float:
	return now_override if now_override >= 0.0 else Time.get_ticks_msec() / 1000.0
