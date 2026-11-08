class_name MapStones
extends Control
## Ein Klick ans Ufer, also aufs Land dicht am Wasser einer Gebietskarte, wirft einen Stein, der
## über das Wasser hüpft. Ab LUCKY Hüpfern meldet er EventBus.secret_found "stone7". Ebene in
## MapAmbience neben MapFish, dessen Maske sie liest; gezeichnet mit map_stone.gdshader.

const SHADER := preload("res://assets/shaders/map_stone.gdshader")
## Weite des Wurfs bis zur ersten Landung und des ersten Hüpfers danach (Bildhöhen); jeder
## weitere Hüpfer ist SHRINK-mal so weit. Gleich den Konstanten des Shaders.
const THROW := 0.045
const SKIP := 0.04
const SHRINK := 0.8
## Dauer des Wurfs und des ersten Hüpfers (s); die weiteren werden mit der Wurzel aus SHRINK kürzer.
const THROW_TIME := 0.45
const SKIP_TIME := 0.3
## So lange läuft ein Ring nach der Landung aus (s); LIFE deckt den längsten Wurf samt Ring.
const RIPPLE_TIME := 0.9
const LIFE := 3.2
## Höchstens so viele Landungen; ab LUCKY gilt der Wurf als Glückswurf.
const MAX_SKIPS := 9
const LUCKY := 7
## Seite des Quadrats um den Abwurf, in dem der Shader zeichnet (Bildhöhen).
const BOX := 0.48
## Geprüfte Wurfrichtungen; der Shader liest die Richtung als eine davon.
const DIRECTIONS := 24
const MAX_STONES := 3

## Uhr (s); Tests setzen sie fest, sonst die Laufzeit.
var now_override := -1.0

var _canvas: MapCanvas
var _water: MapFish
## Die Steine: { at (Anteil des Bildes), dir (Index in DIRECTIONS), skips, start, lucky_told }.
var _stones: Array = []


func _init(canvas: MapCanvas, water: MapFish) -> void:
	_canvas = canvas
	_water = water
	name = "Stones"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


## Wirft an `local` (Koordinaten des Canvas) einen Stein, wenn dort Land dicht am Wasser ist.
## True, wenn er fliegt.
func throw_at(local: Vector2) -> bool:
	var rect := _map_rect()
	if rect.size.x <= 0.0 or _stones.size() >= MAX_STONES:
		return false
	var at := (_canvas.view_transform().affine_inverse() * local - rect.position) / rect.size
	if at.x < 0.0 or at.y < 0.0 or at.x > 1.0 or at.y > 1.0 or _water.water_at(at):
		return false
	var aspect := rect.size.x / rect.size.y
	var best := -1
	var best_skips := 0
	var offset := randi() % DIRECTIONS
	for k in DIRECTIONS:
		var dir := (k + offset) % DIRECTIONS
		var skips := _skips_toward(at, dir, aspect)
		if skips > best_skips:
			best = dir
			best_skips = skips
	if best < 0:
		return false
	# Wie weit er hüpfen will, entscheidet das Glück; das Wasser setzt die Grenze.
	var luck := 1 + int(pow(randf(), 2.0) * MAX_SKIPS)
	_stones.append({"at": at, "dir": best, "skips": mini(best_skips, luck),
			"start": _now(), "lucky_told": false})
	queue_redraw()
	return true


## Fliegt oder hüpft noch ein Stein? Räumt fertige ab und meldet den Glückswurf, sobald er
## zum LUCKY-ten Mal aufsetzt.
func is_busy() -> bool:
	var now := _now()
	for stone: Dictionary in _stones:
		if int(stone["skips"]) >= LUCKY and not bool(stone["lucky_told"]) \
				and now - float(stone["start"]) >= arrival(LUCKY):
			stone["lucky_told"] = true
			EventBus.secret_found.emit("stone7")
	_stones = _stones.filter(func(stone: Dictionary) -> bool:
		return now < float(stone["start"]) + arrival(int(stone["skips"])) + RIPPLE_TIME)
	return not _stones.is_empty()


## Die Steine, die gerade fliegen — für Tests.
func stones() -> Array:
	return _stones


## Wie weit vom Abwurf er zum `k`-ten Mal aufsetzt (Bildhöhen, k ab 1).
static func landing(k: int) -> float:
	return THROW + SKIP * (1.0 - pow(SHRINK, k - 1)) / (1.0 - SHRINK)


## Wann er zum `k`-ten Mal aufsetzt (s nach dem Wurf).
static func arrival(k: int) -> float:
	var step := sqrt(SHRINK)
	return THROW_TIME + SKIP_TIME * (1.0 - pow(step, k - 1)) / (1.0 - step)


## Die Richtung `dir` (Index in DIRECTIONS) in Bildhöhen.
static func direction(dir: int) -> Vector2:
	return Vector2.from_angle(TAU * dir / DIRECTIONS)


## Wo er zum `k`-ten Mal aufsetzt, als Anteil des Bildes.
static func landing_point(stone: Dictionary, k: int, aspect: float) -> Vector2:
	var d := direction(int(stone["dir"])) * landing(k)
	return (stone["at"] as Vector2) + Vector2(d.x / aspect, d.y)


## Wie oft ein Stein von `at` in Richtung `dir` hintereinander auf Wasser aufsetzen kann.
func _skips_toward(at: Vector2, dir: int, aspect: float) -> int:
	var stone := {"at": at, "dir": dir}
	for k in range(1, MAX_SKIPS + 1):
		if not _water.water_at(landing_point(stone, k, aspect)):
			return k - 1
	return MAX_SKIPS


func _draw() -> void:
	var rect := _map_rect()
	if rect.size.x <= 0.0:
		return
	draw_set_transform_matrix(_canvas.view_transform())
	# Ein unsichtbarer Stein übersetzt den Shader, bevor der erste fliegt.
	draw_rect(Rect2(rect.position, Vector2.ONE), Color(1.0, 0.0, 0.0, 1.0))
	var now := _now()
	var side := BOX * rect.size.y
	for stone: Dictionary in _stones:
		var start: Vector2 = rect.position + (stone["at"] as Vector2) * rect.size
		# r: Zeit seit dem Wurf (Anteil von LIFE), g: Landungen / 16, b: Richtung / DIRECTIONS.
		# Alpha bleibt dem Ausblenden der Karte (modulate).
		draw_rect(Rect2(start - Vector2.ONE * side * 0.5, Vector2.ONE * side),
				Color(clampf((now - float(stone["start"])) / LIFE, 0.0, 1.0),
				float(stone["skips"]) / 16.0, float(stone["dir"]) / DIRECTIONS, 1.0))
	draw_set_transform_matrix(Transform2D())


func _map_rect() -> Rect2:
	return MapCanvas.map_rect(_canvas.size, _canvas.aspect(), _canvas.cover)


func _now() -> float:
	return now_override if now_override >= 0.0 else Time.get_ticks_msec() / 1000.0
