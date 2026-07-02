extends Node
## Runtime session state (autoload).
##
## Holds the live state of the current run. Persistent player progress
## (learning history, unlocks) is handled separately by the learning module
## so it can survive across sessions — see src/learning/.

const FORTRESS_MAX_HEALTH := 100

var fortress_health: int = FORTRESS_MAX_HEALTH
var score: int = 0
var current_wave: String = ""
var active_skills: Array[String] = []


func _ready() -> void:
	EventBus.fortress_damaged.connect(_on_fortress_damaged)
	EventBus.monster_defeated.connect(_on_monster_defeated)
	# Jede Welle startet mit voller Festung — HP wird pro Welle zurückgesetzt.
	EventBus.wave_started.connect(_on_wave_started)


func reset() -> void:
	fortress_health = FORTRESS_MAX_HEALTH
	score = 0
	current_wave = ""
	active_skills.clear()


func _on_wave_started(_wave_id: String) -> void:
	fortress_health = FORTRESS_MAX_HEALTH


func _on_fortress_damaged(amount: int) -> void:
	fortress_health = max(0, fortress_health - amount)


func _on_monster_defeated(monster: Dictionary, was_correct: bool) -> void:
	if was_correct:
		score += int(monster.get("reward", 10))
