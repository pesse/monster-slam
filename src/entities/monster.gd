class_name Monster
extends Node2D
## Ein normales Monster: trägt eine Vokabel, bewegt sich Richtung Festung.
## Rein präsentierend + Bewegung — Kampf-/Wellenlogik liegt im WaveRunner.

## Wird ausgelöst, wenn dieses Monster die Festung erreicht (Node-Handling im WaveRunner).
signal reached_goal(monster: Monster)

var monster_def: Dictionary = {}
var vocab: Dictionary = {}

var _speed: float = 40.0
var _target_y: float = 0.0
var _done: bool = false

@onready var _label: Label = $Label
@onready var _sprite: Sprite2D = $Sprite
@onready var _body: ColorRect = $Body


## Muss VOR add_child aufgerufen werden, damit _ready das Label korrekt setzt.
func setup(def: Dictionary, vocab_entry: Dictionary, target_y: float) -> void:
	monster_def = def
	vocab = vocab_entry
	_speed = float(def.get("speed", 40.0))
	_target_y = target_y


func _ready() -> void:
	_label.text = str(vocab.get("prompt", "?"))
	_apply_sprite()


## Lädt die Textur aus dem "sprite"-Feld der Monster-Definition. Fehlt sie oder
## existiert die Datei (noch) nicht, bleibt das farbige Rechteck als Fallback.
func _apply_sprite() -> void:
	var path := str(monster_def.get("sprite", ""))
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_body.visible = false
	else:
		_sprite.visible = false


func _physics_process(delta: float) -> void:
	if _done:
		return
	position.y += _speed * delta
	if position.y >= _target_y:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def)
		reached_goal.emit(self)
		queue_free()
