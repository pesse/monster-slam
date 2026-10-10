extends SceneTree
## Erzeugt The Rambler (Boss des Schreib-Kampfs, ADR 0023 §3) und die Papierkulisse seines
## Turms als .glb — mit dem Werkzeug von model_forge.gd (`Forge`), im selben Stil.
##
##     tools/godot.sh -s res://src/dev/rambler_forge.gd
##     tools/godot.sh --import
##
## The Rambler ist kein Rig, sondern Teile, die die Bühne (src/battle/rambler_stage.gd)
## zusammensetzt und selbst bewegt: Leibringe, Kopf, Unterkiefer, zwei Flügel, die
## Schwanzspitze und die Papierstapel. So atmet der Leib Ring für Ring, der Kiefer klappt
## beim Reden auf wie ein Buchdeckel, und ein Stapel kann abfallen.
##
## Die Figur: ein aufgeblähter Bücherwurm-Drache. Sein Leib ist ein Stapel Seiten zwischen
## grünen Ledereinbänden, der Kopf ein Buch, dessen Deckel das Maul sind, die Zunge ein
## Lesebändchen; er trägt eine Lesebrille und Schriftrollen als Hörner, die Flügel sind
## aufgefächerte Blätter, und der Schwanz endet in einer Schreibfeder.
##
## Wie in model_forge.gd: Code ist die Quelle, die .glb das Ergebnis. Deterministisch.

const ModelForge := preload("res://src/dev/model_forge.gd")
const BOSS_OUT := "res://assets/models/bosses/rambler"
const PROP_OUT := "res://assets/models/props"

const PAPER_A := Color(0.93, 0.88, 0.76)
const PAPER_B := Color(0.84, 0.78, 0.64)
const PAPER_C := Color(0.72, 0.65, 0.51)
const INK := Color(0.12, 0.1, 0.14)
const LEATHER_A := Color(0.17, 0.42, 0.36)
const LEATHER_B := Color(0.12, 0.31, 0.27)
const GOLD := Color(0.86, 0.66, 0.26)
const GOLD_DARK := Color(0.62, 0.44, 0.16)
const LENS := Color(0.96, 0.96, 0.92)
const RIBBON := Color(0.78, 0.16, 0.2)
const TWINE := Color(0.58, 0.43, 0.25)
const BLUSH := Color(0.86, 0.5, 0.45)
const COVERS := [
	Color(0.55, 0.14, 0.12), Color(0.16, 0.26, 0.5), Color(0.2, 0.38, 0.22),
	Color(0.5, 0.34, 0.16), Color(0.36, 0.2, 0.42), Color(0.26, 0.16, 0.1),
]


func _initialize() -> void:
	for dir in [BOSS_OUT, PROP_OUT]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_export(BOSS_OUT, "segment", _segment())
	_export(BOSS_OUT, "head", _head())
	_export(BOSS_OUT, "jaw", _jaw())
	_export(BOSS_OUT, "wing_r", _wing())
	_export(BOSS_OUT, "wing_l", _mirrored(_wing()))
	_export(BOSS_OUT, "tail", _tail())
	_export(BOSS_OUT, "arm_r", _arm())
	_export(BOSS_OUT, "arm_l", _mirrored(_arm()))
	_export(BOSS_OUT, "stack", _stack())
	_export(PROP_OUT, "paper_tower_a", _paper_tower(601, 3.6))
	_export(PROP_OUT, "paper_tower_b", _paper_tower(607, 2.4))
	_export(PROP_OUT, "book_pile", _book_pile())
	_export(PROP_OUT, "paper_litter", _paper_litter())
	quit()


func _export(dir: String, model_name: String, forge: ModelForge.Forge) -> void:
	var root := Node3D.new()
	root.name = model_name
	var inst := MeshInstance3D.new()
	inst.name = model_name
	inst.mesh = forge.commit()
	root.add_child(inst)
	inst.owner = root
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, "%s/%s.glb" % [dir, model_name])
	print("rambler_forge: %s/%s.glb %s" % [dir, model_name, error_string(err)])
	root.free()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Seitenkanten: helle und dunklere Streifen übereinander, wie der Schnitt eines Buchs.
func _pages(m: Vector3, _n: Vector3) -> Color:
	return PAPER_A if int(floor(m.y * 22.0)) % 2 == 0 else PAPER_B


## Spiegelt ein Modell an der y-z-Ebene (rechts ↔ links). Die Reihenfolge der Ecken dreht
## sich mit, sonst zeigten die Flächen nach innen.
func _mirrored(f: ModelForge.Forge) -> ModelForge.Forge:
	for col in f._tris:
		var tris: Array = f._tris[col]
		for k in tris.size():
			var t: PackedVector3Array = tris[k]
			var m := Vector3(-1, 1, 1)
			tris[k] = PackedVector3Array([t[0] * m, t[2] * m, t[1] * m, t[3] * m])
	return f


# --- The Rambler ------------------------------------------------------------------

## Ein Leibring: ein bauchiger Packen Seiten zwischen zwei Einbänden, Achse +y, Radius 1
## (die Bühne skaliert ihn je Ring). Hinten (−z) ein Eselsohr als Rückenzacke.
func _segment() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(503)
	f.lump(Vector3.ZERO, Vector3(1.0, 0.72, 1.0), 4, 12, rng, 0.03,
			func(m: Vector3, n: Vector3) -> Color:
				if absf(n.y) > 0.8:
					return PAPER_C
				return _pages(m * 0.5, n))
	for y: float in [-0.62, 0.62]:
		var dir := signf(y)
		f.frustum(Vector3(0, y - dir * 0.06, 0), Vector3(0, y + dir * 0.06, 0), 0.86, 0.8, 12,
				LEATHER_A, 0.0, LEATHER_B)
	# Rückenzacke: ein gefaltetes Blatt, hinten oben.
	f.tri_out(Vector3(-0.22, 0.25, -0.9), Vector3(0.22, 0.25, -0.9), Vector3(0, 0.45, -1.35),
			GOLD, Vector3(0, 0.3, -0.7))
	f.tri_out(Vector3(-0.22, 0.25, -0.9), Vector3(0, -0.05, -0.95), Vector3(0, 0.45, -1.35),
			GOLD_DARK, Vector3(0.2, 0.2, -0.7))
	f.tri_out(Vector3(0.22, 0.25, -0.9), Vector3(0, -0.05, -0.95), Vector3(0, 0.45, -1.35),
			GOLD_DARK, Vector3(-0.2, 0.2, -0.7))
	return f


## Der Kopf ohne Unterkiefer: Schädel, der obere Buchdeckel als Schnauze, Brille,
## Schriftrollen als Hörner und ein Fächer aus Blättern an jeder Wange. Drehpunkt ist das
## Genick, vorn ist +z. Der Kiefer hängt bei JAW_HINGE.
func _head() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(509)
	# Schädel
	f.lump(Vector3(0, 0.2, -0.02), Vector3(0.44, 0.36, 0.42), 4, 10, rng, 0.04,
			func(_m: Vector3, n: Vector3) -> Color: return LEATHER_B if n.y < -0.2 else LEATHER_A)
	# Schnauze: Deckel und Seiten darunter
	f.box(Vector3(0, 0.15, 0.4), Vector3(0.66, 0.09, 0.66), LEATHER_A, 0.0, -0.08)
	f.box(Vector3(0, 0.06, 0.38), Vector3(0.58, 0.11, 0.58), PAPER_A, 0.0, -0.06)
	f.box(Vector3(0, 0.06, 0.38), Vector3(0.6, 0.04, 0.6), PAPER_B, 0.0, -0.06)
	# Goldene Ecken auf dem Deckel
	for x: float in [-0.29, 0.29]:
		f.box(Vector3(x, 0.17, 0.68), Vector3(0.1, 0.1, 0.1), GOLD, PI * 0.25, -0.08)
	# Nüstern
	for x: float in [-0.12, 0.12]:
		f.blob(Vector3(x, 0.21, 0.62), 0.04, INK, rng, 0.0)
	# Zähne: ein paar kleine Papierzacken an der Unterkante der Schnauze
	for k in 5:
		var x := -0.2 + k * 0.1
		f.blade(Vector3(x - 0.025, 0.01, 0.66), Vector3(x + 0.025, 0.01, 0.66),
				Vector3(x, -0.045, 0.67), LENS)
	# Brille: Goldrand, Glas mit Auge dahinter, Pupille leicht nach innen (schielt ein wenig).
	# Groß und weit vorn, damit man sie auch von unten sieht.
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * 0.21, 0.42, 0.36)
		f.frustum(c - Vector3(0, 0, 0.03), c + Vector3(0, 0, 0.02), 0.2, 0.2, 14, GOLD)
		f.frustum(c + Vector3(0, 0, 0.0), c + Vector3(0, 0, 0.035), 0.165, 0.165, 14, LENS)
		var pupil := c + Vector3(-side * 0.04, -0.03, 0.04)
		f.frustum(pupil - Vector3(0, 0, 0.005), pupil + Vector3(0, 0, 0.008), 0.08, 0.08, 12, INK)
		f.frustum(pupil + Vector3(0.025, 0.03, 0.006), pupil + Vector3(0.025, 0.03, 0.012), 0.022,
				0.022, 6, LENS)
		# Bügel nach hinten
		f.box(Vector3(side * 0.4, 0.44, 0.18), Vector3(0.03, 0.03, 0.36), GOLD, side * 0.35)
		# Braue: schräg, ein wenig selbstgefällig
		f.box(Vector3(side * 0.22, 0.66, 0.33), Vector3(0.28, 0.07, 0.1), LEATHER_B, 0.0, 0.0)
		# Wange mit einem Hauch Rot
		f.blob(Vector3(side * 0.37, 0.18, 0.42), 0.08, BLUSH, rng, 0.0)
	f.box(Vector3(0, 0.44, 0.37), Vector3(0.1, 0.035, 0.03), GOLD, 0.0)
	# Hörner: zwei Schriftrollen, nach hinten geneigt, mit goldenen Knäufen
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.22, 0.44, -0.12)
		var b := Vector3(side * 0.42, 0.86, -0.4)
		f.frustum(a, b, 0.075, 0.065, 8, PAPER_A, 0.0, PAPER_B)
		var axis := (b - a).normalized()
		f.frustum(b, b + axis * 0.05, 0.1, 0.1, 8, GOLD)
		f.blob(b + axis * 0.1, 0.06, GOLD_DARK, rng, 0.0)
	# Wangenfächer: drei Blätter je Seite, nach hinten und außen
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var root := Vector3(side * 0.36, 0.22, -0.1)
			var ang := deg_to_rad(-25.0 + k * 30.0)
			var dir := Vector3(side * cos(ang) * 0.8, sin(ang), -0.6).normalized()
			var across := dir.cross(Vector3(0, 0, 1)).normalized() * 0.09
			var tip := root + dir * 0.42
			f.leaf_quad(root - across * 0.5, tip - across, tip + across, root + across * 0.5,
					PAPER_A if k % 2 == 0 else PAPER_B)
	return f


## Wo der Unterkiefer am Kopf hängt (Kopfkoordinaten).
const JAW_HINGE := Vector3(0, 0.02, -0.02)


## Der Unterkiefer: der untere Buchdeckel mit Seiten darauf, Zacken oben und ein rotes
## Lesebändchen als Zunge, das vorn heraushängt. Drehpunkt ist das Scharnier, vorn +z.
func _jaw() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(521)
	f.lump(Vector3(0, -0.1, 0.12), Vector3(0.34, 0.14, 0.3), 3, 8, rng, 0.03,
			func(_m: Vector3, _n: Vector3) -> Color: return LEATHER_B)
	f.box(Vector3(0, -0.13, 0.38), Vector3(0.6, 0.08, 0.6), LEATHER_A, 0.0, 0.05)
	f.box(Vector3(0, -0.06, 0.37), Vector3(0.52, 0.08, 0.54), PAPER_A, 0.0, 0.05)
	for x: float in [-0.27, 0.27]:
		f.box(Vector3(x, -0.15, 0.65), Vector3(0.09, 0.09, 0.09), GOLD, PI * 0.25, 0.05)
	for k in 4:
		var x := -0.15 + k * 0.1
		f.blade(Vector3(x - 0.025, -0.03, 0.62), Vector3(x + 0.025, -0.03, 0.62),
				Vector3(x, 0.02, 0.63), LENS)
	# Lesebändchen: liegt auf den Seiten, hängt vorn über die Kante und baumelt
	var pts := [Vector3(0.02, -0.015, 0.2), Vector3(0.03, -0.015, 0.5), Vector3(0.05, -0.04, 0.66),
			Vector3(0.07, -0.2, 0.72), Vector3(0.05, -0.36, 0.7), Vector3(0.08, -0.46, 0.66)]
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var w := Vector3(0.05, 0, 0)
		f.leaf_quad(a - w, b - w, b + w, a + w, RIBBON)
	# Gekerbtes Ende
	var end: Vector3 = pts[-1]
	f.leaf_quad(end - Vector3(0.05, 0, 0), end + Vector3(-0.05, -0.08, 0), end + Vector3(0, -0.04, 0),
			end, RIBBON)
	f.leaf_quad(end, end + Vector3(0, -0.04, 0), end + Vector3(0.05, -0.08, 0), end + Vector3(0.05, 0, 0),
			RIBBON)
	return f


## Ein Flügel: fünf aufgefächerte Blätter an einem goldenen Kiel. Wurzel im Ursprung,
## gespreizt nach +x und oben, flach in der x-y-Ebene (der rechte; der linke ist gespiegelt).
func _wing() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var root := Vector3.ZERO
	var spar_tip := Vector3(0.75, 0.95, -0.1)
	f.frustum(root, spar_tip, 0.032, 0.016, 6, GOLD, 0.0, GOLD_DARK)
	for k in 5:
		var ang := deg_to_rad(12.0 + k * 17.0)
		var length := 0.95 - absf(k - 2.0) * 0.08
		var dir := Vector3(cos(ang), sin(ang), -0.08).normalized()
		var across := dir.cross(Vector3(0, 0, 1)).normalized()
		var base := root + dir * 0.05
		var tip := root + dir * length
		var col := PAPER_A if k % 2 == 0 else PAPER_B
		f.leaf_quad(base - across * 0.05, tip - across * 0.17, tip + across * 0.17,
				base + across * 0.05, col)
		# Zwei Zeilen Schrift auf jedem Blatt, knapp davor
		for line in 2:
			var t0 := 0.45 + line * 0.18
			var lift := Vector3(0, 0, 0.006)
			var p0 := root + dir * (length * t0) + lift
			var p1 := root + dir * (length * (t0 + 0.02)) + lift
			var half := across * (0.07 + t0 * 0.06)
			f.leaf_quad(p0 - half, p1 - half, p1 + half, p0 + half, PAPER_C)
	return f


## Schwanzspitze: eine Schreibfeder — goldene Spitze mit Tintenschlitz. Fuß im Ursprung,
## Spitze bei +y.
func _tail() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	f.frustum(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.32, 0.3, 8, LEATHER_A, 0.0, LEATHER_B)
	f.frustum(Vector3(0, 0.12, 0), Vector3(0, 0.75, 0), 0.26, 0.01, 8, GOLD, 0.0, GOLD_DARK)
	f.box(Vector3(0, 0.38, 0.17), Vector3(0.025, 0.36, 0.02), INK, 0.0)
	f.frustum(Vector3(0, 0.22, 0.155), Vector3(0, 0.22, 0.19), 0.04, 0.04, 8, INK)
	return f


## Ein Ärmchen mit Federkiel: kurzer Oberarm, Pfote, darin eine Gänsefeder. Schulter im
## Ursprung, der Arm geht nach −y und vorn; die Feder steht nach oben (der rechte; der
## linke ist gespiegelt).
func _arm() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(523)
	var elbow := Vector3(0.05, -0.22, 0.12)
	var paw := Vector3(0.02, -0.3, 0.32)
	f.frustum(Vector3.ZERO, elbow, 0.1, 0.08, 6, LEATHER_A, 0.0, LEATHER_B)
	f.frustum(elbow, paw, 0.08, 0.07, 6, LEATHER_A, 0.0, LEATHER_B)
	f.lump(paw, Vector3(0.09, 0.08, 0.09), 3, 6, rng, 0.05,
			func(_m: Vector3, _n: Vector3) -> Color: return LEATHER_B)
	# Gänsefeder: Kiel und Fahne, schräg nach oben außen
	var q0 := paw + Vector3(0, -0.06, 0.02)
	var q1 := paw + Vector3(0.12, 0.55, 0.05)
	f.frustum(q0, q1, 0.012, 0.006, 4, PAPER_B)
	var dir := (q1 - q0).normalized()
	var side := dir.cross(Vector3(0, 0, 1)).normalized()
	var v0 := q0 + dir * 0.18
	f.leaf_quad(v0, q1, q1 + side * 0.04, v0 + side * 0.09, LENS)
	f.leaf_quad(v0, q1, q1 - side * 0.03, v0 - side * 0.06, PAPER_A)
	f.frustum(q0 - dir * 0.03, q0 + dir * 0.02, 0.016, 0.012, 4, INK)
	return f


## Ein Papierstapel, wie er an The Rambler hängt: sieben Lagen, kreuzweise verschnürt, mit
## Knoten oben. Aufhängepunkt (Knoten) im Ursprung, der Stapel hängt darunter.
func _stack() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(541)
	var w := 0.44
	var d := 0.32
	var y := -0.08
	for k in 7:
		var h := rng.randf_range(0.04, 0.055)
		y -= h
		f.box(Vector3(rng.randf_range(-0.015, 0.015), y + h * 0.5, rng.randf_range(-0.01, 0.01)),
				Vector3(w, h * 0.96, d), PAPER_A if k % 2 == 0 else PAPER_B, rng.randf_range(-0.05, 0.05))
	var bottom := y
	var top := -0.08
	var mid := (top + bottom) * 0.5
	var height := top - bottom
	var t := 0.022
	# Schnur: einmal rundherum längs, einmal quer
	f.box(Vector3(0, mid, d * 0.5 + 0.01), Vector3(t, height + 0.02, t), TWINE, 0.0)
	f.box(Vector3(0, mid, -d * 0.5 - 0.01), Vector3(t, height + 0.02, t), TWINE, 0.0)
	f.box(Vector3(w * 0.5 + 0.01, mid, 0), Vector3(t, height + 0.02, t), TWINE, 0.0)
	f.box(Vector3(-w * 0.5 - 0.01, mid, 0), Vector3(t, height + 0.02, t), TWINE, 0.0)
	f.box(Vector3(0, top + 0.01, 0), Vector3(t, t, d + 0.02), TWINE, 0.0)
	f.box(Vector3(0, top + 0.01, 0), Vector3(w + 0.02, t, t), TWINE, 0.0)
	f.box(Vector3(0, bottom - 0.01, 0), Vector3(t, t, d + 0.02), TWINE, 0.0)
	f.box(Vector3(0, bottom - 0.01, 0), Vector3(w + 0.02, t, t), TWINE, 0.0)
	f.blob(Vector3(0, top + 0.03, 0), 0.04, TWINE, rng, 0.0)
	f.frustum(Vector3(0, top + 0.03, 0), Vector3(0, 0, 0), 0.012, 0.012, 4, TWINE)
	return f


# --- Kulisse ------------------------------------------------------------------------

## Ein schiefer Turm aus Papierpacken und Büchern, `height` hoch, etwa 0.9 breit. Er neigt
## sich nach oben hin ein wenig, wie alles, was zu hoch gestapelt ist.
func _paper_tower(seed_value: int, height: float) -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(seed_value)
	var y := 0.0
	var drift := Vector2.ZERO
	var lean := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03))
	while y < height:
		drift += lean + Vector2(rng.randf_range(-0.015, 0.015), rng.randf_range(-0.015, 0.015))
		var c := Vector3(drift.x, 0, drift.y)
		var yaw := rng.randf_range(-0.25, 0.25)
		if rng.randf() < 0.35:
			# Ein Buch: Einband oben und unten, Seiten dazwischen
			var h := rng.randf_range(0.1, 0.2)
			var size := Vector3(rng.randf_range(0.6, 0.8), h, rng.randf_range(0.45, 0.6))
			var col: Color = COVERS[rng.randi() % COVERS.size()]
			f.box(c + Vector3(0, y + h * 0.5, 0), size, col, yaw)
			f.box(c + Vector3(0.02, y + h * 0.5, 0), size * Vector3(0.96, 0.8, 0.94) + Vector3(0, 0, 0.02),
					PAPER_A, yaw)
			y += h
		else:
			var h := rng.randf_range(0.06, 0.16)
			f.box(c + Vector3(0, y + h * 0.5, 0), Vector3(rng.randf_range(0.65, 0.8), h,
					rng.randf_range(0.5, 0.6)), PAPER_A if rng.randf() < 0.6 else PAPER_B, yaw)
			y += h
	return f


## Ein flacher Haufen Bücher am Boden, eines aufgeschlagen obenauf. Etwa 1.2 breit, 0.6 hoch.
func _book_pile() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(613)
	var y := 0.0
	for k in 4:
		var h := rng.randf_range(0.1, 0.16)
		var size := Vector3(rng.randf_range(0.7, 0.9), h, rng.randf_range(0.5, 0.6))
		var c := Vector3(rng.randf_range(-0.08, 0.08), y + h * 0.5, rng.randf_range(-0.05, 0.05))
		var yaw := rng.randf_range(-0.5, 0.5)
		f.box(c, size, COVERS[(k * 2 + 1) % COVERS.size()], yaw)
		f.box(c + Vector3(0.015, 0, 0.015), size * Vector3(0.95, 0.8, 0.94), PAPER_A, yaw)
		y += h
	# Aufgeschlagen: zwei Seitenhälften, leicht gewölbt
	for side: float in [-1.0, 1.0]:
		f.box(Vector3(side * 0.22, y + 0.03, 0), Vector3(0.44, 0.04, 0.6), PAPER_A, 0.0, 0.0)
		f.box(Vector3(side * 0.24, y + 0.005, 0), Vector3(0.5, 0.03, 0.64), COVERS[0], 0.0)
		for line in 4:
			f.box(Vector3(side * 0.22, y + 0.052, -0.18 + line * 0.11), Vector3(0.32, 0.004, 0.025),
					PAPER_C, 0.0)
	# Ein Tintenfass daneben
	f.frustum(Vector3(0.62, 0, 0.2), Vector3(0.62, 0.12, 0.2), 0.08, 0.07, 8, INK)
	f.frustum(Vector3(0.62, 0.12, 0.2), Vector3(0.62, 0.16, 0.2), 0.04, 0.035, 8, INK)
	return f


## Lose Blätter auf dem Boden, flach verstreut über 6 × 4.
func _paper_litter() -> ModelForge.Forge:
	var f := ModelForge.Forge.new()
	var rng := _rng(617)
	for k in 26:
		var c := Vector3(rng.randf_range(-3.0, 3.0), 0.006 + k * 0.0012, rng.randf_range(-2.0, 2.0))
		f.box(c, Vector3(0.3, 0.004, 0.4), PAPER_A if k % 3 else PAPER_B, rng.randf_range(0.0, PI))
	return f
