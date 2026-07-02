class_name Explosion
extends Node3D
## Kurzlebiger prozeduraler Explosionseffekt: heller expandierender Blast-Kern
## (Schockwelle) + Partikel-Burst aus leuchtenden Würfeln + Licht-Flash. Baut sich
## selbst auf und gibt sich nach der Lebensdauer selbst frei. Farbe/Größe via setup().

var _color: Color = Color(1.0, 0.6, 0.2)
var _scale: float = 1.0


func setup(color: Color, scale: float = 1.0) -> void:
	_color = color
	_scale = scale


func _ready() -> void:
	# --- Blast-Kern: heller Ball, der schnell aufblitzt, expandiert und ausblendet ---
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.albedo_color = Color(_color.r, _color.g, _color.b, 0.85)
	cmat.emission_enabled = true
	cmat.emission = _color
	cmat.emission_energy_multiplier = 4.0
	core.mesh = sphere
	core.material_override = cmat
	core.position = Vector3(0.0, 1.0, 0.0)
	core.scale = Vector3.ONE * 0.4
	add_child(core)
	var core_tw := create_tween()
	core_tw.set_parallel(true)
	core_tw.tween_property(core, "scale", Vector3.ONE * 3.0 * _scale, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	core_tw.tween_property(cmat, "albedo_color:a", 0.0, 0.35)

	# --- Partikel-Burst ---
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60
	p.lifetime = 0.9
	p.emitting = true

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.28 * _scale
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _color
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4 * _scale
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 6.0 * _scale
	p.initial_velocity_max = 14.0 * _scale
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.color = _color
	add_child(p)

	# --- Licht-Blitz ---
	var flash := OmniLight3D.new()
	flash.light_color = _color
	flash.light_energy = 9.0 * _scale
	flash.omni_range = 10.0 * _scale
	flash.position = Vector3(0.0, 1.0, 0.0)
	add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.3)

	await get_tree().create_timer(p.lifetime + 0.4).timeout
	queue_free()
