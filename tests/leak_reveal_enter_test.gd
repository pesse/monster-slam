extends GdUnitTestSuite
## Enter drückt in der Vokabel-Auflösung „Weiter" — auch bei perfekter Welle, wo der
## Screen ohne Durchlauf dasteht. Vorher ging es nur mit der Maus weiter.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")


func _item(id: String, leaked: bool) -> Dictionary:
	return {
		"prompt": "Frage %s" % id, "answers": ["antwort"], "lexeme_type": "noun",
		"source_id": "zz-%s" % id, "learnable_id": "zz-%s" % id, "leaked": leaked,
	}


func _enter() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	return key


func _reveal(grace_ms: int) -> PanelContainer:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var reveal := auto_free(REVEAL_SCENE.instantiate()) as PanelContainer
	layer.add_child(reveal)
	reveal.enter_grace_ms = grace_ms
	# Nicht erwartet: play() wartet am Ende auf „Weiter".
	reveal.play([_item("a", false), _item("b", false)])
	await get_tree().process_frame
	await get_tree().process_frame
	return reveal


func test_enter_continues_after_a_perfect_wave() -> void:
	var reveal := await _reveal(0)
	assert_bool((reveal.get_node("%ContinueBtn") as Button).disabled).is_false()
	reveal._input(_enter())
	await get_tree().process_frame
	assert_bool(reveal.visible).is_false()


func test_enter_right_after_the_last_answer_does_not_click_through() -> void:
	var reveal := await _reveal(60000)
	reveal._input(_enter())
	await get_tree().process_frame
	assert_bool(reveal.visible).is_true()
