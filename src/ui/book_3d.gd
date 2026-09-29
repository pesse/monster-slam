class_name Book3D
extends Node3D
## Ein Buch auf dem Lesepult der Bibliothek (ADR 0006), als gebundenes Buch: gerundeter
## Rücken, Falz hinter dem Rücken, Deckel, die über den Buchblock stehen. Es steht frontal,
## ein wenig gedreht, sodass links der Rücken zu sehen ist. Ausgewählt wird es vom Pult
## genommen: es kommt weit nach vorn in die Bildmitte, steht gerade zur Kamera, damit die
## Schrift gut lesbar ist, und leuchtet golden (`%Glow`, book_glow.gdshader). Geöffnet
## schlägt der vordere Deckel auf, und die Doppelseite trägt die Buchkarte — dort taucht die
## Bibliothek hinein.
##
## Das Cover ist eine kleine 2D-Szene in `%Art` (SubViewport): oben Titel und Sprache, in
## der Mitte die Buchkarte im verschnörkelten Rahmen (OrnateFrame), unten der Stand
## (`%Stats`: Wörter, Bosse). Der Stand ist nur am herausgenommenen Buch zu sehen, sein
## Platz bleibt frei, damit das Cover nicht springt. Die Meshes baut BookMesh aus Profilen,
## je Buch nach seiner Dicke.
##
## Kanonische Lage in `%Body`: Cover nach +Z, Rücken nach -X. Auf dem Pult ist `%Body` um
## SLOT_ANGLE gedreht. Der vordere Deckel hängt an `%Hinge`, am Falz; um dessen y-Achse
## schlägt er auf.

const WIDTH := 1.0
const HEIGHT := 1.4
const BOARD := 0.03
## So weit wölbt sich der Rücken nach außen; so viel stehen die Deckel über den Block.
const BULGE := 0.07
const OVERHANG := 0.015
## Der Falz: Abstand vom Scharnier, Breite, Tiefe.
const GROOVE_AT := 0.012
const GROOVE_WIDTH := 0.035
const GROOVE_DEPTH := 0.012
## Dicke nach Zahl der Units: ein Buch mit mehr Units ist dicker.
const MIN_THICKNESS := 0.22
const MAX_THICKNESS := 0.4
const THICKNESS_PER_UNIT := 0.045
## Wie weit ein ausgewähltes Buch nach vorn und nach oben kommt, wenn es vom Pult genommen
## wird. Dabei rückt es um TOWARD des Wegs zur Bildmitte (`center_x`) und bleibt nah an
## seinem Platz; erst beim Aufschlagen geht es ganz in die Mitte.
const PULL := 1.8
const TOWARD := 0.35
const LIFT := 0.32
## Auf seinem Platz steht das Buch so schräg (Grad), dass links Rücken und Dicke zu sehen
## sind; erst beim Öffnen dreht es sich ganz zur Kamera.
const SLOT_ANGLE := 16.0
const LIFT_TIME := 0.3
const OPEN_TIME := 0.55
## Zurück auf den Platz geht es schneller als heraus.
const RETURN_SPEED := 1.6
## Höhe der Goldbänder auf dem Rücken, von der Mitte aus, und ihre Breite.
const BAND_Y := 0.58
const BAND_HEIGHT := 0.035
## Die Karte auf der Doppelseite: ihre Breite auf jeder Seite und der Abstand zum Bund.
const SPREAD_HALF := 0.84
const SPREAD_GUTTER := 0.01
## Einbandfarben nach Position auf dem Pult, damit Nachbarn sich unterscheiden.
const COLORS := [
	Color(0.16, 0.33, 0.62), Color(0.62, 0.2, 0.22), Color(0.18, 0.46, 0.3),
	Color(0.44, 0.27, 0.6), Color(0.74, 0.44, 0.14),
]
const PAPER := Color(0.8, 0.75, 0.64)
## Der Einband (grau, kachelbar) wird mit der Buchfarbe getönt. Grau dunkelt ab; so viel
## heller wird die Farbe dafür angesetzt. Auf den Deckeln liegt er triplanar — BookMesh
## erzeugt keine UVs —, eine Kachel je TILE Meter.
const CLOTH := preload("res://assets/ui/library/cover_cloth.webp")
const CLOTH_GAIN := 1.6
const CLOTH_TILE := 0.35
## Der Glanz hinter dem ausgewählten Buch, so viel größer als das Buch.
const GLOW_MARGIN := 0.5

## 0 = auf seinem Platz, 1 = ausgewählt vorn.
var lift := 0.0
var selected := false
var thickness := MIN_THICKNESS
## Die Bildmitte (x im Raum des Elternknotens): dorthin rückt das Buch, wenn es vom Pult
## genommen wird, und dort steht der Bund, wenn es aufgeschlagen ist — auch wenn die Reihe
## geblättert ist. Die Bibliothek setzt es.
var center_x := 0.0
## Vorn halten (beim Öffnen und Zurückkommen) und aufschlagen.
var _held := false
var _opening := false
## 0..1: wie weit das Buch aus der Schräge ganz zur Kamera gedreht ist.
var _flat := 0.0
## 0..1: wie weit der vordere Deckel aufgeschlagen ist.
var _open := 0.0
var _texture: Texture2D
## Der Einband: ein Material für Deckel und Rücken, je Buch eigens angelegt.
var _cloth := StandardMaterial3D.new()
var _left_map := StandardMaterial3D.new()
var _right_map := StandardMaterial3D.new()
var _glow_material: ShaderMaterial

@onready var _body: Node3D = %Body
@onready var _hinge: Node3D = %Hinge
@onready var _art: SubViewport = %Art


func _ready() -> void:
	var cover := StandardMaterial3D.new()
	cover.albedo_texture = _art.get_texture()
	cover.roughness = 0.9
	(%CoverFace as MeshInstance3D).material_override = cover
	_cloth.roughness = 0.75
	_cloth.albedo_texture = CLOTH
	_cloth.uv1_triplanar = true
	_cloth.uv1_scale = Vector3.ONE / CLOTH_TILE
	_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	for part: MeshInstance3D in [%Front, %Back, %Spine]:
		part.material_override = _cloth
	var paper := StandardMaterial3D.new()
	paper.albedo_color = PAPER
	paper.roughness = 1.0
	(%LeftPage as MeshInstance3D).material_override = paper
	# Die Karte über beide Seiten: links die linke Hälfte des Bildes, rechts die rechte.
	for half: StandardMaterial3D in [_left_map, _right_map]:
		half.roughness = 0.95
		half.uv1_scale = Vector3(0.5, 1.0, 1.0)
	_right_map.uv1_offset = Vector3(0.5, 0.0, 0.0)
	(%LeftMap as MeshInstance3D).material_override = _left_map
	(%RightMap as MeshInstance3D).material_override = _right_map
	# Eigene Kopie: jedes Buch leuchtet für sich (CLAUDE.md „Fallen", geteilte Ressourcen).
	var glow := %Glow as MeshInstance3D
	_glow_material = (glow.material_override as ShaderMaterial).duplicate()
	glow.material_override = _glow_material
	_shape()
	_pose()
	set_process(false)


## Titel, Kartenbild (oder null), Platz auf dem Pult und Stand aus BookSelect.stats, dazu
## `language` (Anzeigename der Sprache) und `bosses` (Units mit Boss; ohne Feld alle).
func fill(title: String, texture: Texture2D, index: int, stats: Dictionary) -> void:
	_texture = texture
	thickness = thickness_for(int(stats.get("units", 0)))
	var color: Color = COLORS[index % COLORS.size()]
	_cloth.albedo_color = _gained(color)
	(%Paper as TextureRect).self_modulate = _gained(color.darkened(0.15))
	(%Map as TextureRect).texture = texture
	_left_map.albedo_texture = texture
	_right_map.albedo_texture = texture
	(%Language as Label).text = str(stats.get("language", ""))
	(%Title as Label).text = title
	(%SpineTitle as Label3D).text = title
	var done := int(stats.get("done", 0))
	var total := int(stats.get("total", 0))
	(%Words as Label).text = "📖 %d / %d" % [done, total]
	var bar := %Bar as ProgressBar
	bar.max_value = maxi(total, 1)
	bar.value = done
	var bosses := int(stats.get("bosses", stats.get("units", 0)))
	(%Crowns as Label).text = "Noch kein Bosskampf" if bosses == 0 \
			else "👑 %d / %d Bosse besiegt" % [int(stats.get("crowns", 0)), bosses]
	_shape()


## Die Farbe, heller angesetzt für den grauen Einband (CLOTH_GAIN); Alpha bleibt.
static func _gained(color: Color) -> Color:
	return Color(color.r * CLOTH_GAIN, color.g * CLOTH_GAIN, color.b * CLOTH_GAIN, color.a)


func texture() -> Texture2D:
	return _texture


static func thickness_for(units: int) -> float:
	return clampf(0.16 + THICKNESS_PER_UNIT * float(units), MIN_THICKNESS, MAX_THICKNESS)


## Wählt das Buch aus oder stellt es zurück.
func set_selected(on: bool) -> void:
	selected = on
	set_process(true)


## Hält das Buch vorn und gerade zur Kamera; `false` schlägt es auch wieder zu.
func hold_forward(held: bool) -> void:
	_held = held
	if not held:
		_opening = false
	set_process(true)


## Holt das Buch nach vorn, dreht es zur Kamera und schlägt es auf.
func open_book() -> void:
	_held = true
	_opening = true
	set_process(true)


## Steht sofort aufgeschlagen da — für den Weg zurück aus der Buchkarte.
func show_open() -> void:
	_held = true
	_opening = true
	lift = 1.0
	_flat = 1.0
	_open = 1.0
	_pose()


## Steht das Buch ganz vorn und gerade zur Kamera?
func is_facing() -> bool:
	return lift >= 1.0 and _flat >= 1.0


## Liegt die Doppelseite offen? Dann kann die Bibliothek hineintauchen.
func is_spread_open() -> bool:
	return _open >= 1.0


func _process(delta: float) -> void:
	var dt := minf(delta, MapCanvas.MAX_ZOOM_STEP)
	var step := dt / LIFT_TIME
	# Solange der Deckel offen ist, bleibt das Buch vorn und gerade — erst zu, dann zurück.
	var forward := _held or _open > 0.0
	var goal := 1.0 if forward or selected else 0.0
	lift = move_toward(lift, goal, step if goal >= lift else step * RETURN_SPEED)
	# Ausgewählt steht es ganz gerade, damit die Schrift auf dem Cover lesbar ist.
	var flat_goal := 1.0 if forward or selected else 0.0
	_flat = move_toward(_flat, flat_goal, step)
	# Aufschlagen erst, wenn das Buch gerade vorn steht; zuschlagen sofort.
	var open_goal := 0.0
	if _opening:
		open_goal = 1.0 if is_facing() else _open
	_open = move_toward(_open, open_goal, dt / OPEN_TIME)
	_pose()
	if lift == goal and _flat == flat_goal and _open == (1.0 if _opening else 0.0):
		set_process(false)


## Wo das Scharnier des vorderen Deckels liegt (x in der Buchlage).
static func hinge_x() -> float:
	return -WIDTH * 0.5 + BULGE


func _pose() -> void:
	var pull := smoothstep(0.0, 1.0, lift)
	var opened := smoothstep(0.0, 1.0, _open)
	# Vom Pult genommen rückt das Buch ein Stück zur Bildmitte; aufgeschlagen steht dort
	# der Bund, die Doppelseite mittig.
	var toward := lerpf(TOWARD, 1.0, opened) * pull
	_body.position = Vector3((center_x - position.x) * toward - hinge_x() * opened,
			LIFT * pull, PULL * pull)
	_body.rotation = Vector3(0.0, deg_to_rad(SLOT_ANGLE * (1.0 - smoothstep(0.0, 1.0, _flat))), 0.0)
	_hinge.rotation = Vector3(0.0, -PI * opened, 0.0)
	# Glanz und Stand gehören zum ausgewählten Buch; aufgeschlagen tritt der Glanz zurück.
	(%Stats as Control).modulate.a = smoothstep(0.5, 1.0, lift)
	var glow := pull * (1.0 - opened)
	_glow_material.set_shader_parameter("strength", glow)
	(%Glow as MeshInstance3D).visible = glow > 0.0


## Baut die Meshes nach `thickness`. Jedes Buch bekommt eigene Meshes — geladene
## Ressourcen wären geteilt, und jedes Buch änderte die der anderen mit.
func _shape() -> void:
	if not is_node_ready():
		return
	var t := thickness
	var half := t * 0.5
	var hx := hinge_x()
	var board_width := WIDTH * 0.5 - hx
	var board := BookMesh.board_profile(board_width, BOARD, GROOVE_AT, GROOVE_WIDTH, GROOVE_DEPTH)
	var y0 := -HEIGHT * 0.5
	var y1 := HEIGHT * 0.5
	(%Front as MeshInstance3D).mesh = BookMesh.extrude(board, y0, y1)
	(%Back as MeshInstance3D).mesh = BookMesh.extrude(
			BookMesh.mirrored(board, Vector2(hx, -half + BOARD)), y0, y1)
	(%Spine as MeshInstance3D).mesh = BookMesh.extrude(
			BookMesh.spine_profile(hx, half, BULGE, BOARD), y0, y1)
	# Der Deckel hängt am Scharnier, innen bündig mit dem Buchblock.
	_hinge.position = Vector3(hx, 0.0, half - BOARD)

	var pages := BoxMesh.new()
	pages.size = Vector3(WIDTH * 0.5 - OVERHANG - (hx - 0.02), HEIGHT - 2.0 * OVERHANG, t - 2.0 * BOARD)
	(%Pages as MeshInstance3D).mesh = pages
	(%Pages as MeshInstance3D).position = Vector3(hx - 0.02 + pages.size.x * 0.5, 0.0, 0.0)

	# Der Glanz liegt hinter dem Buch und steht rundum über.
	var glow_size := Vector2(WIDTH + GLOW_MARGIN, HEIGHT + GLOW_MARGIN)
	_quad(%Glow, glow_size, Vector3(0.0, 0.0, -half - 0.02), false)
	_glow_material.set_shader_parameter("quad_size", glow_size)
	_glow_material.set_shader_parameter("book_size", Vector2(WIDTH, HEIGHT))

	# Außen auf dem Deckel das Cover, vom Falz bis zur Kante; innen die linke Seite.
	var flat_from := GROOVE_AT + GROOVE_WIDTH
	_quad(%CoverFace, Vector2(board_width - flat_from, HEIGHT),
			Vector3((flat_from + board_width) * 0.5, 0.0, BOARD + 0.002), false)
	_quad(%LeftPage, Vector2(board_width - OVERHANG - 0.01, HEIGHT - 2.0 * OVERHANG),
			Vector3((board_width - OVERHANG + 0.01) * 0.5, 0.0, -0.001), true)
	var map_height := spread_height()
	_quad(%LeftMap, Vector2(SPREAD_HALF, map_height),
			Vector3(SPREAD_GUTTER + SPREAD_HALF * 0.5, 0.0, -0.002), true)
	_quad(%RightMap, Vector2(SPREAD_HALF, map_height),
			Vector3(hx + SPREAD_GUTTER + SPREAD_HALF * 0.5, 0.0, half - BOARD + 0.002), false)

	# Auf dem Rücken (-X): der Titel läuft von oben nach unten, die Goldbänder quer.
	var title := %SpineTitle as Label3D
	title.position = Vector3(hx - BULGE - 0.004, 0.0, 0.0)
	title.rotation_degrees = Vector3(0.0, -90.0, -90.0)
	var arc := BookMesh.spine_arc(hx, half, BULGE, 0.002)
	(%BandTop as MeshInstance3D).mesh = BookMesh.extrude(arc, BAND_Y - BAND_HEIGHT * 0.5,
			BAND_Y + BAND_HEIGHT * 0.5, false)
	(%BandBottom as MeshInstance3D).mesh = BookMesh.extrude(arc, -BAND_Y - BAND_HEIGHT * 0.5,
			-BAND_Y + BAND_HEIGHT * 0.5, false)


## Wie hoch die Karte auf der Doppelseite steht: so breit wie beide Seiten, im
## Seitenverhältnis des Bildes.
func spread_height() -> float:
	var ratio := MapCanvas.ASPECT
	if _texture != null and _texture.get_height() > 0:
		ratio = float(_texture.get_width()) / float(_texture.get_height())
	return (2.0 * (SPREAD_HALF + SPREAD_GUTTER)) / ratio


## Ein Quad der Größe `size` bei `at`; `inside` dreht es um, für die Innenseite des Deckels.
func _quad(node: MeshInstance3D, size: Vector2, at: Vector3, inside: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	node.mesh = quad
	node.position = at
	node.rotation = Vector3(0.0, PI if inside else 0.0, 0.0)


# --- Treffer und Bildschirm -----------------------------------------------------

## Wie weit der Strahl bis zu diesem Buch auf seinem Platz in der Reihe läuft, oder INF.
## Gezielt wird immer auf den Platz, nicht auf das herausgenommene Buch: das steht groß vor
## den Nachbarn und würde sie sonst verdecken.
func hit(origin: Vector3, direction: Vector3) -> float:
	var home := global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(SLOT_ANGLE)),
			Vector3.ZERO)
	return ray_box(home, _box(), origin, direction)


## Wie weit der Strahl bis zum Körper läuft, wo er gerade steht (herausgenommen), oder INF.
func hit_body(origin: Vector3, direction: Vector3) -> float:
	return ray_box(_body.global_transform, _box(), origin, direction)


func _box() -> AABB:
	var t := thickness
	return AABB(Vector3(-WIDTH * 0.5, -HEIGHT * 0.5, -t * 0.5), Vector3(WIDTH, HEIGHT, t))


## Abstand entlang des Strahls bis zur Box `box` im Raum `frame`, oder INF.
static func ray_box(frame: Transform3D, box: AABB, origin: Vector3, direction: Vector3) -> float:
	var inv := frame.affine_inverse()
	var o := inv * origin
	var d := inv.basis * direction
	var near := -INF
	var far := INF
	for axis in 3:
		if absf(d[axis]) < 0.000001:
			if o[axis] < box.position[axis] or o[axis] > box.end[axis]:
				return INF
			continue
		var a := (box.position[axis] - o[axis]) / d[axis]
		var b := (box.end[axis] - o[axis]) / d[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
	if near > far or far < 0.0:
		return INF
	return maxf(near, 0.0) * d.length() / maxf(direction.length(), 0.000001)


## Wo die Kamera steht, wenn die Karte der Doppelseite den Bildschirm füllt wie auf der
## Buchkarte (MapCanvas.map_rect mit `fill`): mittig davor, senkrecht darauf, so nah, dass
## die Karte an der knapperen Achse gerade randlos ist. `fov` senkrecht in Grad.
func spread_view(fov: float, aspect: float) -> Transform3D:
	var page := _body.global_transform
	var center := page * Vector3(hinge_x(), 0.0, thickness * 0.5 - BOARD + 0.002)
	var normal := page.basis.z.normalized()
	var width := 2.0 * (SPREAD_HALF + SPREAD_GUTTER)
	var height := spread_height()
	var visible_height := minf(height, width / maxf(aspect, 0.01))
	var distance := visible_height * 0.5 / tan(deg_to_rad(fov) * 0.5)
	var eye := center + normal * distance
	return Transform3D(Basis.looking_at(-normal, page.basis.y.normalized()), eye)
