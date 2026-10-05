class_name FrostShell
extends Node3D
## Das Eis um ein eingefrorenes Monster (Frost, ADR 0014): eine durchscheinende Hülle in der
## Größe des Körpers, ein Kranz Eiskristalle an den Füßen und Raureif am Boden. Sie wächst
## beim Gefrieren mit einem Aufleuchten heran, bekommt in den letzten Sekunden Risse
## (`tick`) und zerspringt beim Auftauen in Splitter (`shatter`).
##
## Hängt am Monster (Monster.freeze) und geht mit ihm: wer es vorher besiegt, nimmt das Eis
## mit. Die Kristalle sind Körper wie die Modelle, die Splitter weich wie die übrigen Effekte.

const SHADER := preload("res://assets/shaders/ice_shell.gdshader")
const MARK_SHADER := preload("res://assets/shaders/ground_mark.gdshader")
const SPARK_SHADER := preload("res://assets/shaders/spark.gdshader")

const TINT := Color(0.62, 0.86, 1.0)
## So lange vor dem Auftauen ziehen die Risse auf (s).
const CRACK_TIME := 1.6
const GROW_TIME := 0.28

var _mat := ShaderMaterial.new()
var _mark_mat := ShaderMaterial.new()
var _shell: MeshInstance3D
var _box := AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 2.4, 1.2))
var _breaking := false


## `box`: die Hülle des Körpers im Rahmen des Monsters (Monster.body_box).
func setup(box: AABB) -> void:
	_box = box


func _ready() -> void:
	_mat.shader = SHADER
	_mat.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	var radius := maxf(0.7, maxf(_box.size.x, _box.size.z) * 0.62)
	var height := maxf(1.6, _box.end.y * 1.08)
	_shell = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	capsule.radial_segments = 32
	capsule.rings = 12
	_shell.mesh = capsule
	_shell.material_override = _mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.position = Vector3(_box.get_center().x, capsule.height * 0.5, _box.get_center().z)
	add_child(_shell)
	_crystals(radius)
	_rime(radius)
	# Heranwachsen mit einem Aufleuchten.
	scale = Vector3.ONE * 0.4
	_mat.set_shader_parameter("flash", 2.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, GROW_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("flash", v),
			2.5, 0.0, 0.6)


## Noch `left` Sekunden gefroren: in den letzten CRACK_TIME ziehen Risse auf, und die Hülle
## zittert.
func tick(left: float) -> void:
	if _breaking:
		return
	var crack := clampf(1.0 - left / CRACK_TIME, 0.0, 1.0)
	_mat.set_shader_parameter("cracks", crack)
	_shell.position.x = _box.get_center().x + sin(left * 70.0) * 0.03 * crack


## Taut auf: Splitter fliegen, die Hülle blitzt und vergeht.
func shatter() -> void:
	if _breaking:
		return
	_breaking = true
	_shards()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_shell, "scale", Vector3.ONE * 1.15, 0.12)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.18)
	tw.tween_method(func(v: float) -> void: _mark_mat.set_shader_parameter("fade", v),
			1.0, 0.0, 0.8)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_callback(queue_free)


## Fünf Kristalle im Kranz um die Füße, nach außen gekippt.
func _crystals(radius: float) -> void:
	for i in 5:
		var crystal := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = randf_range(0.28, 0.45)
		prism.height = randf_range(1.1, 1.9)
		prism.radial_segments = 5
		prism.rings = 1
		crystal.mesh = prism
		crystal.material_override = _mat
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * (float(i) + randf_range(-0.25, 0.25)) / 5.0
		var out := Vector3(cos(angle), 0.0, sin(angle))
		crystal.position = _box.get_center() * Vector3(1, 0, 1) + out * radius * 1.05 \
				+ Vector3(0.0, prism.height * 0.35, 0.0)
		crystal.basis = Basis(Vector3.UP.cross(out).normalized(), deg_to_rad(randf_range(20.0, 40.0)))
		add_child(crystal)


## Weißer Reif am Boden.
func _rime(radius: float) -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 4.0
	quad.orientation = PlaneMesh.FACE_Y
	_mark_mat.shader = MARK_SHADER
	_mark_mat.set_shader_parameter("color", Color(0.86, 0.94, 1.0, 0.75))
	_mark_mat.set_shader_parameter("glow_color", Vector3(0.55, 0.8, 1.0))
	_mark_mat.set_shader_parameter("glow", 1.5)
	_mark_mat.set_shader_parameter("seed", randf())
	mark.mesh = quad
	mark.material_override = _mark_mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = Vector3(_box.get_center().x, 0.06, _box.get_center().z)
	add_child(mark)


func _shards() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 36
	p.lifetime = 0.9
	p.position = _shell.position
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -16.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	mat.set_shader_parameter("tint", Vector3(0.75, 0.92, 1.0))
	mat.set_shader_parameter("stretch", 2.5)
	quad.material = mat
	p.mesh = quad
	p.particle_flag_align_y = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
