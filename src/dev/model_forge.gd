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

	## Quader um `center`, um die Hochachse gedreht.
	func box(center: Vector3, size: Vector3, col: Color, yaw: float) -> void:
		var h := size * 0.5
		var basis := Basis(Vector3.UP, yaw)
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
