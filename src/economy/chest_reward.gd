class_name ChestReward
extends RefCounted
## Die Schatzkiste am Ende einer Welle: welche Güte sie hat und wie viel Gold darin liegt.
## Reine Rechnung ohne Zustand. Die Menge kommt aus den Punkten der Welle (sie tragen die
## Schwierigkeit `t - c` schon in sich), die Güte aus der Genauigkeit.

## Güte der Kiste, aufsteigend. Index in TIER_NAMES/TIER_FACTOR, also nicht umsortieren.
enum Tier { WOOD, BRONZE, SILVER, GOLD }

const TIER_NAMES := ["Holzkiste", "Bronzekiste", "Silberkiste", "Goldkiste"]

## Gold je Punkt der Welle. Eine erste Welle (~36 Punkte) bringt eine Handvoll Münzen.
const GOLD_PER_SCORE := 0.1
## Faktor der Güte auf die Grundmenge, je Tier.
const TIER_FACTOR := [0.8, 1.0, 1.2, 1.5]
## Mindestgold einer Kiste, sobald ein Monster besiegt ist.
const MIN_GOLD := 1
## Trostgold ohne besiegtes Monster. Dann gibt es keine Kiste, auch keine Holzkiste.
const CONSOLATION_GOLD := 1

## Genauigkeits-Schwellen der Güte (Anteil). Ohne Durchgelassenes ist die Kiste golden.
const SILVER_ACCURACY := 0.8
const BRONZE_ACCURACY := 0.5


## Güte der Kiste aus dem Ausgang der Welle: perfekt = Gold, sonst nach Genauigkeit.
## Ohne jedes erledigte Monster eine Holzkiste.
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


## Goldmenge aus den Punkten der Welle und der Güte. Ohne Punkte 0 (keine Kiste).
static func gold_for(score_gained: int, tier: Tier) -> int:
	if score_gained <= 0:
		return 0
	var base := float(score_gained) * GOLD_PER_SCORE * float(TIER_FACTOR[int(tier)])
	return maxi(MIN_GOLD, int(round(base)))


## Die vollständige Belohnung einer Welle:
## { "tier": Tier, "gold": int, "name": String, "consolation": int }.
## `gold` 0 heißt „keine Kiste“, dann steht in `consolation` das Trostgold, sonst 0.
static func for_wave(score_gained: int, correct: int, leaked: int) -> Dictionary:
	var tier := tier_for(correct, leaked)
	return {
		"tier": tier,
		"gold": gold_for(score_gained, tier),
		"name": TIER_NAMES[int(tier)],
		"consolation": CONSOLATION_GOLD if gold_for(score_gained, tier) <= 0 else 0,
	}
