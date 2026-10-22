class_name RamblerStage
extends Node3D
## Die Bühne des Schreib-Kampfs (scenes/battle/rambler_stage.tscn, ADR 0023 §3): The
## Rambler in seinem Turm aus Papier und Büchern, gesehen aus der Ich-Sicht.
##
## Die Teile kommen aus src/dev/rambler_forge.gd und werden hier ohne Rig zusammengesetzt
## und bewegt: der Leib ist eine Kette von Ringen auf einer Kurve.
##
## Um den Bauch trägt er eine Schnur, an der `stack_count` Papierstapel hängen — einer je
## Bewertungskriterium. Sie sind die Lebensleiste: `drop_stack` lässt einen abfallen (und
## ihn ein Stück schrumpfen), `hold_stack` lässt einen wackeln und halten.
##
## Wie BossStage spielt die Bühne nur vor; was geschehen ist, sagt ihr der Kampf. Zwischen
## den Ereignissen lebt sie von selbst: er atmet, wiegt den Kopf, murmelt vor sich hin,
## die Flügel blättern, Blätter segeln durch den Raum, Kerzen flackern.
##
## Zwei Plätze (`set_focus`): vorn ist er groß in der Mitte und spricht. Hinten liegen
## Texte als Overlay über dem Bild; dann wandert er ruhig durch den Raum — hin und her über
## die Breite des Bildes, mit Pausen, in denen er den Spieler anschaut — und tritt ab und zu
## vorn am Bildrand auf (PEEK, `is_peeking`), wo er neben den Panels zu sehen ist. Die
## Kamera steht dabei still: ein mitschwenkendes Bild lenkt beim Lesen ab.

## Vorn: mitten im Bild, nah.
const FRONT := Vector3(0.0, 0.0, -3.0)
## Hinten: das Feld, in dem er wandert (x von–bis, z von–bis). Breit genug, dass er bis
## nah an die Bildränder kommt, und frei von Papiertürmen und Kerzen.
const WANDER := Rect2(-5.4, -6.6, 10.8, 1.2)
## Auftritt: ein Platz am Bildrand (x je Seite ±, z), weiter vorn als WANDER und knapp neben
## den vorderen Büchertürmen — bei 16:9 neben dem Lese-Panel zu sehen.
const PEEK := Vector2(5.0, -3.6)
## Wahrscheinlichkeit, dass das nächste Ziel ein Auftritt ist (0–1).
const PEEK_CHANCE := 0.4
## Wie lange er am Bildrand steht (s, von–bis).
const PEEK_REST := Vector2(5.0, 8.0)
## Schritttempo beim Wandern und beim Gang nach vorn (m/s).
const WALK_SPEED := 0.75
const RUSH_SPEED := 3.0
## Wie schnell er sich umdreht (rad/s, weich über lerp_angle).
const TURN_RATE := 4.0
## Wie lange er zwischen zwei Gängen stehen bleibt (s), und wie weit ein Gang mindestens ist.
const REST_MIN := 2.0
const REST_MAX := 5.0
const STRIDE_MIN := 2.5
## Wie lange das Leiserwerden beim Wechsel nach hinten dauert (s).
const FOCUS_TIME := 1.1
## Wohin die Kamera schaut, je Platz. Hinten fest auf die Raummitte.
const LOOK_FRONT := Vector3(0.0, 2.05, -3.0)
const LOOK_BACK := Vector3(0.0, 1.8, -5.5)
## Wie weit er insgesamt schrumpft, wenn alle Stapel gefallen sind (Anteil der Größe).
const SHRINK_TOTAL := 0.4
## Wie viele Ringe der Leib hat.
const SEGMENTS := 15
## Größe des Kopfs relativ zum Modell.
const HEAD_SCALE := 1.55
const JAW_HINGE := Vector3(0.0, 0.02, -0.02)
## Mund in Kopfkoordinaten: vorn zwischen den Deckeln.
const MOUTH := Vector3(0.0, 0.0, 0.66)
## Wie lange er nach `speak()` redet (s).
const SPEAK_TIME := 2.4
## Die Schnur um den Bauch: Höhe über dem Boden, halbe Breite und Tiefe des Ovals vor der
## Bauchmitte; die Stapel hängen STACK_GAP auseinander, höchstens BELT_SPAN zu jeder Seite.
const BELT_HEIGHT := 1.5
const BELT_HALF := 1.35
const BELT_DEPTH := 0.85
const STACK_GAP := 0.52
const BELT_SPAN := 1.15
const STACK_SCALE := 1.0
## Wie weit ein Stapel unter seinem Knoten hängt (Modellmeter): so hoch liegt der Knoten,
## wenn der Stapel am Boden liegt.
const STACK_HEIGHT := 0.43
## Die Farben der Zettel an den Stapeln, der Reihe nach — damit man sie auseinanderhält.
const TAG_COLORS := [
	Color(0.85, 0.27, 0.22), Color(0.25, 0.48, 0.85), Color(0.35, 0.7, 0.3),
	Color(0.95, 0.72, 0.2), Color(0.62, 0.38, 0.8), Color(0.25, 0.7, 0.7),
]

## Die Wirbelsäule in Ruhe (Boss-Koordinaten, vorn +z): vom Schwanz am Boden hinten rechts
## über den dicken Bauch nach oben zum Genick.
const SPINE := [
	Vector3(1.55, 0.2, -0.9), Vector3(1.0, 0.32, -0.45), Vector3(0.3, 0.52, -0.05),
	Vector3(-0.05, 1.1, 0.2), Vector3(0.0, 1.75, 0.1), Vector3(0.05, 2.3, -0.05),
	Vector3(0.0, 2.75, 0.05),
]
## Und gefallen: der Leib sackt nach vorn auf den Boden, der Kopf liegt vor ihm.
const SPINE_FALLEN := [
	Vector3(1.55, 0.2, -0.9), Vector3(1.0, 0.3, -0.45), Vector3(0.3, 0.45, 0.0),
	Vector3(-0.1, 0.6, 0.45), Vector3(-0.35, 0.5, 0.95), Vector3(-0.6, 0.4, 1.35),
	Vector3(-0.8, 0.42, 1.6),
]
## Dicke des Leibs entlang der Wirbelsäule (0 = Schwanz, 1 = Genick): dünn, dann der
## aufgeblähte Bauch, dann ein schmaler Hals.
const GIRTH := [
	Vector2(0.0, 0.2), Vector2(0.14, 0.3), Vector2(0.3, 0.6), Vector2(0.45, 0.95),
	Vector2(0.6, 0.85), Vector2(0.76, 0.56), Vector2(0.9, 0.38), Vector2(1.0, 0.32),
]

const SEGMENT_SCENE := preload("res://assets/models/bosses/rambler/segment.glb")
const STACK_SCENE := preload("res://assets/models/bosses/rambler/stack.glb")
const SHEET_SHADER := preload("res://assets/shaders/paper_sheet.gdshader")
const MOTE_SHADER := preload("res://assets/shaders/soft_mote.gdshader")
const SMOKE_SHADER := preload("res://assets/shaders/smoke.gdshader")

enum State { IDLE, FALLEN }

## So viele Stapel hängen an ihm (einer je Kriterium). Vor `restore_all()` setzen.
var stack_count := 5

@onready var _boss: Node3D = %Boss
@onready var _body: Node3D = %Body
@onready var _segments: Node3D = %Segments
@onready var _head: Node3D = %Head
@onready var _jaw: Node3D = %Jaw
@onready var _wing_l: Node3D = %WingL
@onready var _wing_r: Node3D = %WingR
@onready var _arm_l: Node3D = %ArmL
@onready var _arm_r: Node3D = %ArmR
@onready var _tail: Node3D = %Tail
@onready var _belt: Node3D = %Belt
@onready var _camera: Camera3D = %Camera
@onready var _candles: Node3D = %Candles

var _state := State.IDLE
var _front := true
## 0 = vorn, 1 = hinten; läuft weich zwischen beiden.
var _back_k := 0.0
## Wohin er gerade geht, wie lange er noch steht, wohin er schauen will.
var _goal := FRONT
var _rest_left := 0.0
## Ob das Ziel ein Auftritt ist, und ob er gerade dort steht.
var _peek_goal := false
var _peeking := false
var _yaw_goal := 0.0
## 0 = steht, 1 = geht; weich, für das Watscheln.
var _walk_k := 0.0
var _fall_k := 0.0
var _time := 0.0
var _speak_left := 0.0
var _mutter_left := 0.0
var _gloat_left := 0.0
## Ein kurzes Zusammenzucken (Treffer), klingt ab.
var _flinch := 0.0
## Wie aufgebläht er gerade ist, zusätzlich zur Größe (Freude, Treffer).
var _puff := 0.0
var _size := 1.0
var _shake_left := 0.0
var _shake_mag := 0.0
var _camera_home: Vector3
var _look := LOOK_FRONT
var _rings: Array[Node3D] = []
## Je Stapel: { node, pivot, tag, dropped, wobble, wobble_v, angle }
var _stacks: Array[Dictionary] = []
var _rope: Array[MeshInstance3D] = []
var _light_energy: Dictionary = {}
var _flash: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

static var _sheet_material: ShaderMaterial
static var _mote_material: ShaderMaterial
static var _dust_material: ShaderMaterial
static var _rope_material: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	GraphicsQuality.apply_environment($WorldEnvironment as WorldEnvironment)
	_camera_home = _camera.position
	for i in SEGMENTS:
		var ring := SEGMENT_SCENE.instantiate() as Node3D
		ring.name = "Ring%d" % i
		_segments.add_child(ring)
		_rings.append(ring)
	_jaw.position = JAW_HINGE
	for light in find_children("*", "OmniLight3D", true, false):
		_light_energy[light] = (light as OmniLight3D).light_energy
	_kindle_candles()
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 0.95, 0.8, 0.0)
	add_child(_air())
	add_child(_motes())
	restore_all()
	_boss.position = FRONT
	_goal = FRONT
	_pose(0.0)


## Vorwärmen hinter dem Schleier (FxWarmup): Blätterwirbel, Staubwolke und der helle Blitz
## auf dem Leib einmal zeigen, damit ihre Shader nicht erst beim ersten Treffer entstehen.
func warm_up() -> void:
	var at := FxWarmup.point_in_view(_camera, _mouth_point())
	_burst(at, 6)
	_dust(at)
	_set_overlay(_flash)
	await FxWarmup.frames()
	_set_overlay(null)


## true: er kommt nach vorn in die Bildmitte und spricht. false: er tritt zurück nach links
## und bewegt sich nur noch leise — dann liegt Text über dem Bild.
func set_focus(front: bool) -> void:
	if front == _front:
		return
	_front = front
	if front and _state == State.IDLE:
		speak()
	if not front:
		# Erst ein Stück nach hinten ins Feld, dann wandern.
		_rest_left = 0.0
		_pick_goal()


## Er redet: der Kiefer klappt, Kopf und Ärmchen gestikulieren, ein paar Blätter fliegen.
func speak() -> void:
	if _state == State.FALLEN:
		return
	_speak_left = SPEAK_TIME
	_burst(_mouth_point(), 4, 1.2)


## Er murmelt `seconds` lang leise vor sich hin: nur der Kiefer klappert, ohne Gesten.
func mutter(seconds: float) -> void:
	if _state == State.FALLEN:
		return
	_mutter_left = seconds


## Ein Kriterium ist erfüllt: Stapel `index` reißt ab, fällt zu Boden und staubt, der
## Rambler zuckt zusammen und schrumpft ein Stück.
func drop_stack(index: int) -> void:
	if index < 0 or index >= _stacks.size() or _stacks[index]["dropped"]:
		return
	var entry := _stacks[index]
	entry["dropped"] = true
	var pivot: Node3D = entry["pivot"]
	# Er bleibt liegen, wo er fällt, und wandert nicht mit — und er schrumpft nicht mehr
	# mit dem Leib. Gefallen wird vorn; hinten wandert er weiter weg, durch sie nicht hindurch.
	pivot.reparent(self)
	var from := pivot.position
	var rest_y := STACK_HEIGHT * pivot.scale.y
	var forward := _boss.basis.z
	var land := Vector3(_boss.position.x + (from.x - _boss.position.x) * 1.15, rest_y, from.z) \
			+ forward * _rng.randf_range(0.25, 0.5) + Vector3(_rng.randf_range(-0.15, 0.15), 0.0, 0.0)
	var spin := Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.3, 0.3))
	var tw := create_tween()
	tw.tween_property(pivot, "position", land, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pivot, "rotation", pivot.rotation + spin, 0.45)
	tw.tween_callback(func():
		var ground := to_global(land)
		_dust(ground - Vector3(0.0, rest_y * 0.8, 0.0))
		_burst(ground, 6, 0.8)
		shake(0.05, 0.25))
	tw.tween_property(pivot, "position", land + Vector3(0, 0.06, 0), 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "position", land, 0.12).set_ease(Tween.EASE_IN)
	_update_rope()
	_flinch = 1.0
	_puff = -0.12
	_red_flash()
	shake(0.06, 0.3)
	_burst(_mouth_point(), 5, 1.4)


## Ein Kriterium ist nicht erfüllt: Stapel `index` wackelt kräftig — und hält.
func hold_stack(index: int) -> void:
	if index < 0 or index >= _stacks.size() or _stacks[index]["dropped"]:
		return
	_stacks[index]["wobble_v"] = 7.0 * (1.0 if _rng.randf() < 0.5 else -1.0)
	_puff = maxf(_puff, 0.05)


## Neuer Kampf: alle Stapel hängen wieder, er ist wieder groß und steht.
func restore_all() -> void:
	for entry in _stacks:
		var pivot: Node3D = entry["pivot"]
		if is_instance_valid(pivot):
			# Erst abhängen: der neue Stapel gleichen Namens soll ihn nicht mehr vorfinden.
			pivot.get_parent().remove_child(pivot)
			pivot.queue_free()
	_stacks.clear()
	for k in maxi(stack_count, 0):
		_stacks.append(_make_stack(k))
	_state = State.IDLE
	_fall_k = 0.0
	_speak_left = 0.0
	_gloat_left = 0.0
	_flinch = 0.0
	_puff = 0.0
	_size = 1.0
	_update_rope()


## Daneben: er bläht sich auf, wirft den Kopf zurück und lacht mit klappernden Deckeln.
func gloat() -> void:
	if _state == State.FALLEN:
		return
	_gloat_left = 1.6
	_puff = 0.16
	shake(0.03, 0.25)
	_burst(_mouth_point(), 6, 1.6)


## Besiegt: die übrigen Stapel fallen, er sackt in sich zusammen und bleibt liegen.
func fall() -> void:
	if _state == State.FALLEN:
		return
	for k in _stacks.size():
		drop_stack(k)
	_state = State.FALLEN
	_speak_left = 0.0
	_gloat_left = 0.0
	shake(0.14, 0.6)
	_dust(_boss.global_position + Vector3(0.0, 0.2, 0.6))
	_burst(_mouth_point(), 14, 2.0)


## Bebt die Kamera — `magnitude` in Metern, `duration` in Sekunden.
func shake(magnitude: float, duration: float) -> void:
	_shake_mag = maxf(_shake_mag if _shake_left > 0.0 else 0.0, magnitude)
	_shake_left = maxf(_shake_left, duration)


## Wo sein Maul gerade im Bild ist, in Canvas-Koordinaten des Viewports.
func mouth_on_screen() -> Vector2:
	var point := _mouth_point()
	if _camera.is_position_behind(point):
		return Vector2.INF
	return _camera.unproject_position(point)


## Ob er gerade bei einem Auftritt am Bildrand steht (dann ist er zu sehen).
func is_peeking() -> bool:
	return _peeking and not _front and _state != State.FALLEN


## Wie viele Stapel noch hängen.
func stacks_left() -> int:
	return _stacks.filter(func(e: Dictionary) -> bool: return not e["dropped"]).size()


func _process(delta: float) -> void:
	_time += delta
	_speak_left = maxf(_speak_left - delta, 0.0)
	_mutter_left = maxf(_mutter_left - delta, 0.0)
	_gloat_left = maxf(_gloat_left - delta, 0.0)
	_flinch = move_toward(_flinch, 0.0, delta * 1.8)
	_puff = move_toward(_puff, 0.0, delta * 0.25)
	_back_k = move_toward(_back_k, 0.0 if _front else 1.0, delta / FOCUS_TIME)
	_fall_k = move_toward(_fall_k, 1.0 if _state == State.FALLEN else 0.0, delta * 1.4)
	var dropped := _stacks.size() - stacks_left()
	var goal_size := 1.0 - SHRINK_TOTAL * (float(dropped) / maxf(float(_stacks.size()), 1.0))
	_size = move_toward(_size, goal_size, delta * 0.35)
	_move(delta)
	_body.scale = Vector3.ONE * _size * (1.0 + _puff)
	_pose(delta)
	_swing_stacks(delta)
	_flicker()
	_aim_camera(delta)


## Vorn: auf dem kürzesten Weg in die Mitte, dann zum Spieler gedreht. Hinten: wandern —
## ein Ziel im Feld WANDER, hingehen, stehen bleiben und schauen, ein neues Ziel.
func _move(delta: float) -> void:
	var walking := false
	if _state == State.FALLEN:
		pass
	elif _front:
		_rest_left = 0.0
		_goal = FRONT
		walking = _step_toward(FRONT, RUSH_SPEED, delta)
		if not walking:
			_yaw_goal = 0.0
	elif _rest_left > 0.0:
		_rest_left -= delta
		if _rest_left <= 0.0:
			_pick_goal()
	else:
		walking = _step_toward(_goal, WALK_SPEED, delta)
		if not walking and _peek_goal:
			_peeking = true
			_rest(_rng.randf_range(PEEK_REST.x, PEEK_REST.y))
			_yaw_goal = 0.0
		elif not walking:
			_rest(_rng.randf_range(REST_MIN, REST_MAX))
	_walk_k = move_toward(_walk_k, 1.0 if walking else 0.0, delta * 4.0)
	_boss.rotation.y = lerp_angle(_boss.rotation.y, _yaw_goal, clampf(TURN_RATE * delta, 0.0, 1.0))
	# Watscheln: ein kleines Hüpfen je Schritt.
	_boss.position.y = absf(sin(_time * 5.0)) * 0.07 * _walk_k


## Ein Stück auf `goal` zu (nur am Boden), zugewandt der Laufrichtung. false, wenn er da ist.
func _step_toward(goal: Vector3, speed: float, delta: float) -> bool:
	var at := Vector2(_boss.position.x, _boss.position.z)
	var to := Vector2(goal.x, goal.z) - at
	if to.length() < 0.05:
		return false
	_yaw_goal = atan2(to.x, to.y)
	# Erst drehen, dann gehen — sonst rutscht er seitwärts.
	var facing := absf(angle_difference(_boss.rotation.y, _yaw_goal))
	var step := minf(to.length(), speed * delta * clampf(1.4 - facing, 0.0, 1.0))
	at += to.normalized() * step
	_boss.position.x = at.x
	_boss.position.z = at.y
	return true


## Stehen bleiben: meist zum Spieler schauen, manchmal ein wenig zur Seite.
func _rest(seconds: float) -> void:
	_rest_left = seconds
	_yaw_goal = 0.0 if _rng.randf() < 0.65 else _rng.randf_range(-0.6, 0.6)


## Ein neues Ziel im Feld, deutlich weg vom jetzigen Platz — bevorzugt zur anderen Seite.
func _pick_goal() -> void:
	var goal := _goal
	# Meist auf die andere Bildhälfte, damit er nicht nur auf einer Seite auftaucht.
	var other := -signf(_boss.position.x) if absf(_boss.position.x) > 0.5 else (1.0 if _rng.randf() < 0.5 else -1.0)
	var was_peeking := _peeking
	_peeking = false
	_peek_goal = not was_peeking and _rng.randf() < PEEK_CHANCE
	if _peek_goal:
		_goal = Vector3(other * PEEK.x, 0.0, PEEK.y)
		return
	for i in 6:
		var x := _rng.randf_range(WANDER.position.x, WANDER.end.x)
		if _rng.randf() < 0.75:
			x = other * _rng.randf_range(1.0, WANDER.end.x)
		goal = Vector3(x, 0.0, _rng.randf_range(WANDER.position.y, WANDER.end.y))
		if absf(goal.x - _boss.position.x) > STRIDE_MIN:
			break
	_goal = goal


## Setzt Leib, Kopf, Flügel und Ärmchen für diesen Augenblick.
func _pose(delta: float) -> void:
	var t := _time
	# Hinten bewegt er sich leiser — das Overlay soll Ruhe haben.
	var calm := lerpf(1.0, 0.45, _back_k)
	var talk := clampf(_speak_left / 0.3, 0.0, 1.0) * clampf((SPEAK_TIME - _speak_left) / 0.15 + 0.2, 0.0, 1.0)
	var laugh := clampf(_gloat_left / 0.3, 0.0, 1.0)
	var pts: Array[Vector3] = []
	for i in SPINE.size():
		var p: Vector3 = (SPINE[i] as Vector3).lerp(SPINE_FALLEN[i], _fall_k)
		var h := float(i) / float(SPINE.size() - 1)
		var alive := 1.0 - _fall_k
		# Wiegen: oben mehr als unten, eine langsame Welle den Leib hinauf.
		p.x += sin(t * 0.8 - h * 1.6) * 0.09 * h * calm * alive
		p.z += sin(t * 0.55 + h) * 0.05 * h * calm * alive
		# Gehen: der Leib schwankt von Seite zu Seite.
		p.x += sin(t * 2.5) * 0.12 * h * _walk_k * alive
		# Atmen hebt Brust und Kopf ein wenig.
		p.y += sin(t * 1.6) * 0.03 * h * alive
		# Treffer: Kopf und Hals zucken zurück.
		p.z -= _flinch * 0.35 * h * h
		# Lachen: Kopf ein wenig in den Nacken.
		p.z -= laugh * 0.12 * h * h
		p.y += laugh * 0.08 * h
		pts.append(p)
	var breath := sin(t * 1.6) * 0.035
	for i in _rings.size():
		var u := float(i) / float(_rings.size() - 1)
		var pos := _catmull(pts, u)
		var ahead := _catmull(pts, minf(u + 0.02, 1.0))
		var behind := _catmull(pts, maxf(u - 0.02, 0.0))
		var tangent := (ahead - behind).normalized()
		var girth := _girth(u) * (1.0 + breath * sin(PI * u) + sin(t * 1.6 - u * 3.0) * 0.015)
		var ring := _rings[i]
		ring.transform = Transform3D(_frame(tangent), pos).scaled_local(Vector3(girth, girth * 0.9, girth))
	# Schwanzspitze: am ersten Punkt, in Verlängerung des Leibs.
	var tail_dir := (pts[0] - _catmull(pts, 0.04)).normalized()
	_tail.transform = Transform3D(_frame(tail_dir), pts[0] + tail_dir * 0.05).scaled_local(Vector3.ONE * 0.7)
	_tail.rotate_object_local(Vector3.UP, sin(t * 2.2) * 0.4 * calm)
	# Kopf: auf dem Genick, schaut zum Spieler, wiegt sich.
	var neck := pts[-1]
	var head_basis := Basis.from_euler(Vector3(
			0.22 + sin(t * 1.1) * 0.04 * calm - laugh * 0.28 + _flinch * 0.25 + talk * sin(t * 7.0) * 0.06,
			sin(t * 0.7) * 0.18 * calm + talk * sin(t * 3.3) * 0.12,
			sin(t * 0.9 + 1.0) * 0.1 * calm + _fall_k * 1.25))
	_head.transform = Transform3D(head_basis.scaled(Vector3.ONE * HEAD_SCALE), neck + Vector3(0, 0.08, 0))
	# Kiefer: Reden klappert, Lachen weit auf, im Hintergrund murmelt er vor sich hin.
	var mumble := maxf(sin(t * 0.9), 0.0) * absf(sin(t * 9.0)) * 0.12
	mumble = maxf(mumble, absf(sin(t * 10.0)) * 0.22 * clampf(_mutter_left / 0.3, 0.0, 1.0))
	var chatter := absf(sin(t * 11.0)) * 0.55 * talk
	var cackle := (0.45 + absf(sin(t * 16.0)) * 0.3) * laugh
	var open := maxf(maxf(mumble * (1.0 - talk), chatter), cackle)
	open = maxf(open, _fall_k * 0.5) + _flinch * 0.3
	_jaw.rotation = Vector3(open, 0.0, 0.0)
	# Flügel: an den Schultern, langsam blätternd; beim Reden und Lachen schneller.
	var shoulder := _catmull(pts, 0.72)
	var flap := sin(t * (1.4 + talk * 4.0 + laugh * 7.0)) * (0.12 + talk * 0.2 + laugh * 0.35) * (1.0 - _fall_k)
	var droop := _fall_k * 0.9
	for side: float in [-1.0, 1.0]:
		var wing := _wing_r if side > 0.0 else _wing_l
		wing.position = shoulder + Vector3(side * 0.45, 0.15, -0.25)
		wing.rotation = Vector3(0.0, side * (0.3 + flap * 0.6), side * (flap - droop))
		wing.scale = Vector3.ONE * 1.7
	# Ärmchen mit Federkiel: vorn an der Brust, beim Reden fuchteln sie.
	var chest := _catmull(pts, 0.74)
	for side: float in [-1.0, 1.0]:
		var arm := _arm_r if side > 0.0 else _arm_l
		var wave := sin(t * 6.0 + side) * 0.5 * talk + sin(t * 1.6 + side) * 0.05
		arm.position = chest + Vector3(side * _girth(0.74) * 0.9, -0.05, _girth(0.74) * 0.55)
		arm.rotation = Vector3(-0.5 - wave - laugh * 0.6 + _fall_k * 0.8, side * 0.5, side * (0.55 + laugh * 0.5))
		arm.scale = Vector3.ONE * 1.3
	# Die Schnur folgt dem Bauch.
	var belly := _catmull(pts, 0.45)
	_belt.position = Vector3(belly.x, BELT_HEIGHT + (belly.y - 1.1) * 0.6, belly.z)


## Basis mit y entlang `tangent` und z so weit wie möglich zum Spieler (+z): so zeigt die
## Rückenzacke der Ringe nach hinten.
func _frame(tangent: Vector3) -> Basis:
	var y := tangent.normalized()
	var z := (Vector3.BACK - y * y.dot(Vector3.BACK))
	if z.length_squared() < 1e-4:
		z = Vector3.UP - y * y.dot(Vector3.UP)
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func _girth(u: float) -> float:
	for i in GIRTH.size() - 1:
		var a: Vector2 = GIRTH[i]
		var b: Vector2 = GIRTH[i + 1]
		if u <= b.x:
			return lerpf(a.y, b.y, (u - a.x) / maxf(b.x - a.x, 0.001))
	return (GIRTH[-1] as Vector2).y


## Catmull-Rom über die Punkte, `u` von 0 bis 1 über die ganze Kette.
func _catmull(pts: Array[Vector3], u: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(u, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var s := f - i
	var p0 := pts[maxi(i - 1, 0)]
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p3 := pts[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s * s
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * s * s * s)


## Ein Punkt auf der Schnur bei `x` (Gürtel-Koordinaten): ein flaches Oval um den Bauch,
## vorn ein wenig tiefer durchhängend als an den Seiten. Hinter dem Bauch (|x| > BELT_HALF)
## läuft sie nach hinten weg.
func _belt_point(x: float) -> Vector3:
	var k := clampf(absf(x) / BELT_HALF, 0.0, 1.0)
	var front := sqrt(1.0 - k * k)
	return Vector3(x, -front * 0.1, front * BELT_DEPTH - maxf(absf(x) - BELT_HALF, 0.0))


## Wo Stapel `k` von `n` hängt (x auf der Schnur): gleichmäßig verteilt und mittig, damit
## man sie von vorn zählen kann.
func _hang_x(k: int, n: int) -> float:
	if n <= 1:
		return 0.0
	var gap := minf(STACK_GAP, 2.0 * BELT_SPAN / (n - 1))
	return (k - (n - 1) * 0.5) * gap


func _make_stack(k: int) -> Dictionary:
	var pivot := Node3D.new()
	pivot.name = "Stack%d" % k
	var x := _hang_x(k, stack_count)
	pivot.position = _belt_point(x)
	# Nur ein wenig mit dem Bauch gedreht: so bleiben auch die äußeren Stapel von vorn zählbar.
	pivot.rotation.y = asin(clampf(x / BELT_HALF, -1.0, 1.0)) * 0.4
	pivot.scale = Vector3.ONE * STACK_SCALE
	_belt.add_child(pivot)
	var stack := STACK_SCENE.instantiate() as Node3D
	stack.name = "Paper"
	pivot.add_child(stack)
	# Ein farbiger Zettel vorn am Stapel, damit man sie auseinanderhält und zählt.
	var tag := MeshInstance3D.new()
	tag.name = "Tag"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.15, 0.012)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TAG_COLORS[k % TAG_COLORS.size()]
	mat.roughness = 1.0
	mesh.material = mat
	tag.mesh = mesh
	tag.position = Vector3(0.0, -0.26, 0.175)
	tag.rotation.z = (_rng.randf() - 0.5) * 0.3
	pivot.add_child(tag)
	return {"pivot": pivot, "dropped": false, "wobble": 0.0, "wobble_v": 0.0,
			"phase": _rng.randf() * TAU}


## Die Stapel pendeln leise; ein gehaltener schwingt gedämpft aus.
func _swing_stacks(delta: float) -> void:
	for entry in _stacks:
		if entry["dropped"]:
			continue
		var w: float = entry["wobble"]
		var v: float = entry["wobble_v"]
		v += (-w * 60.0 - v * 3.0) * delta
		w += v * delta
		entry["wobble"] = w
		entry["wobble_v"] = v
		var pivot: Node3D = entry["pivot"]
		var idle := sin(_time * 1.6 + float(entry["phase"])) * 0.04
		pivot.rotation.x = idle + w * 0.6
		pivot.rotation.z = w + idle * 0.5


## Die Schnur: ein Bogen um den Bauch durch alle Aufhängepunkte, an beiden Enden ein
## Stück weiter, damit sie um den Leib zu laufen scheint.
func _update_rope() -> void:
	if _rope_material == null:
		_rope_material = StandardMaterial3D.new()
		_rope_material.albedo_color = Color(0.58, 0.43, 0.25)
		_rope_material.roughness = 1.0
	var pts: Array[Vector3] = []
	var steps := 14
	var reach := BELT_HALF + 0.3
	for k in steps + 1:
		pts.append(_belt_point(lerpf(-reach, reach, float(k) / steps)) + Vector3(0.0, 0.012, -0.02))
	while _rope.size() < steps:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = 1.0
		cyl.radial_segments = 5
		cyl.rings = 1
		cyl.material = _rope_material
		mi.mesh = cyl
		_belt.add_child(mi)
		_rope.append(mi)
	for k in steps:
		var a := pts[k]
		var b := pts[k + 1]
		var y := (b - a).normalized()
		var x := y.cross(Vector3.UP).normalized()
		var z := x.cross(y)
		_rope[k].transform = Transform3D(Basis(x, y, z).scaled_local(Vector3(1, a.distance_to(b) + 0.02, 1)),
				(a + b) * 0.5)


func _mouth_point() -> Vector3:
	return _head.global_transform * MOUTH


func _aim_camera(delta: float) -> void:
	# Das Ziel hängt am Platz, nicht an ihm: hinten folgt die Kamera ihm nicht.
	var goal := LOOK_FRONT.lerp(LOOK_BACK, _back_k * _back_k * (3.0 - 2.0 * _back_k))
	if _state == State.FALLEN:
		goal.y = lerpf(goal.y, 1.2, _fall_k)
	_look = _look.lerp(goal, clampf(delta * 3.0, 0.0, 1.0))
	var sway := Vector3(sin(_time * 0.7) * 0.03, sin(_time * 1.3) * 0.025, 0.0) * (1.0 - 0.6 * _back_k)
	var jolt := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		jolt = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake_mag
	_camera.look_at_from_position(_camera_home + sway + jolt, _look + jolt * 0.5)


func _flicker() -> void:
	var i := 0
	for light: OmniLight3D in _light_energy:
		var base: float = _light_energy[light]
		var wave := sin(_time * 8.0 + i * 1.7) * 0.5 + sin(_time * 19.0 + i * 3.1) * 0.3
		light.light_energy = base * (0.88 + 0.1 * wave)
		i += 1


## Flammen auf die Kerzen: an jeden Knoten „Wick…" unter Candles eine Fire-Flamme.
func _kindle_candles() -> void:
	for wick: Node in _candles.find_children("Wick*", "Node3D", true, false):
		var fire := Fire.new()
		fire.name = "Flame"
		(wick as Node3D).add_child(fire)


func _set_overlay(mat: Material) -> void:
	for mi in _boss.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


## Ein heller Blitz auf dem Leib — ein Treffer.
func _red_flash() -> void:
	_set_overlay(_flash)
	_flash.albedo_color.a = 0.6
	var tw := create_tween()
	tw.tween_property(_flash, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(_set_overlay.bind(null))


# --- Effekte ------------------------------------------------------------------------

## Lose Blätter, die langsam durch den Turm segeln.
func _air() -> CPUParticles3D:
	var p := _sheets(14, 16.0, Vector3(0.22, 0.3, 1.0))
	p.name = "Air"
	p.position = Vector3(0.0, 7.0, -5.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 0.5, 4.0)
	p.gravity = Vector3(0.0, -0.32, 0.0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.spread = 180.0
	p.preprocess = 16.0
	p.visibility_aabb = AABB(Vector3(-8, -8, -6), Vector3(16, 10, 12))
	return p


## Staub, der im warmen Licht schimmert — weiche Punkte, kein Würfel.
func _motes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Motes"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	if _mote_material == null:
		_mote_material = ShaderMaterial.new()
		_mote_material.shader = MOTE_SHADER
	quad.material = _mote_material
	p.mesh = quad
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(-1.0, 2.0, -4.5)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.5, 1.8, 2.5)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.gravity = Vector3(0, 0.02, 0)
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 0.8))
	ramp.add_point(0.7, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	p.visibility_aabb = AABB(Vector3(-5, -3, -4), Vector3(10, 7, 8))
	return p


func _sheets(amount: int, lifetime: float, size: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y)
	if _sheet_material == null:
		_sheet_material = ShaderMaterial.new()
		_sheet_material.shader = SHEET_SHADER
	quad.material = _sheet_material
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.particle_flag_rotate_y = true
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.08, Color(1, 1, 1, 1))
	ramp.add_point(0.85, Color(1, 1, 1, 1))
	p.color_ramp = ramp
	return p


## Ein Wirbel aus `amount` Blättern bei `at` (Weltkoordinaten); `power` die Wucht.
func _burst(at: Vector3, amount: int, power := 1.0) -> void:
	var p := _sheets(amount, 2.2, Vector3(0.18, 0.24, 1.0))
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0.6)
	p.spread = 70.0
	p.initial_velocity_min = 1.2 * power
	p.initial_velocity_max = 2.4 * power
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## Eine weiche Staubwolke am Boden bei `at`.
func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	if _dust_material == null:
		_dust_material = ShaderMaterial.new()
		_dust_material.shader = SMOKE_SHADER
		_dust_material.set_shader_parameter("ember", 0.0)
	quad.material = _dust_material
	p.mesh = quad
	p.amount = 10
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 90.0
	p.flatness = 0.7
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.78, 0.64, 0.7))
	ramp.set_color(1, Color(0.85, 0.78, 0.64, 0.0))
	p.color_ramp = ramp
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
