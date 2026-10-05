class_name Blast
extends Node3D
## Die Explosion des Explosionspfeils (Späher-Baum): größer und in Schichten, wo die
## `Explosion` ein Ball aus Würfeln ist. Nacheinander: weißer Blitz, Feuerball
## (fireball.gdshader), Druckwelle am Boden (shockwave.gdshader), Funken und Glut in der
## Wortfarbe des Monsters (spark.gdshader) und Rauch, der aus dem Feuer aufsteigt
## (smoke.gdshader). Weich und nicht Low-Poly wie die Modelle: kantige Effekte sahen neben
## ihnen billig aus.
## Baut sich selbst auf und gibt sich nach der Lebensdauer frei, wie die `Explosion`.
##
## Der Ursprung liegt am Boden unter dem Monster; der Feuerball sitzt auf Rumpfhöhe.
## Alle Zeiten laufen nach `Engine.time_scale` — die Zeitlupe dehnt den Knall.
##
## `plasma` ist der Einschlag des Donnerschlags (ADR 0014): kein Feuerball, sondern ein
## blauweißer Lichtball, blaue Funken und Druckwelle, und der Rauch glimmt blau statt orange.

const FIREBALL_SHADER := preload("res://assets/shaders/fireball.gdshader")
const SMOKE_SHADER := preload("res://assets/shaders/smoke.gdshader")
const SHOCKWAVE_SHADER := preload("res://assets/shaders/shockwave.gdshader")
const SPARK_SHADER := preload("res://assets/shaders/spark.gdshader")

## So hoch über dem Boden zündet der Feuerball.
const CORE_HEIGHT := 1.2
const FIRE_COLOR := Color(1.0, 0.55, 0.15)
## Der längste Teil: danach ist auch der letzte Rauch weg.
const LIFETIME := 2.6

var _debris_color: Color = Color(0.7, 1.0, 0.4)
var _scale: float = 1.0
var _plasma := false

## Die Farben des Donnerschlags.
const PLASMA_COLOR := Color(0.6, 0.78, 1.0)


## `debris_color`: die Brocken, die fliegen — die Wortfarbe des getroffenen Monsters.
func setup(debris_color: Color, scale: float = 1.0, plasma := false) -> void:
	_debris_color = debris_color
	_scale = scale
	_plasma = plasma


func _ready() -> void:
	_flash()
	if not _plasma:
		_fireball()
	_shockwave()
	_sparks()
	_debris()
	_smoke()
	# process_always = false: in der Baum-Pause bleibt der Knall stehen (wie Explosion).
	# Verbunden statt abgewartet: FxWarmup gibt den Knall vor dem Timer frei, und ein
	# await liefe dann ins Leere.
	get_tree().create_timer(LIFETIME, false).timeout.connect(queue_free)


## Weißer Kern, der nur einen Augenblick steht, und ein warmes Licht, das ausklingt.
func _flash() -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.9, 1.0) if _plasma else Color(1.0, 0.95, 0.8)
	mat.emission_energy_multiplier = 9.0 if _plasma else 6.0
	core.mesh = sphere
	core.material_override = mat
	core.position = Vector3(0.0, CORE_HEIGHT, 0.0)
	core.scale = Vector3.ONE * 1.2 * _scale
	add_child(core)
	# Das Plasma steht länger und größer: es ersetzt den Feuerball.
	var grow := 4.0 if _plasma else 2.6
	var hold := 0.22 if _plasma else 0.12
	var tw := create_tween().set_parallel(true)
	tw.tween_property(core, "scale", Vector3.ONE * grow * _scale, hold).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, hold).set_delay(0.04)
	tw.chain().tween_callback(core.queue_free)

	var light := OmniLight3D.new()
	light.light_color = PLASMA_COLOR if _plasma else Color(1.0, 0.7, 0.35)
	light.light_energy = (20.0 if _plasma else 14.0) * _scale
	light.omni_range = 14.0 * _scale
	light.position = Vector3(0.0, CORE_HEIGHT, 0.0)
	add_child(light)
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 5.0 * _scale, 0.1)
	lt.tween_property(light, "light_energy", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Die Kugel wächst schnell, steigt ein wenig und verglüht über `progress`.
func _fireball() -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	# Fein genug, dass die Beulen des Rauschens rund bleiben — ein Effekt, kein Modell.
	sphere.radial_segments = 96
	sphere.rings = 48
	var mat := ShaderMaterial.new()
	mat.shader = FIREBALL_SHADER
	mat.set_shader_parameter("seed", Vector3(randf(), randf(), randf()) * 40.0)
	mat.set_shader_parameter("progress", 0.0)
	ball.mesh = sphere
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = Vector3(0.0, CORE_HEIGHT, 0.0)
	ball.scale = Vector3.ONE * 0.3 * _scale
	add_child(ball)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 2.5 * _scale, 0.35) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "position:y", CORE_HEIGHT + 0.8 * _scale, 0.9) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v),
			0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ball.queue_free)


## Flacher Ring knapp über dem Boden.
func _shockwave() -> void:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 12.0 * _scale
	quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE_SHADER
	mat.set_shader_parameter("progress", 0.0)
	if _plasma:
		mat.set_shader_parameter("color", PLASMA_COLOR)
		mat.set_shader_parameter("energy", 4.0)
	ring.mesh = quad
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.08, 0.0)
	add_child(ring)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v),
			0.0, 1.0, 0.55)
	tw.tween_callback(ring.queue_free)


## Schnelle, weiche Glutstreifen (spark.gdshader), die in Flugrichtung zeigen und fallen.
func _sparks() -> void:
	var p := _streaks(80, 0.9, PLASMA_COLOR if _plasma else Color(1.0, 0.7, 0.3), 6.0)
	p.emission_sphere_radius = 0.3 * _scale
	p.spread = 180.0
	p.initial_velocity_min = 9.0 * _scale
	p.initial_velocity_max = 22.0 * _scale
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.scale_amount_min = 0.07 * _scale
	p.scale_amount_max = 0.12 * _scale
	add_child(p)


## Glut in der Wortfarbe des Monsters: langsamer und größer als die Funken, steigt in einem
## Bogen und fällt — was vom Monster übrig ist, in seiner Farbe.
func _debris() -> void:
	var p := _streaks(28, 1.4, _debris_color, 2.5)
	p.emission_sphere_radius = 0.5 * _scale
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 5.0 * _scale
	p.initial_velocity_max = 11.0 * _scale
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.scale_amount_min = 0.14 * _scale
	p.scale_amount_max = 0.26 * _scale
	add_child(p)


## Ein Schub gestreckter Leuchtstreifen: Partikel an ihrer Flugrichtung ausgerichtet, die
## Größe (scale_amount) ist die Breite, `stretch` das Verhältnis zur Länge. Sie verblassen
## über die Lebenszeit (color_ramp) und werden dabei kürzer.
func _streaks(amount: int, lifetime: float, tint: Color, stretch: float) -> CPUParticles3D:
	var p := _burst_particles(amount, lifetime)
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("stretch", stretch)
	quad.material = mat
	p.mesh = quad
	p.particle_flag_align_y = true
	p.scale_amount_curve = _fade_curve()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 0.6, 0.4, 0.0))
	p.color_ramp = ramp
	return p


## Puffs, die als Feuer beginnen (Glut im Shader) und als Rauch aufsteigen, wachsen und
## vergehen. Zwei Schübe: ein dichter Kern und ein lockerer Kranz nach außen.
func _smoke() -> void:
	for ring in 2:
		var p := _burst_particles(16 if ring == 0 else 12, 2.2 if ring == 0 else 1.7)
		p.explosiveness = 0.85
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 2.0 * _scale
		var mat := ShaderMaterial.new()
		mat.shader = SMOKE_SHADER
		mat.set_shader_parameter("ember", 0.3 if ring == 0 else 0.15)
		if _plasma:
			mat.set_shader_parameter("ember_color", Vector3(0.4, 0.6, 1.0))
		quad.material = mat
		p.mesh = quad
		p.emission_sphere_radius = (0.5 if ring == 0 else 1.0) * _scale
		p.direction = Vector3.UP
		p.spread = 50.0 if ring == 0 else 100.0
		p.initial_velocity_min = (1.5 if ring == 0 else 3.0) * _scale
		p.initial_velocity_max = (3.0 if ring == 0 else 5.5) * _scale
		p.damping_min = 2.0
		p.damping_max = 3.5
		p.gravity = Vector3(0.0, 1.2, 0.0)
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -30.0
		p.angular_velocity_max = 30.0
		p.scale_amount_min = 0.9
		p.scale_amount_max = 1.5
		var grow := Curve.new()
		grow.max_value = 3.0
		grow.add_point(Vector2(0.0, 0.6))
		grow.add_point(Vector2(1.0, 2.6))
		p.scale_amount_curve = grow
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.16, 0.14, 0.13, 0.0))
		ramp.set_color(1, Color(0.6, 0.58, 0.56, 0.0))
		ramp.add_point(0.06, Color(0.18, 0.16, 0.15, 1.0))
		ramp.add_point(0.55, Color(0.38, 0.36, 0.35, 0.8))
		p.color_ramp = ramp
		add_child(p)


func _burst_particles(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.position = Vector3(0.0, CORE_HEIGHT, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emitting = true
	return p


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
