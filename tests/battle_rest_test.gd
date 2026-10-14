extends GdUnitTestSuite
## Rasten mitten in der Welle (ADR 0020 Nachtrag): was der WaveRunner von der angefangenen
## Welle mitnimmt und wie er sie fortsetzt.
##
## Gefahren wird der Kampf mit einem leeren Pool (wie battle_wave_end_test): so startet
## keine Welle, und nichts landet im Lernstand des Entwicklungsprofils. Die Zähler der Welle
## setzt der Test von Hand.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const NO_MATCH_TAG := "kein-tag-mit-diesem-namen"

var _tags: PackedStringArray
var _scope: PackedStringArray


func before_test() -> void:
	_tags = UserSettings.selected_tags()
	_scope = UserSettings.selected_scope()
	UserSettings.set_selected_scope(PackedStringArray([]))
	UserSettings.set_selected_tags(PackedStringArray([NO_MATCH_TAG]))
	GameState.reset()


func after_test() -> void:
	UserSettings.set_selected_tags(_tags)
	UserSettings.set_selected_scope(_scope)
	GameState.reset()


func _battle() -> Node:
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(2)
	var battle := runner.scene()
	var until := Time.get_ticks_msec() + 5000
	while battle.get("_warming") and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return battle


func test_the_open_wave_round_trips() -> void:
	var battle := await _battle()
	battle.set("_total", 42)
	battle.set("_spawned", 30)
	battle.set("_wave_correct", 22)
	battle.set("_wave_leaked", 3)
	battle.set("_wave_xp", 90)
	battle.set("_score_at_start", -250)
	battle.set("_fortress_tier", 2)
	battle.get("_spells").wave_pace = 0.5
	var played: Array[Dictionary] = [{"prompt": "dog", "leaked": true},
			{"prompt": "cat", "leaked": false}]
	battle.set("_wave_played_tasks", played)
	var wave: Dictionary = battle._open_wave_state()
	# 12 kommen noch, das Feld ist leer: nur die nicht erschienenen bleiben.
	assert_int(int(wave["remaining"])).is_equal(12)
	assert_int(int(wave["score_gained"])).is_equal(250)
	assert_int(int(wave["fortress_tier"])).is_equal(2)

	# Wie nach dem Laden: JSON macht aus Zahlen Floats.
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(wave))
	battle.set("_wave_played_tasks", [] as Array[Dictionary])
	battle.set("_wave_leaked_tasks", [] as Array[Dictionary])
	battle.get("_spells").reset_wave()
	var spawns := [{"count": 25, "interval": 2.0, "task_pool": {}}]
	battle._continue_wave(loaded, spawns)
	assert_int(int(spawns[0]["count"])).is_equal(12)
	assert_int(battle.get("_total")).is_equal(42)
	assert_int(battle.get("_spawned")).is_equal(30)
	assert_int(battle.get("_wave_correct")).is_equal(22)
	assert_int(battle.get("_wave_leaked")).is_equal(3)
	assert_int(battle.get("_wave_xp")).is_equal(90)
	assert_int(GameState.score - int(battle.get("_score_at_start"))).is_equal(250)
	assert_float(battle.get("_spells").wave_pace).is_equal(0.5)
	assert_array(battle.get("_wave_played_tasks")).has_size(2)
	assert_array(battle.get("_wave_leaked_tasks")).has_size(1)
	battle.set("_finished", true)
