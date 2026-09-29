class_name AmbientParticles
extends RefCounted
## Was in der Luft des Schlachtfelds treibt: Laub, Schnee, Staub, Pollen, Glühwürmchen.
##
## Welches, sagt das Thema (`BattleTheme.particles`); wie es aussieht, steht hier. Kleine
## einfarbige Plättchen ohne Textur, wie der Rest der Low-Poly-Welt. CPUParticles3D, weil
## gl_compatibility die GPU-Partikel nur eingeschränkt kann; die paar hundert kosten nichts.
## Sie laufen mit dem skalierten delta, in der Zeitlupe also langsamer.
##
## Dicht ist je 1000 m² Boden, damit ein breiteres Fenster nicht dünner schneit.

const KINDS := ["leaves", "snow", "dust", "pollen", "fireflies"]

## Je Art: Dichte, Lebensdauer, Höhe (von–bis), Richtung, Tempo (von–bis), Streuung in Grad,
## Größe, Drehung in Grad/s, Farben (zufällig je Teilchen) und Helligkeit des Materials.
const SPEC := {
	"leaves": {"density": 25.0, "lifetime": 10.0, "y": [1.0, 12.0], "dir": Vector3(0.5, -1.0, 0.35),
		"speed": [0.9, 1.4], "spread": 25.0, "size": 0.42, "spin": 200.0,
		"colors": [Color(0.78, 0.25, 0.12), Color(0.9, 0.48, 0.14), Color(0.92, 0.72, 0.2), Color(0.55, 0.32, 0.16)],
		"glow": 1.0},
	"snow": {"density": 150.0, "lifetime": 8.0, "y": [0.5, 12.0], "dir": Vector3(0.2, -1.0, 0.15),
		"speed": [1.2, 1.8], "spread": 10.0, "size": 0.17, "spin": 0.0,
		"colors": [Color(0.95, 0.97, 1.0), Color(0.86, 0.9, 0.98)], "glow": 1.0},
	"dust": {"density": 18.0, "lifetime": 7.0, "y": [0.2, 2.6], "dir": Vector3(0.8, 0.05, 0.6),
		"speed": [0.6, 1.4], "spread": 20.0, "size": 0.2, "spin": 0.0,
		"colors": [Color(1.0, 0.93, 0.8, 0.6), Color(0.96, 0.86, 0.7, 0.5)], "glow": 1.0},
	"pollen": {"density": 20.0, "lifetime": 8.0, "y": [0.3, 4.0], "dir": Vector3(0.8, 0.3, 0.6),
		"speed": [0.2, 0.5], "spread": 60.0, "size": 0.12, "spin": 0.0,
		"colors": [Color(1.0, 0.97, 0.8, 0.85), Color(1.0, 0.92, 0.65, 0.85)], "glow": 1.0},
	"fireflies": {"density": 14.0, "lifetime": 5.0, "y": [0.3, 2.5], "dir": Vector3(0.0, 1.0, 0.0),
		"speed": [0.1, 0.4], "spread": 180.0, "size": 0.18, "spin": 0.0,
		"colors": [Color(0.85, 1.0, 0.45), Color(1.0, 0.95, 0.5)], "glow": 2.2},
}


## Die Teilchen der Art `kind` über dem Boden `area` (x/z in Weltmetern), oder null, wenn
## das Thema keine hat (leer) oder die Art unbekannt ist.
static func build(kind: String, area: Rect2) -> CPUParticles3D:
	if kind.is_empty():
		return null
	if not SPEC.has(kind):
		push_warning("AmbientParticles: unbekannte Art '%s'" % kind)
		return null
	var spec: Dictionary = SPEC[kind]
	var p := CPUParticles3D.new()
	p.name = "AmbientParticles"
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = clampi(int(spec.density * area.get_area() / 1000.0), 8, 1200)
	p.lifetime = spec.lifetime
	# Schon beim Aufziehen des Schleiers voll, nicht erst nach einer Lebensdauer.
	p.preprocess = spec.lifetime
	p.randomness = 1.0
	var y: Array = spec.y
	var center := area.get_center()
	p.position = Vector3(center.x, (y[0] + y[1]) * 0.5, center.y)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area.size.x * 0.5, (y[1] - y[0]) * 0.5, area.size.y * 0.5)
	p.direction = (spec.dir as Vector3).normalized()
	p.spread = spec.spread
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = spec.speed[0]
	p.initial_velocity_max = spec.speed[1]
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -spec.spin
	p.angular_velocity_max = spec.spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.color_initial_ramp = _palette(spec.colors)
	p.color_ramp = _fade(kind == "fireflies")
	p.mesh = _flake(spec.size, spec.glow)
	return p


## Zufallsfarbe je Teilchen: harte Stufen, keine Mischtöne dazwischen.
static func _palette(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / colors.size(), colors[i])
	return g


## Ein- und Ausblenden über die Lebensdauer — kein Teilchen erscheint oder verschwindet
## schlagartig. Glühwürmchen blinken dazwischen.
static func _fade(blink: bool) -> Gradient:
	var g := Gradient.new()
	if blink:
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.15),
				Color(1, 1, 1, 1), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1),
				Color(1, 1, 1, 0)])
	return g


## Ein unbeleuchtetes Plättchen, das zur Kamera schaut und sich in ihrer Ebene dreht.
static func _flake(size: float, glow: float) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(glow, glow, glow)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad
