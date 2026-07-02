extends Node2D
## Fährt eine einzelne Welle: spawnt Monster aus der Wave-Definition, gleicht
## Spielerantworten gegen aktive Monster ab und erkennt das Wellenende.
## Nutzt ausschließlich bestehende Autoloads + AnswerEvaluator — rein additiv.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const GOAL_Y := 560.0
const SPAWN_Y := 40.0
const FORTRESS_HIT := 10

var _evaluator := AnswerEvaluator.new()
var _active: Array[Monster] = []
var _total: int = 0
var _spawned: int = 0
var _finished: bool = false

@onready var _monsters: Node2D = $Monsters
@onready var _end_label: Label = $UI/EndLabel


func _ready() -> void:
	GameState.reset()
	EventBus.answer_submitted.connect(_on_answer_submitted)
	start_wave("wave.tutorial_1")


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
	var candidates := ContentRegistry.vocabulary_by_tags(entry.get("vocab_tags", []))
	if candidates.is_empty():
		push_warning("WaveRunner: keine Vokabeln für Tags %s" % str(entry.get("vocab_tags", [])))
		return
	var vocab: Dictionary = candidates[randi() % candidates.size()]

	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(def, vocab, GOAL_Y)
	monster.position = Vector2(randf_range(120.0, 1000.0), SPAWN_Y)
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
			return
	# Kein Treffer: bewusst ignoriert. Anknüpfpunkt für Lernsystem (Fehlversuch).


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
