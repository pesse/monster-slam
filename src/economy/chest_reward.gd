class_name ChestReward
extends RefCounted
## Die Schatzkiste am Ende einer Welle: welche Güte sie hat und wie viel Gold darin liegt.
##
## Reine Rechnung ohne Zustand, Szene und Autoload — deshalb statisch und für sich prüfbar
## (siehe tests/chest_reward_test.gd). Wer die Kiste zeigt, ist TreasureChest; wer das
## Gold verbucht, ist Wallet; WER SIE VERDIENT, entscheidet der Aufrufer. Die Kiste soll
## später an mehreren Stellen zu holen sein (Tagesziel, Boss, Meisterung), und jede
## dieser Stellen bringt ihre eigene Güte mit.
##
## Die Menge Gold kommt aus den PUNKTEN der Welle und nicht aus der Zahl der Monster:
## die Punkte je Monster tragen die Schwierigkeit schon in sich (WaveGenerator.reward
## steigt mit der Grundschwierigkeit der Aufgabe, fällt mit der Confidence des Spielers
## und wächst mit dem Wellentempo). Ein zweites Schwierigkeitsmaß daneben würde davon
## abweichen, sobald eines von beiden justiert wird.
##
## Die Güte kommt aus der Genauigkeit und nicht aus den Punkten: sie ist das, was der
## Spieler in DIESER Welle besser machen konnte, und sie ist unabhängig davon, wie lang
## die Welle war.

## Güte der Kiste. Reihenfolge = Wertigkeit; als Index in TIER_NAMES/TIER_FACTOR
## benutzt, also nicht umsortieren.
enum Tier { WOOD, BRONZE, SILVER, GOLD }

const TIER_NAMES := ["Holzkiste", "Bronzekiste", "Silberkiste", "Goldkiste"]

## Gold je Punkt der Welle. 0.1 heißt: eine erste Welle (drei Monster, ~36 Punkte) bringt
## eine Handvoll, eine späte (sieben Monster, ~85 Punkte) das Doppelte. Die Größenordnung
## soll zählbar bleiben — verdiente Münzen fliegen aus der Kiste, und dreistellige
## Beträge kann man nicht mehr aufpicken.
const GOLD_PER_SCORE := 0.1
## Zuschlag der Güte auf die Grundmenge. Die bessere Kiste ist auch die vollere; ohne das
## wäre die Güte nur Lack.
const TIER_FACTOR := [0.8, 1.0, 1.2, 1.5]
## Wer ein Monster besiegt hat, geht nie mit leeren Händen — eine Kiste mit 0 Gold wäre
## ein Versprechen, das der Deckel nicht hält.
const MIN_GOLD := 1

## Genauigkeits-Schwellen der Güte (0..1). Ohne Durchgelassenes ist die Welle perfekt und
## die Kiste golden — das ist die Bedingung, die man beim Spielen im Kopf haben kann.
const SILVER_ACCURACY := 0.8
const BRONZE_ACCURACY := 0.5


## Güte der Kiste aus dem Ausgang der Welle: perfekt = Gold, sonst nach Genauigkeit.
## Eine Welle ohne jedes erledigte Monster (Abbruch) ist eine Holzkiste, keine goldene.
static func tier_for(correct: int, leaked: int) -> Tier:
	var total := correct + leaked
	if total <= 0:
		return Tier.WOOD
	if leaked == 0:
		return Tier.GOLD
	var accuracy := float(correct) / float(total)
	if accuracy >= SILVER_ACCURACY:
		return Tier.SILVER
	return Tier.BRONZE if accuracy >= BRONZE_ACCURACY else Tier.WOOD


## Goldmenge aus den in der Welle erspielten Punkten und der Güte der Kiste.
## Ohne Punkte (kein einziges besiegtes Monster) ist die Kiste leer und es gibt sie nicht
## — den Fall entscheidet `for_wave`, hier kommt konsequent 0 zurück.
static func gold_for(score_gained: int, tier: Tier) -> int:
	if score_gained <= 0:
		return 0
	var base := float(score_gained) * GOLD_PER_SCORE * float(TIER_FACTOR[int(tier)])
	return maxi(MIN_GOLD, int(round(base)))


## Die vollständige Belohnung einer Welle: { "tier": Tier, "gold": int, "name": String }.
## `gold` 0 heißt „keine Kiste" — der Aufrufer überspringt die Belohnung dann (siehe
## WaveStats.show_stats).
static func for_wave(score_gained: int, correct: int, leaked: int) -> Dictionary:
	var tier := tier_for(correct, leaked)
	return {
		"tier": tier,
		"gold": gold_for(score_gained, tier),
		"name": TIER_NAMES[int(tier)],
	}
