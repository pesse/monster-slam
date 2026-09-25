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
## Erfahrung für dieses Monster, vom WaveGenerator aus seiner Schwierigkeit bestimmt
## (Experience.for_monster) und beim SPAWN festgelegt: nach dem Treffer ist die
## Confidence schon angehoben, und dann wäre nicht mehr zu sehen, ob die Aufgabe vorher
## gemeistert war. Verbucht wird sie im WaveRunner (PlayerLevel).
var xp: int = Experience.MONSTER_XP_MIN

## Zeitpunkt des Spawns (ms) für die Antwortzeit-Messung; vom WaveRunner gesetzt.
var spawned_at_ms: int = 0

var _speed: float = 2.0
var _target_z: float = 0.0
var _done: bool = false

## Wortart-Outline: Inverted-Hull-Shader, Farbe je Wortart (siehe WordTypePalette).
const OUTLINE_SHADER := preload("res://assets/shaders/monster_outline.gdshader")
const OUTLINE_WORLD_WIDTH := 0.12   # gewünschte Rand-Dicke in Welteinheiten
const OUTLINE_GLOW_STRENGTH := 1.0  # Emission-Faktor; genau 1.0 => kein Kanal-Clipping,
                                    # Outline-Farbe == Legenden-Farbe. Der Glow-Halo kommt
                                    # aus dem WorldEnvironment (niedrige HDR-Schwelle).

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
	var color := WordTypePalette.color_for(str(task.get("lexeme_type", "")))
	if path == "" or not ResourceLoader.exists(path):
		# Kein Modell -> Platzhalter-Kapsel behält die Wortart-Outline (Konsistenz).
		_apply_outline(_placeholder, color, 1.0)
		return
	var packed: PackedScene = load(path)
	var inst := packed.instantiate() as Node3D
	var model_scale := float(monster_def.get("model_scale", 1.0))
	inst.scale = Vector3.ONE * model_scale
	inst.rotation_degrees.y = float(monster_def.get("model_yaw", 0.0))
	add_child(inst)
	_placeholder.visible = false
	_apply_outline(inst, color, model_scale)
	_setup_animation(inst)


## Legt die Wortart-Outline als material_overlay auf alle MeshInstance3D unterhalb von
## `root`. Eine eigene ShaderMaterial-Instanz je Monster (kein geteiltes preload), damit
## jede Wortart ihre Farbe bekommt, ohne importierte GLB-Materialien anzufassen.
## Die Welt-Dicke bleibt trotz model_scale konstant, indem sie herausgerechnet wird.
func _apply_outline(root: Node3D, color: Color, model_scale: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", OUTLINE_WORLD_WIDTH / maxf(model_scale, 0.001))
	mat.set_shader_parameter("glow_strength", OUTLINE_GLOW_STRENGTH)
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_overlay = mat
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


## KayKit-Charaktere haben keine eigenen Animationen — sie kommen aus der geteilten
## Bewegungs-Library (RigAnimations); das Monster loopt "Walking_A".
func _setup_animation(model_root: Node3D) -> void:
	var lib := RigAnimations.movement()
	if lib == null:
		return
	var anim := RigAnimations.attach_player(model_root, {"": lib})
	for candidate in ["Walking_A", "Walking_B", "Walking_C", "Running_A"]:
		if lib.has_animation(candidate):
			lib.get_animation(candidate).loop_mode = Animation.LOOP_LINEAR
			anim.play(candidate)
			return


func _physics_process(delta: float) -> void:
	if _done:
		return
	position.z += _speed * delta
	if position.z >= _target_z:
		_done = true
		EventBus.monster_reached_fortress.emit(monster_def, task, damage)
		reached_goal.emit(self)
		queue_free()
