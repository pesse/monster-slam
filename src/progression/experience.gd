class_name Experience
extends RefCounted
## Die Regeln von Erfahrung und Spielerlevel: was ein Monster einbringt, wann man
## aufsteigt und wie viele Skillpunkte das gibt.
##
## Reine Rechnung ohne Zustand, Szene und Autoload — deshalb statisch und für sich
## prüfbar (siehe tests/experience_test.gd), genau wie ChestReward für das Gold. Wer die
## Erfahrung HÄLT, ist PlayerLevel; wer sie VERBUCHT, ist der Aufrufer (WaveRunner).
##
## Der Unterschied zum Gold ist Absicht: Gold ist Beute und schwankt mit Wellenlänge,
## Güte der Kiste und Tempo. Erfahrung ist Lernfortschritt — sie hängt nur an der
## Schwierigkeit der einzelnen Aufgabe, und ihr Band ist schmal (10..15). Eine lange
## leichte Welle bringt viel Gold; sie soll nicht auch noch schnell Level bringen.

## Erfahrung eines besiegten Monsters, von leicht bis schwer. Das Band ist bewusst eng:
## über die Schwierigkeit soll es einen Unterschied geben, aber keinen, der das Suchen
## nach schweren Wörtern zur Pflicht macht.
const MONSTER_XP_MIN := 10
const MONSTER_XP_MAX := 15

## Erfahrung für ein Monster, dessen Aufgabe schon gemeistert ist (siehe
## PlayerProgress.MASTERY_CONFIDENCE). Fast nichts, und das ist der Punkt: Erfahrung
## kommt aus dem Lernen, nicht aus dem Wiederholen längst gekonnter Wörter. Ganz auf 0
## wäre eine Strafe für Wiederholung — die ist zum Behalten nötig, und die
## Wiederholungen wählt der Scheduler, nicht der Spieler.
const MASTERED_XP := 1

## Erfahrung für den Aufstieg von Level L: L * LEVEL_XP_STEP. Linear je Stufe, also
## quadratisch in der Summe: Level 2 ab 100 XP, Level 3 ab 300, Level 4 ab 600.
const LEVEL_XP_STEP := 100

## Skillpunkte je Aufstieg. Bewusst eine Konstante und keine 1 im Code: die Zahl ist
## eine Balance-Entscheidung und soll an einer Stelle stehen.
const SKILL_POINTS_PER_LEVEL := 1


## Erfahrung eines besiegten Monsters. `difficulty` ist die auf 0..1 normalisierte
## Netto-Schwierigkeit des Monsters (0 = sicher beherrscht, 1 = schwer), wie sie der
## WaveGenerator aus Aufgaben-Schwierigkeit und Confidence bildet — dieselbe Größe, aus
## der auch Tempo und Punkte entstehen. `mastered` heißt: die Aufgabe war VOR diesem
## Treffer schon gemeistert.
static func for_monster(difficulty: float, mastered: bool) -> int:
	if mastered:
		return MASTERED_XP
	return int(round(lerpf(float(MONSTER_XP_MIN), float(MONSTER_XP_MAX),
			clampf(difficulty, 0.0, 1.0))))


## Erfahrung, die der Aufstieg VON `level` auf das nächste kostet (Level 1 -> 2: 100).
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


## Skillpunkte, die ein Spieler auf `level` insgesamt verdient hat. Level 1 ist der
## Start, es gibt sie also je ABGESCHLOSSENEM Aufstieg.
static func skill_points_for(level: int) -> int:
	return (maxi(1, level) - 1) * SKILL_POINTS_PER_LEVEL


## Stand innerhalb des Levels: { "level": int, "xp_in_level": int, "xp_for_level_up": int }
## — genau die drei Zahlen, die ein Erfahrungsbalken braucht.
##
## Gerechnet wird in einer Schleife und nicht über die Umkehrung der Summenformel: die
## Wurzel trifft die Stufengrenze (bei 300 XP genau Level 3) nicht zuverlässig, und ein
## Balken, der bei rundem Stand eine Stufe zurückfällt, ist schlimmer als ein paar
## Additionen. Die Schleife läuft mit der Wurzel der Erfahrung, bei 1.000.000 XP also
## rund 140 Durchgänge.
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
