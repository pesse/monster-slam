extends GdUnitTestSuite
## Zauber im Wellenkampf, von der Ziffertaste bis zur Wirkung (ADR 0014): die Ziffer wirkt
## nur bei leerem Antwortfeld, ein wirkungsloser Zauber bleibt im Vorrat, der Donnerschlag
## nimmt Monster vom Feld und zählt sie nur als erledigt.
##
## Gefahren wird der Kampf mit einem leeren Pool (wie battle_pause_test): so startet keine
## Welle, und nichts landet im Lernstand des Entwicklungsprofils. Das Autoload `Inventory`
## läuft für den Test auf einem `zz-`-Profil; Vorrat und Profil kommen danach zurück.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const NO_MATCH_TAG := "kein-tag-mit-diesem-namen"
const TEST_PROFILE := "zz-battle-spell-test"

var _tags: PackedStringArray
var _scope: PackedStringArray
var _player: String
var _slots: Array[Dictionary]
var _extra: int


func before_test() -> void:
	_tags = UserSettings.selected_tags()
	_scope = UserSettings.selected_scope()
	UserSettings.set_selected_scope(PackedStringArray([]))
	UserSettings.set_selected_tags(PackedStringArray([NO_MATCH_TAG]))
	_player = Inventory.player_id
	_slots = Inventory.slots.duplicate()
	_extra = Inventory.extra_slots
	Inventory.player_id = TEST_PROFILE
	Inventory.extra_slots = 0
	GameState.reset()


func after_test() -> void:
	UserSettings.set_selected_tags(_tags)
	UserSettings.set_selected_scope(_scope)
	Inventory.player_id = _player
	Inventory.slots.assign(_slots)
	Inventory.extra_slots = _extra
	Inventory.changed.emit()
	DirAccess.remove_absolute("user://progress/%s_inventory.json" % TEST_PROFILE)
	GameState.reset()


func _battle() -> Node:
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(2)
	var battle := runner.scene()
	var until := Time.get_ticks_msec() + 5000
	while battle.get("_warming") and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	battle.set("_finished", false)
	(battle.get_node("UI/AnswerInput") as LineEdit).visible = true
	return battle


func _stock(entries: Array) -> void:
	Inventory.slots.assign(entries)
	Inventory.changed.emit()


func _digit(n: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_0 + n
	key.pressed = true
	return key


func _monster(battle: Node) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.setup(FxWarmup.monster_defs()[0], {"learnable_id": "zz.task", "prompt": "zz"},
			1000.0, 40.0)
	battle.add_child(monster)
	(battle.get("_active") as Array).append(monster)
	return monster


func test_the_digit_casts_from_its_slot() -> void:
	var battle := await _battle()
	_stock([{}, {"id": "spell.mend", "count": 2}])
	GameState.fortress_health = GameState.fortress_max_health - 40
	var cast: Array = []
	var on_cast := func(id: String) -> void: cast.append(id)
	EventBus.spell_activated.connect(on_cast)
	battle._input(_digit(2))
	EventBus.spell_activated.disconnect(on_cast)
	assert_array(cast).contains_exactly(["spell.mend"])
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 15)
	assert_int(Inventory.count_of("spell.mend")).is_equal(1)


## Mit Text im Feld ist die Ziffer ein Zeichen der Antwort.
func test_the_digit_types_while_the_field_has_text() -> void:
	var battle := await _battle()
	_stock([{"id": "spell.mend", "count": 1}])
	GameState.fortress_health = GameState.fortress_max_health - 40
	(battle.get_node("UI/AnswerInput") as LineEdit).text = "abc"
	battle._input(_digit(1))
	assert_int(Inventory.count_of("spell.mend")).is_equal(1)
	assert_int(GameState.fortress_health).is_equal(GameState.fortress_max_health - 40)


## Eine heile Festung braucht keinen Lebensquell: er bleibt im Vorrat.
func test_a_spell_without_effect_is_kept() -> void:
	var battle := await _battle()
	_stock([{"id": "spell.mend", "count": 1}, {"id": "spell.frost", "count": 1}])
	battle._input(_digit(1))
	battle._input(_digit(2))
	assert_int(Inventory.count_of("spell.mend")).is_equal(1)
	assert_int(Inventory.count_of("spell.frost")).is_equal(1)


## Ein leerer Platz und eine Taste jenseits der Plätze tun nichts.
func test_empty_and_missing_slots_do_nothing() -> void:
	var battle := await _battle()
	_stock([{}])
	battle._input(_digit(1))
	battle._input(_digit(9))
	assert_int(GameState.wave_resolved).is_equal(0)


func test_thunder_clears_the_field_and_only_resolves() -> void:
	var battle := await _battle()
	_stock([{"id": "spell.thunder", "count": 1}])
	var a := _monster(battle)
	var b := _monster(battle)
	battle._input(_digit(1))
	# Vom Feld sofort, das Bild kommt mit dem Blitz: bis dahin stehen sie nur.
	assert_array(battle.get("_active") as Array).is_empty()
	assert_vector(a.velocity()).is_equal(Vector3.ZERO)
	assert_int(battle.get("_underway")).is_equal(2)
	await get_tree().create_timer(SpellFx.STRIKE_WINDUP + SpellFx.STRIKE_STAGGER + 0.3).timeout
	assert_bool(not is_instance_valid(a) or a.is_queued_for_deletion()).is_true()
	assert_bool(not is_instance_valid(b) or b.is_queued_for_deletion()).is_true()
	assert_int(battle.get("_underway")).is_equal(0)
	# Eingeschlagen, aber noch zu sehen: die Welle wartet mit dem Abschluss auf das Bild.
	assert_bool((battle.get("_spell_fx") as SpellFx).is_busy()).is_true()
	assert_bool(battle.get("_finished")).is_false()
	assert_int(GameState.wave_resolved).is_equal(2)
	assert_int(GameState.monsters_defeated).is_equal(0)
	assert_int(GameState.score).is_equal(0)
	assert_int(Inventory.count_of("spell.thunder")).is_equal(0)


func test_frost_freezes_the_field() -> void:
	var battle := await _battle()
	_stock([{"id": "spell.frost", "count": 1}])
	var monster := _monster(battle)
	battle._input(_digit(1))
	assert_bool(monster.is_frozen()).is_true()
	assert_vector(monster.velocity()).is_equal(Vector3.ZERO)
