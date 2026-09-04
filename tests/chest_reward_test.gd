extends GdUnitTestSuite
## Die Belohnung einer Welle: Güte der Kiste und Goldmenge.
##
## Geprüft an den statischen Funktionen — ohne Szene, ohne Autoload und ohne Geldbörse.
## Die Rechnung ist die Stelle, an der sich die Wirtschaft des Spiels justieren lässt;
## dass sie stimmt, soll nicht an einem Durchspielen hängen.

const REWARD := preload("res://src/economy/chest_reward.gd")


# --- Güte ---------------------------------------------------------------------

## Keine durchgelassenen Monster = perfekte Welle = goldene Kiste. Das ist die
## Bedingung, die man beim Spielen im Kopf haben kann.
func test_a_perfect_wave_yields_a_golden_chest() -> void:
	assert_int(REWARD.tier_for(6, 0)).is_equal(REWARD.Tier.GOLD)


func test_tiers_follow_the_accuracy() -> void:
	assert_int(REWARD.tier_for(9, 1)).is_equal(REWARD.Tier.SILVER)   # 90 %
	assert_int(REWARD.tier_for(6, 4)).is_equal(REWARD.Tier.BRONZE)   # 60 %
	assert_int(REWARD.tier_for(2, 8)).is_equal(REWARD.Tier.WOOD)     # 20 %


## Eine Welle ohne jedes erledigte Monster ist keine perfekte Welle: ohne den Sonderfall
## wäre „0 durchgelassen" hier eine Goldkiste für nichts.
func test_an_empty_wave_is_not_perfect() -> void:
	assert_int(REWARD.tier_for(0, 0)).is_equal(REWARD.Tier.WOOD)


# --- Gold ---------------------------------------------------------------------

## Die Menge hängt an den Punkten, und die tragen die Schwierigkeit der besiegten
## Monster schon in sich (siehe WaveGenerator.reward).
func test_more_score_means_more_gold() -> void:
	var small := REWARD.gold_for(36, REWARD.Tier.SILVER)
	var large := REWARD.gold_for(120, REWARD.Tier.SILVER)
	assert_int(large).is_greater(small)


## Die bessere Kiste ist auch die vollere — sonst wäre die Güte nur Lack.
func test_a_better_chest_holds_more() -> void:
	var wood := REWARD.gold_for(100, REWARD.Tier.WOOD)
	var gold := REWARD.gold_for(100, REWARD.Tier.GOLD)
	assert_int(gold).is_greater(wood)


## Wer ein Monster besiegt hat, geht nie mit leeren Händen — auch nicht bei einem
## einzigen Punkt in der schlechtesten Kiste.
func test_a_won_monster_is_never_worth_nothing() -> void:
	assert_int(REWARD.gold_for(1, REWARD.Tier.WOOD)).is_greater_equal(REWARD.MIN_GOLD)


## Ohne Punkte ist die Kiste leer, und eine leere Kiste zeigt der Screen nicht
## (siehe WaveStats._goto_stage).
func test_without_score_there_is_no_chest() -> void:
	assert_int(REWARD.gold_for(0, REWARD.Tier.GOLD)).is_equal(0)
	assert_int(REWARD.for_wave(0, 0, 3)["gold"]).is_equal(0)


func test_for_wave_carries_tier_gold_and_name() -> void:
	var reward := REWARD.for_wave(60, 6, 0)
	assert_int(reward["tier"]).is_equal(REWARD.Tier.GOLD)
	assert_int(reward["gold"]).is_greater(0)
	assert_str(reward["name"]).is_equal("Goldkiste")
