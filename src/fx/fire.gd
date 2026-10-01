class_name Fire
extends Node3D
## Ein Feuer in der Deko: eine weiche, züngelnde Flamme (flame.gdshader) und — wenn noch
## eins frei ist — ein kleines Licht, das mit ihr flackert und den Boden ringsum warm färbt.
##
## Wo es brennt, sagt das Modell: die Forge (src/dev/model_forge.gd, `fire_at`) setzt dort
## einen leeren Knoten „Fire…", dessen Größe die der Flamme ist. Das Modell selbst trägt nur
## die Glut darunter; die Flamme gehört hierher, denn sie bewegt sich (Effekte weich per
## Shader, nicht als Low-Poly-Kegel).
##
## Lichter kosten: im Compatibility-Renderer zeichnet jedes Punktlicht alles, was es trifft,
## noch einmal. Deshalb gibt es je Kampf nur wenige (GraphicsQuality.fire_lights), und eine
## Flamme ohne Licht leuchtet trotzdem über den Glow.
##
## Das Flackern läuft nach der Uhr wie die Flamme im Shader (TIME), nicht nach dem
## skalierten delta: Licht und Flamme bleiben beieinander, auch in der Zeitlupe.

const MARKER := "Fire"
const SHADER := preload("res://assets/shaders/flame.gdshader")
## Höhe zu Breite der Flamme.
const ASPECT := 1.7
## Licht je Meter Flamme: Reichweite und Helligkeit, und wie weit es über ihr sitzt.
const LIGHT_RANGE := 5.0
const LIGHT_ENERGY := 1.6
const LIGHT_LIFT := 0.45
const LIGHT_COLOR := Color(1.0, 0.56, 0.24)
## Wie stark das Licht flackert (Anteil der Helligkeit) und wie schnell.
const FLICKER := 0.35
const FLICKER_SPEED := 9.0

static var _material: ShaderMaterial
static var _quad: QuadMesh

var _light: OmniLight3D
var _energy := 0.0
var _phase := 0.0


## Zündet die Feuer in `model` (Knoten „Fire…") an; höchstens `lights` von ihnen bekommen
## ein Licht. Gibt zurück, wie viele Lichter es gebraucht hat.
static func kindle(model: Node3D, lights: int) -> int:
	if model == null:
		return 0
	var used := 0
	for marker: Node in model.find_children(MARKER + "*", "Node3D", true, false):
		var fire := Fire.new()
		fire.name = "Flame"
		(marker as Node3D).add_child(fire)
		if used < lights:
			fire._add_light()
			used += 1
	return used


func _ready() -> void:
	var flame := MeshInstance3D.new()
	flame.name = "FlameQuad"
	flame.mesh = _flame_mesh()
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	_phase = fmod(absf(global_position.x * 3.1 + global_position.z * 1.7), TAU)


func _add_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = LIGHT_COLOR
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, LIGHT_LIFT * ASPECT, 0.0)
	add_child(_light)


func _process(_delta: float) -> void:
	if _light == null:
		set_process(false)
		return
	# Die Größe der Flamme ist die des Knotens im Raum (Modell × Markierung).
	var size := global_basis.get_scale().y
	if _energy == 0.0:
		_light.omni_range = LIGHT_RANGE * size
		_energy = LIGHT_ENERGY * size
	var t := Time.get_ticks_msec() / 1000.0 * FLICKER_SPEED + _phase
	var flicker := sin(t) * 0.5 + sin(t * 2.3 + 1.1) * 0.3 + sin(t * 5.7 + 2.0) * 0.2
	_light.light_energy = _energy * (1.0 + FLICKER * flicker)


## Eine Flamme ist ein Quad von 1 × ASPECT mit dem Fuß im Ursprung — für alle dasselbe.
static func _flame_mesh() -> QuadMesh:
	if _quad == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.0, ASPECT)
		_quad.center_offset = Vector3(0.0, ASPECT * 0.5, 0.0)
		_quad.material = _material
	return _quad
