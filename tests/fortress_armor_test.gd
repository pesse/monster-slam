extends GdUnitTestSuite
## Die Rüstung des Bollwerk-Baums: Polster VOR dem Leben, neu gefüllt zu jeder Welle.
##
## Das ist die eine Stelle, an der der Wellenstart die Festung doch anfasst (siehe
## game_state.gd:103-112) — und die Stelle, an der ein Schadensereignis zwei Dinge tut:
## Rüstung abtragen UND als durchgelassenes Monster zählen. Beides steht hier auf dem
## Prüfstand, weil beides beim nächsten Umbau leicht zusammenfällt.
##
## Getestet wird über den EventBus, also auf demselben Weg, den WaveRunner nimmt.
## GameState ist ein Autoload und damit geteilter Zustand -> vorher/nachher reset().

const MONSTER := {"reward": 10}


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


func _damage(amount: int) -> void:
	EventBus.fortress_damaged.emit(amount)


## Ein Lauf mit gelerntem Bollwerk-Baum: reset(), dann die Boni, dann die erste Welle —
## genau die Reihenfolge aus WaveRunner._ready().
func _run_with_armor(armor: int) -> void:
	GameState.reset()
	GameState.apply_skills({"fortress_armor": armor})
	EventBus.wave_started.emit("procedural_1")


# --- Ohne Skill ---------------------------------------------------------------

## Der Normalfall: wer den Baum nicht gelernt hat, merkt von ihm nichts.
func test_without_the_skill_there_is_no_armor() -> void:
	GameState.apply_skills({})
	assert_int(GameState.fortress_armor_max).is_equal(0)
	assert_int(GameState.fortress_armor).is_equal(0)
	_damage(30)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 30)


## Ein neuer Lauf erbt die Rüstung des alten nicht — auch dann nicht, wenn der Baum
## inzwischen umgelernt wurde.
func test_reset_takes_the_armor_away() -> void:
	_run_with_armor(40)
	GameState.reset()
	assert_int(GameState.fortress_armor_max).is_equal(0)
	assert_int(GameState.fortress_armor).is_equal(0)


# --- Der Vorrat ---------------------------------------------------------------

## Der Lauf beginnt mit voller Rüstung: `apply_skills` steht unmittelbar hinter `reset()`,
## und die erste Welle soll nicht ungeschützt sein.
func test_the_run_starts_with_full_armor() -> void:
	GameState.reset()
	GameState.apply_skills({"fortress_armor": 25})
	assert_int(GameState.fortress_armor_max).is_equal(25)
	assert_int(GameState.fortress_armor).is_equal(25)


## DER Grund für den Baum: die Rüstung kommt jede Welle zurück, das Leben nicht. Ohne das
## wäre das Bollwerk nur ein umständlicheres höheres Maximum.
func test_every_wave_refills_the_armor_but_not_the_health() -> void:
	_run_with_armor(40)
	_damage(60)
	assert_int(GameState.fortress_armor).is_equal(0)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 20)
	EventBus.wave_started.emit("procedural_2")
	assert_int(GameState.fortress_armor).is_equal(40)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 20)


## Eine verbogene Datei darf keine negative Rüstung erzeugen — die würde beim ersten
## Treffer als Zuschlag auf den Schaden wirken.
func test_a_negative_bonus_gives_no_armor() -> void:
	GameState.apply_skills({"fortress_armor": -50})
	assert_int(GameState.fortress_armor_max).is_equal(0)


# --- Der Treffer --------------------------------------------------------------

## Die Rüstung liegt VOR dem Leben: was sie schluckt, kostet keine HP.
func test_armor_is_spent_before_health() -> void:
	_run_with_armor(40)
	_damage(30)
	assert_int(GameState.fortress_armor).is_equal(10)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health)


## Reicht sie nicht, geht nur der Rest ans Leben — kein Schaden fällt unter den Tisch.
func test_a_hit_larger_than_the_armor_splits() -> void:
	_run_with_armor(10)
	_damage(30)
	assert_int(GameState.fortress_armor).is_equal(0)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 20)


## Ist sie aufgebraucht, trifft der nächste Treffer voll — sie füllt sich innerhalb der
## Welle nicht nach.
func test_armor_does_not_refill_inside_a_wave() -> void:
	_run_with_armor(20)
	_damage(20)
	_damage(15)
	assert_int(GameState.fortress_armor).is_equal(0)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 15)


## Der tiefste HP-Stand hängt am LEBEN, nicht an der Rüstung: eine Auszeichnung „nie unter
## 90 HP" soll eine aufgefangene Welle nicht als Beinahe-Niederlage zählen.
func test_the_low_water_mark_follows_the_health_only() -> void:
	_run_with_armor(40)
	_damage(40)
	assert_int(GameState.min_fortress_health).is_equal(GameState.fortress_max_health)


## Aufgefangen ist trotzdem durchgelassen: das Monster hat die Festung erreicht, die Serie
## ist hin und die Welle einen Eintrag weiter. Eine aufgefangene Welle ist keine saubere.
func test_an_absorbed_hit_still_counts_as_a_leak() -> void:
	_run_with_armor(40)
	EventBus.monster_defeated.emit(MONSTER, true)
	assert_int(GameState.no_leak_streak).is_equal(1)
	_damage(10)
	assert_int(GameState.monsters_leaked).is_equal(1)
	assert_int(GameState.no_leak_streak).is_equal(0)
	assert_int(GameState.wave_resolved).is_equal(2)
