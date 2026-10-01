extends GdUnitTestSuite
## Wachkatapult (Bollwerk, `auto_catapult`): wo es Katapulte gibt, was als gemeistert gilt
## und was ein abgeschossenes Monster zählt. Die Welle selbst fährt kein Test.
##
## PlayerProgress auf einer EIGENEN Instanz mit `zz-`-Profil (nicht im Szenenbaum, kein
## _ready()); GameState ist Autoload und geteilter Zustand -> vorher und nachher reset().

const PROGRESS := preload("res://src/learning/player_progress.gd")
const TEST_PROFILE := "zz-catapult-test"
const TASK := "translate:de_to_en:zz.lex.catapult"

var _pp: Node


func before_test() -> void:
	GameState.reset()
	_pp = auto_free(PROGRESS.new())
	_pp.player_id = TEST_PROFILE


func after_test() -> void:
	GameState.reset()
	DirAccess.remove_absolute("user://progress/%s.json" % TEST_PROFILE)


static func _flat(_x: float, _z: float) -> float:
	return 0.0


## Katapulte gibt es erst auf der vollen Festung: dann zwei Ecktürme, jeder mit Drehkranz
## und Wurfarm als eigenem Knoten — daran hängt die Wurf-Animation.
func test_only_the_full_fortress_has_catapults() -> void:
	for tier in 5:
		var fort: Node3D = auto_free(Node3D.new())
		FortressModel.build(fort, tier, 10.0, _flat)
		var turrets := FortressModel.catapults(fort)
		var expected := 2 if tier >= FortressModel.CATAPULT_TIER else 0
		assert_int(turrets.size()).append_failure_message("Stufe %d" % tier).is_equal(expected)
		for turret in turrets:
			assert_object(turret.get_node_or_null(FortressModel.CATAPULT_ARM)).is_not_null()


## Ungesehen ist nie gemeistert, auch mit hohem Prior — gemeistert wird im Kampf.
func test_an_unseen_task_is_not_mastered() -> void:
	assert_bool(_pp.is_mastered(TASK)).is_false()


func test_a_task_over_the_threshold_is_mastered() -> void:
	_pp.record(TASK, true, 1500)
	assert_bool(_pp.is_mastered(TASK)).is_false()
	for i in 10:
		_pp.record(TASK, true, 1500)
	assert_float(_pp.confidence(TASK)).is_greater_equal(PROGRESS.MASTERY_CONFIDENCE)
	assert_bool(_pp.is_mastered(TASK)).is_true()


## Ein abgeschossenes Monster ist erledigt (Wellenbalken), aber nicht beantwortet: keine
## Punkte, kein Sieg, keine Serie, kein Heilen.
func test_a_catapulted_monster_only_resolves() -> void:
	GameState.fortress_health = GameState.fortress_max_health - 5
	var health := GameState.fortress_health
	EventBus.monster_catapulted.emit({"learnable_id": TASK})
	assert_int(GameState.wave_resolved).is_equal(1)
	assert_int(GameState.score).is_equal(0)
	assert_int(GameState.monsters_defeated).is_equal(0)
	assert_int(GameState.no_leak_streak).is_equal(0)
	assert_int(GameState.fortress_health).is_equal(health)


## Der Effekt-Schlüssel ist bekannt und hat eine lesbare Zeile.
func test_the_effect_key_is_known() -> void:
	assert_array(SkillTree.EFFECT_KEYS).contains(["auto_catapult"])
	assert_str(SkillTree.effect_label("auto_catapult", 1.0)).is_not_empty()


## Ein stehendes Monster trifft man, wo es steht; ein laufendes dort, wo es nach Drehen,
## Ausschlagen und Flug angekommen ist.
func test_the_catapult_leads_a_walking_monster() -> void:
	var WaveRunner := load("res://src/battle/wave_runner.gd")
	var from := Vector3(15.0, 9.0, 18.0)
	var at := Vector3(4.0, 1.0, -6.0)
	assert_vector(WaveRunner.catapult_lead(from, at, Vector3.ZERO)).is_equal(at)
	var velocity := Vector3(0.0, 0.0, 2.0)
	var target: Vector3 = WaveRunner.catapult_lead(from, at, velocity)
	var time: float = FortressModel.CATAPULT_TURN_TIME + FortressModel.CATAPULT_SWING_TIME \
			+ WaveRunner.catapult_flight_time(from, target)
	assert_float(target.z).is_equal_approx(at.z + velocity.z * time, 0.05)
	assert_float(target.x).is_equal_approx(at.x, 0.001)
