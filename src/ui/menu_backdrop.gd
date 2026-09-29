class_name MenuBackdrop
extends Node3D
## Die Kulisse hinter dem Hauptmenü (scenes/ui/menu_backdrop.tscn): ein Lager am Waldrand,
## davor ein Skelett mit roter Kapuze, das steht und atmet und ab und zu zum Marktstand
## hinübergeht.
##
## „Wer spielt?", das Hauptmenü und die Bibliothek stehen in derselben Kulisse: schiebt
## profile_menu die Seite weiter, fährt die Kamera mit (`page`) — vom Waldrand links hinüber
## zum Skelett und weiter nach rechts durch die Mauer in den Turm mit der Bibliothek
## (`%Library`, library_room.tscn). Dort steht sie, wo der Raum sie haben will (`%Eye`).
##
## Die Kulisse spielt nur vor und weiß nichts vom Menü. Aufgebaut ist sie im Editor; hier
## kommt nur dazu, was die gekauften Modelle nicht mitbringen: die Idle-Schleife, das
## Schwert in der Hand und die Farbe der Kapuze. Ab und zu schaut es sich um (Idle_B), seltener
## geht es hinüber zum Marktstand und kommt wieder zurück (`_stroll`) — immer an seinen
## Platz und mit dem Blick nach vorn, so bleibt das Bild des Menüs, wie es gebaut ist.

const IDLE := &"general/Idle_A"
const LOOK_AROUND := &"general/Idle_B"
const SWORD := preload("res://assets/models/forge/sword.glb")
## Die Klinge zeigt im Modell nach +y; so gedreht steht sie in der Hand schräg nach oben.
const SWORD_TURN := Vector3(-PI / 4.0, 0.0, PI / 8.0)
## Kapuze und Umhang des Rogue — ihre Textur ist grau-violett, der Entwurf will Rot.
const CLOTH_MESHES := ["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"]
const CLOTH_TINT := Color(1.0, 0.22, 0.2)
## Die Augen glühen im Entwurf rot statt gelb.
const EYES_MESH := "Skeleton_Rogue_Eyes"
const EYES_GLOW := Color(1.0, 0.18, 0.08)
## Pause zwischen zwei Umschauen (s).
const LOOK_MIN := 7.0
const LOOK_MAX := 13.0
const WALK := &"move/Walking_A"
## Pause zwischen zwei Spaziergängen (s).
const STROLL_MIN := 14.0
const STROLL_MAX := 26.0
## Der erste Gang kommt bald nach dem Start: dann steht „Wer spielt?" im Bild, und das
## Skelett soll eine Chance haben, dort hineinzulaufen.
const FIRST_STROLL_MIN := 3.0
const FIRST_STROLL_MAX := 6.0
## Der Weg zum Marktstand, in Koordinaten der Kulisse: an den Felsen vorbei vor die
## Theke. Der letzte Punkt liegt schon im Bild von „Wer spielt?" (Kamera um `intro_offset`
## versetzt) — das Skelett geht dorthin hinüber, wo die Profilwahl steht. Zurück denselben
## Weg. Wer Felsen oder Stand verschiebt, prüft den Weg (menu_lab).
const STALL_ROUTE: Array[Vector3] = [Vector3(0.2, 0.0, -0.9), Vector3(-1.4, 0.0, -2.4)]
## Wie schnell es geht (m/s) und sich dreht (rad/s).
const STROLL_SPEED := 0.8
const TURN_SPEED := 4.0
## Wie weit die Kamera schwebt (m) und wie langsam (s je Schwingung).
const SWAY := Vector3(0.12, 0.05, 0.0)
const SWAY_PERIOD := 11.0

## Drinnen im Turm: kein Dunst, warmes Licht statt Himmelsblau. Die Kulisse blendet dahin
## über, während die Kamera hineinfährt (`_light_for`).
const INDOOR_AMBIENT := Color(0.62, 0.48, 0.38)
const INDOOR_SKY_CONTRIBUTION := 0.25
const INDOOR_SUN := 0.8

## Wo die Kamera für „Wer spielt?" steht, gemessen an ihrem Platz fürs Hauptmenü: so weit
## links, dass das Skelett außerhalb des Bildes bleibt — die Profilwahl hat keine Figur,
## außer es ist gerade zum Marktstand hinübergegangen (`STALL_ROUTE`).
@export var intro_offset := Vector3(-4.5, 0.0, 0.0)
## 0 = „Wer spielt?", 1 = Hauptmenü, 2 = Bibliothek, dazwischen die Fahrt.
var page := 1.0
## Solange gesetzt, rührt die Kulisse die Kamera nicht an — die Bibliothek fliegt sie dann
## selbst in ein Buch hinein.
var hold_camera := false

@onready var _model: Node3D = %Model
@onready var _monster: Node3D = %Monster
@onready var _camera: Camera3D = %Camera
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment
@onready var _sun: DirectionalLight3D = $Sun

var _anim: AnimationPlayer
var _camera_home: Transform3D
var _time := 0.0
var _look_left := LOOK_MIN
var _rng := RandomNumberGenerator.new()
## Das Licht draußen, wie es in der Szene steht.
var _outdoor := {}
## Der Platz des Skeletts, wie er in der Szene steht, und sein Blick dort.
var _home := Vector3.ZERO
var _home_yaw := 0.0
var _stroll_left := STROLL_MAX
## Die Wegpunkte des laufenden Spaziergangs (hin, zurück); leer = es steht.
var _route: Array[Vector3] = []
## Am Ziel schaut es sich einmal um, bevor es zurückgeht.
var _looking := false


func _ready() -> void:
	_rng.randomize()
	_camera_home = _camera.transform
	# Eigene Kopie: die geladene Umgebung bliebe sonst über den Szenenwechsel hinweg verstellt.
	_env = _env.duplicate()
	($WorldEnvironment as WorldEnvironment).environment = _env
	_outdoor = {"fog": _env.fog_density, "ambient": _env.ambient_light_color,
			"sky": _env.ambient_light_sky_contribution, "sun": _sun.light_energy}
	_anim = RigAnimations.attach_player(_model, {"general": RigAnimations.general(),
			"move": RigAnimations.movement()})
	if _anim.has_animation(WALK):
		_anim.get_animation(WALK).loop_mode = Animation.LOOP_LINEAR
	# Die Library ist geteilt (RigAnimations): Idle schleift ohnehin, Idle_B hier nicht —
	# es läuft einmal und kehrt dann ins Idle zurück.
	if _anim.has_animation(IDLE):
		_anim.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
		_anim.play(IDLE)
	_anim.animation_finished.connect(func(_name: StringName) -> void: _anim.play(IDLE, 0.3))
	_tint_cloth()
	_arm()
	_look_left = _rng.randf_range(LOOK_MIN, LOOK_MAX)
	_home = _monster.position
	_home_yaw = _monster.rotation.y
	_stroll_left = _rng.randf_range(FIRST_STROLL_MIN, FIRST_STROLL_MAX)


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / SWAY_PERIOD
	_light_for(page)
	if not hold_camera:
		var view := view_at(page)
		view.origin += Vector3(sin(phase) * SWAY.x, sin(phase * 2.0) * SWAY.y, 0.0)
		_camera.transform = view
	_stroll(delta)
	if not _route.is_empty():
		return
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = _rng.randf_range(LOOK_MIN, LOOK_MAX)
		if _anim.has_animation(LOOK_AROUND) and _anim.current_animation == IDLE:
			_anim.play(LOOK_AROUND, 0.3)


## Ab und zu ein Gang: zum Marktstand, dort einmal umschauen, und zurück. Es dreht sich
## zuerst in die Richtung und geht erst los, wenn es ungefähr dorthin schaut; zurück am
## Platz dreht es sich wieder nach vorn.
func _stroll(delta: float) -> void:
	if _route.is_empty():
		if _anim.current_animation != IDLE and _anim.current_animation != LOOK_AROUND:
			return
		_turn_to(_home_yaw, delta)
		_stroll_left -= delta
		if _stroll_left <= 0.0 and _anim.current_animation == IDLE and _anim.has_animation(WALK):
			_stroll_left = _rng.randf_range(STROLL_MIN, STROLL_MAX)
			_route = STALL_ROUTE.duplicate()
			var back := STALL_ROUTE.slice(0, -1)
			back.reverse()
			_route.append_array(back)
			_route.append(_home)
		return
	if _looking:
		_looking = _anim.current_animation != IDLE
		return
	var to := _route[0] - _monster.position
	to.y = 0.0
	if to.length() < 0.03:
		_monster.position = Vector3(_route[0].x, _monster.position.y, _route[0].z)
		var reached: Vector3 = _route.pop_front()
		if _route.is_empty():
			_anim.play(IDLE, 0.3)
		elif reached == STALL_ROUTE.back() and _anim.has_animation(LOOK_AROUND):
			_anim.play(LOOK_AROUND, 0.3)
			_looking = true
		return
	var facing := _turn_to(atan2(to.x, to.z), delta)
	if facing < 0.35:
		if _anim.current_animation != WALK:
			_anim.play(WALK, 0.25)
		_monster.position += to.normalized() * minf(to.length(), STROLL_SPEED * delta)


## Dreht das Skelett ein Stück zu `yaw` hin; gibt den Winkel zurück, der noch fehlt.
func _turn_to(yaw: float, delta: float) -> float:
	var left := angle_difference(_monster.rotation.y, yaw)
	_monster.rotation.y = wrapf(_monster.rotation.y
			+ clampf(left, -TURN_SPEED * delta, TURN_SPEED * delta), -PI, PI)
	return absf(left)


## Wo die Kamera bei `at` steht (ohne Schweben), im Raum der Kulisse.
func view_at(at: float) -> Transform3D:
	if at <= 1.0:
		return Transform3D(_camera_home.basis, _camera_home.origin + intro_offset * (1.0 - at))
	var library := (%Library as Node3D).transform * (%Library.get_node("%Eye") as Node3D).transform
	return _camera_home.interpolate_with(library, clampf(at - 1.0, 0.0, 1.0))


## Draußen (bis zum Menü) das Licht der Szene, zur Bibliothek hin das von drinnen.
func _light_for(at: float) -> void:
	var t := smoothstep(1.3, 1.9, at)
	_env.fog_density = lerpf(float(_outdoor["fog"]), 0.0, t)
	_env.ambient_light_color = (_outdoor["ambient"] as Color).lerp(INDOOR_AMBIENT, t)
	_env.ambient_light_sky_contribution = lerpf(float(_outdoor["sky"]), INDOOR_SKY_CONTRIBUTION, t)
	_sun.light_energy = lerpf(float(_outdoor["sun"]), INDOOR_SUN, t)


func camera() -> Camera3D:
	return _camera


## Hier stellt die Bibliothek ihre Bücher auf.
func library_books() -> Node3D:
	return %Library.get_node("%Books") as Node3D


## Eigene Kopie des Materials — das geladene teilen alle Rogues im Kampf.
func _tint_cloth() -> void:
	for mesh_name in CLOTH_MESHES:
		var mi := _model.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var tinted := mat.duplicate() as StandardMaterial3D
		tinted.albedo_color = CLOTH_TINT
		mi.material_override = tinted
	var eyes := _model.find_child(EYES_MESH, true, false) as MeshInstance3D
	if eyes != null and eyes.get_active_material(0) is StandardMaterial3D:
		var glow := (eyes.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		glow.albedo_color = EYES_GLOW
		glow.emission_enabled = true
		glow.emission = EYES_GLOW
		glow.emission_energy_multiplier = 2.0
		eyes.material_override = glow


func _arm() -> void:
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone("handslot.r") < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.bone_name = "handslot.r"
	skeleton.add_child(slot)
	var sword := SWORD.instantiate() as Node3D
	sword.rotation = SWORD_TURN
	slot.add_child(sword)
