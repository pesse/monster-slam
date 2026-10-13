class_name Fire
extends Node3D
## Ein Feuer in der Deko: eine Flamme (flame.gdshader) an jedem Knoten „Fire…“ des Modells,
## dessen Größe die der Flamme ist, und höchstens wenige flackernde Lichter: im
## Compatibility-Renderer zeichnet jedes Punktlicht alles, was es trifft, noch einmal.
## Das Flackern läuft nach der Uhr wie `TIME` im Shader, damit Licht und Flamme auch in der
## Zeitlupe beieinander bleiben.

const MARKER := "Fire"
const SHADER := preload("res://assets/shaders/flame.gdshader")
## Höhe zu Breite der Flamme.
const ASPECT := 1.7
## Licht je Meter Flamme: Reichweite (m), Helligkeit und Höhe über dem Fuß (Anteil der Breite).
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
	# Phase aus dem Ort, damit benachbarte Feuer nicht im Takt flackern.
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
	# Drei unharmonische Sinus, Ausschlag höchstens ±1.
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
