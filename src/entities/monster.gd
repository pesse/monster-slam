class_name Monster
extends Node3D
## Ein normales Monster in 3D: trägt eine aufgelöste Aufgabe (schwebendes Label3D
## mit dem Prompt) und bewegt sich entlang +Z auf die Festung zu. Präsentation +
## Bewegung; Kampf-/Wellenlogik liegt im WaveRunner. Das Monster kennt die Aufgabe
## nur als { prompt, accepted_answers, learnable_id, ... } (siehe TaskResolver).

## Wird ausgelöst, wenn dieses Monster die Festung erreicht (Node-Handling im WaveRunner).
signal reached_goal(monster: Monster)

var monster_def: Dictionary = {}
var task: Dictionary = {}

## Aus der monster_task_rule abgeleitet und vom WaveGenerator gesetzt.
var damage: int = 10
var reward: int = 10

## Zeitpunkt des Spawns (ms) für die Antwortzeit-Messung; vom WaveRunner gesetzt.
var spawned_at_ms: int = 0

var _speed: float = 2.0
var _target_z: float = 0.0
var _done: bool = false

@onready var _label: Label3D = $Label
@onready var _placeholder: MeshInstance3D = $Placeholder


## Muss VOR add_child aufgerufen werden, damit _ready Label/Modell korrekt setzt.
## `speed_units` ist die vom WaveGenerator aus der Schwierigkeit (Grundschwierigkeit
## der Aufgabe + Confidence + Wellenfaktor) berechnete Geschwindigkeit; sie wird hier
## auf 3D-Einheiten/s heruntergerechnet. Geschwindigkeit IST Schwierigkeit — das Monster
## selbst trägt kein eigenes Tempo mehr.
func setup(def: Dictionary, task_data: Dictionary, target_z: float, speed_units: float) -> void:
	monster_def = def
	task = task_data
	_speed = speed_units / 20.0
	_target_z = target_z


func _ready() -> void:
	_label.text = str(task.get("prompt", "?"))
	_apply_model()


## Lädt das 3D-Modell aus dem "model"-Feld (GLTF/GLB/scn). Fehlt es oder existiert
## die Datei (noch) nicht, bleibt das Platzhalter-Mesh sichtbar.
## Optionale JSON-Felder: "model_scale" (Standard 1.0) und "model_yaw" (Grad,
## um das Modell in Laufrichtung zu drehen).
func _apply_model() -> void:
	var path := str(monster_def.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	var inst := packed.instantiate() as Node3D
	inst.scale = Vector3.ONE * float(monster_def.get("model_scale", 1.0))
	inst.rotation_degrees.y = float(monster_def.get("model_yaw", 0.0))
	add_child(inst)
	_placeholder.visible = false
	_setup_animation(inst)


## KayKit-Charaktere haben keine eigenen Animationen — diese liegen in einer
## separaten Rig-Datei mit identischem "Rig_Medium/Skeleton3D"-Aufbau. Wir hängen
## einen AnimationPlayer an den Modell-Root, dessen root_node dorthin zeigt, und
## bespielen ihn mit der geteilten Bewegungs-Library (loopt "Walking_A").
func _setup_animation(model_root: Node3D) -> void:
	var lib := _get_movement_library()
	if lib == null:
		return
	var anim := AnimationPlayer.new()
	model_root.add_child(anim)
	anim.root_node = anim.get_path_to(model_root)
	anim.add_animation_library("", lib)
	for candidate in ["Walking_A", "Walking_B", "Walking_C", "Running_A"]:
		if lib.has_animation(candidate):
			lib.get_animation(candidate).loop_mode = Animation.LOOP_LINEAR
			anim.play(candidate)
			return


## Lädt die Bewegungs-AnimationLibrary einmalig und teilt sie zwischen allen Monstern.
static var _movement_library: AnimationLibrary

static func _get_movement_library() -> AnimationLibrary:
	const ANIM_SCENE := "res://assets/models/animations/Rig_Medium_MovementBasic.glb"
	if _movement_library != null:
		return _movement_library
	if not ResourceLoader.exists(ANIM_SCENE):
		return null
	var scene: PackedScene = load(ANIM_SCENE)
	var inst := scene.instantiate()
	var src := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src != null and not src.get_animation_library_list().is_empty():
		_movement_library = src.get_animation_library(src.get_animation_library_list()[0])
	inst.free()
	return _movement_library


func _physics_process(delta: float) -> void:
	if _done:
		return
	position.z += _speed * delta
	if position.z >= _target_z:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def)
		reached_goal.emit(self)
		queue_free()
