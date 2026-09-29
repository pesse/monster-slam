class_name Bow
extends Node3D
## Der Bogen in der Hand (Ich-Sicht, Späher-Baum): hängt an der Kamera, unten links wie in
## der linken Hand. Zwischen zwei Antworten ist er gesenkt, bei offener Eingabe gehoben, und
## jeder Buchstabe zieht die Sehne ein Stück weiter (`pull`). Beim Abschicken schnellt sie
## vor (`release`), und ein neuer Pfeil liegt gleich wieder auf.
##
## Wie weit gespannt ist, hängt NUR an den getippten Buchstaben, nie an der erwarteten
## Antwort — sonst verriete der Bogen, wie lang das Wort ist.
##
## Alles nach der Wanduhr: getippt wird in der Zeitlupe.

## Von Spitze zu Spitze, und so weit steht der Griff vor der Sehne.
const HEIGHT := 1.0
const BRACE := 0.16
## So weit zieht die volle Spannung die Sehne zurück.
const DRAW_LENGTH := 0.34
## Das öffnende Enter legt an, jeder Buchstabe zieht weiter, bis zum Anschlag.
const DRAW_ON_RAISE := 0.25
const DRAW_PER_KEY := 0.1
const RELOAD_TIME := 0.3
## Vor einem Treffer schwenkt der Bogen so schnell aufs Ziel und bleibt so lange darauf,
## bevor er in seine Lage zurückgeht.
const SWING_TIME := 0.06
const SWING_HOLD := 0.14
const SEGMENTS := 10

const WOOD_COLOR := Color(0.5, 0.3, 0.15)
const GRIP_COLOR := Color(0.24, 0.14, 0.08)
const STRING_COLOR := Color(0.9, 0.87, 0.78)

## Lage an der Kamera: gesenkt (am Bildrand) und gehoben (angelegt).
const LOWERED_POS := Vector3(-0.5, -0.66, -0.8)
const LOWERED_ROT := Vector3(-30.0, 10.0, 22.0)
const RAISED_POS := Vector3(-0.34, -0.2, -0.85)
const RAISED_ROT := Vector3(0.0, 3.0, -10.0)

## 0 = entspannt, 1 = voll gespannt.
var draw := 0.0:
	set(value):
		draw = clampf(value, 0.0, 1.0)
		_update_string()

var _raised := false
## Läuft ein Schwenk, gehört ihm die Lage: set_raised merkt sich nur, wohin es danach geht.
var _swinging := false
## Wohin die Sehne gerade gezogen wird. Eigener Wert, weil schnelles Tippen den laufenden
## Tween abbricht: vom halb gezogenen `draw` aus gerechnet ginge jeder Buchstabe verloren.
var _goal := 0.0
var _upper_string: MeshInstance3D
var _lower_string: MeshInstance3D
var _nocked: Arrow
var _pose: Tween
var _draw: Tween


func _ready() -> void:
	var wood := Arrow.material(WOOD_COLOR)
	var points := limb_points()
	for i in points.size() - 1:
		var t := absf(float(i) + 0.5 - SEGMENTS * 0.5) / (SEGMENTS * 0.5)
		var width := lerpf(0.045, 0.02, t)
		_segment(points[i], points[i + 1], Vector2(width, 0.03), wood)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.055, 0.15, 0.05)
	grip.mesh = grip_mesh
	grip.material_override = Arrow.material(GRIP_COLOR)
	grip.position = Vector3(0.0, 0.0, -BRACE)
	add_child(grip)
	var cord := Arrow.material(STRING_COLOR)
	_upper_string = _segment(Vector3.ZERO, Vector3.UP, Vector2(0.006, 0.006), cord)
	_lower_string = _segment(Vector3.ZERO, Vector3.UP, Vector2(0.006, 0.006), cord)
	_nocked = Arrow.new()
	add_child(_nocked)
	_update_string()
	position = LOWERED_POS
	rotation_degrees = LOWERED_ROT


## Die Punkte des Bogenholzes von unten nach oben: eine Parabel, die Spitzen an der Sehne
## (z = 0), der Griff BRACE davor.
static func limb_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS * 2.0 - 1.0
		out.append(Vector3(0.0, t * HEIGHT * 0.5, -BRACE * (1.0 - t * t)))
	return out


## Wo die Sehne die Nocke hält: auf der Linie der Spitzen, mit der Spannung zurückgezogen.
static func nock_point(amount: float) -> Vector3:
	return Vector3(0.0, 0.0, DRAW_LENGTH * clampf(amount, 0.0, 1.0))


## Heben (Eingabe offen) oder senken. Gesenkt entspannt er sich.
func set_raised(on: bool) -> void:
	if on == _raised:
		return
	_raised = on
	# Gesenkt wird nicht sofort: nach dem Abschicken soll man den Schuss noch aus dem Bogen
	# gehen sehen.
	if not _swinging:
		_to_pose(0.0 if on else 0.2)
	# Eben abgeschossen (release) ist schon entspannt; ein zweites Entspannen legte den
	# nächsten Pfeil auf, bevor der erste weg ist. Im Schwenk bleibt die Sehne gespannt —
	# losgelassen wird erst am Ziel.
	if on or (_goal > 0.0 and not _swinging):
		_tween_draw(DRAW_ON_RAISE if on else 0.0, 0.2)


## Schwenkt kurz auf `target` (Weltlage), damit der Pfeil sichtbar dorthin abgeht, und
## kehrt danach in die Lage zurück, die dann gilt (gehoben oder gesenkt). Der Aufrufer
## wartet SWING_TIME, bevor er loslässt.
func swing_to(target: Vector3) -> void:
	var parent := get_parent() as Node3D
	var dir := target - global_position
	if parent != null:
		dir = parent.global_basis.inverse() * dir
	if dir.length_squared() < 0.0001 or absf(dir.normalized().y) > 0.99:
		return
	# Die Neigung der gehobenen Lage bleibt: nur die Richtung ändert sich.
	var aim := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.BACK, deg_to_rad(RAISED_ROT.z))
	_swinging = true
	if _pose != null:
		_pose.kill()
	_pose = create_tween().set_ignore_time_scale(true)
	_pose.tween_property(self, "quaternion", aim.get_rotation_quaternion(), SWING_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose.tween_interval(SWING_HOLD)
	_pose.tween_callback(func() -> void:
		_swinging = false
		_to_pose(0.0))


func is_swinging() -> bool:
	return _swinging


func _to_pose(delay: float) -> void:
	if _pose != null:
		_pose.kill()
	_pose = create_tween().set_ignore_time_scale(true).set_parallel(true)
	var pos := RAISED_POS if _raised else LOWERED_POS
	var rot := RAISED_ROT if _raised else LOWERED_ROT
	var time := 0.18 if _raised else 0.3
	_pose.tween_property(self, "position", pos, time).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose.tween_property(self, "rotation_degrees", rot, time).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func is_raised() -> bool:
	return _raised


## Ein Buchstabe: die Sehne ein Stück weiter zurück.
func pull() -> void:
	if _raised:
		_tween_draw(_goal + DRAW_PER_KEY, 0.1)


## Die Sehne schnellt vor, der aufgelegte Pfeil geht ab: gibt zurück, wo er lag (Weltlage),
## damit der fliegende Pfeil genau dort beginnt. Kurz danach liegt ein neuer auf.
func release() -> Transform3D:
	var from := _nocked.global_transform
	_nocked.visible = false
	_goal = 0.0
	if _draw != null:
		_draw.kill()
	_draw = create_tween().set_ignore_time_scale(true)
	_draw.tween_property(self, "draw", 0.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_draw.tween_callback(func() -> void: _nocked.visible = true).set_delay(RELOAD_TIME)
	return from


func _tween_draw(goal: float, time: float) -> void:
	_goal = clampf(goal, 0.0, 1.0)
	if _draw != null:
		_draw.kill()
	_draw = create_tween().set_ignore_time_scale(true)
	_draw.tween_property(self, "draw", _goal, time).set_trans(Tween.TRANS_SINE)
	# Wurde während des Nachladens neu gespannt, liegt trotzdem ein Pfeil auf.
	_nocked.visible = true


func _update_string() -> void:
	if _nocked == null:
		return
	var nock := nock_point(draw)
	var top := Vector3(0.0, HEIGHT * 0.5, 0.0)
	_place(_upper_string, top, nock)
	_place(_lower_string, -top, nock)
	# Der Pfeil liegt links am Griff vorbei, nicht durch ihn hindurch.
	_nocked.position = nock + Vector3(-0.035, 0.0, 0.0)


## Ein Stab von `a` nach `b` mit dem Querschnitt `size` (x, z).
func _segment(a: Vector3, b: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 1.0, size.y)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	_place(mi, a, b)
	return mi


## Legt einen Einheits-Stab (Länge 1 entlang y) von `a` nach `b`.
static func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.0001:
		return
	var y := along / length
	var ref := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.99 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
