extends Node3D
## Fährt eine einzelne Welle in 3D: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const GOAL_Z := 6.5           # Festungsfront (Monster-Ziel)
const SPAWN_Z := -11.0        # Spawn am hinteren Ende der Bahn
const LANE_HALF_WIDTH := 7.0
const FORTRESS_HIT := 10

const SHAKE_DURATION := 0.35
const SHAKE_MAGNITUDE := 0.35 # in 3D-Einheiten
const FLASH_CORRECT := Color(0.3, 1.0, 0.45)
const FLASH_WRONG := Color(1.0, 0.3, 0.3)

var _evaluator := AnswerEvaluator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false

var _cam_base: Vector3
var _shake_left: float = 0.0

@onready var _monsters: Node3D = $Monsters
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _end_label: Label = $UI/EndLabel
@onready var _flash: ColorRect = $UI/Flash


func _ready() -> void:
	_setup_view()
	_cam_base = _camera.position
	GameState.reset()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	start_wave("wave.tutorial_1")


## Orthografische Iso-Kamera + Sonne. Per Code, damit die .tscn keine
## Transform-Basis-Mathematik enthalten muss.
func _setup_view() -> void:
	($CameraPivot as Node3D).rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 24.0
	_camera.position = Vector3(0.0, 0.0, 32.0)
	($Sun as DirectionalLight3D).rotation_degrees = Vector3(-55.0, -35.0, 0.0)


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = max(0.0, _shake_left - delta)
	if _shake_left == 0.0:
		_camera.position = _cam_base
	else:
		var mag := SHAKE_MAGNITUDE * (_shake_left / SHAKE_DURATION)
		_camera.position = _cam_base + Vector3(randf_range(-mag, mag), randf_range(-mag, mag), 0.0)


func start_wave(wave_id: String) -> void:
	var wave: Dictionary = ContentRegistry.waves.get(wave_id, {})
	if wave.is_empty():
		push_error("WaveRunner: unbekannte Welle '%s'" % wave_id)
		return
	GameState.current_wave = wave_id
	var spawns: Array = wave.get("spawns", [])
	for entry in spawns:
		_total += int(entry.get("count", 0))
	EventBus.wave_started.emit(wave_id)
	for entry in spawns:
		_run_spawn_batch(entry)


## Läuft als Coroutine — mehrere Batches spawnen dadurch nebenläufig im Takt.
func _run_spawn_batch(entry: Dictionary) -> void:
	var count := int(entry.get("count", 0))
	var interval := float(entry.get("interval", 2.0))
	for i in count:
		await get_tree().create_timer(interval).timeout
		if _finished or not is_inside_tree():
			return
		_spawn(entry)


func _spawn(entry: Dictionary) -> void:
	var def: Dictionary = ContentRegistry.monsters.get(entry.get("monster", ""), {})
	if def.is_empty():
		push_warning("WaveRunner: unbekanntes Monster '%s'" % entry.get("monster", ""))
		return
	var candidates: Array = ContentRegistry.vocabulary_by_tags(entry.get("vocab_tags", []))
	if candidates.is_empty():
		push_warning("WaveRunner: keine Vokabeln für Tags %s" % str(entry.get("vocab_tags", [])))
		return
	var vocab: Dictionary = candidates[randi() % candidates.size()]

	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(def, vocab, GOAL_Z)
	monster.position = Vector3(randf_range(-LANE_HALF_WIDTH, LANE_HALF_WIDTH), 0.0, SPAWN_Z)
	monster.reached_goal.connect(_on_monster_reached_goal)
	_monsters.add_child(monster)
	_active.append(monster)
	_spawned += 1
	EventBus.monster_spawned.emit(def)


func _on_answer_submitted(text: String) -> void:
	if _finished:
		return
	for monster in _active:
		if _evaluator.evaluate_vocab(monster.vocab, text):
			_defeat(monster)
			_flash_feedback(FLASH_CORRECT)
			return
	# Kein Treffer -> Falscheingabe: rotes Flash + Kamera-Wackeln.
	# Anknüpfpunkt fürs Lernsystem (Fehlversuch protokollieren).
	_flash_feedback(FLASH_WRONG)
	_shake()


func _shake() -> void:
	_shake_left = SHAKE_DURATION


func _flash_feedback(color: Color) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.35)
	_flash.modulate = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.4)


func _defeat(monster: Monster) -> void:
	_active.erase(monster)
	EventBus.monster_defeated.emit(monster.monster_def, true)
	monster.queue_free()
	_check_end()


## Monster hat sich beim Erreichen der Festung selbst freigegeben.
func _on_monster_reached_goal(monster: Monster) -> void:
	if not _active.has(monster):
		return
	_active.erase(monster)
	EventBus.fortress_damaged.emit(FORTRESS_HIT)
	if GameState.fortress_health <= 0:
		_end("Niederlage – die Festung ist gefallen.")
		return
	_check_end()


func _check_end() -> void:
	if _finished:
		return
	if _spawned >= _total and _active.is_empty():
		EventBus.wave_cleared.emit(GameState.current_wave)
		_end("Welle geräumt!")


func _end(message: String) -> void:
	_finished = true
	_end_label.text = message
	_end_label.visible = true
