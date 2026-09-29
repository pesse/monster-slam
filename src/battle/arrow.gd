class_name Arrow
extends Node3D
## Ein Pfeil des Bogens (Ich-Sicht): Schaft, Spitze und Federn, Low-Poly wie die Modelle des
## Kampfs. Der Ursprung liegt an der Nocke, die Spitze zeigt nach -z — so liegt er auf der
## Sehne, ohne verschoben zu werden, und `look_at` richtet ihn im Flug aus.
##
## Geflogen wird nach der Wanduhr wie der Anlauf des Sturmangriffs: `Engine.time_scale`
## gehört SlowMotion, und deren Rampe nach dem Abschicken soll den Schuss nicht dämpfen. In
## der Pause der Meister-Feier steht er mit allem anderen (der Tween hängt an ihm).

const LENGTH := 0.8
## So lange steckt ein Fehlschuss im Boden, bevor er verschwindet.
const STICK_TIME := 1.6

const SHAFT_COLOR := Color(0.72, 0.55, 0.34)
const HEAD_COLOR := Color(0.55, 0.58, 0.62)
const FLETCH_COLOR := Color(0.85, 0.22, 0.16)
const TRAIL_COLOR := Color(1.0, 0.95, 0.7)
const TRAIL_LENGTH := 1.6

## Ein fliegender Pfeil zieht eine helle Spur hinter sich her — aus der Ich-Sicht wäre er
## über das Feld sonst nur ein Strich, den man verpasst. Der aufgelegte hat keine.
var trail := false

var _trail: MeshInstance3D


func _ready() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.009
	shaft.bottom_radius = 0.009
	shaft.height = LENGTH
	shaft.radial_segments = 5
	shaft.rings = 1
	_part(shaft, SHAFT_COLOR, Vector3(0.0, 0.0, -LENGTH * 0.5), Vector3(-90.0, 0.0, 0.0))
	# Eine vierseitige Pyramide: die Spitze eines Zylinders mit Radius 0 oben.
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.026
	head.height = 0.1
	head.radial_segments = 4
	head.rings = 1
	_part(head, HEAD_COLOR, Vector3(0.0, 0.0, -LENGTH - 0.05), Vector3(-90.0, 0.0, 0.0))
	for i in 3:
		var vane := BoxMesh.new()
		vane.size = Vector3(0.004, 0.036, 0.13)
		var pivot := Node3D.new()
		pivot.rotation.z = TAU * float(i) / 3.0
		add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = vane
		mi.material_override = material(FLETCH_COLOR)
		mi.position = Vector3(0.0, 0.024, -0.1)
		pivot.add_child(mi)
	if trail:
		# Dieselbe Machart wie der Kern der Explosion (unbeleuchtet, halbdurchsichtig,
		# leuchtend) — deren Shader ist dann schon übersetzt.
		var streak := BoxMesh.new()
		streak.size = Vector3(0.018, 0.018, TRAIL_LENGTH)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.55)
		mat.emission_enabled = true
		mat.emission = TRAIL_COLOR
		mat.emission_energy_multiplier = 2.0
		_trail = MeshInstance3D.new()
		_trail.mesh = streak
		_trail.material_override = mat
		_trail.position = Vector3(0.0, 0.0, TRAIL_LENGTH * 0.5)
		add_child(_trail)


## Fliegt von hier nach `to`, auf einem Bogen `lift` hoch über der Geraden, in `time`
## Sekunden, und kehrt dort zurück.
func fly(to: Vector3, lift: float, time: float) -> void:
	var from := global_position
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(t: float) -> void: _place_on(from, to, lift, t), 0.0, 1.0, time)
	await tw.finished


## Bleibt, wo er ist (im Boden), und verschwindet nach STICK_TIME.
func stick() -> void:
	if _trail != null:
		_trail.visible = false
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3).set_delay(STICK_TIME)
	tw.tween_callback(queue_free)


## Der Punkt der Flugbahn bei `t` (0..1): die Gerade plus eine Parabel nach oben.
static func path_point(from: Vector3, to: Vector3, lift: float, t: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * lift * 4.0 * t * (1.0 - t)


## Die Flugrichtung bei `t` — die Ableitung von path_point.
static func path_direction(from: Vector3, to: Vector3, lift: float, t: float) -> Vector3:
	return (to - from) + Vector3.UP * lift * 4.0 * (1.0 - 2.0 * t)


func _place_on(from: Vector3, to: Vector3, lift: float, t: float) -> void:
	var p := path_point(from, to, lift, t)
	global_position = p
	var d := path_direction(from, to, lift, t)
	if d.length_squared() > 0.0001 and absf(d.normalized().dot(Vector3.UP)) < 0.99:
		look_at(p + d, Vector3.UP)


func _part(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
