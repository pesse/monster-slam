extends Node
## Runtime session state (autoload).
##
## Holds the live state of the current run. Persistent player progress
## (learning history, unlocks) is handled separately by the learning module
## so it can survive across sessions — see src/learning/.

## Grundwerte der Festung — der Stand OHNE Talente. Beide sind flache HP und bewusst
## voneinander unabhängig: ein Talent soll das Maximum anheben können, ohne die Heilung
## mitzuziehen, und umgekehrt (deshalb ist die Heilung kein Anteil des Maximums).
const FORTRESS_BASE_MAX_HEALTH := 100
const FORTRESS_BASE_HEAL_PER_CORRECT := 1

## Die effektiven Werte des laufenden Laufs: Grundwert plus Talent-Boni. Alles, was HP
## anzeigt oder verrechnet, liest DIESE beiden — nie die Konstanten (siehe hud.gd).
## `reset()` setzt sie auf den Grundwert zurück, ein Talent-System hebt sie danach an.
## Ganzzahlig, damit `fortress_health` int bleibt (kein Nachkomma-Akkumulator).
var fortress_max_health: int = FORTRESS_BASE_MAX_HEALTH
var fortress_heal_per_correct: int = FORTRESS_BASE_HEAL_PER_CORRECT

var fortress_health: int = FORTRESS_BASE_MAX_HEALTH
var score: int = 0
var current_wave: String = ""
var active_skills: Array[String] = []

## Lauf-Statistik (für HUD-Zähler und Statistik-Screen).
var monsters_defeated: int = 0   # per korrekter Antwort erledigt
var monsters_leaked: int = 0     # bis zur Festung durchgelassen

## Serie korrekt besiegter Monster ohne Durchgelassenes und ihr Bestwert im laufenden
## Lauf. Sie stehen hier und nicht im SessionLog, weil GameState der Zustand DES LAUFS
## ist; das Log liest sie am Laufende ab und schreibt sie fort (siehe SessionLog.end).
var no_leak_streak: int = 0
var best_no_leak_streak: int = 0

## Tiefster Festungs-HP-Stand des laufenden Laufs (für Auszeichnungen wie
## „nie unter 90 HP"). Wird beim Schaden nachgeführt, nicht beim Heilen.
var min_fortress_health: int = FORTRESS_BASE_MAX_HEALTH

## Wellen-Fortschritt: wave_total kommt über EventBus.wave_totals (Wellenstart, und
## nochmal, wenn ein Spawn ausfällt), wave_resolved zählt erledigte Monster
## (besiegt + durchgelassen) und wird beim Wellenstart zurückgesetzt.
var wave_total: int = 0
var wave_resolved: int = 0


func _ready() -> void:
	EventBus.fortress_damaged.connect(_on_fortress_damaged)
	EventBus.monster_defeated.connect(_on_monster_defeated)
	# HP wird NICHT pro Welle zurückgesetzt (siehe _on_wave_started) — der Stand wird
	# über gewonnene Wellen hinweg mitgenommen.
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_totals.connect(_on_wave_totals)


func reset() -> void:
	# Grundwerte zuerst: ein Talent-System hebt sie NACH dem reset() an, sonst erbte der
	# neue Lauf die Boni des alten.
	fortress_max_health = FORTRESS_BASE_MAX_HEALTH
	fortress_heal_per_correct = FORTRESS_BASE_HEAL_PER_CORRECT
	fortress_health = fortress_max_health
	score = 0
	current_wave = ""
	active_skills.clear()
	monsters_defeated = 0
	monsters_leaked = 0
	no_leak_streak = 0
	best_no_leak_streak = 0
	min_fortress_health = fortress_max_health
	wave_total = 0
	wave_resolved = 0


## Der Wellenstart rührt die Festungs-HP NICHT an: der Stand wird über die Wellen
## hinweg mitgenommen, Schaden bleibt spürbar, und korrekte Antworten reparieren ihn
## nach und nach (siehe _on_monster_defeated). Aufgefüllt wird nur beim Start eines
## Laufs (reset()) — eine gefallene Festung beendet den Lauf, eine Folgewelle mit 0 HP
## gibt es nicht (der Statistik-Screen bietet sie dann nicht an, siehe wave_stats.gd).
func _on_wave_started(_wave_id: String) -> void:
	# Der Zähler gehört zum Wellenstart, nicht zur Gesamtzahl: wave_totals kann sich
	# mitten in der Welle nochmal ändern (ausgefallener Spawn, WaveRunner._spawn) —
	# ein Reset dort würde den HUD-Balken grundlos zurückwerfen.
	wave_resolved = 0


func _on_wave_totals(total: int) -> void:
	wave_total = total


func _on_fortress_damaged(amount: int) -> void:
	fortress_health = max(0, fortress_health - amount)
	# Ein Schadensereignis = ein durchgelassenes Monster = ein erledigtes Monster.
	monsters_leaked += 1
	no_leak_streak = 0
	min_fortress_health = mini(min_fortress_health, fortress_health)
	wave_resolved += 1


func _on_monster_defeated(monster: Dictionary, was_correct: bool) -> void:
	if was_correct:
		score += int(monster.get("reward", 10))
		monsters_defeated += 1
		no_leak_streak += 1
		best_no_leak_streak = maxi(best_no_leak_streak, no_leak_streak)
		# Doppelte Belohnung: Monster erledigt UND Festung ein Stück repariert.
		# Eine gefallene Festung (0 HP) heilt nicht mehr hoch — mit ihr ist der Lauf
		# vorbei, aufgefüllt wird erst wieder beim Start eines neuen (reset()).
		if fortress_health > 0:
			fortress_health = mini(fortress_max_health, fortress_health + fortress_heal_per_correct)
	wave_resolved += 1
