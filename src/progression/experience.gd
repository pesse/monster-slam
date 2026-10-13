class_name Experience
extends RefCounted
## Die Regeln von Erfahrung und Spielerlevel: was ein Monster einbringt, wann man
## aufsteigt und wie viele Skillpunkte das gibt. Reine Rechnung ohne Zustand; die
## Erfahrung hält PlayerLevel. Anders als Gold hängt Erfahrung nur an der Schwierigkeit
## der einzelnen Aufgabe, nicht an Wellenlänge oder Tempo.

## Erfahrung eines besiegten Monsters, von leicht bis schwer.
const MONSTER_XP_MIN := 10
const MONSTER_XP_MAX := 15

## Erfahrung für ein Monster, dessen Aufgabe schon gemeistert ist
## (PlayerProgress.MASTERY_CONFIDENCE). Nicht 0, weil der Scheduler die Wiederholungen wählt.
const MASTERED_XP := 1

## Erfahrung für den Aufstieg von Level L: L * LEVEL_XP_STEP. Level 2 ab 100 XP, Level 3
## ab 300, Level 4 ab 600.
const LEVEL_XP_STEP := 100

## Skillpunkte je Aufstieg.
const SKILL_POINTS_PER_LEVEL := 1


## Erfahrung eines besiegten Monsters. `difficulty` ist die Netto-Schwierigkeit, auf 0..1
## normalisiert (1 = schwer), dieselbe Größe wie für Tempo und Punkte. `mastered` heißt:
## die Aufgabe war vor diesem Treffer schon gemeistert.
static func for_monster(difficulty: float, mastered: bool) -> int:
	if mastered:
		return MASTERED_XP
	return int(round(lerpf(float(MONSTER_XP_MIN), float(MONSTER_XP_MAX),
			clampf(difficulty, 0.0, 1.0))))


## Erfahrung, die der Aufstieg von `level` auf das nächste kostet (Level 1 -> 2: 100).
static func xp_for_level_up(level: int) -> int:
	return maxi(1, level) * LEVEL_XP_STEP


## Gesamt-Erfahrung, mit der `level` erreicht ist (Level 1: 0, Level 2: 100, Level 3: 300).
static func total_xp_for_level(level: int) -> int:
	var target := maxi(1, level)
	# Summe der linearen Stufenkosten = LEVEL_XP_STEP * (L-1)L/2.
	return LEVEL_XP_STEP * (target - 1) * target / 2


## Level zu einer Gesamt-Erfahrung (mindestens 1).
static func level_for(total_xp: int) -> int:
	return int(progress_in_level(total_xp)["level"])


## Skillpunkte, die ein Spieler auf `level` insgesamt verdient hat: einer je
## abgeschlossenem Aufstieg.
static func skill_points_for(level: int) -> int:
	return (maxi(1, level) - 1) * SKILL_POINTS_PER_LEVEL


## Stand innerhalb des Levels: { "level": int, "xp_in_level": int, "xp_for_level_up": int }.
## Gerechnet in einer Schleife statt über die Wurzel der Summenformel: die Wurzel trifft
## die Stufengrenze (300 XP = Level 3) nicht zuverlässig. Bei 1.000.000 XP sind das rund
## 140 Durchgänge.
static func progress_in_level(total_xp: int) -> Dictionary:
	var level := 1
	var remaining := maxi(0, total_xp)
	while remaining >= xp_for_level_up(level):
		remaining -= xp_for_level_up(level)
		level += 1
	return {
		"level": level,
		"xp_in_level": remaining,
		"xp_for_level_up": xp_for_level_up(level),
	}
