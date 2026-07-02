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

## Lauf-Statistik (für HUD-Zähler und Statistik-Screen).
var monsters_defeated: int = 0   # per korrekter Antwort erledigt
var monsters_leaked: int = 0     # bis zur Festung durchgelassen

## Wellen-Fortschritt: wave_total kommt beim Wellenstart über EventBus.wave_totals,
## wave_resolved zählt erledigte Monster (besiegt + durchgelassen).
var wave_total: int = 0
var wave_resolved: int = 0


func _ready() -> void:
	EventBus.fortress_damaged.connect(_on_fortress_damaged)
	EventBus.monster_defeated.connect(_on_monster_defeated)
	# Jede Welle startet mit voller Festung — HP wird pro Welle zurückgesetzt.
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_totals.connect(_on_wave_totals)


func reset() -> void:
	fortress_health = FORTRESS_MAX_HEALTH
	score = 0
	current_wave = ""
	active_skills.clear()
	monsters_defeated = 0
	monsters_leaked = 0
	wave_total = 0
	wave_resolved = 0


func _on_wave_started(_wave_id: String) -> void:
	fortress_health = FORTRESS_MAX_HEALTH


func _on_wave_totals(total: int) -> void:
	wave_total = total
	wave_resolved = 0


func _on_fortress_damaged(amount: int) -> void:
	fortress_health = max(0, fortress_health - amount)
	# Ein Schadensereignis = ein durchgelassenes Monster = ein erledigtes Monster.
	monsters_leaked += 1
	wave_resolved += 1


func _on_monster_defeated(monster: Dictionary, was_correct: bool) -> void:
	if was_correct:
		score += int(monster.get("reward", 10))
		monsters_defeated += 1
	wave_resolved += 1
