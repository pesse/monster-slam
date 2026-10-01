class_name GroundCover
extends RefCounted
## Der Bewuchs zwischen der Streudeko: Tausende kleiner Halmbüschel, Blüten darin und
## Sträucher um die Bäume. Erst er macht aus einer Fläche mit Bäumen darauf eine
## Landschaft — die Streudeko (WaveRunner._scatter) setzt einzelne Modelle, hier steht die
## Menge.
##
## Gezeichnet als MultiMesh: je Art EIN Knoten und ein Zeichenaufruf, egal wie viele
## Büschel. Die Formen sind klein und entstehen hier im Code; die Farbe kommt je Büschel aus
## dem Boden darunter (BattleTheme.ground_color), etwas heller — so passt der Bewuchs in
## jedem Thema, ohne dass eins eine eigene Graspalette braucht. Blüten (`cover_flowers`) und
## Sträucher (`bush_color`) haben ihre Farbe im Thema.
##
## Wie dicht, sagt das Thema (`cover`, `bushes`, 0 = keiner) mal die Grafikstufe
## (GraphicsQuality.cover). Auf dem Weg, in der Burg und im Schnee wächst nichts.

## Büschel je Quadratmeter bei `cover` = 1, bevor die Klumpen (CLUMP_*) ausdünnen.
const TUFT_DENSITY := 0.95
## Klumpen: Rauschen in dieser Frequenz, ab `CLUMP_FROM` wächst etwas, ab `CLUMP_FULL` voll.
## Gleichmäßig verteilt läse sich der Bewuchs als Raster; in Klumpen als Wiese.
const CLUMP_FREQUENCY := 0.09
const CLUMP_FROM := -0.1
const CLUMP_FULL := 0.85
## Abstand vom Wegrand, bis zu dem nichts wächst — und gleich dahinter mehr: am Wegrand
## steht das Gras am dichtesten (EDGE_BOOST mal so oft).
const PATH_MARGIN := 0.15
const EDGE_BAND := 1.6
const EDGE_BOOST := 1.6
## So viel heller als der Boden darunter (ohne `cover_color`): die Spitzen stehen im Licht.
const TUFT_LIFT := 1.3
## Hellster Kanal eines Büschels: auf hellem Boden (Savanne, Sand) blendete es sonst.
const TUFT_MAX := 0.8
const TUFT_SCALE := Vector2(1.1, 1.9)
## Anteil der Schneefarbe (BattleTheme.ground_snow), ab dem nichts mehr wächst.
const SNOW_LIMIT := 0.35
## Sträucher je Baum (zufällig 0 bis so viele) und wie weit vom Stamm.
const BUSHES_PER_TREE := 4
const BUSH_RING := Vector2(2.2, 4.5)
const BUSH_SCALE := Vector2(1.0, 1.8)
## Ausschlag im Wind (Wind.SWAY), Büschel wie grass.glb, Sträucher wie ein Baum.
const TUFT_SWAY := 0.12
const BUSH_SWAY := 0.02
## Wie TUFT_LIFT für die Sträucher.
const BUSH_LIFT := 1.7

static var _meshes := {}


## Die Stellschrauben, mit den Konstanten oben als Vorgabe. Das Spiel nimmt immer die;
## eigene Werte setzt nur die Werkbank (battle_theme_lab, Reiter Bewuchs), um sie am Bild zu
## finden — „Werte kopieren" schreibt sie dann als Konstanten heraus.
class Tuning:
	var tuft_density := TUFT_DENSITY
	var clump_from := CLUMP_FROM
	var clump_full := CLUMP_FULL
	var tuft_lift := TUFT_LIFT
	var tuft_scale := TUFT_SCALE
	var bushes_per_tree := BUSHES_PER_TREE
	## Obere Grenzen von BUSH_RING und BUSH_SCALE.
	var bush_ring := BUSH_RING.y
	var bush_scale := BUSH_SCALE.y


## Wo der Bewuchs wächst: der Boden eines Kampfes, wie WaveRunner und die Werkbank ihn
## kennen. `height(x, z)` und `t_at(x, z)` sind die des Bodens (WaveRunner.terrain_height,
## BattleTheme.ground_t), `on_screen(x, z)` sagt, ob die Stelle im Bild liegt.
class Site:
	var area: Rect2
	var on_screen: Callable
	var height: Callable
	var t_at: Callable
	var path: BattlePath
	## Hier wächst nichts: Burg und Hof hinter der Mauer.
	var keep_out := Rect2()
	## Fußpunkte der Bäume, um die Sträucher stehen.
	var trees: Array[Vector3] = []

	func free_at(x: float, z: float) -> bool:
		return not keep_out.has_point(Vector2(x, z)) and on_screen.call(x, z)


## Wächst unter `parent` auf `site`. `density` ist die der Grafikstufe
## (GraphicsQuality.cover); 0 heißt: keine Büschel, nur Sträucher.
static func grow(parent: Node3D, theme: BattleTheme, site: Site, density: float,
		rng: RandomNumberGenerator, tuning: Tuning = null) -> void:
	var plan := plan(theme, site, density, rng, tuning)
	_add(parent, "Tufts", _mesh("tuft"), plan.tufts, TUFT_SWAY, false)
	_add(parent, "Flowers", _mesh("flower"), plan.flowers, TUFT_SWAY, false)
	_add(parent, "Bushes", _mesh("bush"), plan.bushes, BUSH_SWAY, true)


## Was wo wächst, ohne es zu bauen: je Art (`tufts`, `flowers`, `bushes`) eine Liste aus
## [Transform3D, Color]. Getrennt von `grow`, weil ein MultiMesh seine Lagen kopflos nicht
## zurückgibt — der Test prüft hier.
static func plan(theme: BattleTheme, site: Site, density: float, rng: RandomNumberGenerator,
		tuning: Tuning = null) -> Dictionary:
	if tuning == null:
		tuning = Tuning.new()
	var out := {"tufts": [], "flowers": [], "bushes": []}
	_plan_tufts(out, theme, site, density, rng, tuning)
	_plan_bushes(out, theme, site, rng, tuning)
	return out


static func _plan_tufts(out: Dictionary, theme: BattleTheme, site: Site, density: float,
		rng: RandomNumberGenerator, tuning: Tuning) -> void:
	if density <= 0.0 or theme.cover <= 0.0:
		return
	var clumps := FastNoiseLite.new()
	clumps.seed = rng.randi()
	clumps.frequency = CLUMP_FREQUENCY
	var path := site.path
	for i in int(site.area.get_area() * tuning.tuft_density * theme.cover * density):
		var x := rng.randf_range(site.area.position.x, site.area.end.x)
		var z := rng.randf_range(site.area.position.y, site.area.end.y)
		var keep := smoothstep(tuning.clump_from, tuning.clump_full, clumps.get_noise_2d(x, z))
		if path != null and z < path.gate_z + 1.0:
			var edge := path.distance(x, z) - path.half_width()
			if edge < PATH_MARGIN:
				continue
			if edge < EDGE_BAND:
				keep = minf(keep * EDGE_BOOST + 0.25, 1.0)
		if rng.randf() >= keep or not site.free_at(x, z):
			continue
		var y: float = site.height.call(x, z)
		var t: float = site.t_at.call(x, z)
		if theme.ground_snow(t, y) > SNOW_LIMIT:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
				.scaled(Vector3.ONE * rng.randf_range(tuning.tuft_scale.x, tuning.tuft_scale.y))
		var at := Transform3D(basis, Vector3(x, y, z))
		var base := (theme.cover_color if theme.cover_color.a > 0.0
				else theme.ground_color(t, y)).srgb_to_linear() * tuning.tuft_lift
		var top := maxf(base.r, maxf(base.g, base.b))
		if top > TUFT_MAX:
			base *= TUFT_MAX / top
		out.tufts.append([at, _vary(base, rng)])
		if not theme.cover_flowers.is_empty() and rng.randf() < theme.cover_flower_amount:
			out.flowers.append([at, theme.cover_flowers[rng.randi() % theme.cover_flowers.size()]])


## Sträucher um die Bäume: so stehen die Bäume in Hainen mit Unterholz statt einzeln auf
## dem Rasen. Nicht von der Grafikstufe ausgedünnt — es sind wenige, und ohne sie stünden
## die Bäume in „Schnell" wieder nackt da.
static func _plan_bushes(out: Dictionary, theme: BattleTheme, site: Site,
		rng: RandomNumberGenerator, tuning: Tuning) -> void:
	if theme.bushes <= 0.0:
		return
	for tree in site.trees:
		for k in rng.randi_range(0, tuning.bushes_per_tree):
			if rng.randf() >= theme.bushes:
				continue
			var off := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(BUSH_RING.x, tuning.bush_ring)
			var x := tree.x + off.x
			var z := tree.z + off.y
			if (site.path != null and site.path.blocks(x, z, 0.8)) or not site.free_at(x, z):
				continue
			var s := rng.randf_range(BUSH_SCALE.x, tuning.bush_scale)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
					.scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s))
			var at := Transform3D(basis, Vector3(x, float(site.height.call(x, z)) - 0.05, z))
			var v := rng.randf_range(-0.06, 0.06)
			out.bushes.append([at, Color(theme.bush_color.r + v, theme.bush_color.g + v * 1.3,
					theme.bush_color.b + v * 0.5).srgb_to_linear() * BUSH_LIFT])


static func _vary(col: Color, rng: RandomNumberGenerator) -> Color:
	var v := rng.randf_range(0.9, 1.1)
	return Color(col.r * v, col.g * v * rng.randf_range(0.97, 1.05), col.b * v)


static func _add(parent: Node3D, node_name: String, mesh: Mesh, items: Array, sway: float,
		shadow: bool) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = _material(mesh, sway)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


## Der Windshader (Wind), mit Vertexfarbe mal Farbe des Büschels.
static func _material(mesh: Mesh, sway: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Wind.SHADER
	mat.set_shader_parameter("use_vertex_color", true)
	mat.set_shader_parameter("roughness", 1.0)
	mat.set_shader_parameter("specular", 0.2)
	mat.set_shader_parameter("sway_height", maxf(mesh.get_aabb().end.y, 0.001))
	mat.set_shader_parameter("sway", sway)
	return mat


## Die Formen werden einmal gebaut und geteilt; sie hängen an keinem Thema.
static func _mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			"tuft":
				_tuft(st, rng)
			"flower":
				_flower(st, rng)
			"bush":
				_bush(st, rng)
		_meshes[kind] = st.commit()
	return _meshes[kind]


## Neun Halme, nach außen geneigt, etwa 0.3 hoch (im Feld TUFT_SCALE mal so groß). Jeder Halm hat Vorder- und Rückseite
## mit eigener Fläche statt `cull_disabled`: so zeigen beide Normalen nach oben, und das
## Büschel ist so hell wie der Boden, auf dem es steht, statt von hinten dunkel.
static func _tuft(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 9:
		var yaw := TAU * i / 9.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-out.z, 0.0, out.x) * rng.randf_range(0.04, 0.06)
		var base := out * rng.randf_range(0.0, 0.07)
		var tip := base + out * rng.randf_range(0.08, 0.16) + Vector3.UP * rng.randf_range(0.2, 0.36)
		var low := Color(0.78, 0.78, 0.78)
		var high := Color(1.0, 1.0, 1.0)
		_blade(st, base - side, base + side, tip, low, high)


static func _blade(st: SurfaceTool, a: Vector3, b: Vector3, tip: Vector3, low: Color, high: Color) -> void:
	var face := (b - a).cross(tip - a).normalized()
	for sgn: float in [1.0, -1.0]:
		var n := (Vector3.UP * 1.5 + face * sgn * 0.5).normalized()
		var pts := [a, tip, b] if sgn > 0.0 else [a, b, tip]
		for p: Vector3 in pts:
			st.set_normal(n)
			st.set_color(high if p == tip else low)
			st.add_vertex(p)


## Drei kleine Blütenköpfe über einem Büschel, flache Doppelpyramiden.
static func _flower(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var c := Vector3(rng.randf_range(-0.09, 0.09), rng.randf_range(0.24, 0.34), rng.randf_range(-0.09, 0.09))
		var r := rng.randf_range(0.06, 0.09)
		var rim: Array[Vector3] = []
		for k in 5:
			var ang := TAU * k / 5.0
			rim.append(c + Vector3(cos(ang) * r, 0.0, sin(ang) * r))
		for k in 5:
			var p := rim[k]
			var q := rim[(k + 1) % 5]
			_tri(st, c + Vector3.UP * r * 0.5, p, q, Color.WHITE)
			_tri(st, c - Vector3.UP * r * 0.4, q, p, Color(0.7, 0.7, 0.7))


## Ein Strauch aus drei Klumpen, je eine zerknautschte Kugel; flach schattiert wie die
## Modelle, oben hell, unten dunkel. Etwa 1.4 breit und 1 hoch.
static func _bush(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var lobes := [[Vector3(0.0, 0.42, 0.0), 0.52], [Vector3(0.38, 0.3, 0.12), 0.38],
			[Vector3(-0.3, 0.28, -0.2), 0.4], [Vector3(0.05, 0.25, -0.4), 0.32]]
	for lobe: Array in lobes:
		_lobe(st, lobe[0], lobe[1], rng)


static func _lobe(st: SurfaceTool, c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	const RINGS := 4
	const SIDES := 7
	var grid: Array = []
	for i in RINGS + 1:
		var ring: Array[Vector3] = []
		var lat := PI * (float(i) / RINGS - 0.5)
		for k in SIDES:
			var lon := TAU * (k + 0.5 * (i % 2)) / SIDES
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			if i > 0 and i < RINGS:
				p *= rng.randf_range(0.88, 1.1)
			ring.append(c + p * r * Vector3(1.0, 0.85, 1.0))
		grid.append(ring)
	for i in RINGS:
		for k in SIDES:
			var a: Vector3 = grid[i][k]
			var b: Vector3 = grid[i][(k + 1) % SIDES]
			var d: Vector3 = grid[i + 1][k]
			var e: Vector3 = grid[i + 1][(k + 1) % SIDES]
			_shaded_tri(st, a, b, d, rng)
			_shaded_tri(st, b, e, d, rng)


static func _shaded_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-8:
		return
	var up := n.normalized().y + rng.randf_range(-0.15, 0.15)
	var shade := 1.0 if up > 0.5 else 0.82 if up > -0.2 else 0.62
	_tri(st, a, b, c, Color(shade, shade, shade))


## Ein Dreieck mit Flächennormale, im Uhrzeigersinn von außen (Godots Vorderseite).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(p)
