extends GdUnitTestSuite
## Das Wellenende wartet, bis der letzte Treffer zu sehen war: eine laufende Explosion hält
## die Abrechnung auf (`WaveRunner._settle`), sonst verdeckt die Statistik den Knall.
##
## Gefahren wird der Kampf mit einem leeren Pool (wie battle_pause_test): so startet keine
## Welle, und nichts landet im Lernstand des Entwicklungsprofils. Das Feld ist leer und
## alles „gespawnt", das Ende wäre also sofort fällig. Am Schluss setzt der Test den Kampf
## von Hand auf beendet, damit das aufgeschobene Ende nach dem Test nichts mehr abrechnet.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const NO_MATCH_TAG := "kein-tag-mit-diesem-namen"

var _tags: PackedStringArray
var _scope: PackedStringArray


func before_test() -> void:
	_tags = UserSettings.selected_tags()
	_scope = UserSettings.selected_scope()
	UserSettings.set_selected_scope(PackedStringArray([]))
	UserSettings.set_selected_tags(PackedStringArray([NO_MATCH_TAG]))


func after_test() -> void:
	UserSettings.set_selected_tags(_tags)
	UserSettings.set_selected_scope(_scope)


func _battle() -> Node:
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(2)
	var battle := runner.scene()
	var until := Time.get_ticks_msec() + 5000
	while battle.get("_warming") and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	battle.set("_finished", false)
	return battle


func test_a_running_explosion_holds_the_wave_end() -> void:
	var battle := await _battle()
	battle._spawn_explosion(Vector3.ZERO, Color.WHITE, 1.0)
	battle._check_end()
	assert_bool(battle.get("_finished")).is_false()
	assert_int(battle.get("_settling")).is_equal(1)
	battle.set("_finished", true)
