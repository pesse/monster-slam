class_name Tumbleweeds
extends Node3D
## Steppenläufer: selten rollt ein verdorrter Busch mit dem Wind durch Wüste und Savanne,
## hüpft über den Boden und verschwindet am Rand. Statt schwebendem Staub — der hatte dort
## keinen Grund, ein rollender Busch hat einen.
##
## Welche Themen, sagt `BattleTheme.tumbleweeds`. Die Form entsteht hier im Code (ein Knäuel
## aus dünnen Zweigen), gerollt wird nach dem skalierten delta: in der Zeitlupe langsamer.
## Ein Busch rollt um die Burg herum nicht hindurch — er verschwindet vorher (`keep_out`).

## Windrichtung wie im Windshader (wind.gdshaderinc, WIND_DIR).
const WIND_DIR := Vector2(0.8, 0.6)
## Abstand zwischen zwei Büschen in Sekunden: selten, er soll etwas Besonderes bleiben.
## Der erste kommt etwas früher, damit man ihn in einer Welle auch einmal sieht.
const INTERVAL := Vector2(10.0, 60.0)
const FIRST := Vector2(10.0, 25.0)
## Immer nur einer.
const MAX_ALIVE := 1
## Größer als ein echter, damit er im schrägen Blick aus der Ferne noch zu lesen ist.
const RADIUS := Vector2(0.75, 1.1)
const SPEED := Vector2(7.0, 12.0)
## Sprünge: so hoch (in Radien) und so oft je Meter.
const HOP := 0.8
const HOPS_PER_M := 0.18
## So lange schrumpft ein Busch weg, wenn er die Fläche verlässt oder an die Burg kommt.
const FADE := 0.6

var area: Rect2
## Höhe des Bodens bei (x, z) (WaveRunner.terrain_height).
var height: Callable
## Hier rollt keiner hinein (Burg und Hof).
var keep_out := Rect2()
## Liegt (x, z) im Bild? Gestartet wird knapp außerhalb davon — die Fläche ist der Umriss des
## schrägen Blicks und viel größer als das Bild, ein Start an ihrem Rand bliebe lange
## unsichtbar. Ohne gilt die Fläche.
var on_screen := Callable()
var rng := RandomNumberGenerator.new()

var _wait := 0.0
var _weeds: Array[Dictionary] = []

static var _mesh: Mesh


## Ein Steppenläufer-Feld über `area`. `seed_value` würfelt Zeitpunkte und Bahnen.
static func make(ground: Rect2, ground_height: Callable, fortress: Rect2, seed_value: int) -> Tumbleweeds:
	var t := Tumbleweeds.new()
	t.name = "Tumbleweeds"
	t.area = ground
	t.height = ground_height
	t.keep_out = fortress
	t.rng.seed = seed_value
	t._wait = t.rng.randf_range(FIRST.x, FIRST.y)
	return t


## Ein Busch zum Vorwärmen (FxWarmup): dasselbe Mesh und Material, ohne Bewegung.
static func specimen() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh()
	return mi


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = rng.randf_range(INTERVAL.x, INTERVAL.y)
		if _weeds.size() < MAX_ALIVE:
			roll()
	step(delta)


## Schickt sofort einen Busch los (auch der Knopf der Werkbank). Er startet knapp
## außerhalb der Fläche gegen den Wind, irgendwo quer dazu, und rollt mit ihm hindurch, bis
## er sie auf der anderen Seite verlässt.
func roll() -> void:
	var dir := WIND_DIR.normalized().rotated(rng.randf_range(-0.25, 0.25))
	var across := Vector2(-dir.y, dir.x)
	var centre := area.get_center()
	# Die Fläche ist der Umriss des schrägen Blicks, größer als das Bild: nah an der Mitte
	# vorbei, sonst rollt er ungesehen am Rand entlang.
	var through := centre + across * rng.randf_range(-0.12, 0.12) * area.size.length()
	if not _inside(through):
		through = centre
	var r := rng.randf_range(RADIUS.x, RADIUS.y)
	var back := _to_edge(through, -dir) + r * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh()
	add_child(node)
	_weeds.append({"node": node, "at": through - dir * back, "dir": dir,
			"speed": rng.randf_range(SPEED.x, SPEED.y), "r": r, "travel": 0.0,
			"spin": Basis(Vector3.UP, rng.randf_range(0.0, TAU)), "fade": -1.0,
			"length": back + _to_edge(through, dir) + r * 2.0})
	# Gleich an seinen Platz, nicht einen Frame lang im Ursprung.
	step(0.0)


## Wie weit es von `from` in Richtung `dir` bis zum Rand des Bilds ist (0, wenn `from`
## schon draußen liegt).
func _to_edge(from: Vector2, dir: Vector2) -> float:
	var d := 0.0
	while _inside(from + dir * d) and d < area.size.length():
		d += 0.5
	return d


func _inside(at: Vector2) -> bool:
	return area.has_point(at) and (not on_screen.is_valid() or on_screen.call(at.x, at.y))


## Ein Schritt aller Büsche. Getrennt von `_process`, damit ein Test ihn ohne Warten fährt.
func step(delta: float) -> void:
	for weed: Dictionary in _weeds.duplicate():
		var node: MeshInstance3D = weed.node
		# Böen: das Tempo schwankt mit dem Weg.
		var speed: float = weed.speed * (0.75 + 0.35 * sin(weed.travel * 0.4))
		var move: Vector2 = weed.dir * speed * delta
		weed.at += move
		weed.travel += move.length()
		var at: Vector2 = weed.at
		var r: float = weed.r
		# Rollen: um die Achse quer zur Bahn, so weit wie der Weg durch den Umfang.
		var axis := Vector3(weed.dir.y, 0.0, -weed.dir.x)
		weed.spin = Basis(axis, -move.length() / r) * weed.spin
		var hop := absf(sin(weed.travel * HOPS_PER_M * PI)) * HOP * r
		var y: float = height.call(at.x, at.y) + r * 0.85 + hop
		node.transform = Transform3D(weed.spin.scaled(Vector3.ONE * r * _shrink(weed)),
				Vector3(at.x, y, at.y))
		if weed.fade < 0.0 and (keep_out.has_point(at) or weed.travel > weed.length):
			weed.fade = 0.0
		if weed.fade >= 0.0:
			weed.fade += delta
			if weed.fade >= FADE:
				node.queue_free()
				_weeds.erase(weed)


## Wie viele gerade rollen.
func alive() -> int:
	return _weeds.size()


func _shrink(weed: Dictionary) -> float:
	return 1.0 if weed.fade < 0.0 else maxf(1.0 - weed.fade / FADE, 0.0)


## Das Knäuel: fünfzig dünne Zweige zwischen Punkten in einer Kugel vom Radius 1, dazu ein
## paar Gegenzweige durch die Mitte. Flach schattiert, in trockenen Brauntönen.
static func mesh() -> Mesh:
	if _mesh != null:
		return _mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 113
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dunkler als Sand und Steppe, sonst verschwimmt er darauf.
	var cols := [Color(0.42, 0.3, 0.17), Color(0.33, 0.24, 0.14), Color(0.5, 0.38, 0.23)]
	for i in 52:
		var a := _in_ball(rng, 0.95)
		var b := _in_ball(rng, 0.95)
		if a.distance_to(b) < 0.6:
			b = -a
		_twig(st, a, b, rng.randf_range(0.035, 0.06), cols[i % cols.size()])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = st.commit()
	_mesh.surface_set_material(0, mat)
	return _mesh


static func _in_ball(rng: RandomNumberGenerator, r: float) -> Vector3:
	var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	return p.normalized() * r * pow(rng.randf_range(0.55, 1.0), 0.5)


## Ein Zweig als dreiseitiges Prisma von `a` nach `b`.
static func _twig(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side)
	var ring: Array[Vector3] = []
	for k in 3:
		var ang := TAU * k / 3.0
		ring.append((side * cos(ang) + up * sin(ang)) * w)
	for k in 3:
		var p := ring[k]
		var q := ring[(k + 1) % 3]
		var n := (p + q).normalized()
		var shade := 1.0 if n.y > 0.3 else 0.8 if n.y > -0.3 else 0.62
		for v: Vector3 in [a + p, b + p, b + q, a + p, b + q, a + q]:
			st.set_normal(n)
			st.set_color(Color(col.r * shade, col.g * shade, col.b * shade))
			st.add_vertex(v)
