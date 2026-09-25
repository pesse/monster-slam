class_name BossStage
extends Node3D
## Die Bühne des Bosskampfs (scenes/battle/boss_stage.tscn): ein Gewölbe, ein Skelett darin
## und eine Kamera auf Augenhöhe des Spielers.
##
## Die Bühne spielt nur vor. Sie weiß nichts von Sätzen, Urteilen und HP — der Bosskampf
## sagt ihr, was geschehen ist (`hurt`, `gloat`, `fall` …), und sie zeigt es. Zwischen den
## Ereignissen lebt sie von selbst: das Skelett geht vor dem Spieler auf und ab und bleibt
## zwischendurch stehen und schaut ihn an, die Fackeln flackern, die Kamera atmet.
##
## Wo der Kopf des Skeletts gerade im Bild ist, sagt `mouth_on_screen()` — daran hängen die
## Spitzen der Sprechblasen.

## Hier steht das Skelett, wenn es gerade nicht geht. Links der Mitte, weil rechts im Bild
## die Blase mit der Erklärung steht.
const HOME := Vector3(-1.0, 0.0, -3.7)
## So weit geht es nach jeder Seite.
const PACE := 1.1
const WALK_SPEED := 0.8
## Wie schnell es sich umdreht (rad/s, weich über lerp_angle).
const TURN_RATE := 6.0
## Wie lange es stehen bleibt, bevor es weitergeht (s).
const REST_MIN := 1.5
const REST_MAX := 3.5
## Wie stark die Kamera dem Kopf folgt: 0 starr, 1 ganz. Ein wenig, damit sie lebt, aber
## nicht so viel, dass das Bild mitläuft.
const LOOK_FOLLOW := 0.3
## Wo der Mund über dem Kopf-Knochen liegt (Weltmeter).
const MOUTH_OFFSET := Vector3(0.0, 0.1, 0.0)
const GATE_Z := -11.0

const IDLE := &"general/Idle_A"
const LISTEN := &"general/Idle_B"
const WALK := &"move/Walking_B"
const LEAVE_WALK := &"move/Walking_A"
const HIT := &"general/Hit_A"
const HIT_HARD := &"general/Hit_B"
const GLOAT := &"move/Jump_Full_Short"
const WAKE := &"general/Spawn_Ground"
const DEATH := &"general/Death_A"

enum State { ROAM, LISTEN, FALLEN, GONE }

@onready var _boss: Node3D = %Boss
@onready var _model: Node3D = %Model
@onready var _camera: Camera3D = %Camera
@onready var _torches: Node3D = %Torches
@onready var _aura: CPUParticles3D = %Aura
@onready var _rune: Node3D = %Rune

var _anim: AnimationPlayer
var _head: Node3D
var _state := State.ROAM
## Eine einmalige Animation läuft (Treffer, Hüpfer, Erwachen) — solange steht das Skelett.
var _acting := false
var _goal_x := HOME.x
var _rest_left := 0.0
var _yaw_goal := 0.0
var _time := 0.0
var _shake_left := 0.0
var _shake_mag := 0.0
var _camera_home: Vector3
var _look := Vector3.ZERO
var _torch_energy: Dictionary = {}
var _flash: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_head = _model.find_child("head", true, false) as Node3D
	_anim = RigAnimations.attach_player(_model, {
		"general": RigAnimations.general(),
		"move": RigAnimations.movement(),
	})
	# Die Libraries sind geteilt (RigAnimations): Schleifen nur an dem, was ohnehin
	# schleift — Idle und Gehen, nie an einem Treffer oder am Sterben.
	for loop in [IDLE, LISTEN, WALK, LEAVE_WALK]:
		if _anim.has_animation(loop):
			_anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_on_animation_finished)
	_boss.position = HOME
	_camera_home = _camera.position
	_look = _head_point()
	for light in _torches.find_children("*", "OmniLight3D", true, false):
		_torch_energy[light] = (light as OmniLight3D).light_energy
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 0.25, 0.2, 0.0)
	_rest(REST_MIN)


## Das Skelett steigt aus dem Boden.
func wake() -> void:
	_state = State.ROAM
	_boss.visible = true
	_boss.position = HOME
	_yaw_goal = 0.0
	_boss.rotation.y = 0.0
	_act(WAKE)


## Es wartet auf das Urteil: bleibt stehen und schaut den Spieler an.
func listen() -> void:
	if _state == State.ROAM:
		_state = State.LISTEN
		_yaw_goal = 0.0


## Das Warten ist vorbei — es geht wieder.
func resume() -> void:
	if _state == State.LISTEN:
		_state = State.ROAM
		_rest(REST_MIN)


## Ein Treffer: es zuckt zurück, leuchtet rot auf, das Bild bebt. `hard` für den letzten.
func hurt(hard := false) -> void:
	if _state >= State.FALLEN:
		return
	resume()
	_yaw_goal = 0.0
	_act(HIT_HARD if hard else HIT)
	_red_flash()
	shake(0.12 if hard else 0.08, 0.35)
	var back := _boss.position + Vector3(0.0, 0.0, -0.5)
	var tw := create_tween()
	tw.tween_property(_boss, "position", back, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss, "position:z", HOME.z, 0.6).set_trans(Tween.TRANS_SINE).set_delay(0.2)
	_burst(Color(1.0, 0.85, 0.5), 0.35)


## Daneben: es freut sich, hüpft und kommt einen Schritt näher.
func gloat() -> void:
	if _state >= State.FALLEN:
		return
	resume()
	_yaw_goal = 0.0
	_act(GLOAT)
	shake(0.03, 0.25)


## Besiegt: es fällt, und es bleibt liegen.
func fall() -> void:
	_state = State.FALLEN
	_acting = true
	_yaw_goal = 0.0
	_anim.play(DEATH, 0.1)
	_red_flash()
	shake(0.18, 0.6)
	_burst(Color(0.75, 0.45, 1.0), 1.0)
	_aura.emitting = false


## Unbesiegt: es dreht sich um und geht durch das Tor davon.
func leave() -> void:
	_state = State.GONE
	_acting = false
	_yaw_goal = PI
	_anim.play(LEAVE_WALK, 0.3)


## Bebt die Kamera — `magnitude` in Metern, `duration` in Sekunden.
func shake(magnitude: float, duration: float) -> void:
	_shake_mag = maxf(_shake_mag if _shake_left > 0.0 else 0.0, magnitude)
	_shake_left = maxf(_shake_left, duration)


## Wo der Mund des Skeletts gerade im Bild ist, in Canvas-Koordinaten des Viewports.
func mouth_on_screen() -> Vector2:
	var point := _head_point() + MOUTH_OFFSET
	if _camera.is_position_behind(point):
		return Vector2.INF
	return _camera.unproject_position(point)


func _process(delta: float) -> void:
	_time += delta
	_move(delta)
	_boss.rotation.y = lerp_angle(_boss.rotation.y, _yaw_goal, clampf(TURN_RATE * delta, 0.0, 1.0))
	_rune.rotate_y(delta * 0.4)
	_flicker()
	_aim_camera(delta)


func _move(delta: float) -> void:
	match _state:
		State.GONE:
			if _boss.visible:
				_boss.position.z -= WALK_SPEED * 1.3 * delta
				if _boss.position.z < GATE_Z:
					_boss.visible = false
			return
		State.FALLEN, State.LISTEN:
			_play_loop(LISTEN if _state == State.LISTEN else &"")
			return
	if _acting:
		return
	if _rest_left > 0.0:
		_rest_left -= delta
		_yaw_goal = 0.0
		_play_loop(IDLE)
		if _rest_left <= 0.0:
			_pick_goal()
		return
	var dx := _goal_x - _boss.position.x
	if absf(dx) < 0.05:
		_rest(_rng.randf_range(REST_MIN, REST_MAX))
		return
	_yaw_goal = PI / 2.0 * signf(dx)
	_play_loop(WALK)
	_boss.position.x += signf(dx) * minf(absf(dx), WALK_SPEED * delta)


func _rest(seconds: float) -> void:
	_rest_left = seconds


func _pick_goal() -> void:
	var goal := HOME.x
	for i in 4:
		goal = HOME.x + _rng.randf_range(-PACE, PACE)
		if absf(goal - _boss.position.x) > 0.6:
			break
	_goal_x = goal


func _play_loop(anim_name: StringName) -> void:
	if anim_name.is_empty() or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.25)


func _act(anim_name: StringName) -> void:
	if not _anim.has_animation(anim_name):
		return
	_acting = true
	_anim.play(anim_name, 0.1)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == DEATH:
		return
	_acting = false
	if _state == State.ROAM:
		_rest(_rng.randf_range(REST_MIN, REST_MAX))


func _head_point() -> Vector3:
	if _head != null:
		return _head.global_position
	return _boss.global_position + Vector3(0.0, 2.6, 0.0)


func _aim_camera(delta: float) -> void:
	var rest_look := HOME + Vector3(0.0, 3.1, 0.0)
	var goal := rest_look.lerp(_head_point(), LOOK_FOLLOW) if _state != State.GONE else rest_look
	_look = _look.lerp(goal, clampf(delta * 2.0, 0.0, 1.0))
	# Atmen: ein langsames Heben und ein kleines Wiegen.
	var sway := Vector3(sin(_time * 0.7) * 0.03, sin(_time * 1.3) * 0.025, 0.0)
	var jolt := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		jolt = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake_mag
	_camera.look_at_from_position(_camera_home + sway + jolt, _look + jolt * 0.5)


func _flicker() -> void:
	var i := 0
	for light: OmniLight3D in _torch_energy:
		var base: float = _torch_energy[light]
		var wave := sin(_time * 9.0 + i * 1.7) * 0.5 + sin(_time * 23.0 + i * 3.1) * 0.3
		light.light_energy = base * (0.85 + 0.12 * wave)
		i += 1


func _red_flash() -> void:
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _flash
	_flash.albedo_color.a = 0.75
	var tw := create_tween()
	tw.tween_property(_flash, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(func():
		for mi in _model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null)


func _burst(color: Color, scale_factor: float) -> void:
	var fx := Explosion.new()
	fx.setup(color, scale_factor)
	add_child(fx)
	fx.global_position = _head_point() - Vector3(0.0, 1.0, 0.0)
