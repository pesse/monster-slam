class_name BookMesh
extends RefCounted
## Die Meshes eines gebundenen Buchs (Book3D): Profile im Schnitt (x, z) und ihre Extrusion
## entlang der Höhe (y).
##
## Ein gebundenes Buch ist nicht eckig: der Rücken ist gerundet, und gleich hinter ihm liegt
## im Deckel der Falz, eine kleine Rinne, an der der Deckel aufgeht. Die Profile tragen je
## Punkt, ob die Fläche dort glatt verläuft (Rundung, Rinne) oder eine Kante hat.

## Punkte je Rundung: genug für eine glatte Kontur, wenig genug für viele Bücher im Regal.
const ARC_STEPS := 10
const GROOVE_STEPS := 6


## Ein Deckel im Raum seines Scharniers: x von 0 (am Rücken) bis `width`, z von 0 (innen)
## bis `thickness` (außen). Außen, kurz hinter dem Scharnier, die Rinne des Falzes.
static func board_profile(width: float, thickness: float, groove_at: float, groove_width: float,
		groove_depth: float) -> Dictionary:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, thickness)])
	var smooth := [false, false, false]
	points.append(Vector2(groove_at + groove_width, thickness))
	smooth.append(false)
	for i in range(1, GROOVE_STEPS):
		var s := float(i) / float(GROOVE_STEPS)
		points.append(Vector2(groove_at + groove_width * (1.0 - s), thickness - groove_depth * sin(PI * s)))
		smooth.append(true)
	points.append(Vector2(groove_at, thickness))
	smooth.append(false)
	points.append(Vector2(0, thickness))
	smooth.append(false)
	return {"points": points, "smooth": smooth}


## Der Rücken: eine gewölbte Schale von der vorderen zur hinteren Kante bei x = `hinge_x`,
## `bulge` weit nach -x gewölbt, `half` die halbe Dicke des Buchs, `thickness` die Wand.
static func spine_profile(hinge_x: float, half: float, bulge: float, thickness: float) -> Dictionary:
	var points := PackedVector2Array()
	var smooth := []
	for i in ARC_STEPS + 1:
		var phi := PI * 0.5 - PI * float(i) / float(ARC_STEPS)
		points.append(Vector2(hinge_x - bulge * cos(phi), half * sin(phi)))
		smooth.append(i > 0 and i < ARC_STEPS)
	for i in ARC_STEPS + 1:
		var phi := -PI * 0.5 + PI * float(i) / float(ARC_STEPS)
		points.append(Vector2(hinge_x - (bulge - thickness) * cos(phi), (half - thickness) * sin(phi)))
		smooth.append(i > 0 and i < ARC_STEPS)
	return {"points": points, "smooth": smooth}


## Die Außenseite der Rückenwölbung, `lift` nach außen gerückt: für die Goldbänder.
static func spine_arc(hinge_x: float, half: float, bulge: float, lift: float) -> Dictionary:
	var points := PackedVector2Array()
	var smooth := []
	for i in ARC_STEPS + 1:
		var phi := PI * 0.5 - PI * float(i) / float(ARC_STEPS)
		points.append(Vector2(hinge_x - (bulge + lift) * cos(phi), (half + lift) * sin(phi)))
		smooth.append(true)
	return {"points": points, "smooth": smooth}


## Spiegelt ein Profil an z = 0 und verschiebt es um `offset` — der hintere Deckel ist der
## vordere, von hinten gesehen.
static func mirrored(profile: Dictionary, offset: Vector2) -> Dictionary:
	var points := PackedVector2Array()
	for p in profile["points"]:
		points.append(Vector2(p.x, -p.y) + offset)
	return {"points": points, "smooth": profile["smooth"]}


## Zieht ein Profil von `y0` bis `y1` hoch. Geschlossen mit Deckeln oben und unten, offen
## als Band. Die Normalen zeigen nach außen, gleich wie das Profil umläuft.
static func extrude(profile: Dictionary, y0: float, y1: float, closed := true) -> ArrayMesh:
	var points: PackedVector2Array = profile["points"]
	var smooth: Array = profile["smooth"]
	var count := points.size()
	var turn := 1.0 if _area(points) >= 0.0 else -1.0
	var segments := count if closed else count - 1
	var seg_normals: Array[Vector2] = []
	for i in segments:
		var d := points[(i + 1) % count] - points[i]
		seg_normals.append(Vector2(d.y, -d.x).normalized() * turn)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var j := (i + 1) % count
		var n_i := _vertex_normal(seg_normals, i, i, smooth, closed)
		var n_j := _vertex_normal(seg_normals, i, j, smooth, closed)
		var a := Vector3(points[i].x, y0, points[i].y)
		var b := Vector3(points[j].x, y0, points[j].y)
		var c := Vector3(points[j].x, y1, points[j].y)
		var e := Vector3(points[i].x, y1, points[i].y)
		for v in [[a, n_i], [b, n_j], [c, n_j], [a, n_i], [c, n_j], [e, n_i]]:
			tool.set_normal(Vector3(v[1].x, 0.0, v[1].y))
			tool.add_vertex(v[0])
	if closed:
		var triangles := Geometry2D.triangulate_polygon(points)
		for k in range(0, triangles.size(), 3):
			for cap: Array in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
				tool.set_normal(cap[1])
				for m in 3:
					var p := points[triangles[k + m]]
					tool.add_vertex(Vector3(p.x, cap[0], p.y))
	return tool.commit()


## Die Normale am Punkt `at` für das Segment `seg`: an einer glatten Stelle der Mittelwert
## beider Segmente, an einer Kante die des Segments selbst.
static func _vertex_normal(normals: Array[Vector2], seg: int, at: int, smooth: Array,
		closed: bool) -> Vector2:
	if not bool(smooth[at]):
		return normals[seg]
	var count := normals.size()
	var before := at - 1
	var after := at
	if closed:
		before = (at - 1 + count) % count
		after = at % count
	before = clampi(before, 0, count - 1)
	after = clampi(after, 0, count - 1)
	return (normals[before] + normals[after]).normalized()


static func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
