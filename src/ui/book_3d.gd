class_name Book3D
extends Node3D
## Ein Buch im Regal der Buchauswahl (ADR 0006), als gebundenes Buch: gerundeter Rücken,
## Falz hinter dem Rücken, Deckel, die über den Buchblock stehen. Im Regal zeigt es den
## Rücken mit seinem Titel; ausgewählt wird es herausgezogen und schräg zur Kamera gedreht;
## geöffnet schlägt der vordere Deckel auf, und die Doppelseite trägt die Buchkarte — dort
## taucht die Buchauswahl hinein.
##
## Das Cover ist eine kleine 2D-Szene in `%Art` (SubViewport): oben die Buchkarte im
## verschnörkelten Rahmen (OrnateFrame), unten Titel und Stand, gedruckt in der Typografie
## des Themes. Die Meshes baut BookMesh aus Profilen, je Buch nach seiner Dicke.
##
## Kanonische Lage in `%Body`: Cover nach +Z, Rücken nach -X. Im Regal ist `%Body` um 90°
## gedreht, dann zeigt der Rücken nach +Z, zur Kamera. Der vordere Deckel hängt an
## `%Hinge`, am Falz; um dessen y-Achse schlägt er auf.

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
## Abstand zwischen den Büchern im Regal.
const GAP := 0.06
## Wie weit ein ausgewähltes Buch über seinen Platz hinaus nach vorn kommt.
const PULL_MARGIN := 0.15
const LIFT := 0.12
## Ausgewählt steht das Buch so schräg (Grad), dass Rücken und Dicke zu sehen bleiben; erst
## beim Öffnen dreht es sich ganz zur Kamera.
const SHOWN_ANGLE := 26.0
## Ein ausgewähltes Buch rückt so weit zur Mitte des Regals.
const TO_CENTER := 0.5
const LIFT_TIME := 0.35
const OPEN_TIME := 0.55
## Ab hier dreht sich ein Buch; bis dahin kommt es nur gerade aus seinem Platz.
const TURN_START := 0.3
## Zurück ins Regal geht es schneller als heraus.
const RETURN_SPEED := 1.6
## Höhe der Goldbänder auf dem Rücken, von der Mitte aus, und ihre Breite.
const BAND_Y := 0.58
const BAND_HEIGHT := 0.035
## Die Karte auf der Doppelseite: ihre Breite auf jeder Seite und der Abstand zum Bund.
const SPREAD_HALF := 0.84
const SPREAD_GUTTER := 0.01
## Einbandfarben nach Position im Regal, damit Nachbarn sich unterscheiden.
const COLORS := [
	Color(0.16, 0.33, 0.62), Color(0.62, 0.2, 0.22), Color(0.18, 0.46, 0.3),
	Color(0.44, 0.27, 0.6), Color(0.74, 0.44, 0.14),
]
const PAPER := Color(0.8, 0.75, 0.64)

## 0 = im Regal, 1 = vorn mit dem Cover zur Kamera.
var lift := 0.0
var selected := false
var thickness := MIN_THICKNESS
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

@onready var _body: Node3D = %Body
@onready var _hinge: Node3D = %Hinge
@onready var _art: SubViewport = %Art


func _ready() -> void:
	var cover := StandardMaterial3D.new()
	cover.albedo_texture = _art.get_texture()
	cover.roughness = 0.9
	(%CoverFace as MeshInstance3D).material_override = cover
	_cloth.roughness = 0.75
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
	_shape()
	_pose()
	set_process(false)


## Titel, Kartenbild (oder null), Platz im Regal und Stand aus BookSelect.stats.
func fill(title: String, texture: Texture2D, index: int, stats: Dictionary) -> void:
	_texture = texture
	thickness = thickness_for(int(stats.get("units", 0)))
	var color: Color = COLORS[index % COLORS.size()]
	_cloth.albedo_color = color
	(%Paper as ColorRect).color = color.darkened(0.15)
	(%Map as TextureRect).texture = texture
	_left_map.albedo_texture = texture
	_right_map.albedo_texture = texture
	(%Title as Label).text = title
	(%SpineTitle as Label3D).text = title
	var done := int(stats.get("done", 0))
	var total := int(stats.get("total", 0))
	(%Words as Label).text = "%d von %d Wörtern gemeistert" % [done, total]
	var bar := %Bar as ProgressBar
	bar.max_value = maxi(total, 1)
	bar.value = done
	(%Crowns as Label).text = "👑 %d von %d Bossen besiegt" % [int(stats.get("crowns", 0)), int(stats.get("units", 0))]
	_shape()


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


## Liegt die Doppelseite offen? Dann kann die Buchauswahl hineintauchen.
func is_spread_open() -> bool:
	return _open >= 1.0


func _process(delta: float) -> void:
	var dt := minf(delta, MapCanvas.MAX_ZOOM_STEP)
	var step := dt / LIFT_TIME
	# Solange der Deckel offen ist, bleibt das Buch vorn und gerade — erst zu, dann zurück.
	var forward := _held or _open > 0.0
	var goal := 1.0 if forward or selected else 0.0
	# Ein anderes Buch ist noch gedreht draußen: erst nur gerade herausziehen, sonst
	# schneiden sich die beiden Einbände.
	var target := goal
	if goal > 0.0 and not forward and _other_is_out():
		target = minf(goal, TURN_START)
	lift = move_toward(lift, target, step if target >= lift else step * RETURN_SPEED)
	var flat_goal := 1.0 if forward else 0.0
	_flat = move_toward(_flat, flat_goal, step * 2.0)
	# Aufschlagen erst, wenn das Buch gerade vorn steht; zuschlagen sofort.
	var open_goal := 0.0
	if _opening:
		open_goal = 1.0 if is_facing() else _open
	_open = move_toward(_open, open_goal, dt / OPEN_TIME)
	_pose()
	if lift == goal and _flat == flat_goal and _open == (1.0 if _opening else 0.0):
		set_process(false)


func _other_is_out() -> bool:
	for sibling in get_parent().get_children():
		if sibling != self and sibling is Book3D and (sibling as Book3D).lift > TURN_START:
			return true
	return false


## Erst ziehen, dann drehen: am Anfang kommt das Buch gerade heraus, das Drehen setzt ein,
## wenn es die Nachbarn nicht mehr streift.
static func pull_of(k: float) -> float:
	return smoothstep(0.0, 0.65, k)


static func turn_of(k: float) -> float:
	return smoothstep(TURN_START, 1.0, k)


## Wo das Scharnier des vorderen Deckels liegt (x in der Buchlage).
static func hinge_x() -> float:
	return -WIDTH * 0.5 + BULGE


func _pose() -> void:
	var pull := pull_of(lift)
	var turn := turn_of(lift)
	var opened := smoothstep(0.0, 1.0, _open)
	var reach := WIDTH * 0.5 + thickness * 0.5 + PULL_MARGIN
	# Beim Aufschlagen rückt der Bund in die Bildmitte: die Doppelseite steht mittig.
	var center := lerpf(TO_CENTER * turn, 1.0, opened)
	_body.position = Vector3(-position.x * center - hinge_x() * opened, LIFT * pull, reach * pull)
	var angle := 90.0 * (1.0 - turn) + SHOWN_ANGLE * turn * (1.0 - _flat)
	_body.rotation = Vector3(0.0, deg_to_rad(angle), 0.0)
	_hinge.rotation = Vector3(0.0, -PI * opened, 0.0)


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

## Wie weit der Strahl bis zu diesem Buch läuft, oder INF: getroffen ist sein Platz im
## Regal oder der Körper, wo er gerade steht.
func hit(origin: Vector3, direction: Vector3) -> float:
	var t := thickness
	var slot := AABB(Vector3(-t * 0.5, -HEIGHT * 0.5, -WIDTH * 0.5), Vector3(t, HEIGHT, WIDTH))
	var body := AABB(Vector3(-WIDTH * 0.5, -HEIGHT * 0.5, -t * 0.5), Vector3(WIDTH, HEIGHT, t))
	return minf(ray_box(global_transform, slot, origin, direction),
			ray_box(_body.global_transform, body, origin, direction))


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
