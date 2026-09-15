extends GdUnitTestSuite
## Festungs-HP über Wellen hinweg (Issue #2).
##
## Zwei Regeln stehen hier auf dem Prüfstand: der Wellenstart füllt NICHT mehr
## automatisch auf (Schaden wird in die nächste Welle mitgenommen), und eine korrekte
## Antwort heilt einen kleinen, ganzzahligen Betrag. Aufgefüllt wird nur noch nach
## einer verlorenen Welle (zerstörte Festung) und beim Start eines neuen Laufs.
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


func _defeat(was_correct: bool) -> void:
	EventBus.monster_defeated.emit(MONSTER, was_correct)


## Der Heilwert ist eine flache HP-Zahl (kein Anteil des Maximums). Mindestens 1,
## sonst heilt eine korrekte Antwort gar nicht.
func test_heal_per_correct_is_positive_flat_hp() -> void:
	assert_int(GameState.fortress_heal_per_correct).is_greater_equal(1)


## Ein neuer Lauf startet auf den Grundwerten — sonst erbte er die Talent-Boni des
## vorherigen Laufs.
func test_reset_restores_base_values() -> void:
	GameState.fortress_max_health = 500
	GameState.fortress_heal_per_correct = 25
	GameState.reset()
	assert_int(GameState.fortress_max_health).is_equal(GameState.FORTRESS_BASE_MAX_HEALTH)
	assert_int(GameState.fortress_heal_per_correct).is_equal(GameState.FORTRESS_BASE_HEAL_PER_CORRECT)
	assert_int(GameState.fortress_health).is_equal(GameState.FORTRESS_BASE_MAX_HEALTH)


## Ein angehobenes Maximum verschiebt den Deckel der Heilung mit. Würde irgendwo noch die
## Konstante gelesen, bliebe hier bei 100 Schluss.
func test_raised_max_health_lifts_heal_cap() -> void:
	GameState.apply_skills({"max_health": 20})
	assert_int(GameState.fortress_max_health).is_equal(120)
	GameState.fortress_health = 119
	_defeat(true)
	assert_int(GameState.fortress_health).is_equal(120)
	_defeat(true)
	assert_int(GameState.fortress_health).is_equal(120)


## Ein angehobener Heilwert heilt mehr pro Antwort — ohne dass das Maximum sich ändert.
## Beide Werte sind unabhängig verstellbar, deshalb ist die Heilung kein Anteil des
## Maximums (siehe game_state.gd:8-12).
func test_raised_heal_value_is_independent_of_max() -> void:
	GameState.apply_skills({"heal_per_correct": 9})
	assert_int(GameState.fortress_heal_per_correct).is_equal(10)
	_damage(50)
	_defeat(true)
	assert_int(GameState.fortress_health).is_equal(60)
	assert_int(GameState.fortress_max_health).is_equal(GameState.FORTRESS_BASE_MAX_HEALTH)


## Ohne gelernte Skills ändert `apply_skills` nichts — ein leeres Dictionary ist der
## Normalfall (neues Profil), nicht ein Sonderfall.
func test_apply_skills_without_bonuses_keeps_the_base_values() -> void:
	GameState.apply_skills({})
	assert_int(GameState.fortress_max_health).is_equal(GameState.FORTRESS_BASE_MAX_HEALTH)
	assert_int(GameState.fortress_heal_per_correct).is_equal(
			GameState.FORTRESS_BASE_HEAL_PER_CORRECT)
	assert_int(GameState.fortress_health).is_equal(GameState.FORTRESS_BASE_MAX_HEALTH)


## Eine verbogene Datei darf die Heilung nicht abschalten und das Maximum nicht auf 0
## ziehen: unter 1 geht keiner der beiden Werte.
func test_negative_bonuses_cannot_break_the_fortress() -> void:
	GameState.apply_skills({"max_health": -999, "heal_per_correct": -999})
	assert_int(GameState.fortress_max_health).is_equal(1)
	assert_int(GameState.fortress_heal_per_correct).is_equal(1)


func test_wave_start_keeps_damage() -> void:
	_damage(30)
	EventBus.wave_started.emit("procedural_2")
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 30)


func test_correct_answer_heals() -> void:
	_damage(30)
	_defeat(true)
	assert_int(GameState.fortress_health).is_equal(
			GameState.fortress_max_health - 30 + GameState.fortress_heal_per_correct)


func test_wrong_answer_does_not_heal() -> void:
	_damage(30)
	_defeat(false)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 30)


## Die Heilung ist gedeckelt: eine unbeschädigte Festung bleibt auf dem Maximum.
func test_heal_capped_at_max() -> void:
	_damage(1)
	for i in 10:
		_defeat(true)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health)


## Der Wellenstart füllt NIE auf — auch nicht bei 0 HP. Eine gefallene Festung beendet
## den Lauf (der Statistik-Screen bietet keine nächste Welle an), aufgefüllt wird erst
## beim Start eines neuen Laufs über reset().
func test_wave_start_never_refills() -> void:
	_damage(GameState.fortress_max_health)
	assert_int(GameState.fortress_health).is_equal(0)
	EventBus.wave_started.emit("procedural_2")
	assert_int(GameState.fortress_health).is_equal(0)


## Eine gefallene Festung heilt nicht wieder hoch: mit ihr ist der Lauf vorbei.
func test_fallen_fortress_does_not_heal_up() -> void:
	_damage(GameState.fortress_max_health)
	_defeat(true)
	assert_int(GameState.fortress_health).is_equal(0)


func test_reset_refills() -> void:
	_damage(40)
	GameState.reset()
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health)
