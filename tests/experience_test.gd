extends GdUnitTestSuite
## Die Regeln von Erfahrung und Level: XP je Monster, Stufenkosten, Skillpunkte.
##
## Reine Rechnung ohne Autoload und ohne Szene (wie tests/chest_reward_test.gd) — was
## hier steht, ist die Balance des Systems und soll sich nicht unbemerkt verschieben.


## Das Band ist eng und die Enden liegen fest: das leichteste Monster bringt 10, das
## schwerste 15. Ohne die Enden wäre jede Justierung der Schwierigkeitsformel auch eine
## Justierung der XP-Menge.
func test_the_difficulty_spans_the_full_xp_band() -> void:
	assert_int(Experience.for_monster(0.0, false)).is_equal(Experience.MONSTER_XP_MIN)
	assert_int(Experience.for_monster(1.0, false)).is_equal(Experience.MONSTER_XP_MAX)


## Zwischen den Enden geht es aufwärts und nie darüber hinaus — auch nicht, wenn ein
## Aufrufer eine Schwierigkeit außerhalb von 0..1 hereingibt.
func test_xp_rises_with_difficulty_and_stays_in_the_band() -> void:
	var previous := 0
	for step in 11:
		var xp := Experience.for_monster(float(step) / 10.0, false)
		assert_int(xp).is_greater_equal(previous)
		assert_int(xp).is_between(Experience.MONSTER_XP_MIN, Experience.MONSTER_XP_MAX)
		previous = xp
	assert_int(Experience.for_monster(-3.0, false)).is_equal(Experience.MONSTER_XP_MIN)
	assert_int(Experience.for_monster(7.0, false)).is_equal(Experience.MONSTER_XP_MAX)


## Eine gemeisterte Aufgabe bringt fast nichts, egal wie schwer sie einmal war:
## Erfahrung kommt aus dem Lernen, nicht aus dem Wiederholen des Gekonnten. Nicht 0 —
## die Wiederholung selbst ist nichts Falsches.
func test_a_mastered_task_gives_almost_nothing() -> void:
	assert_int(Experience.for_monster(1.0, true)).is_equal(Experience.MASTERED_XP)
	assert_int(Experience.for_monster(0.0, true)).is_equal(Experience.MASTERED_XP)
	assert_int(Experience.MASTERED_XP).is_greater(0)
	assert_int(Experience.MASTERED_XP).is_less(Experience.MONSTER_XP_MIN)


## Die Stufenkosten wachsen linear: Level*100 für den Aufstieg von Level.
func test_the_step_cost_grows_linearly() -> void:
	assert_int(Experience.xp_for_level_up(1)).is_equal(100)
	assert_int(Experience.xp_for_level_up(2)).is_equal(200)
	assert_int(Experience.xp_for_level_up(7)).is_equal(700)


## Die Summe daraus: Level 2 ab 100 XP, Level 3 ab 300, Level 4 ab 600.
func test_the_totals_are_the_sum_of_the_steps() -> void:
	assert_int(Experience.total_xp_for_level(1)).is_equal(0)
	assert_int(Experience.total_xp_for_level(2)).is_equal(100)
	assert_int(Experience.total_xp_for_level(3)).is_equal(300)
	assert_int(Experience.total_xp_for_level(4)).is_equal(600)


## Das Level zur Erfahrung, an den Grenzen genau. Die Stufe fällt EXAKT beim runden
## Betrag — mit der Umkehrung der Summenformel lag hier eine Wurzel daneben, und der
## Balken sprang bei 300 XP zurück auf Level 2.
func test_the_level_changes_exactly_at_the_threshold() -> void:
	assert_int(Experience.level_for(0)).is_equal(1)
	assert_int(Experience.level_for(99)).is_equal(1)
	assert_int(Experience.level_for(100)).is_equal(2)
	assert_int(Experience.level_for(299)).is_equal(2)
	assert_int(Experience.level_for(300)).is_equal(3)
	assert_int(Experience.level_for(599)).is_equal(3)
	assert_int(Experience.level_for(600)).is_equal(4)


## Eine handgeschriebene negative Zahl ist kein negatives Level.
func test_negative_experience_is_level_one() -> void:
	assert_int(Experience.level_for(-500)).is_equal(1)
	assert_int(Experience.progress_in_level(-500)["xp_in_level"]).is_equal(0)


## Jedes Levelup gibt einen Skillpunkt — Level 1 ist der Start, also gibt es sie je
## abgeschlossenem Aufstieg.
func test_every_level_up_gives_one_skill_point() -> void:
	assert_int(Experience.skill_points_for(1)).is_equal(0)
	assert_int(Experience.skill_points_for(2)).is_equal(1)
	assert_int(Experience.skill_points_for(5)).is_equal(4)


## Der Stand im Level ist das, was ein Balken braucht: erreicht, gesamt und Level dazu.
func test_the_progress_in_level_fills_a_bar() -> void:
	var at_start := Experience.progress_in_level(300)
	assert_int(at_start["level"]).is_equal(3)
	assert_int(at_start["xp_in_level"]).is_equal(0)
	assert_int(at_start["xp_for_level_up"]).is_equal(300)
	var midway := Experience.progress_in_level(450)
	assert_int(midway["level"]).is_equal(3)
	assert_int(midway["xp_in_level"]).is_equal(150)
	assert_int(midway["xp_for_level_up"]).is_equal(300)


## Der Stand im Level und die Stufenkosten passen zusammen: die Summe aus dem
## Gesamt-Schwellwert und dem Rest ist wieder die Erfahrung. Geprüft über einen weiten
## Bereich, damit die Schleife in progress_in_level nirgends um eine Stufe verrutscht.
func test_level_and_remainder_add_back_up_to_the_experience() -> void:
	for xp in [0, 1, 99, 100, 101, 299, 300, 1000, 4321, 100000]:
		var progress := Experience.progress_in_level(xp)
		var level := int(progress["level"])
		assert_int(Experience.total_xp_for_level(level) + int(progress["xp_in_level"])) \
				.is_equal(xp)
		assert_int(progress["xp_in_level"]).is_less(int(progress["xp_for_level_up"]))
