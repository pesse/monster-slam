class_name FirstPersonView
extends Node3D
## Die Ich-Sicht im Wellenkampf (Späher-Baum): der Spieler steht auf dem Feld statt über
## ihm, läuft mit WASD und sieht sich mit der Maus um. Sonst ändert sie am Kampf nichts —
## Monster, Wellen, Schwierigkeit und Auswertung sind dieselben. Die eine Regel, die sie
## dazubringt: eine Antwort trifft nur ein Monster, das im Bild ist (`sees`, geprüft im
## WaveRunner).
##
## Gelaufen wird nach der Wanduhr: `Engine.time_scale` gehört SlowMotion, und weder die
## Zeitlupe noch der Zeitraffer von „Schnell auflösen" sollen den Spieler mitnehmen.
## Während der Eingabe (AnswerInput.is_typing) gehören die Buchstaben dem Wort, und die
## Maus ist frei: die Zeit steht ohnehin, und so ist „Schnell auflösen" einen Klick entfernt.
##
## Die Maus ist nur im laufenden Kampf und außerhalb der Eingabe gefangen (`active`). Alt
## gibt sie auch dann frei, solange es gehalten wird: für die Hinweise.

## Grundtempo in Welteinheiten je Sekunde; `walk_speed` aus dem Baum legt Anteile darauf.
const BASE_SPEED := 6.0
const EYE_HEIGHT := 2.2
const LOOK_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(70.0)
## Blickweite: weiter reicht der Boden nicht (WaveRunner baut ihn für die Iso-Kamera).
## Der Nebel beginnt davor und hat die Farbe des Hintergrunds — so endet die Welt im Dunst
## statt an einer Kante.
const FOG_BEGIN := 24.0
const FOG_END := 60.0
## Sturmangriff: so schnell rast der Spieler auf das getroffene Monster zu, so weit davor
## kracht er hinein, und so weit reißt das Blickfeld dabei auf. Die Dauer ist gedeckelt:
## ein Anlauf über das halbe Feld soll ein Ruck sein, keine Reise.
const CHARGE_SPEED := 45.0
const CHARGE_STOP := 2.5
const CHARGE_MIN_TIME := 0.12
const CHARGE_MAX_TIME := 0.45
const CHARGE_FOV_KICK := 18.0
## Bogen: so schnell fliegt der Pfeil, so hoch steigt seine Bahn (Anteil der Strecke), und
## die Flugzeit ist gedeckelt wie der Anlauf. Größer als in der Hand, sonst sähe man ihn
## über das Feld nicht fliegen.
const ARROW_SPEED := 38.0
const ARROW_MIN_TIME := 0.1
const ARROW_MAX_TIME := 0.55
const ARROW_LIFT := 0.04
const ARROW_SCALE := 3.0
## Ein Treffer fliegt schneller und fast gerade — er soll Wucht haben; der Fehlschuss
## behält seinen Bogen. Beim Abschuss zuckt das Blickfeld kurz auf.
const HIT_SPEED := 75.0
const HIT_MAX_TIME := 0.32
const HIT_LIFT := 0.004
const HIT_FOV_KICK := 6.0
## Ein Fehlschuss geht so weit neben dem Monster vorbei (und etwas darüber) und fliegt so
## weit hinter ihm weiter, bis er im Boden steckt.
const MISS_WIDE := 1.8
const MISS_HIGH := 0.6
const MISS_OVERSHOOT := 4.0
## Ohne Monster im Bild: so weit geradeaus.
const MISS_BLIND := 22.0

## Was ein Treffer in der Ich-Sicht tut. NONE: das Monster platzt, wo es ist.
enum Weapon { NONE, CHARGE, BOW }

## Die zuletzt gewählte Waffe, über Kämpfe hinweg — aber nicht gespeichert: eine Vorliebe
## der Sitzung, kein Ursprungswert.
static var _preferred := Weapon.BOW

## Der Späherblick ist gelernt.
static func unlocked(bonuses: Dictionary) -> bool:
	return float(bonuses.get("first_person", 0.0)) > 0.0


## Der Sturmangriff ist gelernt.
static func charges_for(bonuses: Dictionary) -> bool:
	return float(bonuses.get("charge", 0.0)) > 0.0


## Der Bogen ist gelernt.
static func bows_for(bonuses: Dictionary) -> bool:
	return float(bonuses.get("bow", 0.0)) > 0.0


## Die gelernten Waffen, in der Reihenfolge, in der Tab sie durchgeht.
static func weapons_for(bonuses: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if bows_for(bonuses):
		out.append(Weapon.BOW)
	if charges_for(bonuses):
		out.append(Weapon.CHARGE)
	return out


## Welche Waffe nach `current` kommt (Tab). Mit weniger als zwei bleibt es, wie es ist.
static func next_weapon(weapons: Array[int], current: int) -> int:
	if weapons.is_empty():
		return Weapon.NONE
	var at := weapons.find(current)
	return weapons[(at + 1) % weapons.size()]


## Die Flugzeit eines Pfeils über `distance`.
static func arrow_time(distance: float, speed: float = ARROW_SPEED,
		longest: float = ARROW_MAX_TIME) -> float:
	return clampf(distance / speed, ARROW_MIN_TIME, longest)


## Wo ein Fehlschuss landet: an `target` vorbei auf der Seite `side` (±1), etwas darüber,
## und auf derselben Linie weiter, bis er MISS_OVERSHOOT dahinter im Boden (y = `ground`)
## steckt.
static func miss_end(from: Vector3, target: Vector3, side: float, ground: float = 0.0) -> Vector3:
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var right := Vector3(-flat.z, 0.0, flat.x)
	var past := target + right * signf(side) * MISS_WIDE + Vector3.UP * MISS_HIGH
	var dir := Vector3(past.x - from.x, 0.0, past.z - from.z).normalized()
	var reach := Vector2(past.x - from.x, past.z - from.z).length() + MISS_OVERSHOOT
	var end := from + dir * reach
	return Vector3(end.x, ground, end.z)


## Welcher der Punkte am nächsten an der Bildmitte liegt — der kleinste Winkel zur
## Blickrichtung. -1 ohne Punkte. Darauf zielt ein Fehlschuss: es gibt kein Fadenkreuz,
## und eine falsche Antwort gehört zu keinem Monster.
static func nearest_to_view(eye: Vector3, forward: Vector3, points: Array[Vector3]) -> int:
	var best := -1
	var best_dot := -INF
	for i in points.size():
		var to := points[i] - eye
		if to.length_squared() < 0.0001:
			continue
		var d := forward.normalized().dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = i
	return best


## Wo der Anlauf endet: auf der Linie zum Ziel, CHARGE_STOP davor, im Feld. Steht der
## Spieler schon näher, bleibt er, wo er ist.
static func charge_end(from: Vector3, target: Vector3, field: Rect2) -> Vector3:
	var to := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist := to.length()
	if dist <= CHARGE_STOP:
		return from
	return clamp_to(field, from + to / dist * (dist - CHARGE_STOP))


## Der Gierwinkel, unter dem man von `from` auf `target` blickt (vorwärts ist -z).
static func yaw_towards(from: Vector3, target: Vector3) -> float:
	return atan2(-(target.x - from.x), -(target.z - from.z))


## Tempo mit den Boni des Baums — eine Summe auf das Grundtempo, wie jeder Skill.
static func speed_for(bonuses: Dictionary) -> float:
	return BASE_SPEED * (1.0 + maxf(0.0, float(bonuses.get("walk_speed", 0.0))))


## Ist der Punkt im Bild dieser Kamera? Das ist „sichtbar" im Sinne der Trefferregel:
## im Blickfeld, nicht unbedingt unverdeckt — die Prompt-Schilder stehen ohnehin über allem.
static func sees(camera: Camera3D, point: Vector3) -> bool:
	return camera.is_position_in_frustum(point)


## Die Laufrichtung in der Welt aus Tasten (x = rechts, y = vorwärts) und Blickrichtung.
## Nur der Gierwinkel zählt: wer nach oben sieht, läuft nicht in die Luft.
static func walk_direction(input: Vector2, yaw: float) -> Vector3:
	if input.is_zero_approx():
		return Vector3.ZERO
	var v := input.normalized()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return (right * v.x + forward * v.y).normalized()


## Hält eine Position (x/z) im Feld.
static func clamp_to(bounds: Rect2, pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, bounds.position.x, bounds.end.x), pos.y,
			clampf(pos.z, bounds.position.y, bounds.end.y))


@onready var camera: Camera3D = $Camera

## Die Kampfeingabe — solange in ihr getippt wird, steht der Spieler.
var answer_input: Node = null
var speed := BASE_SPEED
## Die gelernten Waffen (weapons_for) und die gewählte; Tab wechselt (`switch_weapon`).
var weapons: Array[int] = []:
	set(value):
		weapons = value
		weapon = _preferred if _preferred in weapons else (weapons[0] if not weapons.is_empty() else Weapon.NONE)
var weapon := Weapon.NONE:
	set(value):
		weapon = value
		if _bow != null:
			_bow.visible = weapon == Weapon.BOW
## Begehbare Fläche in x/z.
var bounds := Rect2(-10.0, -25.0, 20.0, 30.0)

var _active := false
var _yaw := 0.0
var _pitch := deg_to_rad(-8.0)
var _last_usec := 0
var _base_fov := 70.0
var _charge: Tween = null
var _bow: Bow = null


func _ready() -> void:
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.make_current()
	_base_fov = camera.fov
	_apply_look()
	_last_usec = Time.get_ticks_usec()
	_bow = Bow.new()
	_bow.visible = weapon == Weapon.BOW
	camera.add_child(_bow)
	EventBus.typing_activity.connect(_bow.pull)


## Tab: die nächste gelernte Waffe. Gemerkt für den nächsten Kampf.
func switch_weapon() -> void:
	weapon = next_weapon(weapons, weapon)
	_preferred = weapon


## Im laufenden Kampf an, wenn Statistik, Auflösung oder Rückfrage die Maus brauchen aus.
func set_active(on: bool) -> void:
	_active = on
	_update_mouse()


func is_active() -> bool:
	return _active


## Wackeln in der Bildebene. Die Iso-Kamera verschiebt dafür ihre Position; hier geht das
## über die Bildverschiebung, damit der Blick selbst nicht wandert.
func shake(offset: Vector2) -> void:
	camera.h_offset = offset.x
	camera.v_offset = offset.y


## Rast auf `target` zu und kehrt zurück, wenn der Spieler hineingekracht ist — der Aufrufer
## lässt das Monster erst dann platzen. Nach der Wanduhr wie das Laufen (die Zeitlupe endet
## zwar mit dem Abschicken, aber ihre Rampe soll den Ruck nicht dämpfen); in der Pause der
## Meister-Feier steht er mit allem anderen. Kommt ein zweiter Treffer, während der erste
## noch läuft, springt der erste ans Ziel: jedes Monster platzt, keins wartet ewig.
func charge_at(target: Vector3) -> void:
	if _charge != null and _charge.is_valid() and _charge.is_running():
		# Vorher loslassen: der alte Anlauf soll das Blickfeld nicht zurückstellen, während
		# der neue es aufreißt.
		var old := _charge
		_charge = null
		old.custom_step(CHARGE_MAX_TIME * 2.0)
	var end := charge_end(position, target, bounds)
	var time := clampf(position.distance_to(end) / CHARGE_SPEED, CHARGE_MIN_TIME, CHARGE_MAX_TIME)
	var yaw_goal := _yaw + wrapf(yaw_towards(position, target) - _yaw, -PI, PI)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	_charge = tw
	tw.tween_property(self, "position", end, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_yaw, _yaw, yaw_goal, time * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "fov", _base_fov + CHARGE_FOV_KICK, time).set_ease(Tween.EASE_IN)
	await tw.finished
	if _charge == tw:
		_charge = null
		create_tween().set_ignore_time_scale(true).tween_property(camera, "fov", _base_fov, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_charging() -> bool:
	return _charge != null


## Schießt einen Pfeil auf `target` und kehrt zurück, wenn er dort ist — der Aufrufer lässt
## das Monster dann platzen. Der Pfeil geht mit dem Monster.
func shoot_at(target: Vector3) -> void:
	var arrow := await _loose(target)
	arrow.queue_free()


## Ein Fehlschuss: an `target` vorbei (seitlich zufällig) und dahinter in den Boden. Ohne
## Ziel (kein Monster im Bild) geradeaus. Kehrt zurück, wenn er steckt.
func shoot_past(target: Variant) -> void:
	var from := _bow.release().origin if _bow != null else camera.global_position
	var end: Vector3
	if target is Vector3:
		end = miss_end(from, target, -1.0 if randf() < 0.5 else 1.0)
	else:
		var forward := -camera.global_basis.z
		forward = Vector3(forward.x, 0.0, forward.z).normalized()
		end = Vector3(from.x, 0.0, from.z) + forward * MISS_BLIND
	# Die Nocke landet über dem Boden, die Spitze steckt darin.
	end.y += Arrow.LENGTH * ARROW_SCALE * 0.45
	var arrow := await _fly(from, end)
	arrow.stick()


func _loose(target: Vector3) -> Arrow:
	if _bow != null and _bow.visible:
		_bow.swing_to(target)
		# Ein Timer und nicht das Ende des Schwenks: den kann ein Senken abbrechen, und ein
		# nie endendes await hielte das Wellenende fest. Er steht in der Pause mit allem.
		await get_tree().create_timer(Bow.SWING_TIME, false, false, true).timeout
	var from := _bow.release().origin if _bow != null else camera.global_position
	# Die Nocke hält vor dem Ziel an, sonst ragte der Pfeil vor dem Knall hinten heraus.
	var back := (from - target).normalized() * Arrow.LENGTH * ARROW_SCALE * 0.5
	var kick := create_tween().set_ignore_time_scale(true)
	kick.tween_property(camera, "fov", _base_fov + HIT_FOV_KICK, 0.04).set_ease(Tween.EASE_OUT)
	kick.tween_property(camera, "fov", _base_fov, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return await _fly(from, target + back, HIT_LIFT, HIT_SPEED, HIT_MAX_TIME)


func _fly(from: Vector3, to: Vector3, lift: float = ARROW_LIFT, speed: float = ARROW_SPEED,
		longest: float = ARROW_MAX_TIME) -> Arrow:
	var arrow := Arrow.new()
	arrow.trail = true
	arrow.scale = Vector3.ONE * ARROW_SCALE
	get_parent().add_child(arrow)
	arrow.global_position = from
	if absf((to - from).normalized().y) < 0.99:
		arrow.look_at(to, Vector3.UP)
	var distance := from.distance_to(to)
	await arrow.fly(to, distance * lift, arrow_time(distance, speed, longest))
	return arrow


func _set_yaw(value: float) -> void:
	_yaw = value
	_apply_look()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Tab wechselt die Waffe, auch bei offener Eingabe (dort hieße es sonst: nächstes Feld).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	if not _active or weapons.size() < 2:
		return
	get_viewport().set_input_as_handled()
	switch_weapon()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_yaw -= motion.relative.x * LOOK_SENSITIVITY
	_pitch = clampf(_pitch - motion.relative.y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	_apply_look()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# Gedeckelt wie SceneZoom: der erste Frame eines Kampfs baut die Welt und dauert lang.
	var real_delta := minf(float(now - _last_usec) / 1_000_000.0, 0.1)
	_last_usec = now
	_update_mouse()
	if _bow != null and not get_tree().paused:
		_bow.set_raised(_typing() and weapon == Weapon.BOW)
	if not _active or _typing() or is_charging() or get_tree().paused:
		return
	var dir := walk_direction(_key_input(), _yaw)
	if dir == Vector3.ZERO:
		return
	position = clamp_to(bounds, position + dir * speed * real_delta)


func _typing() -> bool:
	return answer_input != null and answer_input.has_method("is_typing") \
			and bool(answer_input.call("is_typing"))


## Physische Tasten: auf QWERTZ und AZERTY liegen W/A/S/D an derselben Stelle.
static func _key_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	return v


## Gefangen nur, wenn gelaufen und umgesehen wird — zum Tippen und mit Alt ist sie frei.
func mouse_captured() -> bool:
	return _active and not _typing() and not Input.is_key_pressed(KEY_ALT)


func _update_mouse() -> void:
	var want := Input.MOUSE_MODE_CAPTURED if mouse_captured() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _apply_look() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	camera.rotation = Vector3(_pitch, 0.0, 0.0)
