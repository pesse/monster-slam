class_name Monster
extends Node3D
## Ein normales Monster in 3D: trägt eine Vokabel (schwebendes Label3D) und
## bewegt sich entlang +Z auf die Festung zu. Präsentation + Bewegung;
## Kampf-/Wellenlogik liegt im WaveRunner.

## Wird ausgelöst, wenn dieses Monster die Festung erreicht (Node-Handling im WaveRunner).
signal reached_goal(monster: Monster)

var monster_def: Dictionary = {}
var vocab: Dictionary = {}

var _speed: float = 2.0
var _target_z: float = 0.0
var _done: bool = false

@onready var _label: Label3D = $Label
@onready var _placeholder: MeshInstance3D = $Placeholder


## Muss VOR add_child aufgerufen werden, damit _ready Label/Modell korrekt setzt.
func setup(def: Dictionary, vocab_entry: Dictionary, target_z: float) -> void:
	monster_def = def
	vocab = vocab_entry
	# 2D-Pixelgeschwindigkeiten (~35..120) auf 3D-Einheiten/s herunterskalieren.
	_speed = float(def.get("speed", 40.0)) / 20.0
	_target_z = target_z


func _ready() -> void:
	_label.text = str(vocab.get("prompt", "?"))
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
	_play_loop_animation(inst)


## Sucht einen AnimationPlayer im geladenen Modell und loopt eine Lauf-/Idle-
## Animation (bevorzugt gängige Namen, sonst die erste vorhandene).
func _play_loop_animation(root: Node) -> void:
	var anim := _find_animation_player(root)
	if anim == null:
		return
	var name := ""
	for candidate in ["Walking_A", "Walk", "Walking", "Run", "Idle", "Idle_A"]:
		if anim.has_animation(candidate):
			name = candidate
			break
	if name == "" and not anim.get_animation_list().is_empty():
		name = anim.get_animation_list()[0]
	if name == "":
		return
	var clip := anim.get_animation(name)
	if clip:
		clip.loop_mode = Animation.LOOP_LINEAR
	anim.play(name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	if _done:
		return
	position.z += _speed * delta
	if position.z >= _target_z:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def)
		reached_goal.emit(self)
		queue_free()
