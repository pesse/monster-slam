extends Node
## Runtime state of the current run (autoload); persistent progress lives in src/learning/.

## Grundwerte der Festung ohne Skills, in HP. Die Heilung ist kein Anteil des Maximums,
## damit Skills beide unabhängig heben können.
const FORTRESS_BASE_MAX_HEALTH := 100
const FORTRESS_BASE_HEAL_PER_CORRECT := 1

## Effektive Werte des Laufs: Grundwert plus Skill-Boni. Wer HP anzeigt oder verrechnet,
## liest diese, nie die Konstanten.
var fortress_max_health: int = FORTRESS_BASE_MAX_HEALTH
var fortress_heal_per_correct: int = FORTRESS_BASE_HEAL_PER_CORRECT

## Rüstung (Bollwerk): Vorrat (0 ohne Skill) und Rest. Sie geht vor dem Leben auf, bleibt
## über die Wellen und bekommt je Wellenstart `fortress_armor_regen` zurück.
var fortress_armor_max: int = 0
var fortress_armor: int = 0
var fortress_armor_regen: int = 0

var fortress_health: int = FORTRESS_BASE_MAX_HEALTH
var score: int = 0
var current_wave: String = ""
## Laufende Nummer der Welle für die Anzeige; gezählt wird im WaveRunner.
var wave_number: int = 0

## Lauf-Statistik (für HUD-Zähler und Statistik-Screen).
var monsters_defeated: int = 0   # per korrekter Antwort erledigt
var monsters_leaked: int = 0     # bis zur Festung durchgelassen

## Serie korrekt besiegter Monster ohne Durchgelassenes und ihr Bestwert im Lauf.
var no_leak_streak: int = 0
var best_no_leak_streak: int = 0

## Tiefster Festungs-HP-Stand des Laufs; nachgeführt beim Schaden.
var min_fortress_health: int = FORTRESS_BASE_MAX_HEALTH

## Wellen-Fortschritt: Gesamtzahl und erledigte Monster der Welle.
var wave_total: int = 0
var wave_resolved: int = 0


func _ready() -> void:
	EventBus.fortress_damaged.connect(_on_fortress_damaged)
	EventBus.monster_defeated.connect(_on_monster_defeated)
	EventBus.monster_catapulted.connect(_on_monster_catapulted)
	EventBus.monster_struck.connect(_on_monster_struck)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_totals.connect(_on_wave_totals)


func reset() -> void:
	fortress_max_health = FORTRESS_BASE_MAX_HEALTH
	fortress_heal_per_correct = FORTRESS_BASE_HEAL_PER_CORRECT
	fortress_armor_max = 0
	fortress_armor = 0
	fortress_armor_regen = 0
	fortress_health = fortress_max_health
	score = 0
	current_wave = ""
	wave_number = 0
	monsters_defeated = 0
	monsters_leaked = 0
	no_leak_streak = 0
	best_no_leak_streak = 0
	min_fortress_health = fortress_max_health
	wave_total = 0
	wave_resolved = 0


## Legt die Skill-Boni (additiv, SkillTree.bonuses) auf die Grundwerte. Gehört direkt
## hinter `reset()`, weil es die Festung auf das neue Maximum auffüllt.
func apply_skills(bonuses: Dictionary) -> void:
	fortress_max_health = maxi(1, FORTRESS_BASE_MAX_HEALTH + int(bonuses.get("max_health", 0)))
	fortress_heal_per_correct = maxi(1,
			FORTRESS_BASE_HEAL_PER_CORRECT + int(bonuses.get("heal_per_correct", 0)))
	fortress_armor_max = maxi(0, int(bonuses.get("fortress_armor", 0)))
	fortress_armor_regen = maxi(0, int(bonuses.get("armor_regen", 0)))
	fortress_health = fortress_max_health
	min_fortress_health = fortress_max_health
	fortress_armor = fortress_armor_max


## Stände für einen begonnenen Lauf (RunSave, ADR 0020); Maxima rechnet `apply_skills` neu.
func run_snapshot() -> Dictionary:
	return {
		"fortress_health": fortress_health,
		"fortress_armor": fortress_armor,
		"score": score,
		"monsters_defeated": monsters_defeated,
		"monsters_leaked": monsters_leaked,
		"no_leak_streak": no_leak_streak,
		"best_no_leak_streak": best_no_leak_streak,
		"min_fortress_health": min_fortress_health,
	}


## Setzt einen begonnenen Lauf fort; gehört hinter `apply_skills()`, dessen Maxima die
## Stände begrenzen. Eine gerastete Festung lebt, deshalb mindestens 1 HP.
func restore_run(run: Dictionary) -> void:
	fortress_health = clampi(int(run.get("fortress_health", fortress_max_health)), 1,
			fortress_max_health)
	fortress_armor = clampi(int(run.get("fortress_armor", 0)), 0, fortress_armor_max)
	score = maxi(0, int(run.get("score", 0)))
	monsters_defeated = maxi(0, int(run.get("monsters_defeated", 0)))
	monsters_leaked = maxi(0, int(run.get("monsters_leaked", 0)))
	no_leak_streak = maxi(0, int(run.get("no_leak_streak", 0)))
	best_no_leak_streak = maxi(no_leak_streak, int(run.get("best_no_leak_streak", 0)))
	min_fortress_health = clampi(int(run.get("min_fortress_health", fortress_health)), 0,
			fortress_health)


## Neue Festungsstufe mitten im Lauf: Maximum und Stand steigen um `extra` HP.
func grow_fortress(extra: int) -> void:
	if extra <= 0:
		return
	fortress_max_health += extra
	fortress_health = mini(fortress_max_health, fortress_health + extra)


## Die HP bleiben über die Wellen; nur die Rüstung bekommt die Instandsetzung.
func _on_wave_started(_wave_id: String) -> void:
	fortress_armor = mini(fortress_armor_max, fortress_armor + fortress_armor_regen)
	# Hier und nicht bei wave_totals: das kommt mitten in der Welle erneut.
	wave_resolved = 0


func _on_wave_totals(total: int) -> void:
	wave_total = total


## Setzt eine mitten in der Welle gerastete Welle fort (ADR 0020). Gehört direkt hinter
## ihr `wave_started` und setzt Rüstung und Balken auf den gespeicherten Stand.
func continue_wave(resolved: int, armor: int) -> void:
	fortress_armor = clampi(armor, 0, fortress_armor_max)
	wave_resolved = maxi(0, resolved)


func _on_fortress_damaged(amount: int) -> void:
	# Rüstung zuerst. Auch ein aufgefangenes Monster zählt als durchgelassen.
	var absorbed := mini(fortress_armor, maxi(0, amount))
	fortress_armor -= absorbed
	fortress_health = max(0, fortress_health - (amount - absorbed))
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
		# Eine gefallene Festung heilt nicht mehr.
		if fortress_health > 0:
			fortress_health = mini(fortress_max_health, fortress_health + fortress_heal_per_correct)
	wave_resolved += 1


## Abgeschossen ist nur erledigt: keine Punkte, keine Serie, kein Heilen.
func _on_monster_catapulted(_task: Dictionary) -> void:
	wave_resolved += 1


## Donnerschlag (ADR 0014): wie das Katapult.
func _on_monster_struck(_task: Dictionary) -> void:
	wave_resolved += 1


## Lebensquell (ADR 0014): bis zu `amount` HP; gibt die tatsächliche Heilung zurück.
func heal(amount: int) -> int:
	if fortress_health <= 0:
		return 0
	var gained := clampi(amount, 0, fortress_max_health - fortress_health)
	fortress_health += gained
	return gained


## Eisenhaut (ADR 0014): bis zu `amount` Rüstung; gibt die tatsächliche Menge zurück.
func restore_armor(amount: int) -> int:
	if fortress_health <= 0:
		return 0
	var gained := clampi(amount, 0, fortress_armor_max - fortress_armor)
	fortress_armor += gained
	return gained
