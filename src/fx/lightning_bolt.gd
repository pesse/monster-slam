class_name LightningBolt
extends MeshInstance3D
## Ein Blitz aus dem Himmel auf einen Punkt (Donnerschlag, ADR 0014): ein Zickzack von oben
## nach unten mit zwei, drei Ästen, der RESHAPE_HZ-mal je Sekunde neu zuckt und flackernd
## verlischt. Die Bänder baut ein ImmediateMesh, das Drehen zur Kamera macht der Shader
## (lightning_bolt.gdshader) — deshalb steht der Knoten im Ursprung der Welt.
## Wie `Lightning` (die 2D-Blitze der Wort-Feier), nur im Feld.
##
## Läuft nach Spielzeit wie die anderen Effekte und gibt sich nach LIFETIME selbst frei.

const SHADER := preload("res://assets/shaders/lightning_bolt.gdshader")

const LIFETIME := 0.42
const RESHAPE_HZ := 24.0
const SEGMENTS := 16
## So weit weicht die Linie seitlich aus, im Verhältnis zur Länge eines Abschnitts.
const JITTER := 0.55
## Breite des Bands (Hof samt Kern) in Metern.
const WIDTH := 3.2
## So hoch über dem Ziel beginnt der Blitz.
const HEIGHT := 34.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _tint := Color(0.45, 0.62, 1.0)
var _age := 0.0
var _next_shape := 0.0
var _rng := RandomNumberGenerator.new()
var _mat := ShaderMaterial.new()
var _imm := ImmediateMesh.new()


## Ein Blitz auf `target` (am Boden); er kommt schräg von oben, nie ganz senkrecht.
func setup(target: Vector3, tint := Color(0.45, 0.62, 1.0)) -> void:
	_rng.randomize()
	_to = target
	_from = target + Vector3(_rng.randf_range(-6.0, 6.0), HEIGHT, _rng.randf_range(-4.0, 2.0))
	_tint = tint


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mat.shader = SHADER
	_mat.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))
	mesh = _imm
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Die Hülle kennt nur die Mittellinie; das Band ragt seitlich darüber hinaus.
	extra_cull_margin = WIDTH * 2.0
	_reshape()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var t := _age / LIFETIME
	# Hart flackern statt weich ausblenden — so verlischt ein Blitz.
	var flicker := 1.0 if int(t * 14.0) % 3 != 2 else 0.25
	_mat.set_shader_parameter("alpha", (1.0 - t * t) * flicker)
	if _age >= _next_shape:
		_reshape()


func _reshape() -> void:
	_next_shape = _age + 1.0 / RESHAPE_HZ
	_imm.clear_surfaces()
	var main := _zigzag(_from, _to, SEGMENTS)
	_ribbon(main, WIDTH)
	for i in _rng.randi_range(2, 3):
		var at := _rng.randi_range(3, SEGMENTS - 5)
		var start := main[at]
		var down := (_to - _from).normalized()
		var out := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
		var end := start + (down + out * _rng.randf_range(0.5, 0.9)).normalized() \
				* _rng.randf_range(4.0, 9.0)
		_ribbon(_zigzag(start, end, 6), WIDTH * 0.45)


## Eine Linie von `a` nach `b` in `count` Abschnitten, seitlich verwackelt (nicht an den Enden).
func _zigzag(a: Vector3, b: Vector3, count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var step := a.distance_to(b) / count
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		if i > 0 and i < count:
			p += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3),
					_rng.randf_range(-1.0, 1.0)) * step * JITTER
		points.append(p)
	return points


## Ein Band entlang `points`: je Punkt zwei Ecken, die der Shader zur Seite schiebt.
func _ribbon(points: PackedVector3Array, width: float) -> void:
	_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var last := points.size() - 1
	for i in points.size():
		var along := points[mini(i + 1, last)] - points[maxi(i - 1, 0)]
		var v := float(i) / last
		for side in [-1.0, 1.0]:
			_imm.surface_set_normal(along.normalized())
			_imm.surface_set_uv(Vector2(0.5 + side * 0.5, v))
			_imm.surface_set_uv2(Vector2(side * width * 0.5, 0.0))
			_imm.surface_add_vertex(points[i])
	_imm.surface_end()
