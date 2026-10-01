class_name AmbientParticles
extends RefCounted
## Was in der Luft des Schlachtfelds treibt: Laub, Schnee, Pollen, Glühwürmchen, Asche, Glut.
##
## Welches, sagt das Thema (`BattleTheme.particles`); wie es aussieht, steht hier. Kleine
## einfarbige Plättchen ohne Textur, wie der Rest der Low-Poly-Welt. Nur was dort auch
## wirklich in der Luft wäre: Schweben braucht einen Grund (Schnee fällt, Pollen und
## Glühwürmchen fliegen) — schwebender Staub über der Wüste hatte keinen und ist raus.
##
## Laub fällt aus den Kronen der Laubbäume (`crowns`, LEAF_TREES), nicht aus der Luft: es
## sind Blätter, keine Plättchen, und sie kippen im Fallen (scale_curve_x). Ohne Kronen
## fällt es über der ganzen Fläche. Kirschblüten (`blossoms`) fallen genauso, aber unabhängig
## von der Art des Themas: wo ein Blütenbaum steht (BLOSSOM_TREES), fallen sie — auch
## neben den Pollen der Frühlingswiese. CPUParticles3D, weil
## gl_compatibility die GPU-Partikel nur eingeschränkt kann; die paar hundert kosten nichts.
## Sie laufen mit dem skalierten delta, in der Zeitlupe also langsamer.
##
## Asche und Glut haben ihren Grund in einem brennenden Gebiet (Ruinen nach der Katastrophe):
## Asche rieselt langsam und taumelnd, Glut steigt leuchtend auf und flackert. Zur Asche
## gehört immer etwas Glut (`with`), allein steigt nur Glut auf.
##
## Dicht ist je 1000 m² Boden, damit ein breiteres Fenster nicht dünner schneit.

const KINDS := ["leaves", "snow", "pollen", "fireflies", "ash", "embers"]
## Arten, die beim Schweben aufblinken statt gleichmäßig zu leuchten.
const BLINKING := ["fireflies", "embers"]

## Bäume, deren Kronen Laub abwerfen (Dateiname ohne Endung) — kein Nadelbaum, kein Haus.
const LEAF_TREES := ["autumn_red", "autumn_orange", "autumn_yellow", "tree", "park_tree", "plane_tree", "vine_row"]
## Blätter je Krone, die gleichzeitig unterwegs sind.
const LEAVES_PER_CROWN := 5.0
## Startpunkte je Krone: im oberen Teil der Krone verteilt.
const POINTS_PER_CROWN := 8
## Aus der Krone: so lange und so schnell, dass ein Blatt aus 7 m knapp unter dem Boden
## ausblendet — länger fiele es unsichtbar weiter und fehlte in der Luft.
const CROWN_FALL_TIME := 7.0
const CROWN_FALL_SPEED := Vector2(0.7, 1.0)

## Bäume, aus deren Kronen Blütenblätter fallen.
const BLOSSOM_TREES := ["blossom_tree"]
## Blüten: kleiner als Laub, mehr davon, sie segeln langsamer.
## Unbeleuchtet: zartes Rosa käme fast weiß heraus, deshalb kräftiger als die Krone.
const BLOSSOM := {"per_crown": 10.0, "size": 0.3, "fall_time": 9.0, "speed": Vector2(0.45, 0.75),
	"spin": 260.0, "colors": [Color(0.96, 0.55, 0.72), Color(0.9, 0.45, 0.64), Color(1.0, 0.72, 0.84)]}

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
	"pollen": {"density": 20.0, "lifetime": 8.0, "y": [0.3, 4.0], "dir": Vector3(0.8, 0.3, 0.6),
		"speed": [0.2, 0.5], "spread": 60.0, "size": 0.12, "spin": 0.0,
		"colors": [Color(1.0, 0.97, 0.8, 0.85), Color(1.0, 0.92, 0.65, 0.85)], "glow": 1.0},
	"fireflies": {"density": 14.0, "lifetime": 5.0, "y": [0.3, 2.5], "dir": Vector3(0.0, 1.0, 0.0),
		"speed": [0.1, 0.4], "spread": 180.0, "size": 0.18, "spin": 0.0,
		"colors": [Color(0.85, 1.0, 0.45), Color(1.0, 0.95, 0.5)], "glow": 2.2},
	"ash": {"density": 60.0, "lifetime": 14.0, "y": [0.3, 10.0], "dir": Vector3(0.6, -1.0, 0.4),
		"speed": [0.35, 0.75], "spread": 35.0, "size": 0.16, "spin": 140.0,
		"colors": [Color(0.22, 0.21, 0.21), Color(0.34, 0.33, 0.32), Color(0.46, 0.45, 0.44)],
		"glow": 1.0, "with": "embers"},
	"embers": {"density": 10.0, "lifetime": 6.0, "y": [0.2, 3.5], "dir": Vector3(0.35, 1.0, 0.2),
		"speed": [0.4, 1.0], "spread": 30.0, "size": 0.1, "spin": 0.0,
		"colors": [Color(1.0, 0.45, 0.12), Color(1.0, 0.62, 0.2), Color(0.95, 0.3, 0.08)],
		"glow": 2.6},
}


## Die Teilchen der Art `kind` über dem Boden `area` (x/z in Weltmetern), oder null, wenn
## das Thema keine hat (leer) oder die Art unbekannt ist. Laub fällt aus `crowns` (Kronen
## der Laubbäume, Weltraum; `crown_of`), wenn es welche gibt.
static func build(kind: String, area: Rect2, crowns: Array[AABB] = []) -> CPUParticles3D:
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
	p.color_ramp = _fade(BLINKING.has(kind))
	p.mesh = _flake(spec.size, spec.glow)
	if kind == "leaves":
		_as_leaves(p, spec, crowns)
	if spec.has("with"):
		var other := build(str(spec.with), area, crowns)
		# Der Begleiter liegt im Ursprung des Elternteils, nicht noch einmal versetzt.
		other.position -= p.position
		p.add_child(other)
	return p


## Laub: Blattform, kippt im Fallen, und — mit Kronen — fällt es von den Bäumen. Die
## Lebensdauer reicht von der Krone bis knapp unter den Boden; was darunter ist, verdeckt
## der Boden.
static func _as_leaves(p: CPUParticles3D, spec: Dictionary, crowns: Array[AABB]) -> void:
	p.mesh = _leaf(spec.size, spec.glow)
	p.split_scale = true
	p.scale_curve_x = _flutter()
	p.scale_curve_y = _constant(1.0)
	p.scale_curve_z = _constant(1.0)
	if crowns.is_empty():
		return
	_from_crowns(p, crowns, LEAVES_PER_CROWN, CROWN_FALL_TIME, CROWN_FALL_SPEED)


## Kirschblüten aus den Kronen `crowns` der Blütenbäume, oder null ohne Kronen.
static func blossoms(crowns: Array[AABB]) -> CPUParticles3D:
	if crowns.is_empty():
		return null
	var p := CPUParticles3D.new()
	p.name = "Blossoms"
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.randomness = 1.0
	p.direction = (SPEC.leaves.dir as Vector3).normalized()
	p.spread = 35.0
	p.gravity = Vector3.ZERO
	p.angle_max = 360.0
	p.angular_velocity_min = -BLOSSOM.spin
	p.angular_velocity_max = BLOSSOM.spin
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.color_initial_ramp = _palette(BLOSSOM.colors)
	p.color_ramp = _fade(false)
	p.mesh = _petal(BLOSSOM.size)
	p.split_scale = true
	p.scale_curve_x = _flutter()
	p.scale_curve_y = _constant(1.0)
	p.scale_curve_z = _constant(1.0)
	_from_crowns(p, crowns, BLOSSOM.per_crown, BLOSSOM.fall_time, BLOSSOM.speed)
	return p


## Startpunkte im oberen Teil der Kronen; die Lebensdauer reicht bis knapp unter den Boden.
static func _from_crowns(p: CPUParticles3D, crowns: Array[AABB], per_crown: float,
		fall_time: float, speed: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crowns.size()
	var points := PackedVector3Array()
	for crown in crowns:
		for k in POINTS_PER_CROWN:
			points.append(Vector3(rng.randf_range(crown.position.x, crown.end.x),
					rng.randf_range(crown.position.y + crown.size.y * 0.5, crown.end.y),
					rng.randf_range(crown.position.z, crown.end.z)))
	p.position = Vector3.ZERO
	p.lifetime = fall_time
	p.preprocess = fall_time
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.amount = clampi(int(crowns.size() * per_crown), 8, 600)


## Die Krone eines aufgestellten Baums: der Umriss seiner Meshes in Weltkoordinaten. Null-
## große AABB, wenn er keine hat.
static func crown_of(tree: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes := tree.find_children("*", "MeshInstance3D", true, false)
	if tree is MeshInstance3D:
		meshes.append(tree)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Hin- und herkippen über die Lebensdauer: die Breite des Blatts schwingt zwischen voll und
## schmal, als drehte es sich um die eigene Achse.
static func _flutter() -> Curve:
	var c := Curve.new()
	const STEPS := 24
	for i in STEPS + 1:
		var t := float(i) / STEPS
		c.add_point(Vector2(t, 0.2 + 0.8 * absf(cos(t * TAU * 3.0))))
	return c


static func _constant(v: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, v))
	c.add_point(Vector2(1.0, v))
	return c


## Ein Blatt: spitz zulaufend mit kurzem Stiel, flach zur Kamera wie die Plättchen.
static func _leaf(size: float, glow: float) -> ArrayMesh:
	var outline := [Vector2(0.0, 0.5), Vector2(0.2, 0.28), Vector2(0.26, 0.02), Vector2(0.18, -0.22),
			Vector2(0.0, -0.36), Vector2(-0.18, -0.22), Vector2(-0.26, 0.02), Vector2(-0.2, 0.28)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	for i in outline.size():
		var a: Vector2 = outline[i] * size
		var b: Vector2 = outline[(i + 1) % outline.size()] * size
		for v: Vector2 in [Vector2.ZERO, b, a]:
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(v.x, v.y, 0.0))
	# Stiel
	for v: Vector2 in [Vector2(-0.02, -0.34), Vector2(0.02, -0.34), Vector2(0.0, -0.5)]:
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v.x, v.y, 0.0) * size)
	var mesh := st.commit()
	var mat := _flake(size, glow).material.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


## Ein Blütenblatt: rundlich mit einer Kerbe an der Spitze, ohne Stiel.
static func _petal(size: float) -> ArrayMesh:
	var outline := [Vector2(0.0, 0.36), Vector2(0.14, 0.5), Vector2(0.3, 0.32), Vector2(0.32, 0.04),
			Vector2(0.2, -0.28), Vector2(0.0, -0.46), Vector2(-0.2, -0.28), Vector2(-0.32, 0.04),
			Vector2(-0.3, 0.32), Vector2(-0.14, 0.5)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2 = outline[i] * size
		var b: Vector2 = outline[(i + 1) % outline.size()] * size
		for v: Vector2 in [Vector2(0.0, -0.05) * size, b, a]:
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(v.x, v.y, 0.0))
	var mesh := st.commit()
	var mat := _flake(size, 1.0).material.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


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
