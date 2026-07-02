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
func _apply_model() -> void:
	var path := str(monster_def.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		add_child(packed.instantiate())
		_placeholder.visible = false


func _physics_process(delta: float) -> void:
	if _done:
		return
	position.z += _speed * delta
	if position.z >= _target_z:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def)
		reached_goal.emit(self)
		queue_free()
