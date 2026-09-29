extends SceneTree
## Erzeugt die selbst gebauten Low-Poly-Modelle unter assets/models/forge/ als .glb.
##
##     tools/godot.sh -s res://src/dev/model_forge.gd
##
## Die Modelle sind Code und keine Handarbeit: wer eines ändern will, ändert es HIER und
## erzeugt neu — die .glb ist Ergebnis, nicht Quelle. Deterministisch (fester Samen je
## Modell), damit ein erneuter Lauf dieselben Dateien schreibt und der Diff leer bleibt.
##
## Stil wie die gekauften Modelle (KayKit, Quaternius): flache Facetten, eine Farbe je
## Fläche, keine Textur. Jede Farbe wird eine eigene Fläche mit eigenem Material, damit
## der glTF-Import sie ohne Vertexfarben richtig zeigt.
##
## Jedes Modell ist für seinen Platz in einem BattleTheme bemessen: der Kampf skaliert je
## Platz (Baum, Fels, Gras, Wahrzeichen) gleich, egal welches Modell dort steht. Zum
## Vergleich bei Skalierung 1: tree.glb ist 7.3 hoch (Bäume stehen bei ~1), rock.glb ein
## Kieselhaufen von 1.1 Breite (Felsen bei ~2.3), grass.glb 1.0 hoch (Gras bei ~1.6),
## pillar.gltf 4.0 (Wahrzeichen bei ~0.9). Die Burg ist 4.0 hoch (im Kampf ×3).

const OUT := "res://assets/models/forge"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Bäume
	_export("palm", _palm())
	_export("cactus", _cactus())
	_export("pine", _pine(false))
	_export("pine_snow", _pine(true))
	_export("dead_tree", _dead_tree())
	_export("acacia", _acacia())
	_export("cypress", _cypress())
	_export("olive", _round_tree(43, OLIVE_BARK, OLIVE_A, OLIVE_B, 0.8))
	_export("blossom_tree", _round_tree(47, BLOSSOM_BARK, BLOSSOM_A, BLOSSOM_B, 1.15))
	_export("jungle_tree", _jungle_tree())
	_export("ice_crystal", _ice_crystal())
	# Felsen — der Kampf stellt sie mit ~2.3 hin, darum hier klein.
	_export("sandstone_rock", _sandstone_rock(), 0.5)
	_export("boulder_grey", _boulder(51, Color(-1, -1, -1)))
	_export("boulder_snow", _boulder(53, SNOW))
	_export("boulder_moss", _boulder(59, MOSS))
	# Gras
	_export("dry_grass", _dry_grass())
	_export("fern", _fern())
	# Wahrzeichen
	_export("ruin_column", _ruin_column())
	_export("marble_column", _marble_column())
	_export("canyon_spire", _canyon_spire())
	# Australien (Access 4) — Bäume, Felsen, Gras
	_export("eucalyptus", _eucalyptus())
	_export("pandanus", _pandanus())
	_export("tree_fern", _tree_fern())
	_export("boab", _boab())
	_export("park_tree", _round_tree(109, PARK_BARK, PARK_A, PARK_B, 1.1))
	_export("red_boulder", _red_boulder())
	_export("coral", _coral())
	_export("spinifex", _spinifex())
	_export("reeds", _reeds())
	# … Wahrzeichen: im Busch und im Outback, in Vorstadt, Stadt, Dorf und auf dem Hof
	_export("termite_mound", _termite_mound())
	_export("windpump", _windpump(), 0.8)
	_export("water_tank", _water_tank())
	_export("tin_shed", _tin_shed())
	_export("cottage", _cottage())
	_export("office_towers", _office_towers(), 0.8)
	_export("lifeguard_tower", _lifeguard_tower())
	_export("stilt_hut", _stilt_hut())
	_export("lookout_tower", _lookout_tower(), 0.85)
	# … Kram am Feldrand
	_export("street_lamp", _street_lamp())
	_export("park_bench", _park_bench())
	_export("wheelie_bin", _wheelie_bin())
	_export("bbq", _bbq())
	_export("hills_hoist", _hills_hoist(), 1.4)
	_export("surfboards", _surfboards())
	_export("canoe", _canoe())
	_export("net_rack", _net_rack())
	# Latein — Rom: Forum, Markt, Hafen
	_export("stone_pine", _stone_pine())
	_export("roman_house", _roman_house())
	_export("statue", _statue())
	_export("triumphal_arch", _triumphal_arch())
	_export("temple", _temple())
	_export("amphorae", _amphorae(), 1.8)
	_export("marble_rubble", _marble_rubble())
	_export("fountain", _fountain(), 1.5)
	_export("roman_boat", _roman_boat())
	_export("crane", _crane())
	_export("harbour_basin", _harbour_basin())
	# … Dörfer der Jahreszeiten: Frühling, Herbst, Eis, Wüste
	_export("flower_tuft", _flower_tuft(), 1.3)
	_export("autumn_red", _round_tree(293, AUTUMN_BARK, AUTUMN_RED_A, AUTUMN_RED_B, 1.1))
	_export("autumn_orange", _round_tree(307, AUTUMN_BARK, AUTUMN_ORANGE_A, AUTUMN_ORANGE_B, 1.0))
	_export("autumn_yellow", _round_tree(311, AUTUMN_BARK, AUTUMN_YELLOW_A, AUTUMN_YELLOW_B, 0.95))
	_export("vine_row", _vine_row(), 1.6)
	_export("log_cabin", _log_cabin())
	_export("woodpile", _woodpile())
	_export("nomad_tent", _nomad_tent())
	_export("clay_house", _clay_house())
	_export("oasis_pond", _oasis_pond(), 1.8)
	# … Himmelsruinen
	_export("floating_rock", _floating_rock(), 1.5)
	_export("aqueduct", _aqueduct(), 0.8)
	_export("tholos", _tholos())
	_export("sky_boulder", _sky_boulder())
	# Kulisse des Hauptmenüs (scenes/ui/menu_backdrop.tscn) — kein Platz im BattleTheme.
	_export("fence", _fence())
	_export("market_stall", _market_stall())
	_export("sword", _sword())
	# Bibliothek (scenes/ui/book_select.tscn) — kein Platz im BattleTheme.
	_export("bookcase", _bookcase())
	_export("candles", _candles())
	_export("reading_desk", _reading_desk())
	quit()


func _export(model_name: String, forge: Forge, scale := 1.0) -> void:
	var root := Node3D.new()
	root.name = model_name
	var inst := MeshInstance3D.new()
	inst.name = model_name
	inst.mesh = forge.commit(scale)
	root.add_child(inst)
	inst.owner = root
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, "%s/%s.glb" % [OUT, model_name])
	print("model_forge: %s/%s.glb %s" % [OUT, model_name, error_string(err)])
	root.free()


# --- Modelle ------------------------------------------------------------------------

const PALM_BARK_A := Color(0.46, 0.33, 0.21)
const PALM_BARK_B := Color(0.55, 0.40, 0.25)
const PALM_LEAF_A := Color(0.30, 0.50, 0.16)
const PALM_LEAF_B := Color(0.21, 0.39, 0.12)
const COCONUT := Color(0.36, 0.24, 0.14)


## Palme: gebogener Stamm aus abwechselnd gefärbten Ringen, darauf ein Schopf hängender
## Wedel mit Mittelrippe. Etwa 6.5 hoch.
func _palm() -> Forge:
	var f := Forge.new()
	var rng := _rng(11)
	var segments := 7
	var lean := 1.1
	var top := Vector3.ZERO
	for i in segments:
		var a := _palm_spine(i, segments, lean)
		var b := _palm_spine(i + 1, segments, lean)
		var r0 := lerpf(0.30, 0.17, float(i) / segments)
		var r1 := lerpf(0.30, 0.17, float(i + 1) / segments)
		# Jeder Ring oben etwas breiter als der nächste unten: die Schuppen des Stamms.
		f.frustum(a, b, r0, r1 * 1.12, 6, PALM_BARK_A if i % 2 == 0 else PALM_BARK_B, i * 0.3)
		top = b
	var fronds := 8
	for k in fronds:
		var yaw := TAU * k / fronds + rng.randf_range(-0.2, 0.2)
		var length := rng.randf_range(2.3, 2.8)
		var droop := rng.randf_range(0.9, 1.3)
		_frond(f, top + Vector3(0, 0.05, 0), yaw, length, droop, 0.62, 0.55, PALM_LEAF_A, PALM_LEAF_B)
	for k in 3:
		var yaw := TAU * k / 3.0 + 0.5
		var c := top + Vector3(cos(yaw) * 0.22, -0.22, sin(yaw) * 0.22)
		f.blob(c, 0.16, COCONUT, rng, 0.0)
	return f


func _palm_spine(i: int, n: int, lean: float) -> Vector3:
	var t := float(i) / n
	return Vector3(lean * t * t, t * 5.6, 0.0)


## Ein Wedel: Mittelrippe als Bogen, zwei Blatthälften schräg daran — flach schattiert
## liest sich das als gefaltetes Blatt.
func _frond(f: Forge, base: Vector3, yaw: float, length: float, droop: float, width: float,
		rise: float, col_a: Color, col_b: Color) -> void:
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var steps := 4
	var prev_mid := base
	var prev_w := 0.08
	for j in range(1, steps + 1):
		var t := float(j) / steps
		# Erst ein wenig hinauf, dann in weitem Bogen hinunter.
		var mid := base + dir * (length * t) + Vector3.UP * (rise * t - droop * t * t)
		var w := width * sin(PI * minf(t * 1.1, 1.0)) + 0.02
		var fall := Vector3.DOWN * 0.18 * w
		var l0 := prev_mid + side * prev_w + Vector3.DOWN * 0.18 * prev_w
		var r0 := prev_mid - side * prev_w + Vector3.DOWN * 0.18 * prev_w
		var l1 := mid + side * w + fall
		var r1 := mid - side * w + fall
		f.leaf_quad(prev_mid, mid, l1, l0, col_a)
		f.leaf_quad(prev_mid, mid, r1, r0, col_b)
		prev_mid = mid
		prev_w = w


const CACTUS_A := Color(0.33, 0.53, 0.25)
const CACTUS_B := Color(0.26, 0.44, 0.20)
const CACTUS_TOP := Color(0.44, 0.62, 0.30)


## Säulenkaktus mit zwei Armen. Die Seiten wechseln die Farbe: das sind die Rippen.
## Etwa 3.4 hoch.
func _cactus() -> Forge:
	var f := Forge.new()
	_cactus_column(f, Vector3.ZERO, Vector3(0, 3.0, 0), 0.38)
	for arm: Array in [[1.0, 1.1, 0.55, 0.95], [-1.0, 1.55, 0.45, 0.7]]:
		var sx: float = arm[0]
		var y: float = arm[1]
		var out: float = arm[2]
		var up: float = arm[3]
		var start := Vector3(sx * 0.25, y, 0.0)
		var elbow := Vector3(sx * (0.38 + out), y + 0.12, 0.0)
		f.frustum(start, elbow, 0.2, 0.2, 8, CACTUS_B, 0.0, CACTUS_A)
		f.blob(elbow, 0.2, CACTUS_B, _rng(3), 0.0)
		_cactus_column(f, elbow, elbow + Vector3(0, up, 0), 0.2)
	return f


func _cactus_column(f: Forge, a: Vector3, b: Vector3, r: float) -> void:
	f.frustum(a, b, r, r * 0.96, 8, CACTUS_A, 0.0, CACTUS_B)
	# Gerundete Kappe: zwei flache Stufen bis zur Spitze.
	var c := b + Vector3(0, r * 0.45, 0)
	f.frustum(b, c, r * 0.96, r * 0.65, 8, CACTUS_A, 0.0, CACTUS_B)
	f.cone_cap(c, r * 0.65, r * 0.3, 8, CACTUS_TOP, 0.0)


const SANDSTONE := [Color(0.62, 0.36, 0.22), Color(0.72, 0.46, 0.28), Color(0.80, 0.57, 0.36)]


## Sandsteinbrocken: verbeulte Kugel, unten flach, in Schichten gefärbt — die Farbe hängt
## an der Höhe der Facette, das ergibt waagerechte Bänder. Etwa 1.1 hoch, 2.5 breit (vor
## der Verkleinerung in _initialize).
func _sandstone_rock() -> Forge:
	var f := Forge.new()
	var rng := _rng(23)
	var rings := 4
	var sides := 7
	var pts: Array = []
	for i in rings + 1:
		var row: Array[Vector3] = []
		var phi := PI * i / rings
		for j in sides:
			var theta := TAU * j / sides + (0.4 if i % 2 == 1 else 0.0)
			var r := rng.randf_range(0.7, 1.2) * 1.1
			var p := Vector3(sin(phi) * cos(theta) * r, cos(phi) * r * 0.75, sin(phi) * sin(theta) * r)
			p.y = maxf(p.y, -0.15) + 0.15
			row.append(p)
		pts.append(row)
	var center := Vector3(0, 0.6, 0)
	for i in rings:
		for j in sides:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % sides]
			var c: Vector3 = pts[i + 1][(j + 1) % sides]
			var d: Vector3 = pts[i + 1][j]
			f.tri_out(a, b, c, _band((a + b + c) / 3.0), center)
			f.tri_out(a, c, d, _band((a + c + d) / 3.0), center)
	return f


func _band(p: Vector3) -> Color:
	return SANDSTONE[clampi(int(p.y / 0.48), 0, SANDSTONE.size() - 1)]


const RUIN_A := Color(0.64, 0.56, 0.43)
const RUIN_B := Color(0.56, 0.48, 0.37)
const RUIN_BASE := Color(0.50, 0.43, 0.33)


## Säulenstumpf: Sockel, drei verrutschte Trommeln, oben abgebrochen; daneben eine
## umgestürzte Trommel und Schutt. Etwa 3.6 hoch — so kräftig wie pillar.gltf daneben.
func _ruin_column() -> Forge:
	var f := Forge.new()
	var rng := _rng(37)
	f.box(Vector3(0, 0.18, 0), Vector3(1.7, 0.36, 1.7), RUIN_BASE, 0.1)
	var y := 0.36
	for i in 3:
		var h := 1.0 if i < 2 else 1.1
		var off := Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
		var jag := 0.0 if i < 2 else 0.35
		f.drum(Vector3(0, y, 0) + off, 0.58, h, 10, RUIN_A if i % 2 == 0 else RUIN_B, rng, jag)
		y += h
	# Umgestürzt: eine Trommel auf der Seite, halb im Sand.
	f.frustum(Vector3(1.2, 0.5, -0.7), Vector3(2.1, 0.54, 0.1), 0.54, 0.54, 10, RUIN_B, 0.2, RUIN_A)
	for k in 4:
		var p := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(0.6, 1.2))
		var s := rng.randf_range(0.18, 0.32)
		f.box(p + Vector3(0, s * 0.5, 0), Vector3(s * 1.3, s, s), RUIN_A if k % 2 == 0 else RUIN_BASE, rng.randf_range(0.0, 1.5))
	return f


const SNOW := Color(0.66, 0.69, 0.74)
const PINE_TRUNK := Color(0.40, 0.27, 0.17)
const PINE_A := Color(0.10, 0.23, 0.14)
const PINE_B := Color(0.07, 0.17, 0.11)


## Tanne: kurzer Stamm, vier gestaffelte Kegel. Verschneit trägt jede Stufe oben eine
## Schneekappe mit derselben Neigung. Etwa 7.1 hoch, wie tree.glb.
func _pine(snowy: bool) -> Forge:
	var f := Forge.new()
	f.frustum(Vector3.ZERO, Vector3(0, 1.4, 0), 0.32, 0.24, 6, PINE_TRUNK)
	# [Fuß, Radius, Höhe] je Stufe
	var tiers := [[1.0, 2.1, 2.0], [2.5, 1.65, 1.9], [3.9, 1.25, 1.8], [5.2, 0.85, 1.9]]
	for i in tiers.size():
		var base := Vector3(0, tiers[i][0], 0)
		var r: float = tiers[i][1]
		var h: float = tiers[i][2]
		var col := PINE_A if i % 2 == 0 else PINE_B
		var twist := PI / 7.0 * i
		if snowy:
			var mid := 0.5
			var ring := base + Vector3(0, h * mid, 0)
			f.frustum(base, ring, r, r * (1.0 - mid), 7, col, twist)
			f.cone_cap(ring, r * (1.0 - mid), h * (1.0 - mid), 7, SNOW, twist)
		else:
			f.cone_cap(base, r, h, 7, col, twist, true)
	return f


const DEAD_A := Color(0.42, 0.36, 0.30)
const DEAD_B := Color(0.34, 0.29, 0.24)


## Abgestorbener Baum: geknickter Stamm, kahle Äste mit je einem Zweig. Etwa 5 hoch.
func _dead_tree() -> Forge:
	var f := Forge.new()
	var rng := _rng(41)
	var knee := Vector3(0.2, 2.6, 0.1)
	var top := Vector3(-0.15, 4.5, 0.3)
	f.frustum(Vector3.ZERO, knee, 0.34, 0.2, 6, DEAD_A, 0.0, DEAD_B)
	f.frustum(knee, top, 0.2, 0.07, 6, DEAD_A, 0.3, DEAD_B)
	var starts := [Vector3.ZERO.lerp(knee, 0.6), Vector3.ZERO.lerp(knee, 0.95),
			knee.lerp(top, 0.35), knee.lerp(top, 0.7)]
	for k in starts.size():
		var yaw := TAU * k / starts.size() + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(yaw), rng.randf_range(0.5, 1.0), sin(yaw)).normalized()
		var length := rng.randf_range(1.1, 1.7) * (1.0 - 0.15 * k)
		var end: Vector3 = starts[k] + dir * length
		f.frustum(starts[k], end, 0.12, 0.05, 5, DEAD_B)
		var twig := (dir + Vector3(rng.randf_range(-0.7, 0.7), 0.6, rng.randf_range(-0.7, 0.7))).normalized()
		f.frustum(end, end + twig * length * 0.55, 0.05, 0.02, 4, DEAD_A)
	return f


const ACACIA_BARK := Color(0.42, 0.31, 0.22)
const ACACIA_A := Color(0.26, 0.34, 0.12)
const ACACIA_B := Color(0.19, 0.26, 0.09)


## Schirmakazie: kurzer Stamm, der sich gabelt, darauf flache Schirme. Etwa 4.8 hoch,
## breiter als hoch.
func _acacia() -> Forge:
	var f := Forge.new()
	var fork := Vector3(0.3, 2.1, 0.0)
	f.frustum(Vector3.ZERO, fork, 0.3, 0.2, 6, ACACIA_BARK)
	for crown: Array in [[Vector3(-1.5, 3.8, 0.6), 1.25], [Vector3(1.8, 4.1, -0.5), 1.45],
			[Vector3(0.3, 4.5, 1.5), 1.0]]:
		var c: Vector3 = crown[0]
		var r: float = crown[1]
		f.frustum(fork, c, 0.17, 0.09, 5, ACACIA_BARK)
		# Unten gewölbt, oben fast flach: der Schirm.
		f.frustum(c + Vector3(0, -0.3, 0), c, r * 0.7, r, 8, ACACIA_B, 0.0)
		f.frustum(c, c + Vector3(0, 0.35, 0), r, r * 0.8, 8, ACACIA_A, 0.0)
	return f


const CYPRESS_TRUNK := Color(0.38, 0.27, 0.18)
const CYPRESS_A := Color(0.14, 0.30, 0.17)
const CYPRESS_B := Color(0.11, 0.24, 0.14)


## Zypresse: schmale Spindel, am Fuß ein Stück Stamm. Etwa 6.9 hoch.
func _cypress() -> Forge:
	var f := Forge.new()
	f.frustum(Vector3.ZERO, Vector3(0, 0.8, 0), 0.2, 0.18, 6, CYPRESS_TRUNK)
	var rings := [[0.5, 0.45], [2.0, 0.78], [3.6, 0.72], [4.8, 0.5]]
	for i in rings.size() - 1:
		f.frustum(Vector3(0, rings[i][0], 0), Vector3(0, rings[i + 1][0], 0),
				rings[i][1], rings[i + 1][1], 8, CYPRESS_A, 0.0, CYPRESS_B)
	f.cone_cap(Vector3(0, rings[-1][0], 0), rings[-1][1], 2.1, 8, CYPRESS_A, 0.0)
	return f


const OLIVE_BARK := Color(0.40, 0.34, 0.27)
const OLIVE_A := Color(0.28, 0.33, 0.22)
const OLIVE_B := Color(0.22, 0.27, 0.18)
const BLOSSOM_BARK := Color(0.36, 0.25, 0.20)
const BLOSSOM_A := Color(0.62, 0.36, 0.46)
const BLOSSOM_B := Color(0.52, 0.28, 0.39)


## Laubbaum mit runder Krone aus drei Ballen: der Olivenbaum knorrig und klein, der
## blühende Baum mit `size` größer. Etwa 4.3 (Olive) bzw. 6.2 (Blüte) hoch.
func _round_tree(seed_value: int, bark: Color, col_a: Color, col_b: Color, size: float) -> Forge:
	var f := Forge.new()
	var rng := _rng(seed_value)
	var s := size / 0.8
	var knee := Vector3(0.3, 1.2, 0.1) * s
	var top := Vector3(-0.1, 2.4, 0.2) * s
	f.frustum(Vector3.ZERO, knee, 0.3 * s, 0.22 * s, 6, bark, 0.0)
	f.frustum(knee, top, 0.22 * s, 0.16 * s, 6, bark, 0.4)
	var paint := func(_m: Vector3, _n: Vector3) -> Color:
		return col_a if rng.randf() < 0.55 else col_b
	for crown: Array in [[Vector3(0, 3.1, 0), Vector3(1.5, 1.0, 1.5)],
			[Vector3(0.9, 2.8, 0.6), Vector3(1.0, 0.8, 1.0)],
			[Vector3(-0.8, 2.9, -0.5), Vector3(1.1, 0.8, 1.1)]]:
		f.lump(crown[0] * s, crown[1] * s, 4, 7, rng, 0.15, paint)
	return f


const JUNGLE_TRUNK := Color(0.36, 0.28, 0.20)
const JUNGLE_A := Color(0.09, 0.27, 0.12)
const JUNGLE_B := Color(0.06, 0.20, 0.09)


## Urwaldriese: hoher, leicht gebogener Stamm mit breiter Krone, darunter hängende Blätter.
## Etwa 8 hoch — über tree.glb, der Urwald steht dicht und hoch.
func _jungle_tree() -> Forge:
	var f := Forge.new()
	var rng := _rng(61)
	var knee := Vector3(0.2, 3.2, 0.0)
	var top := Vector3(-0.1, 6.2, 0.2)
	f.frustum(Vector3.ZERO, knee, 0.42, 0.3, 7, JUNGLE_TRUNK)
	f.frustum(knee, top, 0.3, 0.2, 7, JUNGLE_TRUNK, 0.3)
	var paint := func(_m: Vector3, _n: Vector3) -> Color:
		return JUNGLE_A if rng.randf() < 0.5 else JUNGLE_B
	for crown: Array in [[Vector3(-0.1, 6.9, 0.2), Vector3(2.2, 1.1, 2.2)],
			[Vector3(1.4, 6.4, 0.7), Vector3(1.3, 0.9, 1.3)],
			[Vector3(-1.3, 6.5, -0.6), Vector3(1.4, 0.9, 1.4)]]:
		f.lump(crown[0], crown[1], 4, 8, rng, 0.12, paint)
	for k in 5:
		var yaw := TAU * k / 5.0 + 0.3
		_frond(f, top + Vector3(0, -0.2, 0), yaw, 2.3, 1.6, 0.5, 0.3, JUNGLE_A, JUNGLE_B)
	return f


const ICE_A := Color(0.46, 0.64, 0.76)
const ICE_B := Color(0.34, 0.52, 0.68)
const ICE_TIP := Color(0.60, 0.72, 0.80)


## Eiskristalle: fünf sechseckige, zugespitzte Säulen, schräg aus einem Punkt. Bis 3.6 hoch.
func _ice_crystal() -> Forge:
	var f := Forge.new()
	var rng := _rng(67)
	for k in 5:
		var tilt := 0.0 if k == 0 else rng.randf_range(0.3, 0.6)
		var yaw := TAU * k / 4.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt), sin(tilt) * sin(yaw))
		var h := 3.0 if k == 0 else rng.randf_range(1.2, 2.2)
		var r := 0.42 if k == 0 else rng.randf_range(0.22, 0.32)
		var base := Vector3(cos(yaw), 0, sin(yaw)) * (0.0 if k == 0 else 0.3) + Vector3(0, -0.2, 0)
		var shoulder := base + dir * h
		f.frustum(base, shoulder, r, r, 6, ICE_A, 0.0, ICE_B)
		f.frustum(shoulder, shoulder + dir * r * 1.6, r, 0.0, 6, ICE_TIP, 0.0, ICE_A)
	return f


const BOULDER_A := Color(0.34, 0.34, 0.36)
const BOULDER_B := Color(0.27, 0.27, 0.30)
const MOSS := Color(0.18, 0.28, 0.11)


## Findling, flach auf dem Boden. `cover` (Schnee, Moos) liegt auf den Facetten, die nach
## oben zeigen; ohne (`r` < 0) bleibt er grau. Etwa 0.5 hoch und 1 breit — der Kampf
## stellt Felsen mit ~2.3 hin.
func _boulder(seed_value: int, cover: Color) -> Forge:
	var f := Forge.new()
	var rng := _rng(seed_value)
	var paint := func(_m: Vector3, n: Vector3) -> Color:
		if cover.r >= 0.0 and n.y > 0.6:
			return cover
		return BOULDER_A if rng.randf() < 0.5 else BOULDER_B
	f.lump(Vector3(0, 0.12, 0), Vector3(0.5, 0.4, 0.45), 4, 6, rng, 0.25, paint, -0.12)
	f.lump(Vector3(0.45, 0.06, 0.3), Vector3(0.22, 0.18, 0.2), 3, 5, rng, 0.2, paint, -0.06)
	return f


const DRY_A := Color(0.60, 0.48, 0.26)
const DRY_B := Color(0.48, 0.37, 0.20)


## Trockenes Grasbüschel: siebzehn Halme, nach außen geneigt. Etwa 1 hoch, wie grass.glb.
func _dry_grass() -> Forge:
	var f := Forge.new()
	var rng := _rng(71)
	for k in 17:
		var yaw := TAU * k / 17.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-out.z, 0, out.x) * 0.1
		var foot := out * rng.randf_range(0.05, 0.35)
		var tip := foot + out * rng.randf_range(0.25, 0.5) + Vector3(0, rng.randf_range(0.65, 1.05), 0)
		f.blade(foot - side, foot + side, tip, DRY_A if k % 2 == 0 else DRY_B)
	return f


const FERN_A := Color(0.15, 0.33, 0.11)
const FERN_B := Color(0.11, 0.26, 0.08)


## Farn: sieben Wedel im Kreis, steil hinauf und dann überhängend. Etwa 0.7 hoch.
func _fern() -> Forge:
	var f := Forge.new()
	var rng := _rng(73)
	for k in 7:
		var yaw := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		_frond(f, Vector3.ZERO, yaw, rng.randf_range(0.9, 1.2), 1.1, 0.22, 1.5, FERN_A, FERN_B)
	return f


const MARBLE_A := Color(0.58, 0.56, 0.52)
const MARBLE_B := Color(0.49, 0.47, 0.44)
const MARBLE_BASE := Color(0.42, 0.40, 0.37)


## Marmorsäule, noch aufrecht: Sockel, kannelierter Schaft, Kapitell. Daneben ein Stumpf,
## eine umgestürzte Trommel und Schutt. Etwa 4.4 hoch.
func _marble_column() -> Forge:
	var f := Forge.new()
	var rng := _rng(79)
	f.box(Vector3(0, 0.15, 0), Vector3(1.5, 0.3, 1.5), MARBLE_BASE, 0.0)
	var y := 0.3
	for i in 3:
		f.drum(Vector3(0, y, 0), 0.48, 1.1, 12, MARBLE_A, rng, 0.0, MARBLE_B)
		y += 1.1
	f.frustum(Vector3(0, y, 0), Vector3(0, y + 0.3, 0), 0.48, 0.7, 12, MARBLE_A)
	f.box(Vector3(0, y + 0.42, 0), Vector3(1.5, 0.24, 1.5), MARBLE_BASE, 0.0)
	# Der Nachbar ist nur noch ein Stumpf.
	f.box(Vector3(2.0, 0.15, 0.3), Vector3(1.3, 0.3, 1.3), MARBLE_BASE, 0.2)
	f.drum(Vector3(2.0, 0.3, 0.3), 0.46, 0.9, 12, MARBLE_A, rng, 0.35, MARBLE_B)
	f.frustum(Vector3(-1.1, 0.46, 1.0), Vector3(-1.9, 0.48, 0.2), 0.46, 0.46, 12, MARBLE_B, 0.0, MARBLE_A)
	for k in 4:
		var p := Vector3(rng.randf_range(-0.8, 2.4), 0.0, rng.randf_range(0.8, 1.4))
		var s := rng.randf_range(0.16, 0.28)
		f.box(p + Vector3(0, s * 0.5, 0), Vector3(s * 1.3, s, s), MARBLE_B, rng.randf_range(0.0, 1.5))
	return f


const CANYON := [Color(0.45, 0.20, 0.13), Color(0.55, 0.28, 0.17), Color(0.62, 0.36, 0.23)]


## Felsnadel: nach oben schmaler, verbeult, in roten Schichten, oben flach. Etwa 6 hoch.
func _canyon_spire() -> Forge:
	var f := Forge.new()
	var rng := _rng(83)
	var sides := 7
	var levels := [[0.0, 1.5], [1.0, 1.25], [2.2, 1.05], [3.3, 0.95], [4.4, 0.8], [5.4, 0.72], [6.0, 0.6]]
	var rings: Array = []
	for level: Array in levels:
		var row: Array[Vector3] = []
		for j in sides:
			var ang := TAU * j / sides
			var r: float = level[1] * rng.randf_range(0.8, 1.15)
			row.append(Vector3(cos(ang) * r, level[0], sin(ang) * r))
		rings.append(row)
	for i in rings.size() - 1:
		var inside := Vector3(0, (levels[i][0] + levels[i + 1][0]) * 0.5, 0)
		for j in sides:
			var k := (j + 1) % sides
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][k]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][j]
			f.tri_out(a, b, c, _strata((a + b + c) / 3.0), inside)
			f.tri_out(a, c, d, _strata((a + c + d) / 3.0), inside)
	var top := Vector3(0, levels[-1][0] + 0.1, 0)
	for j in sides:
		f.tri_out(top, rings[-1][j], rings[-1][(j + 1) % sides], CANYON[2], top - Vector3(0, 1, 0))
	return f


func _strata(p: Vector3) -> Color:
	return CANYON[int(p.y / 0.7) % CANYON.size()]


const GUM_BARK_A := Color(0.84, 0.82, 0.76)
const GUM_BARK_B := Color(0.68, 0.66, 0.60)
const GUM_A := Color(0.36, 0.45, 0.30)
const GUM_B := Color(0.27, 0.36, 0.24)
const GUM_C := Color(0.44, 0.52, 0.40)


## Eukalyptus: heller, glatter Stamm mit leichtem Knick, der sich in vier schräge Äste
## gabelt, jeder noch einmal geteilt; an den Enden viele kleine, graugrüne Laubballen in
## verschiedener Höhe — die Krone ist licht und unregelmäßig, weder Kugel noch Schirm.
## Etwa 7 hoch.
func _eucalyptus() -> Forge:
	var f := Forge.new()
	var rng := _rng(89)
	var knee := Vector3(0.15, 1.6, 0.05)
	var fork := Vector3(0.3, 3.0, 0.15)
	f.frustum(Vector3.ZERO, knee, 0.36, 0.29, 7, GUM_BARK_A, 0.0, GUM_BARK_B)
	f.frustum(knee, fork, 0.29, 0.22, 7, GUM_BARK_A, 0.2, GUM_BARK_B)
	var paint := func(_m: Vector3, _n: Vector3) -> Color:
		var roll := rng.randf()
		return GUM_A if roll < 0.45 else (GUM_B if roll < 0.85 else GUM_C)
	for k in 4:
		var yaw := TAU * k / 4.0 + rng.randf_range(-0.35, 0.35)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var elbow := fork + out * rng.randf_range(0.8, 1.2) + Vector3(0, rng.randf_range(1.2, 1.7), 0)
		f.frustum(fork, elbow, 0.17, 0.11, 5, GUM_BARK_A, 0.0, GUM_BARK_B)
		for j in 2:
			var side := Vector3(-out.z, 0, out.x) * (1.0 if j == 0 else -1.0)
			var tip := elbow + out * rng.randf_range(0.4, 0.8) + side * rng.randf_range(0.3, 0.6) \
					+ Vector3(0, rng.randf_range(0.7, 1.3), 0)
			f.frustum(elbow, tip, 0.1, 0.05, 4, GUM_BARK_A)
			var r := rng.randf_range(0.55, 0.8)
			f.lump(tip + Vector3(0, 0.15, 0), Vector3(r, r * 0.55, r), 3, 6, rng, 0.25, paint)
			f.lump(tip + out * r * 0.8 + Vector3(0, -0.3, 0), Vector3(r * 0.6, r * 0.38, r * 0.6), 3, 5,
					rng, 0.25, paint)
	return f


const PAN_BARK_A := Color(0.46, 0.38, 0.28)
const PAN_BARK_B := Color(0.38, 0.31, 0.23)
const PAN_A := Color(0.34, 0.50, 0.20)
const PAN_B := Color(0.26, 0.40, 0.15)


## Schraubenbaum (Pandanus): auf sechs Stelzwurzeln ein kräftiger Stamm mit drei kurzen
## Ästen; an jedem ein dichter Schopf langer, bandförmiger Blätter, die erst steigen und
## dann überhängen. Etwa 4.5 hoch.
func _pandanus() -> Forge:
	var f := Forge.new()
	var rng := _rng(107)
	var foot := Vector3(0, 1.0, 0)
	for k in 6:
		var yaw := TAU * k / 6.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(yaw), 0, sin(yaw))
		f.frustum(d * 0.7, foot + d * 0.1, 0.07, 0.1, 4, PAN_BARK_B)
	var fork := Vector3(0.3, 2.6, 0)
	f.frustum(foot, fork, 0.2, 0.16, 7, PAN_BARK_A, 0.0, PAN_BARK_B)
	var core := func(_m: Vector3, _n: Vector3) -> Color: return PAN_B
	for tip: Vector3 in [Vector3(-0.7, 3.5, 0.3), Vector3(1.1, 3.4, -0.2), Vector3(0.3, 3.9, -0.6)]:
		f.frustum(fork, tip, 0.13, 0.1, 5, PAN_BARK_A, 0.0, PAN_BARK_B)
		f.lump(tip, Vector3(0.22, 0.25, 0.22), 2, 5, rng, 0.1, core)
		for k in 22:
			var yaw := TAU * k / 22.0 + rng.randf_range(-0.15, 0.15)
			_strap_leaf(f, tip, yaw, rng.randf_range(-0.2, 1.1), rng.randf_range(1.1, 1.4), 0.14,
					PAN_A if k % 2 == 0 else PAN_B)
	return f


## Bandförmiges Blatt aus `c`: ein Stück schräg hinauf (`elev`), dann spitz nach außen und
## hinab.
func _strap_leaf(f: Forge, c: Vector3, yaw: float, elev: float, length: float, width: float,
		col: Color) -> void:
	var out := Vector3(cos(yaw), 0, sin(yaw))
	var side := Vector3(-out.z, 0, out.x) * width * 0.5
	var mid := c + (out * cos(elev) + Vector3.UP * sin(elev)) * length * 0.5
	var end := mid + out * length * 0.45 + Vector3.DOWN * length * 0.3
	f.leaf_quad(c, mid, mid + side, c + side * 0.4, col)
	f.leaf_quad(c, mid, mid - side, c - side * 0.4, col)
	f.blade(mid - side, mid + side, end, col)


const TREEFERN_TRUNK_A := Color(0.30, 0.22, 0.15)
const TREEFERN_TRUNK_B := Color(0.24, 0.17, 0.11)
const TREEFERN_A := Color(0.30, 0.54, 0.18)
const TREEFERN_B := Color(0.23, 0.45, 0.13)


## Baumfarn: schlanker, faseriger Stamm, oben ein weiter, flacher Schirm aus zehn
## gefiederten Wedeln, in der Mitte drei eingerollte junge Triebe. Etwa 4.3 hoch.
func _tree_fern() -> Forge:
	var f := Forge.new()
	var rng := _rng(113)
	var mid := Vector3(0.1, 1.8, 0)
	var top := Vector3(0.2, 3.6, 0)
	f.frustum(Vector3.ZERO, mid, 0.28, 0.21, 7, TREEFERN_TRUNK_A, 0.0, TREEFERN_TRUNK_B)
	# Oben wieder dicker: dort sitzen die Stümpfe alter Wedel.
	f.frustum(mid, top, 0.21, 0.26, 7, TREEFERN_TRUNK_A, 0.3, TREEFERN_TRUNK_B)
	for k in 10:
		var yaw := TAU * k / 10.0 + rng.randf_range(-0.12, 0.12)
		_pinnate_frond(f, top, yaw, rng.randf_range(2.2, 2.6), 0.6, 1.1, TREEFERN_A, TREEFERN_B)
	for k in 3:
		var yaw := TAU * k / 3.0
		var end := top + Vector3(cos(yaw) * 0.15, 0.45, sin(yaw) * 0.15)
		f.frustum(top, end, 0.05, 0.04, 4, TREEFERN_B)
		f.blob(end, 0.09, TREEFERN_B, rng, 0.0)
	return f


## Gefiederter Wedel: entlang des Bogens beidseits schmale Fiederblättchen, zur Spitze und
## zum Ansatz kürzer — von oben liest sich das als Farn, nicht als Palmblatt.
func _pinnate_frond(f: Forge, base: Vector3, yaw: float, length: float, rise: float, droop: float,
		col_a: Color, col_b: Color) -> void:
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var steps := 8
	var prev := base
	for j in range(1, steps + 1):
		var t := float(j) / steps
		var p := base + dir * (length * t) + Vector3.UP * (rise * t - droop * t * t)
		var w := 0.7 * sin(PI * minf(t * 1.05, 1.0)) + 0.08
		var fwd := (p - prev).normalized()
		for s: float in [-1.0, 1.0]:
			var tip := p + side * s * w + fwd * w * 0.35 + Vector3.DOWN * 0.12 * w
			f.blade(prev + side * s * 0.03, p + side * s * 0.03, tip, col_a if s > 0.0 else col_b)
		prev = p


const BOAB_A := Color(0.62, 0.54, 0.50)
const BOAB_B := Color(0.54, 0.46, 0.43)
const BOAB_LEAF := Color(0.36, 0.48, 0.22)


## Affenbrotbaum (Boab): dicker Flaschenstamm, oben ein Kranz kurzer, krummer Äste mit
## wenig Laub. Etwa 5 hoch.
func _boab() -> Forge:
	var f := Forge.new()
	var rng := _rng(127)
	var rings := [[0.0, 0.8], [0.9, 1.05], [1.9, 1.05], [2.8, 0.75], [3.3, 0.45]]
	for i in rings.size() - 1:
		f.frustum(Vector3(0, rings[i][0], 0), Vector3(0, rings[i + 1][0], 0), rings[i][1], rings[i + 1][1],
				8, BOAB_A, i * 0.2, BOAB_B)
	var top := Vector3(0, 3.3, 0)
	var paint := func(_m: Vector3, _n: Vector3) -> Color: return BOAB_LEAF
	for k in 6:
		var yaw := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(yaw), rng.randf_range(0.6, 1.2), sin(yaw)).normalized()
		var end := top + dir * rng.randf_range(1.0, 1.5)
		f.frustum(top, end, 0.2, 0.07, 5, BOAB_B)
		f.lump(end + Vector3(0, 0.15, 0), Vector3(0.45, 0.28, 0.45), 3, 5, rng, 0.2, paint)
	return f


const PARK_BARK := Color(0.40, 0.31, 0.22)
const PARK_A := Color(0.25, 0.45, 0.18)
const PARK_B := Color(0.19, 0.37, 0.14)

const RED_ROCK_A := Color(0.56, 0.23, 0.13)
const RED_ROCK_B := Color(0.47, 0.19, 0.11)
const RED_ROCK_TOP := Color(0.66, 0.32, 0.18)


## Roter Felsbrocken wie im Outback: verbeult, oben von der Sonne heller. Etwa 0.5 hoch
## und 1 breit, wie die Findlinge.
func _red_boulder() -> Forge:
	var f := Forge.new()
	var rng := _rng(131)
	var paint := func(_m: Vector3, n: Vector3) -> Color:
		if n.y > 0.7:
			return RED_ROCK_TOP
		return RED_ROCK_A if rng.randf() < 0.5 else RED_ROCK_B
	f.lump(Vector3(0, 0.12, 0), Vector3(0.5, 0.42, 0.45), 4, 6, rng, 0.25, paint, -0.12)
	f.lump(Vector3(-0.42, 0.05, 0.28), Vector3(0.24, 0.2, 0.22), 3, 5, rng, 0.2, paint, -0.05)
	return f


const CORAL_ROCK := Color(0.74, 0.70, 0.60)
const CORALS := [Color(0.92, 0.60, 0.30), Color(0.62, 0.40, 0.66)]
const BRAIN_A := Color(0.88, 0.50, 0.50)
const BRAIN_B := Color(0.76, 0.40, 0.42)


## Angespülter Korallenstock: ein flacher, sandfarbener Kalkbrocken, darauf eine rosa
## Hirnkoralle mit Windungen und zwei verzweigte Geweihkorallen in Orange und Violett.
## Etwa 0.8 hoch und 1 breit — im Felsplatz.
func _coral() -> Forge:
	var f := Forge.new()
	var rng := _rng(137)
	var rock := func(_m: Vector3, _n: Vector3) -> Color: return CORAL_ROCK
	f.lump(Vector3(0, 0.05, 0), Vector3(0.52, 0.14, 0.46), 3, 7, rng, 0.25, rock, -0.05)
	var brain := func(m: Vector3, _n: Vector3) -> Color:
		return BRAIN_A if int((m.x * 2.0 + m.y * 3.0 + m.z) * 9.0) % 2 == 0 else BRAIN_B
	f.lump(Vector3(0.22, 0.14, -0.12), Vector3(0.3, 0.22, 0.27), 4, 8, rng, 0.06, brain, -0.1)
	for stag: Array in [[Vector3(-0.22, 0.12, 0.12), CORALS[0]], [Vector3(-0.05, 0.12, 0.28), CORALS[1]]]:
		for k in 3:
			var yaw := TAU * k / 3.0 + rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(yaw) * 0.45, 1.0, sin(yaw) * 0.45).normalized()
			_coral_branch(f, stag[0], dir, 0.24, 0.05, 2, stag[1], rng)
	return f


## Ein Ast der Geweihkoralle, der sich `depth`-mal gabelt; an den Enden eine stumpfe Kuppe.
func _coral_branch(f: Forge, a: Vector3, dir: Vector3, length: float, r: float, depth: int,
		col: Color, rng: RandomNumberGenerator) -> void:
	var b := a + dir * length
	f.frustum(a, b, r, r * 0.8, 5, col)
	if depth == 0:
		f.blob(b, r * 0.9, col, rng, 0.0)
		return
	for s in 2:
		var nd := (dir + Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(-0.6, 0.6))).normalized()
		_coral_branch(f, b, nd, length * 0.75, r * 0.8, depth - 1, col, rng)


const SPIN_A := Color(0.68, 0.60, 0.32)
const SPIN_B := Color(0.54, 0.52, 0.28)
const SPIN_C := Color(0.46, 0.48, 0.30)


## Spinifex: ein runder, dichter Horst stacheliger Halme, außen flach, innen steil — von
## oben ein Polster, kein Büschel. Etwa 0.7 hoch und 1.6 breit.
func _spinifex() -> Forge:
	var f := Forge.new()
	var rng := _rng(139)
	for k in 64:
		var yaw := rng.randf() * TAU
		var foot_r := rng.randf_range(0.0, 0.35)
		# Außen stehen die Halme flach, innen steil: so wölbt sich der Horst.
		var up := lerpf(1.2, 0.1, foot_r / 0.35) + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(cos(yaw) * cos(up), sin(up), sin(yaw) * cos(up))
		var foot := Vector3(cos(yaw), 0, sin(yaw)) * foot_r
		var side := Vector3(-sin(yaw), 0, cos(yaw)) * 0.05
		var col := SPIN_A if k % 3 == 0 else (SPIN_B if k % 3 == 1 else SPIN_C)
		f.blade(foot - side, foot + side, foot + dir * rng.randf_range(0.55, 0.85), col)
	return f


const REED_A := Color(0.36, 0.48, 0.20)
const REED_B := Color(0.46, 0.54, 0.26)
const CATTAIL := Color(0.38, 0.25, 0.14)


## Schilf am Wasser: steile, schmale Halme, drei davon mit Rohrkolben. Etwa 1.4 hoch.
func _reeds() -> Forge:
	var f := Forge.new()
	var rng := _rng(149)
	for k in 16:
		var yaw := TAU * k / 16.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-out.z, 0, out.x) * 0.04
		var foot := out * rng.randf_range(0.05, 0.3)
		var tip := foot + out * rng.randf_range(0.1, 0.25) + Vector3(0, rng.randf_range(0.9, 1.4), 0)
		f.blade(foot - side, foot + side, tip, REED_A if k % 2 == 0 else REED_B)
	for k in 3:
		var yaw := TAU * k / 3.0 + 0.4
		var foot := Vector3(cos(yaw), 0, sin(yaw)) * 0.15
		var head := foot + Vector3(0, rng.randf_range(1.0, 1.25), 0)
		f.frustum(foot, head, 0.02, 0.02, 4, REED_A)
		f.frustum(head, head + Vector3(0, 0.28, 0), 0.055, 0.05, 6, CATTAIL)
	return f


const TERMITE := [Color(0.60, 0.40, 0.22), Color(0.66, 0.45, 0.26), Color(0.71, 0.51, 0.30)]


## Termitenhügel: ein knorriger, leicht schiefer Lehmturm mit runder Kuppe, daneben zwei
## kleinere, alle auf einem flach auslaufenden Fuß. Etwa 4.4 hoch.
func _termite_mound() -> Forge:
	var f := Forge.new()
	var rng := _rng(151)
	var paint := func(_m: Vector3, _n: Vector3) -> Color: return TERMITE[rng.randi() % TERMITE.size()]
	f.lump(Vector3(0.1, 0, 0.2), Vector3(1.5, 0.35, 1.2), 3, 8, rng, 0.2, paint, 0.0)
	_mound_spire(f, Vector3.ZERO, 1.0, rng)
	_mound_spire(f, Vector3(1.0, 0, 0.55), 0.55, rng)
	_mound_spire(f, Vector3(-0.75, 0, 0.6), 0.4, rng)
	return f


## Ein Turm des Termitenhügels: Ringe mit verbeultem Radius, die nach oben schmaler werden
## und ein wenig wandern, oben eine stumpfe Spitze. `s` skaliert alles.
func _mound_spire(f: Forge, at: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var sides := 8
	var levels := [[0.0, 0.95], [0.8, 0.85], [1.6, 0.74], [2.4, 0.6], [3.1, 0.46], [3.7, 0.32], [4.1, 0.18]]
	var rings: Array = []
	var drift := Vector3.ZERO
	for level: Array in levels:
		var row: Array[Vector3] = []
		for j in sides:
			var ang := TAU * j / sides
			var r: float = level[1] * s * rng.randf_range(0.8, 1.2)
			row.append(at + drift + Vector3(cos(ang) * r, level[0] * s, sin(ang) * r))
		rings.append(row)
		drift += Vector3(rng.randf_range(-0.08, 0.1), 0, rng.randf_range(-0.08, 0.08)) * s
	for i in rings.size() - 1:
		var inside := at + drift * 0.5 + Vector3(0, (levels[i][0] + levels[i + 1][0]) * 0.5 * s, 0)
		for j in sides:
			var k := (j + 1) % sides
			var col: Color = TERMITE[rng.randi() % TERMITE.size()]
			f.tri_out(rings[i][j], rings[i][k], rings[i + 1][k], col, inside)
			f.tri_out(rings[i][j], rings[i + 1][k], rings[i + 1][j], col, inside)
	var tip := at + drift + Vector3(0, 4.4 * s, 0)
	for j in sides:
		f.tri_out(tip, rings[-1][j], rings[-1][(j + 1) % sides], TERMITE[2], tip - Vector3(0, 1, 0))
	# Knollen auf der Wand: der Hügel ist gebaut, nicht gedrechselt.
	var paint := func(_m: Vector3, _n: Vector3) -> Color: return TERMITE[rng.randi() % TERMITE.size()]
	for k in 6:
		var i := rng.randi_range(0, rings.size() - 2)
		var p: Vector3 = rings[i][rng.randi() % sides]
		var r := rng.randf_range(0.2, 0.32) * s
		f.lump(p, Vector3(r, r * 1.3, r), 2, 5, rng, 0.2, paint)


const STEEL_A := Color(0.56, 0.58, 0.60)
const STEEL_B := Color(0.44, 0.46, 0.48)
const VANE := Color(0.78, 0.22, 0.16)
const TROUGH := Color(0.40, 0.42, 0.44)


## Windpumpe einer Farm: Gittermast, oben das Rad aus vierzehn Blättern (zum Betrachter, +z)
## und die rote Fahne dahinter; unten ein Wassertrog. Etwa 6.6 hoch (vor der Verkleinerung).
func _windpump() -> Forge:
	var f := Forge.new()
	var top := Vector3(0, 5.2, 0)
	var corners: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			corners.append(Vector3(x, 0, z))
	for c: Vector3 in corners:
		f.frustum(c * 0.9, top + c * 0.2, 0.06, 0.05, 4, STEEL_A)
	for y: float in [1.3, 2.6, 3.9]:
		var half := lerpf(0.9, 0.2, y / 5.2)
		var ring: Array[Vector3] = [Vector3(-half, y, -half), Vector3(half, y, -half),
				Vector3(half, y, half), Vector3(-half, y, half)]
		for i in 4:
			f.frustum(ring[i], ring[(i + 1) % 4], 0.03, 0.03, 4, STEEL_B)
	f.box(top + Vector3(0, 0.2, 0), Vector3(0.35, 0.35, 0.7), STEEL_B, 0.0)
	var hub := top + Vector3(0, 0.3, 0.4)
	for k in 14:
		var ang := TAU * k / 14.0
		var d := Vector3(cos(ang), sin(ang), 0)
		var side := Vector3(-sin(ang), cos(ang), 0)
		var p0 := hub + d * 0.25
		var p1 := hub + d * 1.4
		f.leaf_quad(p0, p1, p1 + side * 0.24, p0 + side * 0.08, STEEL_A if k % 2 == 0 else STEEL_B)
	f.frustum(top + Vector3(0, 0.25, 0), top + Vector3(0, 0.3, -1.7), 0.04, 0.04, 4, STEEL_B)
	f.leaf_quad(top + Vector3(0, 0.1, -1.0), top + Vector3(0, 0.1, -1.9), top + Vector3(0, 0.9, -1.9),
			top + Vector3(0, 0.6, -1.0), VANE)
	f.box(Vector3(1.7, 0.3, 0.4), Vector3(1.8, 0.6, 0.6), TROUGH, 0.2)
	return f


const TANK_A := Color(0.66, 0.68, 0.66)
const TANK_B := Color(0.56, 0.58, 0.56)
const TIMBER_A := Color(0.50, 0.36, 0.22)
const TIMBER_B := Color(0.40, 0.28, 0.17)


## Regenwassertank aus Wellblech auf einem Holzgestell: Die Rippen sind die wechselnden
## Seiten, oben ein flacher Kegel. Etwa 3.5 hoch.
func _water_tank() -> Forge:
	var f := Forge.new()
	var stand := 1.4
	for x in [-0.8, 0.8]:
		for z in [-0.8, 0.8]:
			f.box(Vector3(x, stand * 0.5, z), Vector3(0.16, stand, 0.16), TIMBER_B, 0.0)
	f.box(Vector3(0, stand + 0.06, 0), Vector3(2.1, 0.12, 2.1), TIMBER_A, 0.0)
	var base := Vector3(0, stand + 0.12, 0)
	f.frustum(base, base + Vector3(0, 1.6, 0), 1.0, 1.0, 16, TANK_A, 0.0, TANK_B)
	f.cone_cap(base + Vector3(0, 1.6, 0), 1.03, 0.35, 16, TANK_B, 0.0)
	f.frustum(Vector3(0.9, stand + 0.4, 0), Vector3(1.2, 0.0, 0), 0.05, 0.05, 5, STEEL_B)
	return f


const SHED_WALL_A := Color(0.50, 0.52, 0.50)
const SHED_WALL_B := Color(0.43, 0.45, 0.43)
const SHED_ROOF_A := Color(0.62, 0.63, 0.62)
const SHED_ROOF_B := Color(0.52, 0.53, 0.52)
const RUST := Color(0.56, 0.32, 0.20)
const DOOR := Color(0.26, 0.20, 0.15)


## Wellblechschuppen: Kasten mit Satteldach, Wände und Dach in Rippen aus zwei Tönen, ein
## paar rostige Bahnen, großes Tor vorn (+z), daneben ein kleiner Tank. Etwa 3.4 hoch,
## 4.4 breit.
func _tin_shed() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, 1.1, 0), Vector3(4.0, 2.2, 2.8), SHED_WALL_B, 0.0)
	# Rippen vorn und hinten: schmale Leisten im Wechsel, einzelne rostig.
	var ribs := 16
	for i in ribs:
		var x := -2.0 + 4.0 * (i + 0.5) / ribs
		var col := RUST if i == 3 or i == 11 else (SHED_WALL_A if i % 2 == 0 else SHED_WALL_B)
		for z: float in [1.41, -1.41]:
			f.box(Vector3(x, 1.1, z), Vector3(4.0 / ribs, 2.2, 0.03), col, 0.0)
	_gable(f, Vector3(0, 2.2, 0), 2.2, 1.65, 1.1, SHED_ROOF_A, SHED_ROOF_B, SHED_WALL_B, 12)
	f.box(Vector3(-0.4, 0.85, 1.44), Vector3(1.6, 1.7, 0.04), DOOR, 0.0)
	f.box(Vector3(1.2, 1.3, 1.44), Vector3(0.6, 0.5, 0.04), DOOR, 0.0)
	f.frustum(Vector3(2.7, 0, 0.6), Vector3(2.7, 1.3, 0.6), 0.5, 0.5, 12, TANK_A, 0.0, TANK_B)
	f.cone_cap(Vector3(2.7, 1.3, 0.6), 0.52, 0.18, 12, TANK_B, 0.0)
	return f


## Satteldach über einem Kasten: First entlang x in Höhe `rise` über `c`, Traufen bei
## z = ±`half_z`, die Giebel in `gable`. Mit `strips` > 1 liegt es in Bahnen entlang x,
## abwechselnd `col_a` und `col_b` (Wellblech); sonst vorn `col_a`, hinten `col_b`.
func _gable(f: Forge, c: Vector3, half_x: float, half_z: float, rise: float, col_a: Color,
		col_b: Color, gable: Color, strips := 1) -> void:
	var inside := c + Vector3(0, rise * 0.3, 0)
	for i in strips:
		var x0 := -half_x + 2.0 * half_x * i / strips
		var x1 := -half_x + 2.0 * half_x * (i + 1) / strips
		var r0 := c + Vector3(x0, rise, 0)
		var r1 := c + Vector3(x1, rise, 0)
		var front := col_a if strips == 1 or i % 2 == 0 else col_b
		var back := col_b if strips == 1 or i % 2 == 0 else col_a
		f.tri_out(c + Vector3(x0, 0, half_z), c + Vector3(x1, 0, half_z), r1, front, inside)
		f.tri_out(c + Vector3(x0, 0, half_z), r1, r0, front, inside)
		f.tri_out(c + Vector3(x0, 0, -half_z), c + Vector3(x1, 0, -half_z), r1, back, inside)
		f.tri_out(c + Vector3(x0, 0, -half_z), r1, r0, back, inside)
	var fl := c + Vector3(-half_x, 0, half_z)
	var fr := c + Vector3(half_x, 0, half_z)
	var bl := c + Vector3(-half_x, 0, -half_z)
	var br := c + Vector3(half_x, 0, -half_z)
	f.tri_out(fl, bl, c + Vector3(-half_x, rise, 0), gable, inside)
	f.tri_out(fr, br, c + Vector3(half_x, rise, 0), gable, inside)
	f.tri_out(fl, fr, br, gable, inside + Vector3(0, 1, 0))
	f.tri_out(fl, br, bl, gable, inside + Vector3(0, 1, 0))


const COTTAGE_WALL := Color(0.90, 0.86, 0.76)
const COTTAGE_TRIM := Color(0.36, 0.52, 0.50)
const COTTAGE_ROOF_A := Color(0.62, 0.24, 0.18)
const COTTAGE_ROOF_B := Color(0.52, 0.19, 0.15)
const WINDOW := Color(0.30, 0.40, 0.48)


## Holzhaus der Vorstadt auf niedrigen Stelzen: helle Bretterwand, Veranda vorn (+z) mit
## Pfosten, rotes Walmdach über beidem, ein Schornstein. Etwa 4.3 hoch.
func _cottage() -> Forge:
	var f := Forge.new()
	var floor_y := 0.5
	for x in [-1.6, 0.0, 1.6]:
		for z in [-1.3, 0.0, 1.3, 2.3]:
			f.box(Vector3(x, floor_y * 0.5, z), Vector3(0.18, floor_y, 0.18), TIMBER_B, 0.0)
	f.box(Vector3(0, floor_y + 0.06, 0.45), Vector3(3.6, 0.12, 4.0), TIMBER_A, 0.0)
	f.box(Vector3(0, floor_y + 1.2, -0.3), Vector3(3.4, 2.3, 2.6), COTTAGE_WALL, 0.0)
	for x in [-1.1, 1.1]:
		f.box(Vector3(x, floor_y + 1.3, 1.01), Vector3(0.7, 0.8, 0.04), WINDOW, 0.0)
		f.box(Vector3(x, floor_y + 1.3, 1.03), Vector3(0.8, 0.08, 0.04), COTTAGE_TRIM, 0.0)
	f.box(Vector3(0, floor_y + 1.0, 1.01), Vector3(0.7, 1.7, 0.04), COTTAGE_TRIM, 0.0)
	for x in [-1.65, -0.6, 0.6, 1.65]:
		f.box(Vector3(x, floor_y + 1.2, 2.3), Vector3(0.12, 2.3, 0.12), COTTAGE_WALL, 0.0)
	f.box(Vector3(0, floor_y + 0.55, 2.3), Vector3(3.4, 0.06, 0.06), COTTAGE_TRIM, 0.0)
	# Walmdach: eine vierseitige Pyramide über Haus und Veranda
	f.cone_cap(Vector3(0, floor_y + 2.35, 0.45), 3.3, 1.5, 4, COTTAGE_ROOF_A, PI / 4.0, true)
	f.box(Vector3(1.0, floor_y + 3.3, -0.6), Vector3(0.4, 1.2, 0.4), COTTAGE_ROOF_B, 0.0)
	return f


const GLASS_A := Color(0.44, 0.56, 0.66)
const GLASS_B := Color(0.36, 0.47, 0.57)
const SLAB := Color(0.84, 0.83, 0.80)


## Zwei Bürotürme als Stadtkulisse: Glas zwischen hellen Geschossdecken, oben Technik.
## Etwa 8 hoch (vor der Verkleinerung) — gehört ins Umland, nicht ans Feld.
func _office_towers() -> Forge:
	var f := Forge.new()
	for tower: Array in [[Vector3(0, 0, 0), Vector2(2.6, 8.0), GLASS_A], [Vector3(2.6, 0, 0.8), Vector2(2.0, 5.6), GLASS_B]]:
		var at: Vector3 = tower[0]
		var w: float = tower[1].x
		var h: float = tower[1].y
		var glass: Color = tower[2]
		f.box(at + Vector3(0, h * 0.5, 0), Vector3(w, h, w), glass, 0.0)
		var floors := int(h / 0.8)
		for i in floors + 1:
			f.box(at + Vector3(0, i * h / floors, 0), Vector3(w + 0.1, 0.14, w + 0.1), SLAB, 0.0)
		f.box(at + Vector3(0.2, h + 0.3, -0.1), Vector3(w * 0.4, 0.6, w * 0.4), SLAB, 0.0)
	return f


const SURF_RED := Color(0.80, 0.18, 0.14)
const SURF_YELLOW := Color(0.96, 0.78, 0.18)


## Rettungsschwimmer-Turm: Hütte auf Stelzen, rot und gelb, Leiter vorn (+z) und ein
## Fähnchen. Etwa 4.2 hoch.
func _lifeguard_tower() -> Forge:
	var f := Forge.new()
	var deck := 2.0
	for x in [-0.8, 0.8]:
		for z in [-0.8, 0.8]:
			f.box(Vector3(x, deck * 0.5, z), Vector3(0.14, deck, 0.14), TIMBER_B, 0.0)
	f.box(Vector3(0, deck + 0.06, 0.2), Vector3(2.0, 0.12, 2.4), TIMBER_A, 0.0)
	f.box(Vector3(0, deck + 0.55, -0.1), Vector3(1.7, 0.9, 1.6), SURF_RED, 0.0)
	f.box(Vector3(0, deck + 1.15, -0.1), Vector3(1.7, 0.3, 1.6), WINDOW, 0.0)
	f.box(Vector3(0, deck + 1.4, -0.1), Vector3(2.1, 0.14, 2.0), SURF_YELLOW, 0.0)
	for x in [-0.35, 0.35]:
		f.frustum(Vector3(x, 0, 1.9), Vector3(x, deck, 1.3), 0.05, 0.05, 4, TIMBER_B)
	for i in 5:
		var t := (i + 0.5) / 5.0
		f.box(Vector3(0, deck * t, 1.9 - 0.6 * t), Vector3(0.7, 0.05, 0.12), TIMBER_A, 0.0)
	f.frustum(Vector3(0.9, deck + 1.4, -0.9), Vector3(0.9, deck + 2.4, -0.9), 0.03, 0.03, 4, STEEL_B)
	f.leaf_quad(Vector3(0.9, deck + 2.35, -0.9), Vector3(0.9, deck + 2.05, -0.9),
			Vector3(1.5, deck + 2.05, -0.9), Vector3(1.5, deck + 2.35, -0.9), SURF_RED)
	f.leaf_quad(Vector3(0.9, deck + 2.05, -0.9), Vector3(0.9, deck + 1.75, -0.9),
			Vector3(1.5, deck + 1.75, -0.9), Vector3(1.5, deck + 2.05, -0.9), SURF_YELLOW)
	return f


const THATCH_A := Color(0.70, 0.58, 0.36)
const THATCH_B := Color(0.60, 0.49, 0.29)
const WEAVE := Color(0.72, 0.62, 0.44)


## Stelzenhütte im Küstendorf: Plattform auf Pfählen, geflochtene Wand, steiles Strohdach,
## Leiter vorn (+z). Etwa 4.2 hoch.
func _stilt_hut() -> Forge:
	var f := Forge.new()
	var deck := 1.2
	for x in [-1.2, 0.0, 1.2]:
		for z in [-1.1, 1.1]:
			f.box(Vector3(x, deck * 0.5, z), Vector3(0.16, deck, 0.16), TIMBER_B, 0.0)
	f.box(Vector3(0, deck + 0.06, 0.2), Vector3(2.9, 0.12, 2.8), TIMBER_A, 0.0)
	f.box(Vector3(0, deck + 0.8, -0.1), Vector3(2.3, 1.5, 1.9), WEAVE, 0.0)
	f.box(Vector3(0, deck + 0.7, 0.86), Vector3(0.6, 1.1, 0.04), DOOR, 0.0)
	_gable(f, Vector3(0, deck + 1.55, -0.1), 1.5, 1.35, 1.4, THATCH_A, THATCH_B, WEAVE)
	for x in [-0.3, 0.3]:
		f.frustum(Vector3(x, 0, 2.1), Vector3(x, deck + 0.1, 1.5), 0.04, 0.04, 4, TIMBER_B)
	for i in 4:
		var t := (i + 0.5) / 4.0
		f.box(Vector3(0, (deck + 0.1) * t, 2.1 - 0.6 * t), Vector3(0.6, 0.05, 0.1), TIMBER_A, 0.0)
	return f


const RANGER_ROOF := Color(0.36, 0.46, 0.34)


## Ranger-Ausguck: vier hohe Holzbeine, Plattform mit Geländer, darüber ein Blechdach auf
## Pfosten, eine Leiter. Etwa 6 hoch (vor der Verkleinerung).
func _lookout_tower() -> Forge:
	var f := Forge.new()
	var deck := 3.8
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			f.frustum(Vector3(x, 0, z), Vector3(x * 0.8, deck, z * 0.8), 0.1, 0.08, 4, TIMBER_B)
	for y: float in [1.3, 2.6]:
		var half := lerpf(1.0, 0.8, y / deck)
		f.frustum(Vector3(-half, y, half), Vector3(half, y, half), 0.04, 0.04, 4, TIMBER_A)
		f.frustum(Vector3(-half, y, -half), Vector3(half, y, -half), 0.04, 0.04, 4, TIMBER_A)
	f.box(Vector3(0, deck + 0.06, 0), Vector3(2.0, 0.12, 2.0), TIMBER_A, 0.0)
	for x in [-0.9, 0.9]:
		for z in [-0.9, 0.9]:
			f.box(Vector3(x, deck + 0.9, z), Vector3(0.1, 1.7, 0.1), TIMBER_B, 0.0)
	for z in [-0.9, 0.9]:
		f.box(Vector3(0, deck + 0.55, z), Vector3(1.9, 0.08, 0.06), TIMBER_A, 0.0)
	f.box(Vector3(-0.9, deck + 0.55, 0), Vector3(0.06, 0.08, 1.9), TIMBER_A, 0.0)
	f.cone_cap(Vector3(0, deck + 1.75, 0), 1.75, 0.7, 4, RANGER_ROOF, PI / 4.0, true)
	for x in [0.55, 0.95]:
		f.frustum(Vector3(x, 0, 1.6), Vector3(x, deck, 1.0), 0.04, 0.04, 4, TIMBER_B)
	return f


const LAMP_POST := Color(0.16, 0.26, 0.20)
const LAMP_GLASS := Color(0.95, 0.88, 0.62)


## Straßenlaterne im Park: dunkelgrüner Mast mit Sockel und Zierring, oben eine Laterne
## mit Dach und Knauf. Etwa 3.5 hoch.
func _street_lamp() -> Forge:
	var f := Forge.new()
	var rng := _rng(179)
	f.frustum(Vector3.ZERO, Vector3(0, 0.5, 0), 0.22, 0.14, 6, LAMP_POST)
	f.frustum(Vector3(0, 0.5, 0), Vector3(0, 2.8, 0), 0.1, 0.08, 6, LAMP_POST)
	f.frustum(Vector3(0, 1.6, 0), Vector3(0, 1.72, 0), 0.14, 0.14, 6, LAMP_POST)
	f.frustum(Vector3(0, 2.8, 0), Vector3(0, 2.9, 0), 0.08, 0.2, 6, LAMP_POST)
	f.frustum(Vector3(0, 2.9, 0), Vector3(0, 3.3, 0), 0.2, 0.3, 6, LAMP_GLASS)
	f.cone_cap(Vector3(0, 3.3, 0), 0.38, 0.24, 6, LAMP_POST, 0.0, true)
	f.blob(Vector3(0, 3.6, 0), 0.06, LAMP_POST, rng, 0.0)
	return f


const BENCH_WOOD := Color(0.56, 0.37, 0.20)
const BENCH_IRON := Color(0.18, 0.20, 0.20)


## Parkbank: zwei eiserne Seitenteile, drei Sitz- und zwei Lehnenlatten. Etwa 1.9 lang
## (entlang x) und 0.9 hoch.
func _park_bench() -> Forge:
	var f := Forge.new()
	for x in [-0.8, 0.8]:
		f.box(Vector3(x, 0.22, 0), Vector3(0.07, 0.44, 0.55), BENCH_IRON, 0.0)
		f.box(Vector3(x, 0.66, -0.25), Vector3(0.07, 0.5, 0.07), BENCH_IRON, 0.0)
	for z in [-0.18, 0.0, 0.18]:
		f.box(Vector3(0, 0.46, z), Vector3(1.9, 0.05, 0.15), BENCH_WOOD, 0.0)
	for y in [0.62, 0.82]:
		f.box(Vector3(0, y, -0.27), Vector3(1.9, 0.13, 0.04), BENCH_WOOD, 0.0)
	return f


const BIN_BODY := Color(0.20, 0.36, 0.24)
const BIN_LID := Color(0.92, 0.74, 0.16)
const TYRE := Color(0.12, 0.12, 0.12)


## Mülltonne auf Rädern mit gelbem Deckel. Etwa 1.1 hoch.
func _wheelie_bin() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, 0.52, 0), Vector3(0.6, 0.92, 0.7), BIN_BODY, 0.0)
	f.box(Vector3(0, 1.02, 0.02), Vector3(0.66, 0.08, 0.76), BIN_LID, 0.0)
	for x in [-0.25, 0.25]:
		f.frustum(Vector3(x - 0.05, 0.1, -0.35), Vector3(x + 0.05, 0.1, -0.35), 0.1, 0.1, 8, TYRE)
	return f


const BRICK := Color(0.62, 0.34, 0.24)
const HOTPLATE := Color(0.20, 0.20, 0.22)


## Gemauerter Grill, wie er in jedem Park steht: Ziegelsockel, Stahlplatte, Haube.
## Etwa 1.3 hoch.
func _bbq() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, 0.42, 0), Vector3(1.4, 0.84, 0.8), BRICK, 0.0)
	f.box(Vector3(0, 0.88, 0), Vector3(1.2, 0.06, 0.7), HOTPLATE, 0.0)
	f.box(Vector3(0, 1.1, -0.3), Vector3(1.2, 0.4, 0.14), STEEL_B, 0.0)
	f.box(Vector3(0.75, 0.9, 0), Vector3(0.12, 0.1, 0.6), STEEL_A, 0.0)
	return f


const LAUNDRY := [Color(0.92, 0.92, 0.88), Color(0.36, 0.56, 0.78), Color(0.90, 0.46, 0.36),
		Color(0.94, 0.80, 0.30)]


## Wäschespinne (Hills Hoist): Mast, vier schräge Arme, drei Leinenringe, daran Wäsche.
## Etwa 2.1 hoch und 2.6 breit (vor der Vergrößerung).
func _hills_hoist() -> Forge:
	var f := Forge.new()
	var rng := _rng(157)
	var hub := Vector3(0, 2.0, 0)
	f.frustum(Vector3.ZERO, hub + Vector3(0, 0.1, 0), 0.05, 0.04, 6, STEEL_A)
	var arms: Array[Vector3] = []
	for k in 4:
		var yaw := TAU * k / 4.0 + PI / 4.0
		var end := Vector3(cos(yaw) * 1.3, 1.75, sin(yaw) * 1.3)
		f.frustum(hub, end, 0.03, 0.03, 4, STEEL_A)
		arms.append(Vector3(cos(yaw), 0, sin(yaw)))
	for r: float in [0.5, 0.9, 1.3]:
		var y := lerpf(2.0, 1.75, r / 1.3)
		for k in 4:
			f.frustum(arms[k] * r + Vector3(0, y, 0), arms[(k + 1) % 4] * r + Vector3(0, y, 0), 0.012, 0.012, 3, STEEL_B)
	for k in 6:
		var a := arms[k % 4] * 0.9
		var b := arms[(k + 1) % 4] * 0.9
		var t0 := rng.randf_range(0.15, 0.5)
		var p0 := a.lerp(b, t0) + Vector3(0, lerpf(2.0, 1.75, 0.9 / 1.3), 0)
		var p1 := a.lerp(b, t0 + 0.3) + Vector3(0, lerpf(2.0, 1.75, 0.9 / 1.3), 0)
		var drop := Vector3(0, -rng.randf_range(0.4, 0.7), 0)
		f.leaf_quad(p0, p1, p1 + drop, p0 + drop, LAUNDRY[k % LAUNDRY.size()])
	return f


const BOARDS := [Color(0.95, 0.94, 0.88), Color(0.30, 0.62, 0.78), Color(0.94, 0.56, 0.24)]


## Drei Surfbretter, aufrecht in den Sand gesteckt, vor einem Holzbalken. Etwa 2.3 hoch.
func _surfboards() -> Forge:
	var f := Forge.new()
	var rng := _rng(163)
	for x in [-1.0, 1.0]:
		f.box(Vector3(x, 0.6, -0.25), Vector3(0.12, 1.2, 0.12), TIMBER_B, 0.0)
	f.box(Vector3(0, 1.15, -0.25), Vector3(2.2, 0.1, 0.1), TIMBER_A, 0.0)
	for k in 3:
		var col: Color = BOARDS[k]
		var paint := func(_m: Vector3, _n: Vector3) -> Color: return col
		f.lump(Vector3(-0.6 + 0.6 * k, 1.0, 0), Vector3(0.24, 1.15, 0.05), 5, 8, rng, 0.0, paint, -0.9)
	return f


const CANOE_A := Color(0.64, 0.30, 0.18)
const CANOE_B := Color(0.54, 0.24, 0.14)
const CANOE_INSIDE := Color(0.46, 0.33, 0.22)


## Kanu am Ufer, offen: spitzer Rumpf mit hochgezogenen Enden, innen dunkleres Holz, zwei
## Querhölzer und ein Paddel darin. Etwa 3.2 lang und 0.5 hoch.
func _canoe() -> Forge:
	var f := Forge.new()
	var half := 1.6
	_hull(f, half, 0.45, 0.4, 0.12, CANOE_A, CANOE_B, CANOE_INSIDE)
	for x: float in [-0.55, 0.55]:
		var q := 1.0 - (x / half) * (x / half)
		f.box(Vector3(x, 0.38, 0), Vector3(0.12, 0.05, 0.85 * 0.45 * q * 2.0), TIMBER_A, 0.0)
	f.box(Vector3(0.1, 0.2, 0.05), Vector3(1.3, 0.04, 0.08), TIMBER_A, 0.15)
	f.box(Vector3(0.8, 0.2, 0.15), Vector3(0.36, 0.04, 0.18), TIMBER_A, 0.15)
	return f


## Offener Rumpf entlang x von -`half` bis `half`: `beam` halbe Breite und `depth` Tiefe
## mittschiffs, zu den Enden spitz; `sheer` hebt Bug und Heck an. Außen `col_a` am
## Dollbord, sonst `col_b`, innen `col_in`. `at` verschiebt den ganzen Rumpf.
func _hull(f: Forge, half: float, beam: float, depth: float, sheer: float, col_a: Color,
		col_b: Color, col_in: Color, at := Vector3.ZERO) -> void:
	var n := 10
	var sides := 6
	var outer: Array = []
	var inner: Array = []
	for i in n + 1:
		var x := -half + 2.0 * half * i / n
		var q := 1.0 - (x / half) * (x / half)
		var w := beam * q
		var d := depth * (0.7 + 0.3 * q)
		var rim := depth + 0.02 + sheer * (1.0 - q)
		var o: Array[Vector3] = []
		var inn: Array[Vector3] = []
		for j in sides + 1:
			var ang := PI * j / sides
			o.append(at + Vector3(x, rim - d * sin(ang), w * cos(ang)))
			inn.append(at + Vector3(x, rim - 0.85 * d * sin(ang), 0.85 * w * cos(ang)))
		outer.append(o)
		inner.append(inn)
	for i in n:
		var x := -half + 2.0 * half * (i + 0.5) / n
		var axis := at + Vector3(x, depth * 0.75, 0)
		for j in sides:
			var col := col_a if j < 1 or j >= sides - 1 else col_b
			f.tri_out(outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], col, axis)
			f.tri_out(outer[i][j], outer[i + 1][j + 1], outer[i][j + 1], col, axis)
			# Innen zeigt die Fläche zur Achse: `inside` ist ihr Spiegelpunkt jenseits der Wand.
			var c: Vector3 = (inner[i][j] + inner[i + 1][j + 1]) * 0.5
			f.tri_out(inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], col_in, c * 2.0 - axis)
			f.tri_out(inner[i][j], inner[i + 1][j + 1], inner[i][j + 1], col_in, c * 2.0 - axis)
		for j: int in [0, sides]:
			var c2: Vector3 = (outer[i][j] + inner[i + 1][j]) * 0.5
			f.tri_out(outer[i][j], outer[i + 1][j], inner[i + 1][j], col_a, c2 - Vector3(0, 1, 0))
			f.tri_out(outer[i][j], inner[i + 1][j], inner[i][j], col_a, c2 - Vector3(0, 1, 0))


const NET := Color(0.32, 0.34, 0.30)
const FLOAT := Color(0.92, 0.50, 0.18)


## Gestell mit hängendem Fischernetz und Schwimmern. Etwa 2 hoch, 2.4 breit.
func _net_rack() -> Forge:
	var f := Forge.new()
	var rng := _rng(173)
	for x in [-1.1, 1.1]:
		f.box(Vector3(x, 1.0, 0), Vector3(0.12, 2.0, 0.12), TIMBER_B, rng.randf_range(-0.1, 0.1))
	f.box(Vector3(0, 1.9, 0), Vector3(2.5, 0.1, 0.1), TIMBER_A, 0.0)
	f.leaf_quad(Vector3(-1.0, 1.85, 0.05), Vector3(1.0, 1.85, 0.05), Vector3(0.8, 0.4, 0.15),
			Vector3(-0.9, 0.6, 0.15), NET)
	for k in 5:
		f.blob(Vector3(-0.8 + 0.4 * k, 1.8, 0.1), 0.08, FLOAT, rng, 0.0)
	return f


# --- Latein: Rom, Dörfer der Jahreszeiten, Himmelsruinen ------------------------------

const TRAV_A := Color(0.84, 0.78, 0.66)
const TRAV_B := Color(0.74, 0.68, 0.56)
const TRAV_DARK := Color(0.62, 0.56, 0.46)
const PLASTER_A := Color(0.90, 0.83, 0.70)
const PLASTER_B := Color(0.80, 0.72, 0.58)
const TILE_A := Color(0.72, 0.36, 0.22)
const TILE_B := Color(0.60, 0.28, 0.17)
const STATUE_A := Color(0.90, 0.88, 0.84)
const STATUE_B := Color(0.78, 0.76, 0.72)
const WATER_A := Color(0.30, 0.56, 0.70)
const WATER_B := Color(0.46, 0.70, 0.80)


## Halbrunder Bogen in der x-y-Ebene, `c` die Mitte der Kämpferlinie, `depth` tief entlang
## z: Keilsteine zwischen `r_in` und `r_out`, abwechselnd `col_a` und `col_b`. Die Zwickel
## bis zur Oberkante `c.y + r_out` füllt `spandrel` — so steht der Bogen in einer Wand.
## `stones` gerade, damit die Fuge im Scheitel liegt und die Zwickel sauber teilen.
func _arch(f: Forge, c: Vector3, r_in: float, r_out: float, depth: float, col_a: Color,
		col_b: Color, spandrel: Color, stones := 8) -> void:
	var dz := Vector3(0, 0, depth * 0.5)
	for i in stones:
		var a0 := PI * i / stones
		var a1 := PI * (i + 1) / stones
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		var i0 := c + d0 * r_in
		var i1 := c + d1 * r_in
		var o0 := c + d0 * r_out
		var o1 := c + d1 * r_out
		var mid := c + (d0 + d1).normalized() * (r_in + r_out) * 0.5
		var col := col_a if i % 2 == 0 else col_b
		for s: Vector3 in [dz, -dz]:
			f.tri_out(i0 + s, i1 + s, o1 + s, col, mid)
			f.tri_out(i0 + s, o1 + s, o0 + s, col, mid)
		f.tri_out(i0 + dz, i1 + dz, i1 - dz, col, mid)
		f.tri_out(i0 + dz, i1 - dz, i0 - dz, col, mid)
		f.tri_out(o0 + dz, o1 + dz, o1 - dz, col, mid)
		f.tri_out(o0 + dz, o1 - dz, o0 - dz, col, mid)
		var corner := c + Vector3(r_out if i < stones / 2 else -r_out, r_out, 0)
		f.tri_out(corner + dz, o0 + dz, o1 + dz, spandrel, c)
		f.tri_out(corner - dz, o0 - dz, o1 - dz, spandrel, c)


const UMBRELLA_BARK := Color(0.48, 0.33, 0.24)
const UMBRELLA_A := Color(0.21, 0.35, 0.17)
const UMBRELLA_B := Color(0.15, 0.27, 0.12)


## Pinie: hoher, leicht geneigter Stamm, oben ein flacher Schirm aus Nadelpolstern — der
## Baum Roms über Mauern und Plätzen. Etwa 6.5 hoch.
func _stone_pine() -> Forge:
	var f := Forge.new()
	var rng := _rng(211)
	var knee := Vector3(0.35, 2.6, 0.1)
	var fork := Vector3(0.2, 4.6, 0.25)
	f.frustum(Vector3.ZERO, knee, 0.32, 0.25, 6, UMBRELLA_BARK, 0.0)
	f.frustum(knee, fork, 0.25, 0.18, 6, UMBRELLA_BARK, 0.3)
	for arm: Vector3 in [Vector3(-1.1, 5.3, 0.3), Vector3(1.2, 5.4, -0.2), Vector3(0.1, 5.5, -1.0)]:
		f.frustum(fork, arm, 0.14, 0.08, 5, UMBRELLA_BARK, 0.0)
	var paint := func(_m: Vector3, n: Vector3) -> Color:
		return UMBRELLA_A if n.y > 0.2 and rng.randf() < 0.7 else UMBRELLA_B
	for pad: Array in [[Vector3(0.1, 5.8, 0), Vector3(2.4, 0.55, 2.2)],
			[Vector3(-1.3, 5.6, 0.4), Vector3(1.3, 0.45, 1.2)],
			[Vector3(1.4, 5.7, -0.3), Vector3(1.3, 0.45, 1.3)],
			[Vector3(0.2, 5.5, -1.3), Vector3(1.2, 0.4, 1.1)]]:
		f.lump(pad[0], pad[1], 3, 9, rng, 0.12, paint)
	return f


## Römisches Wohnhaus: verputzter Kasten unter flachem Ziegeldach in Bahnen, ein niedriger
## Anbau daneben, dunkle Tür mit Sturz und kleine hohe Fenster. Etwa 3.5 hoch.
func _roman_house() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, 1.3, 0), Vector3(3.6, 2.6, 2.8), PLASTER_A, 0.0)
	_gable(f, Vector3(0, 2.6, 0), 1.95, 1.6, 0.8, TILE_A, TILE_B, PLASTER_B, 8)
	f.box(Vector3(2.6, 0.9, 0.4), Vector3(1.8, 1.8, 2.0), PLASTER_B, 0.0)
	_gable(f, Vector3(2.6, 1.8, 0.4), 1.0, 1.15, 0.5, TILE_B, TILE_A, PLASTER_A, 4)
	f.box(Vector3(-0.6, 0.8, 1.42), Vector3(0.8, 1.6, 0.04), DOOR, 0.0)
	f.box(Vector3(-0.6, 1.66, 1.45), Vector3(1.0, 0.12, 0.1), TRAV_B, 0.0)
	for x in [0.5, 1.2]:
		f.box(Vector3(x, 1.9, 1.42), Vector3(0.36, 0.42, 0.04), DOOR, 0.0)
	f.box(Vector3(2.9, 0.7, 1.42), Vector3(0.5, 0.5, 0.04), DOOR, 0.0)
	return f


## Marmorstandbild auf Stufensockel: eine Gestalt in Toga, den rechten Arm erhoben, der
## linke hält den Faltenwurf. Etwa 4 hoch.
func _statue() -> Forge:
	var f := Forge.new()
	var rng := _rng(223)
	f.box(Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 1.6), TRAV_B, 0.0)
	f.box(Vector3(0, 1.0, 0), Vector3(1.1, 1.0, 1.1), TRAV_A, 0.0)
	f.box(Vector3(0, 1.56, 0), Vector3(1.3, 0.12, 1.3), TRAV_B, 0.0)
	var y := 1.62
	var marble := func(_m: Vector3, n: Vector3) -> Color:
		return STATUE_A if n.y > -0.2 else STATUE_B
	f.frustum(Vector3(0, y, 0), Vector3(0, y + 1.3, 0), 0.42, 0.3, 8, STATUE_A, 0.2, STATUE_B)
	f.lump(Vector3(0, y + 1.5, 0), Vector3(0.36, 0.34, 0.26), 3, 7, rng, 0.05, marble)
	f.lump(Vector3(0, y + 2.0, 0.02), Vector3(0.17, 0.2, 0.17), 3, 6, rng, 0.04, marble)
	f.frustum(Vector3(0.32, y + 1.62, 0), Vector3(0.62, y + 2.35, 0.12), 0.09, 0.07, 5, STATUE_A)
	f.frustum(Vector3(-0.33, y + 1.6, 0), Vector3(-0.42, y + 0.95, 0.12), 0.1, 0.08, 5, STATUE_B)
	f.frustum(Vector3(-0.3, y + 1.55, 0.05), Vector3(-0.32, y + 0.55, 0.2), 0.16, 0.26, 5, STATUE_B, 0.3)
	return f


## Triumphbogen: zwei Pfeiler mit vorgesetzten Halbsäulen, dazwischen der Bogen aus
## Keilsteinen, darüber die Attika zwischen zwei Gesimsen. Etwa 5 hoch, 4.4 breit.
func _triumphal_arch() -> Forge:
	var f := Forge.new()
	var rng := _rng(227)
	var depth := 1.6
	var r_in := 1.1
	var r_out := 1.5
	var spring := 2.2
	var top := spring + r_out
	for side: float in [-1.0, 1.0]:
		f.box(Vector3(side * (r_in + 0.55), top * 0.5, 0), Vector3(1.1, top, depth), TRAV_A, 0.0)
		f.box(Vector3(side * (r_in + 0.55), 0.15, 0), Vector3(1.4, 0.3, depth + 0.6), TRAV_DARK, 0.0)
		for z: float in [depth * 0.5 + 0.12, -depth * 0.5 - 0.12]:
			f.drum(Vector3(side * (r_in + 0.8), 0.3, z), 0.16, top - 0.3, 8, TRAV_B, rng, 0.0)
	_arch(f, Vector3(0, spring, 0), r_in, r_out, depth, TRAV_B, TRAV_A, TRAV_A)
	var w := 2.0 * (r_in + 1.1)
	f.box(Vector3(0, top + 0.12, 0), Vector3(w + 0.3, 0.24, depth + 0.5), TRAV_DARK, 0.0)
	f.box(Vector3(0, top + 0.74, 0), Vector3(w, 1.0, depth), TRAV_A, 0.0)
	f.box(Vector3(0, top + 1.3, 0), Vector3(w + 0.2, 0.14, depth + 0.2), TRAV_DARK, 0.0)
	return f


## Tempel mit Säulenvorhalle nach +x: Podium mit Treppe, vier Säulen, Gebälk, flaches
## Ziegeldach mit Giebeldreieck; dahinter die geschlossene Cella. Etwa 4.6 hoch.
func _temple() -> Forge:
	var f := Forge.new()
	var rng := _rng(229)
	f.box(Vector3(0, 0.4, 0), Vector3(5.2, 0.8, 3.6), TRAV_B, 0.0)
	for k in 3:
		var h := 0.8 * (3 - k) / 3.0
		f.box(Vector3(2.75 + 0.3 * k, h * 0.5, 0), Vector3(0.3, h, 2.4), TRAV_A, 0.0)
	for z: float in [-1.35, -0.45, 0.45, 1.35]:
		f.drum(Vector3(2.0, 0.8, z), 0.22, 2.6, 10, STATUE_A, rng, 0.0, STATUE_B)
	f.box(Vector3(-0.7, 2.1, 0), Vector3(3.6, 2.6, 3.0), PLASTER_A, 0.0)
	f.box(Vector3(1.1, 1.5, 0), Vector3(0.05, 1.8, 0.9), DOOR, 0.0)
	f.box(Vector3(0, 3.55, 0), Vector3(5.1, 0.3, 3.5), TRAV_A, 0.0)
	_gable(f, Vector3(0, 3.7, 0), 2.65, 1.85, 0.9, TILE_A, TILE_B, TRAV_A, 10)
	return f


const AMPHORA_A := Color(0.72, 0.42, 0.26)
const AMPHORA_B := Color(0.62, 0.34, 0.20)


## Amphoren: drei stehende an einem Holzgestell, eine liegende davor. Etwa 1.1 hoch.
func _amphorae() -> Forge:
	var f := Forge.new()
	var rng := _rng(233)
	for k in 3:
		_amphora(f, Vector3(-0.5 + 0.5 * k, 0, rng.randf_range(-0.06, 0.06)), Vector3.UP, 1.0 - 0.08 * k)
	_amphora(f, Vector3(-0.35, 0.2, 0.55), Vector3(1, 0.08, 0.2).normalized(), 0.9)
	for x in [-0.8, 0.8]:
		f.box(Vector3(x, 0.4, -0.25), Vector3(0.08, 0.8, 0.08), TIMBER_B, 0.0)
	f.box(Vector3(0, 0.62, -0.25), Vector3(1.7, 0.06, 0.06), TIMBER_A, 0.0)
	return f


## Eine Amphora ab `base` entlang `axis`, `s` hoch: Fuß, bauchiger Körper, Hals, zwei
## Henkel.
func _amphora(f: Forge, base: Vector3, axis: Vector3, s: float) -> void:
	var prof := [[0.0, 0.03], [0.12, 0.13], [0.45, 0.22], [0.7, 0.19], [0.8, 0.08], [0.98, 0.065],
			[1.04, 0.09]]
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		f.frustum(base + axis * a[0] * s, base + axis * b[0] * s, a[1] * s, b[1] * s, 8,
				AMPHORA_A, 0.0, AMPHORA_B)
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	for k: float in [-1.0, 1.0]:
		f.frustum(base + (axis * 0.94 + side * k * 0.07) * s, base + (axis * 0.72 + side * k * 0.17) * s,
				0.025 * s, 0.025 * s, 4, AMPHORA_B)


## Bauschutt vom Forum: ein behauener Quader mit Gesims, eine liegende Säulentrommel, ein
## paar Brocken. Etwa 1.1 breit — steht im Platz der Felsen (~2.3).
func _marble_rubble() -> Forge:
	var f := Forge.new()
	var rng := _rng(239)
	f.box(Vector3(-0.15, 0.16, 0), Vector3(0.62, 0.32, 0.42), TRAV_B, 0.3)
	f.box(Vector3(-0.15, 0.36, 0), Vector3(0.68, 0.08, 0.48), TRAV_DARK, 0.3)
	f.frustum(Vector3(0.25, 0.14, -0.15), Vector3(0.45, 0.14, 0.3), 0.14, 0.14, 10, STATUE_A, 0.0, STATUE_B)
	for k in 3:
		var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(0.25, 0.45))
		var sz := rng.randf_range(0.08, 0.14)
		f.box(p + Vector3(0, sz * 0.5, 0), Vector3(sz * 1.4, sz, sz), TRAV_B, rng.randf_range(0.0, 1.5))
	return f


## Brunnen: achteckiges Becken mit Wasser, in der Mitte ein Pfeiler mit Schale, aus der
## es in vier Strahlen fällt. Etwa 1.7 hoch, 2.2 breit.
func _fountain() -> Forge:
	var f := Forge.new()
	f.frustum(Vector3.ZERO, Vector3(0, 0.42, 0), 0.95, 0.95, 8, WATER_A, PI / 8.0)
	for k in 8:
		var a := TAU * k / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * 1.0
		f.box(p + Vector3(0, 0.3, 0), Vector3(0.86, 0.6, 0.16), TRAV_A if k % 2 == 0 else TRAV_B, -(a + PI / 2.0))
	f.frustum(Vector3.ZERO, Vector3(0, 1.1, 0), 0.2, 0.14, 8, TRAV_B, 0.0)
	f.frustum(Vector3(0, 1.1, 0), Vector3(0, 1.3, 0), 0.2, 0.5, 8, TRAV_A, 0.0)
	f.frustum(Vector3(0, 1.26, 0), Vector3(0, 1.31, 0), 0.44, 0.44, 8, WATER_B, 0.0)
	f.frustum(Vector3(0, 1.3, 0), Vector3(0, 1.6, 0), 0.07, 0.04, 6, TRAV_B, 0.0)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		f.blade(d * 0.5 + Vector3(0, 1.3, 0) - side, d * 0.5 + Vector3(0, 1.3, 0) + side, d * 0.72 + Vector3(0, 0.42, 0), WATER_B)
	return f


const HULL_A := Color(0.36, 0.24, 0.15)
const HULL_B := Color(0.46, 0.31, 0.19)
const SAIL := Color(0.90, 0.84, 0.70)


## Römisches Ruderboot: hochgezogener Rumpf, der Bug in einem geschwungenen Steven, je Seite
## drei Riemen und ein kurzer Mast mit gerefftem Segel. Etwa 3.6 lang.
func _roman_boat() -> Forge:
	var f := Forge.new()
	_hull(f, 1.8, 0.62, 0.5, 0.3, HULL_A, HULL_B, TIMBER_B)
	f.frustum(Vector3(1.7, 0.7, 0), Vector3(2.0, 1.25, 0), 0.07, 0.05, 5, HULL_A, 0.0)
	f.frustum(Vector3(2.0, 1.25, 0), Vector3(1.85, 1.5, 0), 0.05, 0.03, 5, HULL_A, 0.0)
	f.frustum(Vector3(-1.7, 0.7, 0), Vector3(-1.95, 1.05, 0), 0.07, 0.05, 5, HULL_A, 0.0)
	for x: float in [-0.7, 0.0, 0.7]:
		for side: float in [-1.0, 1.0]:
			f.frustum(Vector3(x, 0.52, side * 0.45), Vector3(x - 0.25, 0.05, side * 1.45), 0.03, 0.03, 4, TIMBER_A)
			f.box(Vector3(x - 0.26, 0.05, side * 1.5), Vector3(0.3, 0.02, 0.12), TIMBER_A, 0.4)
	f.frustum(Vector3(0.3, 0.2, 0), Vector3(0.3, 2.2, 0), 0.05, 0.04, 5, TIMBER_B, 0.0)
	f.frustum(Vector3(0.3, 2.0, -0.9), Vector3(0.3, 2.0, 0.9), 0.1, 0.1, 6, SAIL, 0.0)
	return f


## Tretradkran am Hafen: ein Ausleger aus zwei Balken mit Stütze, oben die Rolle, am Seil
## eine Kiste; unten das große Tretrad. Etwa 5.8 hoch.
func _crane() -> Forge:
	var f := Forge.new()
	var rng := _rng(251)
	f.box(Vector3(0, 0.12, 0), Vector3(3.4, 0.24, 2.0), TIMBER_B, 0.0)
	var hub := Vector3(-0.6, 1.5, 0)
	var r := 1.25
	var n := 14
	for side: float in [-0.45, 0.45]:
		for k in n:
			var a0 := TAU * k / n
			var a1 := TAU * (k + 1) / n
			var p0 := hub + Vector3(cos(a0) * r, sin(a0) * r, side)
			var p1 := hub + Vector3(cos(a1) * r, sin(a1) * r, side)
			f.frustum(p0, p1, 0.06, 0.06, 4, TIMBER_A, 0.0)
		for k in 4:
			var a := TAU * k / 4.0 + 0.3
			f.frustum(hub + Vector3(0, 0, side), hub + Vector3(cos(a) * r, sin(a) * r, side), 0.05, 0.05, 4, TIMBER_B, 0.0)
	for k in n:
		var a := TAU * (k + 0.5) / n
		var p := hub + Vector3(cos(a) * r, sin(a) * r, 0)
		f.frustum(p - Vector3(0, 0, 0.45), p + Vector3(0, 0, 0.45), 0.04, 0.04, 4, TIMBER_B, 0.0)
	f.frustum(hub - Vector3(0, 0, 0.8), hub + Vector3(0, 0, 0.8), 0.09, 0.09, 6, TIMBER_B, 0.0)
	for z: float in [-0.8, 0.8]:
		f.frustum(Vector3(-0.6, 0.24, z), hub + Vector3(0, 0, z), 0.09, 0.08, 5, TIMBER_B, 0.0)
	var tip := Vector3(1.9, 5.8, 0)
	for z: float in [-0.55, 0.55]:
		f.frustum(Vector3(0.6, 0.24, z), tip, 0.12, 0.08, 5, TIMBER_A, 0.0)
	f.frustum(Vector3(-1.6, 0.24, 0), tip, 0.08, 0.06, 5, TIMBER_B, 0.0)
	f.blob(tip + Vector3(0, -0.1, 0), 0.22, TIMBER_B, rng, 0.0)
	f.frustum(tip + Vector3(0, -0.2, 0), Vector3(1.9, 2.2, 0), 0.025, 0.025, 4, NET, 0.0)
	f.box(Vector3(1.9, 1.9, 0), Vector3(0.6, 0.6, 0.6), TIMBER_A, 0.3)
	return f


## Hafenbecken im Pflaster: eine Wasserfläche mit Kaimauer ringsum, Pollern und einem
## festgemachten Ruderboot. Etwa 7 lang, 3.6 breit, flach — das Wasser liegt knapp unter
## der Kante.
func _harbour_basin() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, -0.1, 0), Vector3(6.4, 0.3, 3.0), WATER_A, 0.0)
	for e: Array in [[Vector3(0, 0.12, 1.65), Vector3(7.0, 0.3, 0.3)], [Vector3(0, 0.12, -1.65), Vector3(7.0, 0.3, 0.3)],
			[Vector3(3.35, 0.12, 0), Vector3(0.3, 0.3, 3.0)], [Vector3(-3.35, 0.12, 0), Vector3(0.3, 0.3, 3.0)]]:
		f.box(e[0], e[1], TRAV_B, 0.0)
	for x: float in [-2.2, 0.0, 2.2]:
		f.frustum(Vector3(x, 0.27, 1.65), Vector3(x, 0.6, 1.65), 0.1, 0.09, 6, TRAV_DARK, 0.0)
	_hull(f, 1.8, 0.62, 0.5, 0.3, HULL_A, HULL_B, TIMBER_B, Vector3(0.6, -0.3, 0.3))
	return f


const AUTUMN_BARK := Color(0.36, 0.30, 0.26)
const AUTUMN_RED_A := Color(0.70, 0.22, 0.14)
const AUTUMN_RED_B := Color(0.58, 0.16, 0.10)
const AUTUMN_ORANGE_A := Color(0.86, 0.46, 0.14)
const AUTUMN_ORANGE_B := Color(0.74, 0.36, 0.10)
const AUTUMN_YELLOW_A := Color(0.88, 0.70, 0.22)
const AUTUMN_YELLOW_B := Color(0.76, 0.58, 0.14)
const VINE_A := Color(0.80, 0.58, 0.18)
const VINE_B := Color(0.66, 0.30, 0.14)
const VINE_GREEN := Color(0.46, 0.50, 0.18)
const GRAPE := Color(0.32, 0.16, 0.30)


## Rebzeile im Herbst: drei Pfähle mit Draht, sechs Stöcke mit Laub in Gelb und Rot,
## darunter dunkle Trauben. Etwa 1.8 hoch, 4 lang.
func _vine_row() -> Forge:
	var f := Forge.new()
	var rng := _rng(257)
	for x: float in [-2.0, 0.0, 2.0]:
		f.box(Vector3(x, 0.9, 0), Vector3(0.12, 1.8, 0.12), TIMBER_B, rng.randf_range(-0.1, 0.1))
	f.box(Vector3(0, 1.55, 0), Vector3(4.1, 0.03, 0.03), STEEL_B, 0.0)
	var paint := func(_m: Vector3, _n: Vector3) -> Color:
		var r := rng.randf()
		return VINE_A if r < 0.45 else (VINE_B if r < 0.8 else VINE_GREEN)
	for k in 6:
		var x := -1.7 + 0.68 * k
		f.frustum(Vector3(x, 0, 0), Vector3(x + 0.1, 0.85, 0), 0.06, 0.05, 4, DEAD_A, 0.0)
		f.lump(Vector3(x + rng.randf_range(-0.1, 0.1), 1.25, 0), Vector3(0.5, 0.45, 0.35), 3, 6, rng, 0.2, paint)
		for g in 2:
			var side := -1.0 if g == 0 else 1.0
			f.blob(Vector3(x + rng.randf_range(-0.25, 0.25), 0.88, side * 0.3), 0.1, GRAPE, rng, 0.0)
	return f


const LOG_A := Color(0.46, 0.31, 0.19)
const LOG_B := Color(0.38, 0.25, 0.15)
const SNOW_SHADE := Color(0.58, 0.62, 0.68)
const WARM_WINDOW := Color(0.95, 0.72, 0.36)


## Berghütte: Wände aus liegenden Stämmen, verschneites Satteldach, Steinschornstein, ein
## warm erleuchtetes Fenster. Etwa 4.1 hoch.
func _log_cabin() -> Forge:
	var f := Forge.new()
	var logs := 7
	for i in logs:
		var y := 0.18 + 0.3 * i
		var col := LOG_A if i % 2 == 0 else LOG_B
		for z: float in [1.3, -1.3]:
			f.frustum(Vector3(-1.95, y, z), Vector3(1.95, y, z), 0.17, 0.17, 6, col, 0.0)
		for x: float in [1.7, -1.7]:
			f.frustum(Vector3(x, y + 0.15, -1.55), Vector3(x, y + 0.15, 1.55), 0.17, 0.17, 6, col, 0.0)
	f.box(Vector3(0, 1.1, 0), Vector3(3.3, 2.1, 2.5), LOG_B, 0.0)
	var eave := 0.18 + 0.3 * logs
	_gable(f, Vector3(0, eave, 0), 2.2, 1.85, 1.3, SNOW, SNOW_SHADE, LOG_A)
	f.box(Vector3(1.0, eave + 1.2, -0.5), Vector3(0.45, 1.3, 0.45), BOULDER_A, 0.0)
	f.box(Vector3(-0.5, 0.85, 1.48), Vector3(0.8, 1.5, 0.05), DOOR, 0.0)
	f.box(Vector3(0.9, 1.3, 1.48), Vector3(0.6, 0.5, 0.05), WARM_WINDOW, 0.0)
	return f


## Holzstoß neben der Hütte: drei Lagen Scheite, oben Schnee. Etwa 1 hoch.
func _woodpile() -> Forge:
	var f := Forge.new()
	var rng := _rng(263)
	for row in 3:
		for k in 4 - row:
			var x := -0.54 + 0.36 * k + 0.18 * row
			var y := 0.17 + 0.3 * row
			f.frustum(Vector3(x, y, -0.5), Vector3(x, y, 0.5), 0.16, 0.16, 6,
					LOG_A if (k + row) % 2 == 0 else LOG_B, rng.randf())
	f.box(Vector3(0, 0.95, 0), Vector3(0.5, 0.06, 1.05), SNOW, 0.0)
	return f


const TENT_A := Color(0.46, 0.30, 0.22)
const TENT_B := Color(0.86, 0.76, 0.58)
const RUG := Color(0.66, 0.20, 0.16)


## Zelt einer Karawane: flaches, gestreiftes Tuchdach auf Stangen, hinten und an den Seiten
## geschlossen, vorn offen mit Teppich. Etwa 2.4 hoch, 4 breit.
func _nomad_tent() -> Forge:
	var f := Forge.new()
	for x: float in [-1.8, 0.0, 1.8]:
		f.box(Vector3(x, 1.0, 1.2), Vector3(0.1, 2.0, 0.1), TIMBER_B, 0.0)
	_gable(f, Vector3(0, 1.9, 0.3), 2.0, 1.0, 0.5, TENT_A, TENT_B, TENT_B, 6)
	f.box(Vector3(0, 0.95, -0.68), Vector3(4.0, 1.9, 0.04), TENT_A, 0.0)
	for x: float in [-1.98, 1.98]:
		f.box(Vector3(x, 0.95, -0.2), Vector3(0.04, 1.9, 1.0), TENT_B, 0.0)
	f.box(Vector3(0, 0.02, 0.9), Vector3(2.0, 0.04, 1.3), RUG, 0.0)
	return f


const ADOBE_A := Color(0.80, 0.62, 0.42)
const ADOBE_B := Color(0.70, 0.52, 0.34)


## Lehmhaus: flach gedeckter Kubus mit Brüstung und kleinem Aufbau, Balkenköpfe ragen aus
## der Wand, dunkler Eingang. Etwa 3.6 hoch.
func _clay_house() -> Forge:
	var f := Forge.new()
	f.box(Vector3(0, 1.2, 0), Vector3(3.0, 2.4, 2.6), ADOBE_A, 0.0)
	for e: Array in [[Vector3(0, 2.55, 1.25), Vector3(3.0, 0.3, 0.1)], [Vector3(0, 2.55, -1.25), Vector3(3.0, 0.3, 0.1)],
			[Vector3(1.45, 2.55, 0), Vector3(0.1, 0.3, 2.6)], [Vector3(-1.45, 2.55, 0), Vector3(0.1, 0.3, 2.6)]]:
		f.box(e[0], e[1], ADOBE_B, 0.0)
	f.box(Vector3(-0.7, 3.0, -0.4), Vector3(1.3, 1.2, 1.3), ADOBE_B, 0.0)
	for x: float in [-1.1, -0.4, 0.3, 1.0]:
		f.box(Vector3(x, 2.2, 1.4), Vector3(0.12, 0.12, 0.3), TIMBER_B, 0.0)
	f.box(Vector3(0.5, 0.8, 1.31), Vector3(0.8, 1.6, 0.04), DOOR, 0.0)
	f.box(Vector3(-0.8, 1.5, 1.31), Vector3(0.4, 0.4, 0.04), DOOR, 0.0)
	return f


## Wasserstelle der Oase: flacher Teich mit Steinrand und zwei Schilfbüscheln. Etwa 3.2
## breit, flach.
func _oasis_pond() -> Forge:
	var f := Forge.new()
	var rng := _rng(271)
	f.frustum(Vector3(0, -0.2, 0), Vector3(0, 0.06, 0), 1.5, 1.45, 10, WATER_A, 0.0)
	for k in 14:
		var a := TAU * k / 14.0 + rng.randf_range(-0.1, 0.1)
		var r := 1.5 + rng.randf_range(-0.05, 0.1)
		f.blob(Vector3(cos(a) * r, 0.08, sin(a) * r), rng.randf_range(0.16, 0.26), SANDSTONE[k % 3], rng, 0.0)
	for at: Vector3 in [Vector3(1.2, 0, 0.7), Vector3(-0.9, 0, -1.1)]:
		for k in 9:
			var yaw := TAU * k / 9.0
			var out := Vector3(cos(yaw), 0, sin(yaw))
			var side := Vector3(-out.z, 0, out.x) * 0.05
			var tip := at + out * 0.25 + Vector3(0, rng.randf_range(0.8, 1.2), 0)
			f.blade(at - side, at + side, tip, REED_A if k % 2 == 0 else REED_B)
	return f


const SKY_ROCK_A := Color(0.36, 0.34, 0.38)
const SKY_ROCK_B := Color(0.28, 0.27, 0.31)
const SKY_SOIL := Color(0.54, 0.48, 0.32)
const EMBER := Color(0.98, 0.70, 0.30)


## Schwebende Scholle: ein umgekehrter Felskegel über dem Boden, oben Erde mit einem
## Säulenstumpf und einer Zypresse; in Rissen glimmt es. Darunter zwei kleine Brocken.
## Etwa 5 hoch, die Unterseite 1 über dem Boden.
func _floating_rock() -> Forge:
	var f := Forge.new()
	var rng := _rng(277)
	var top := 3.4
	f.frustum(Vector3(0, 1.0, 0), Vector3(0, top, 0), 0.2, 1.6, 7, SKY_ROCK_A, 0.3, SKY_ROCK_B)
	f.frustum(Vector3(0, top - 0.02, 0), Vector3(0, top + 0.14, 0), 1.64, 1.5, 7, SKY_SOIL, 0.3)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.04
		var hi := d * 1.47 + Vector3(0, top - 0.25, 0)
		f.blade(hi - side, hi + side, d * 0.75 + Vector3(0, top - 1.5, 0), EMBER)
	f.drum(Vector3(0.4, top + 0.14, 0.2), 0.34, 1.4, 10, MARBLE_A, rng, 0.35, MARBLE_B)
	f.frustum(Vector3(-0.7, top + 0.14, -0.4), Vector3(-0.7, top + 0.5, -0.4), 0.08, 0.07, 5, CYPRESS_TRUNK, 0.0)
	f.lump(Vector3(-0.7, top + 1.3, -0.4), Vector3(0.3, 0.9, 0.3), 4, 6, rng, 0.1,
			func(_m: Vector3, _n: Vector3) -> Color: return CYPRESS_A if rng.randf() < 0.5 else CYPRESS_B)
	f.blob(Vector3(1.9, 1.5, 0.7), 0.4, SKY_ROCK_A, rng, 0.0)
	f.blob(Vector3(-1.6, 0.9, -0.9), 0.28, SKY_ROCK_B, rng, 0.0)
	return f


## Stück Aquädukt: drei Bögen auf vier Pfeilern, oben die Rinne mit ihren Wangen. Etwa 4.5
## hoch, 8 lang.
func _aqueduct() -> Forge:
	var f := Forge.new()
	var r_in := 0.9
	var r_out := 1.2
	var spring := 2.6
	var span := 2.0 * r_in + 0.7
	var depth := 1.0
	var top := spring + r_out
	for i in 4:
		f.box(Vector3((i - 1.5) * span, top * 0.5, 0), Vector3(0.7, top, depth), TRAV_A if i % 2 == 0 else TRAV_B, 0.0)
	for i in 3:
		_arch(f, Vector3((i - 1.0) * span, spring, 0), r_in, r_out, depth, TRAV_B, TRAV_A, TRAV_A)
	var length := 3.0 * span + 0.7
	f.box(Vector3(0, top + 0.15, 0), Vector3(length, 0.3, depth + 0.1), TRAV_DARK, 0.0)
	for z: float in [-0.42, 0.42]:
		f.box(Vector3(0, top + 0.5, z), Vector3(length, 0.4, 0.16), TRAV_B, 0.0)
	return f


## Rundtempel: runder Stufensockel, acht Säulen im Kreis um die Cella, Gebälkring, flache
## Kuppel mit Laterne. Etwa 4.8 hoch.
func _tholos() -> Forge:
	var f := Forge.new()
	var rng := _rng(281)
	f.frustum(Vector3.ZERO, Vector3(0, 0.3, 0), 2.2, 2.2, 16, TRAV_B, 0.0, TRAV_DARK)
	f.frustum(Vector3(0, 0.3, 0), Vector3(0, 0.6, 0), 1.95, 1.95, 16, TRAV_A, 0.0, TRAV_B)
	for k in 8:
		var a := TAU * k / 8.0
		f.drum(Vector3(cos(a) * 1.6, 0.6, sin(a) * 1.6), 0.18, 2.4, 8, STATUE_A, rng, 0.0, STATUE_B)
	f.frustum(Vector3(0, 0.6, 0), Vector3(0, 3.0, 0), 0.95, 0.95, 10, PLASTER_A, 0.0, PLASTER_B)
	f.frustum(Vector3(0, 3.0, 0), Vector3(0, 3.35, 0), 1.95, 1.95, 16, TRAV_A, 0.0, TRAV_B)
	f.lump(Vector3(0, 3.35, 0), Vector3(1.75, 1.0, 1.75), 4, 12, rng, 0.0,
			func(_m: Vector3, n: Vector3) -> Color: return STATUE_A if n.y > 0.7 else STATUE_B, 0.0)
	f.drum(Vector3(0, 4.3, 0), 0.25, 0.45, 8, TRAV_A, rng, 0.0, TRAV_B)
	return f


## Dunkler Fels der Himmelsinseln mit glimmendem Riss. Etwa 0.5 hoch und 1 breit, wie
## die Findlinge.
func _sky_boulder() -> Forge:
	var f := Forge.new()
	var rng := _rng(283)
	var paint := func(_m: Vector3, n: Vector3) -> Color:
		if n.y < 0.3 and rng.randf() < 0.1:
			return EMBER
		return SKY_ROCK_A if rng.randf() < 0.5 else SKY_ROCK_B
	f.lump(Vector3(0, 0.14, 0), Vector3(0.48, 0.45, 0.42), 4, 6, rng, 0.3, paint, -0.14)
	f.lump(Vector3(-0.42, 0.06, 0.32), Vector3(0.2, 0.2, 0.18), 3, 5, rng, 0.2, paint, -0.06)
	return f


const FLOWER_LEAF := Color(0.30, 0.50, 0.18)
const PETAL_PINK := Color(0.92, 0.56, 0.68)
const PETAL_WHITE := Color(0.94, 0.92, 0.86)


## Blumenbüschel der Frühlingswiese: Blätter als Halme, darüber rosa und weiße Blüten.
## Etwa 0.8 hoch (Gras steht bei ~1.6).
func _flower_tuft() -> Forge:
	var f := Forge.new()
	var rng := _rng(289)
	for k in 11:
		var a := TAU * k / 11.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var foot := d * rng.randf_range(0.0, 0.2)
		var side := Vector3(-d.z, 0, d.x) * 0.06
		f.blade(foot - side, foot + side, foot + d * 0.25 + Vector3(0, rng.randf_range(0.3, 0.5), 0), FLOWER_LEAF)
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(0.1, 0.3)
		var top := Vector3(cos(a) * r, rng.randf_range(0.5, 0.75), sin(a) * r)
		f.frustum(Vector3(top.x * 0.4, 0, top.z * 0.4), top, 0.015, 0.012, 3, FLOWER_LEAF, 0.0)
		f.blob(top, 0.09, PETAL_PINK if k % 2 == 0 else PETAL_WHITE, rng, 0.0)
const FENCE_A := Color(0.55, 0.36, 0.20)
const FENCE_B := Color(0.44, 0.28, 0.15)


## Holzzaun: drei Pfosten mit Spitze, zwei Latten, alles ein wenig schief. Etwa 2.4 lang
## (entlang x) und 1.2 hoch — mehrere nebeneinander, Pfosten an Pfosten.
func _fence() -> Forge:
	var f := Forge.new()
	var rng := _rng(61)
	for x in [-1.1, 0.0, 1.1]:
		var h := rng.randf_range(1.0, 1.15)
		f.box(Vector3(x, h * 0.5, 0), Vector3(0.14, h, 0.14), FENCE_B, rng.randf_range(-0.15, 0.15))
		f.cone_cap(Vector3(x, h, 0), 0.1, 0.14, 4, FENCE_B, PI / 4.0 + rng.randf_range(-0.2, 0.2))
	for y in [0.42, 0.82]:
		f.box(Vector3(0, y + rng.randf_range(-0.03, 0.03), 0.09), Vector3(2.45, 0.13, 0.05),
				FENCE_A, rng.randf_range(-0.02, 0.02), rng.randf_range(-0.04, 0.04))
	return f


const STALL_CLOTH_A := Color(0.93, 0.83, 0.56)
const STALL_CLOTH_B := Color(0.85, 0.72, 0.42)
const APPLE := Color(0.75, 0.18, 0.14)
const PUMPKIN := Color(0.88, 0.50, 0.16)


## Marktstand: Theke vorn (+z), vier Pfosten, ein nach vorn fallendes Stoffdach mit
## gezacktem Saum, auf der Theke Kisten und Obst. Etwa 2.6 breit, 2.7 hoch.
func _market_stall() -> Forge:
	var f := Forge.new()
	var rng := _rng(67)
	var back_h := 2.6
	var front_h := 2.15
	for p: Vector3 in [Vector3(-1.2, 0, 0.75), Vector3(1.2, 0, 0.75)]:
		f.box(p + Vector3(0, front_h * 0.5, 0), Vector3(0.13, front_h, 0.13), FENCE_B, 0.0)
	for p: Vector3 in [Vector3(-1.2, 0, -0.75), Vector3(1.2, 0, -0.75)]:
		f.box(p + Vector3(0, back_h * 0.5, 0), Vector3(0.13, back_h, 0.13), FENCE_B, 0.0)
	# Theke mit überstehendem Brett
	f.box(Vector3(0, 0.45, 0.62), Vector3(2.3, 0.9, 0.5), FENCE_A, 0.0)
	f.box(Vector3(0, 0.93, 0.62), Vector3(2.5, 0.07, 0.62), FENCE_B, 0.0)
	# Dach: eine schräge Stoffbahn, vorn und hinten über die Pfosten hinaus
	var back := Vector3(0, back_h + 0.05, -1.0)
	var front := Vector3(0, front_h + 0.05, 1.15)
	var slope := front - back
	var tilt := atan2(-slope.y, slope.z)
	f.box((back + front) * 0.5, Vector3(2.8, 0.05, slope.length()), STALL_CLOTH_A, 0.0, -tilt)
	# Saum vorn: Zacken im Wechsel der zwei Stofftöne
	var teeth := 9
	for i in teeth:
		var x0 := -1.4 + 2.8 * i / teeth
		var x1 := -1.4 + 2.8 * (i + 1) / teeth
		var y := front.y - 0.02
		var z := front.z + 0.01
		f.blade(Vector3(x0, y, z), Vector3(x1, y, z), Vector3((x0 + x1) * 0.5, y - 0.28, z + 0.02),
				STALL_CLOTH_B if i % 2 == 0 else STALL_CLOTH_A)
	# Ware
	f.box(Vector3(-0.75, 1.1, 0.6), Vector3(0.5, 0.28, 0.4), FENCE_A, 0.15)
	for k in 5:
		f.blob(Vector3(-0.85 + 0.1 * k, 1.28, 0.55 + rng.randf_range(-0.08, 0.08)), 0.08, APPLE, rng, 0.0)
	f.lump(Vector3(0.2, 1.1, 0.62), Vector3(0.2, 0.15, 0.2), 3, 6, rng, 0.08,
			func(_m: Vector3, _n: Vector3) -> Color: return PUMPKIN)
	f.box(Vector3(0.8, 1.06, 0.58), Vector3(0.45, 0.2, 0.35), FENCE_B, -0.2)
	return f


const BLADE_A := Color(0.80, 0.83, 0.88)
const BLADE_B := Color(0.62, 0.66, 0.72)
const HILT := Color(0.78, 0.60, 0.25)
const GRIP := Color(0.36, 0.22, 0.12)


## Kurzschwert für die Hand eines Skeletts (handslot): Griff am Ursprung, Klinge nach +y.
## Etwa 0.9 lang.
func _sword() -> Forge:
	var f := Forge.new()
	var rng := _rng(71)
	f.frustum(Vector3(0, -0.12, 0), Vector3(0, 0.1, 0), 0.028, 0.028, 5, GRIP)
	f.blob(Vector3(0, -0.15, 0), 0.045, HILT, rng, 0.0)
	f.box(Vector3(0, 0.12, 0), Vector3(0.28, 0.045, 0.06), HILT, 0.0)
	# Klinge mit Rautenquerschnitt: Schneiden in x, Grat in z
	var w := 0.055
	var t := 0.014
	var y0 := 0.145
	var y1 := 0.7
	var tip := Vector3(0, 0.85, 0)
	var lo := [Vector3(w, y0, 0), Vector3(0, y0, t), Vector3(-w, y0, 0), Vector3(0, y0, -t)]
	var hi := [Vector3(w * 0.85, y1, 0), Vector3(0, y1, t), Vector3(-w * 0.85, y1, 0), Vector3(0, y1, -t)]
	for j in 4:
		var k := (j + 1) % 4
		var col := BLADE_A if j % 2 == 0 else BLADE_B
		var inside := Vector3(0, (y0 + y1) * 0.5, 0)
		f.tri_out(lo[j], lo[k], hi[k], col, inside)
		f.tri_out(lo[j], hi[k], hi[j], col, inside)
		f.tri_out(hi[j], hi[k], tip, col, Vector3(0, y1, 0))
	return f


const CASE_A := Color(0.42, 0.25, 0.13)
const CASE_B := Color(0.32, 0.18, 0.09)
const SPINES := [
	Color(0.55, 0.14, 0.12), Color(0.16, 0.26, 0.5), Color(0.2, 0.38, 0.22),
	Color(0.5, 0.34, 0.16), Color(0.36, 0.2, 0.42), Color(0.7, 0.55, 0.3),
	Color(0.26, 0.16, 0.1),
]


## Bücherregal: Rahmen, Rückwand, fünf Fächer voller Buchrücken in wechselnder Höhe und
## Farbe, hier und da eine Lücke und ein schräg gelehntes Buch. Etwa 2.0 breit, 3.0 hoch,
## 0.5 tief, vorn +z.
func _bookcase() -> Forge:
	var f := Forge.new()
	var rng := _rng(73)
	var w := 2.0
	var h := 3.0
	var d := 0.5
	var board := 0.08
	f.box(Vector3(-w * 0.5 + board * 0.5, h * 0.5, 0), Vector3(board, h, d), CASE_A, 0.0)
	f.box(Vector3(w * 0.5 - board * 0.5, h * 0.5, 0), Vector3(board, h, d), CASE_A, 0.0)
	f.box(Vector3(0, h - board * 0.5, 0.02), Vector3(w + 0.12, board, d + 0.06), CASE_A, 0.0)
	f.box(Vector3(0, board * 0.5, 0.02), Vector3(w + 0.06, board * 1.5, d + 0.04), CASE_B, 0.0)
	f.box(Vector3(0, h * 0.5, -d * 0.5 + 0.02), Vector3(w - 0.1, h - 0.1, 0.04), CASE_B, 0.0)
	var rows := 5
	var inner := (h - 2.0 * board) / rows
	for r in rows:
		var floor_y := board * 1.5 + r * inner
		if r > 0:
			f.box(Vector3(0, floor_y - board * 0.25, 0), Vector3(w - 2.0 * board, board * 0.5, d - 0.04),
					CASE_A, 0.0)
		var x := -w * 0.5 + board + 0.03
		var end := w * 0.5 - board - 0.03
		while x < end - 0.06:
			if rng.randf() < 0.08:
				x += rng.randf_range(0.12, 0.3)
				continue
			var t := rng.randf_range(0.05, 0.1)
			var bh := rng.randf_range(0.6, 0.9) * (inner - 0.08)
			var col: Color = SPINES[rng.randi() % SPINES.size()]
			if rng.randf() < 0.06 and x + bh < end:
				# Ein gelehntes Buch: unten an seinem Platz, oben an den Nachbarn gelehnt.
				var lean := rng.randf_range(0.35, 0.6)
				var cx := x + sin(lean) * bh * 0.5 + t * 0.5
				f.box(Vector3(cx, floor_y + cos(lean) * bh * 0.5, 0.02), Vector3(0.34, bh, t), col,
						PI * 0.5, -lean)
				x += sin(lean) * bh + t + 0.02
				continue
			f.box(Vector3(x + t * 0.5, floor_y + bh * 0.5, 0.03 + rng.randf_range(-0.02, 0.02)),
					Vector3(t, bh, 0.34), col, 0.0)
			x += t + rng.randf_range(0.0, 0.01)
	return f


const WAX_A := Color(0.95, 0.9, 0.78)
const WAX_B := Color(0.86, 0.8, 0.66)
const WICK := Color(0.12, 0.1, 0.08)


## Drei Kerzen verschiedener Höhe auf einem Klecks Wachs; die Flamme setzt die Szene dazu
## (leuchtend, das kann ein .glb ohne Material nicht). Die Dochte enden bei `candle_tops`.
func _candles() -> Forge:
	var f := Forge.new()
	var rng := _rng(79)
	f.lump(Vector3(0, 0.0, 0), Vector3(0.2, 0.03, 0.16), 2, 7, rng, 0.0,
			func(_m: Vector3, _n: Vector3) -> Color: return WAX_B, 0.0)
	for top: Vector3 in CANDLE_TOPS:
		var base := Vector3(top.x, 0.0, top.z)
		f.frustum(base, top - Vector3(0, 0.02, 0), 0.045, 0.04, 7, WAX_A, rng.randf(), WAX_B)
		f.frustum(top - Vector3(0, 0.025, 0), top + Vector3(0, 0.02, 0), 0.006, 0.004, 4, WICK)
	return f


## Wo die Dochte der drei Kerzen enden — dort sitzen in der Szene die Flammen.
const CANDLE_TOPS := [Vector3(-0.08, 0.34, 0.02), Vector3(0.06, 0.24, -0.04), Vector3(0.1, 0.14, 0.08)]


## Das Lesepult, auf dem die Bücher stehen: eine lange Platte mit Kante, Zarge und vier
## Beinen. Etwa 7.2 breit, 1.5 tief; die Oberfläche liegt bei y = 0.
func _reading_desk() -> Forge:
	var f := Forge.new()
	var w := 7.2
	var d := 1.5
	f.box(Vector3(0, -0.06, 0), Vector3(w, 0.12, d), CASE_A, 0.0)
	f.box(Vector3(0, -0.14, d * 0.5 - 0.03), Vector3(w + 0.04, 0.06, 0.08), CASE_B, 0.0)
	f.box(Vector3(0, -0.3, 0), Vector3(w - 0.3, 0.28, d - 0.2), CASE_B, 0.0)
	for x in [-w * 0.5 + 0.2, w * 0.5 - 0.2]:
		for z in [-d * 0.5 + 0.18, d * 0.5 - 0.18]:
			f.box(Vector3(x, -0.6, z), Vector3(0.16, 1.1, 0.16), CASE_B, 0.0)
	return f


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Werkzeug -----------------------------------------------------------------------

## Sammelt Dreiecke je Farbe; `commit()` macht daraus ein Mesh mit einer Fläche je Farbe.
## Normalen sind flach (eine je Dreieck) und zeigen nach außen, Blätter sind zweiseitig.
class Forge:
	var _tris := {}      # Color -> Array[PackedVector3Array(a, b, c, n)]
	var _two_sided := {} # Color -> true

	## Dreieck mit Normale weg von `inside`. Godot zeichnet im Uhrzeigersinn gewundene
	## Flächen als Vorderseite — die Reihenfolge wird danach gedreht.
	func tri_out(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			return
		n = n.normalized()
		var outward := ((a + b + c) / 3.0 - inside)
		# (b-a)×(c-a) zeigt nach außen = gegen den Uhrzeigersinn von außen gesehen → drehen.
		if n.dot(outward) > 0.0:
			var t := b
			b = c
			c = t
		else:
			n = -n
		_add(a, b, c, n, col)

	func _add(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
		if not _tris.has(col):
			_tris[col] = []
		_tris[col].append(PackedVector3Array([a, b, c, n]))

	## Blattfläche (zweiseitig) zwischen Rippe p0→p1 und Rand e1, e0; Normale nach oben.
	func leaf_quad(p0: Vector3, p1: Vector3, e1: Vector3, e0: Vector3, col: Color) -> void:
		_two_sided[col] = true
		for t: Array in [[p0, p1, e1], [p0, e1, e0]]:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var c: Vector3 = t[2]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-12:
				continue
			n = n.normalized()
			if n.y < 0.0:
				n = -n
			_add(a, b, c, n, col)

	## Kegelstumpf von a nach b; `sides` Seiten, abwechselnd `col` und `col_alt`.
	## Mit Deckel oben und unten.
	func frustum(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color,
			twist := 0.0, col_alt := Color(-1, -1, -1)) -> void:
		var axis := (b - a).normalized()
		var u := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var v := axis.cross(u)
		var inside := (a + b) * 0.5
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for j in sides:
			var ang := TAU * j / sides + twist
			var d := u * cos(ang) + v * sin(ang)
			ring0.append(a + d * r0)
			ring1.append(b + d * r1)
		for j in sides:
			var k := (j + 1) % sides
			var c := col if col_alt.r < 0.0 or j % 2 == 0 else col_alt
			tri_out(ring0[j], ring0[k], ring1[k], c, inside)
			tri_out(ring0[j], ring1[k], ring1[j], c, inside)
			tri_out(a, ring0[k], ring0[j], col, inside + axis * 0.001)
			tri_out(b, ring1[j], ring1[k], col, inside - axis * 0.001)

	## Spitze Kappe auf einen Ring bei `c` (senkrecht), Spitze `h` darüber. Die Ecken liegen
	## wie die eines senkrechten `frustum` mit demselben `twist` — so schließen beide dicht.
	## `closed` gibt ihr einen Boden: aus der Ich-Sicht sieht man unter die Äste.
	func cone_cap(c: Vector3, r: float, h: float, sides: int, col: Color, twist: float,
			closed := false) -> void:
		var tip := c + Vector3(0, h, 0)
		var inside := c + Vector3(0, h * 0.25, 0)
		for j in sides:
			var a0 := TAU * j / sides + twist
			var a1 := TAU * (j + 1) / sides + twist
			var p0 := c + Vector3(-cos(a0), 0, sin(a0)) * r
			var p1 := c + Vector3(-cos(a1), 0, sin(a1)) * r
			tri_out(p0, p1, tip, col, inside)
			if closed:
				tri_out(c, p1, p0, col, inside)

	## Verbeulte Kugel um `c` mit Halbachsen `radii`, unten bei `floor_y` (relativ zu `c`)
	## abgeflacht. Die Farbe jeder Facette wählt `paint(mitte, normale)`.
	func lump(c: Vector3, radii: Vector3, rings: int, sides: int, rng: RandomNumberGenerator,
			jitter: float, paint: Callable, floor_y := -INF) -> void:
		var pts: Array = []
		for i in rings + 1:
			var row: Array[Vector3] = []
			var phi := PI * i / rings
			for j in sides:
				var theta := TAU * j / sides + (PI / sides if i % 2 == 1 else 0.0)
				var k := 1.0 + rng.randf_range(-jitter, jitter)
				var p := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radii * k
				p.y = maxf(p.y, floor_y)
				row.append(c + p)
			pts.append(row)
		for i in rings:
			for j in sides:
				var a: Vector3 = pts[i][j]
				var b: Vector3 = pts[i][(j + 1) % sides]
				var d: Vector3 = pts[i + 1][(j + 1) % sides]
				var e: Vector3 = pts[i + 1][j]
				for t: Array in [[a, b, d], [a, d, e]]:
					var p0: Vector3 = t[0]
					var p1: Vector3 = t[1]
					var p2: Vector3 = t[2]
					var m := (p0 + p1 + p2) / 3.0
					var n := (p1 - p0).cross(p2 - p0)
					if n.dot(m - c) < 0.0:
						n = -n
					tri_out(p0, p1, p2, paint.call(m, n.normalized()), c)

	## Zweiseitiger Halm von der Basis `a`–`b` zur Spitze `tip`.
	func blade(a: Vector3, b: Vector3, tip: Vector3, col: Color) -> void:
		_two_sided[col] = true
		var n := (b - a).cross(tip - a)
		if n.length_squared() < 1e-12:
			return
		_add(a, b, tip, n.normalized(), col)

	## Säulentrommel ab `base` nach oben; `jag` > 0 bricht die Oberkante unregelmäßig ab.
	func drum(base: Vector3, r: float, h: float, sides: int, col: Color, rng: RandomNumberGenerator,
			jag: float, col_alt := Color(-1, -1, -1)) -> void:
		var inside := base + Vector3(0, h * 0.5, 0)
		var top_c := base + Vector3(0, h - jag * 0.5, 0)
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for j in sides:
			var ang := TAU * j / sides
			var d := Vector3(cos(ang), 0, sin(ang))
			lo.append(base + d * r)
			hi.append(base + d * r + Vector3(0, h - (rng.randf() * jag if jag > 0.0 else 0.0), 0))
		for j in sides:
			var k := (j + 1) % sides
			var side_col := col if col_alt.r < 0.0 or j % 2 == 0 else col_alt
			tri_out(lo[j], lo[k], hi[k], side_col, inside)
			tri_out(lo[j], hi[k], hi[j], side_col, inside)
			tri_out(top_c, hi[j], hi[k], col, top_c - Vector3(0, 1, 0))

	## Quader um `center`, um die Hochachse gedreht und danach um seine x-Achse gekippt.
	func box(center: Vector3, size: Vector3, col: Color, yaw: float, tilt := 0.0) -> void:
		var h := size * 0.5
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var p := func(x: float, y: float, z: float) -> Vector3:
			return center + basis * Vector3(x * h.x, y * h.y, z * h.z)
		var faces := [
			[Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)],
			[Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
			[Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
			[Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
			[Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
			[Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1)],
		]
		for q: Array in faces:
			var c: Array[Vector3] = []
			for corner: Vector3 in q:
				c.append(p.call(corner.x, corner.y, corner.z))
			tri_out(c[0], c[1], c[2], col, center)
			tri_out(c[0], c[2], c[3], col, center)

	## Kleiner Klumpen (Oktaeder, leicht verbeult).
	func blob(c: Vector3, r: float, col: Color, rng: RandomNumberGenerator, _twist: float) -> void:
		var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
		var p: Array[Vector3] = []
		for d: Vector3 in dirs:
			p.append(c + d * r * rng.randf_range(0.85, 1.15))
		for x in [0, 1]:
			for y in [2, 3]:
				for z in [4, 5]:
					tri_out(p[x], p[y], p[z], col, c)

	func commit(scale := 1.0) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var cols := _tris.keys()
		cols.sort_custom(func(x: Color, y: Color) -> bool: return x.to_rgba32() < y.to_rgba32())
		for col: Color in cols:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for t: PackedVector3Array in _tris[col]:
				for i in 3:
					st.set_normal(t[3])
					st.add_vertex(t[i] * scale)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 1.0
			if _two_sided.has(col):
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			st.set_material(mat)
			st.commit(mesh)
		return mesh
