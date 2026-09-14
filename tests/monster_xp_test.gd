extends GdUnitTestSuite
## Die Erfahrung am Monster: der Generator legt sie beim Spawn fest, und der Wellenfaktor
## rührt sie nicht an.
##
## Warum das hier steht und nicht in experience_test.gd: dort sind die REGELN geprüft
## (Band, Stufen, Skillpunkte), hier die VERDRAHTUNG — dass der Plan die Erfahrung
## überhaupt mitbringt und dass sie aus der Schwierigkeit der Aufgabe kommt und nicht aus
## der der Welle.
##
## Was hier bewusst NICHT geprüft wird: das Verbuchen im WaveRunner. `PlayerLevel` ist
## Autoload und damit die echte Erfahrung des Spielers — eine gespielte Welle im Test
## würde sie hochschreiben. Das Verbuchen ist eine Zeile in `_defeat`; die Regeln
## dahinter sind einzeln geprüft (siehe experience_test.gd, player_level_test.gd).

## Wellenfaktor, bei dem die Punkte sicher über dem Erfahrungs-Band liegen: die kleinste
## Punktzahl ist REFERENCE_REWARD * 0.4 * speed_scale, mit 5.0 also 24 gegen höchstens 15 XP.
const HARSH_WAVE := 5.0


## Ein Monster ohne gesetzte Erfahrung bringt nicht 0 XP: der Standard liegt im Band.
## Sonst wäre ein vergessenes `monster.xp = …` ein stiller Verlust statt eines Fehlers.
func test_a_monster_starts_with_experience_in_the_band() -> void:
	var monster: Monster = auto_free(preload("res://scenes/entities/monster.tscn").instantiate())
	assert_int(monster.xp).is_between(Experience.MONSTER_XP_MIN, Experience.MONSTER_XP_MAX)


## Jeder Plan des Generators trägt Erfahrung, und zwar entweder das Band (10..15) oder
## den Rest für eine schon gemeisterte Aufgabe.
func test_a_generated_plan_carries_experience(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var plan := WaveGenerator.new().pick({})
	assert_dict(plan).contains_keys(["xp"])
	var xp := int(plan["xp"])
	if xp != Experience.MASTERED_XP:
		assert_int(xp).is_between(Experience.MONSTER_XP_MIN, Experience.MONSTER_XP_MAX)


## Der Wellenfaktor hebt die PUNKTE, nicht die Erfahrung: eine härtere Welle bringt mehr
## Monster und mehr Beute, aber sie macht das einzelne Wort nicht schwerer. Ohne diese
## Trennung wäre die schnellste Welle immer auch der schnellste Weg zum Levelup.
func test_the_wave_factor_lifts_the_points_but_not_the_experience(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var generator := WaveGenerator.new()
	generator.speed_scale = HARSH_WAVE
	var plan := generator.pick({})
	assert_int(int(plan["reward"])).is_greater(Experience.MONSTER_XP_MAX)
	assert_int(int(plan["xp"])).is_less_equal(Experience.MONSTER_XP_MAX)
