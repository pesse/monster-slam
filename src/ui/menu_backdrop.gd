class_name MenuBackdrop
extends Node3D
## Die Kulisse hinter dem Hauptmenü (scenes/ui/menu_backdrop.tscn): ein Lager am Waldrand,
## davor ein Skelett mit roter Kapuze, das auf der Stelle steht und atmet.
##
## Die Kulisse spielt nur vor und weiß nichts vom Menü. Aufgebaut ist sie im Editor; hier
## kommt nur dazu, was die gekauften Modelle nicht mitbringen: die Idle-Schleife, das
## Schwert in der Hand und die Farbe der Kapuze. Ab und zu schaut es sich um (Idle_B).

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
## Wie weit die Kamera schwebt (m) und wie langsam (s je Schwingung).
const SWAY := Vector3(0.12, 0.05, 0.0)
const SWAY_PERIOD := 11.0

@onready var _model: Node3D = %Model
@onready var _camera: Camera3D = %Camera

var _anim: AnimationPlayer
var _camera_home: Vector3
var _time := 0.0
var _look_left := LOOK_MIN
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_camera_home = _camera.position
	_anim = RigAnimations.attach_player(_model, {"general": RigAnimations.general()})
	# Die Library ist geteilt (RigAnimations): Idle schleift ohnehin, Idle_B hier nicht —
	# es läuft einmal und kehrt dann ins Idle zurück.
	if _anim.has_animation(IDLE):
		_anim.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
		_anim.play(IDLE)
	_anim.animation_finished.connect(func(_name: StringName) -> void: _anim.play(IDLE, 0.3))
	_tint_cloth()
	_arm()
	_look_left = _rng.randf_range(LOOK_MIN, LOOK_MAX)


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / SWAY_PERIOD
	_camera.position = _camera_home + Vector3(sin(phase) * SWAY.x, sin(phase * 2.0) * SWAY.y, 0.0)
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = _rng.randf_range(LOOK_MIN, LOOK_MAX)
		if _anim.has_animation(LOOK_AROUND) and _anim.current_animation == IDLE:
			_anim.play(LOOK_AROUND, 0.3)


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
