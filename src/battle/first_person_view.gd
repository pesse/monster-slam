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

## Der Späherblick ist gelernt.
static func unlocked(bonuses: Dictionary) -> bool:
	return float(bonuses.get("first_person", 0.0)) > 0.0


## Der Sturmangriff ist gelernt.
static func charges_for(bonuses: Dictionary) -> bool:
	return float(bonuses.get("charge", 0.0)) > 0.0


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
## Sturmangriff bei jedem Treffer (Späher-Baum)?
var charges := false
## Begehbare Fläche in x/z.
var bounds := Rect2(-10.0, -25.0, 20.0, 30.0)

var _active := false
var _yaw := 0.0
var _pitch := deg_to_rad(-8.0)
var _last_usec := 0
var _base_fov := 70.0
var _charge: Tween = null


func _ready() -> void:
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.make_current()
	_base_fov = camera.fov
	_apply_look()
	_last_usec = Time.get_ticks_usec()


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


func _set_yaw(value: float) -> void:
	_yaw = value
	_apply_look()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
