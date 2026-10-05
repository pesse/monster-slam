class_name SlowAura
extends Node3D
## Zäher Schlamm unter einem gebremsten Monster (Sumpf, Schwere Luft, ADR 0014): ein
## glänzender, moosgrüner Fleck, der mitläuft, mit Ringen und ein paar aufsteigenden Blasen.
## Er quillt beim Bremsen auf und bleibt, solange das Monster gebremst ist — also bis zum Ende
## seiner Welle, mit ihm zusammen.

const MARK_SHADER := preload("res://assets/shaders/ground_mark.gdshader")
const SPARK_SHADER := preload("res://assets/shaders/spark.gdshader")

## Brauner Schlamm, damit er sich vom Gras abhebt; das Grün kommt aus dem Leuchten.
const COLOR := Color(0.5, 0.38, 0.16, 0.9)
const GLOW := Color(0.55, 0.9, 0.2)
## Breit genug, dass der Fleck unter dem Monster hervorschaut.
const SIZE := 6.0

var _mat := ShaderMaterial.new()


func _ready() -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE
	quad.orientation = PlaneMesh.FACE_Y
	_mat.shader = MARK_SHADER
	_mat.set_shader_parameter("color", COLOR)
	_mat.set_shader_parameter("glow_color", Vector3(GLOW.r, GLOW.g, GLOW.b))
	_mat.set_shader_parameter("ripples", 1.0)
	_mat.set_shader_parameter("ring_energy", 3.0)
	_mat.set_shader_parameter("glow", 2.0)
	_mat.set_shader_parameter("seed", randf())
	mark.mesh = quad
	mark.material_override = _mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position.y = 0.05
	add_child(mark)
	add_child(_bubbles())
	scale = Vector3(0.2, 1.0, 0.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Blasen, die aus dem Schlamm steigen und vergehen.
func _bubbles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.9
	p.position.y = 0.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = SIZE * 0.35
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.0
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.18
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	mat.set_shader_parameter("tint", Vector3(GLOW.r, GLOW.g, GLOW.b))
	mat.set_shader_parameter("stretch", 1.2)
	mat.set_shader_parameter("energy", 1.6)
	quad.material = mat
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 0.9))
	p.color_ramp = ramp
	return p
