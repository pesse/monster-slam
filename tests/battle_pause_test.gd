extends GdUnitTestSuite
## Pause im Wellenkampf: Strg+P überall, das nackte P nur in der Ich-Sicht, dazu der Knopf
## unter „Schnell auflösen". Die Pause hält den Baum an, nimmt die Eingabe weg und rechnet
## die Pausenzeit nicht als Bedenkzeit.
##
## Gefahren wird der Kampf mit einem leeren Pool (wie battle_start_gate_test): so startet
## keine Welle, und nichts landet im Lernstand des Entwicklungsprofils. Der Test gibt den
## Kampf danach von Hand frei (`_finished`), damit die Pause überhaupt erlaubt ist.

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
	get_tree().paused = false


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


func _key(ctrl: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	key.ctrl_pressed = ctrl
	return key


func test_ctrl_p_pauses_and_resumes() -> void:
	var battle := await _battle()
	var overlay := battle.get_node("UI/PauseOverlay") as PauseOverlay
	var input := battle.get_node("UI/AnswerInput") as LineEdit
	overlay.toggle_requested.emit(false)
	assert_bool(get_tree().paused).is_true()
	assert_bool(overlay.is_shown()).is_true()
	assert_bool(input.visible).is_false()
	overlay.toggle_requested.emit(false)
	assert_bool(get_tree().paused).is_false()
	assert_bool(overlay.is_shown()).is_false()
	assert_bool(input.visible).is_true()


func _enter() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	return key


## Bei geschlossener Eingabe pausiert das nackte P — auch in der Iso-Sicht (ADR 0016).
func test_bare_p_pauses_while_the_input_is_closed() -> void:
	var battle := await _battle()
	var overlay := battle.get_node("UI/PauseOverlay") as PauseOverlay
	overlay.toggle_requested.emit(true)
	assert_bool(get_tree().paused).is_true()


## In der offenen Eingabe ist das „p" ein Buchstabe der Antwort.
func test_bare_p_types_while_the_input_is_open() -> void:
	var battle := await _battle()
	var overlay := battle.get_node("UI/PauseOverlay") as PauseOverlay
	(battle.get_node("UI/AnswerInput") as LineEdit).call("_input", _enter())
	overlay.toggle_requested.emit(true)
	assert_bool(get_tree().paused).is_false()


func test_the_button_pauses() -> void:
	var battle := await _battle()
	(battle.get_node("UI/PauseButton") as Button).pressed.emit()
	assert_bool(get_tree().paused).is_true()
	assert_bool((battle.get_node("UI/PauseOverlay") as PauseOverlay).is_shown()).is_true()


## Keine Pause über eine Feier hinweg: deren Ende gäbe den Baum frei und nähme die Pause mit.
func test_no_pause_while_the_tree_is_already_paused() -> void:
	var battle := await _battle()
	get_tree().paused = true
	(battle.get_node("UI/PauseOverlay") as PauseOverlay).toggle_requested.emit(false)
	assert_bool((battle.get_node("UI/PauseOverlay") as PauseOverlay).is_shown()).is_false()


func test_the_key_reaches_the_overlay() -> void:
	var battle := await _battle()
	var overlay := battle.get_node("UI/PauseOverlay") as PauseOverlay
	var got: Array = []
	overlay.toggle_requested.connect(func(bare: bool) -> void: got.append(bare))
	overlay._input(_key(true))
	overlay._input(_key(false))
	assert_array(got).contains_exactly([false, true])


## Das Debug-Panel liegt über dem Schleier und bleibt in der Pause bedienbar; nur die
## Feier wartet, sie gäbe am Ende den Baum frei.
func test_the_debug_panel_works_during_the_pause() -> void:
	var battle := await _battle()
	var ui := battle.get_node("UI")
	var panel := ui.get_node_or_null("DebugPanel") as Control
	if panel == null:
		return
	assert_int(panel.get_index()).is_greater(ui.get_node("PauseOverlay").get_index())
	(ui.get_node("PauseOverlay") as PauseOverlay).toggle_requested.emit(false)
	assert_bool(panel.can_process()).is_true()
	panel.celebration_requested.emit(false)
	assert_bool(get_tree().paused).is_true()
	assert_bool((ui.get_node("PauseOverlay") as PauseOverlay).is_shown()).is_true()
