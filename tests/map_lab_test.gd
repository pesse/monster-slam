extends GdUnitTestSuite
## Die Karten-Werkbank (scenes/dev/map_lab.tscn): Flächen malt man mit dem Pinsel in ihre
## Maske (links malt, rechts radiert); Quellen und Orte wählt die linke Maustaste, Ziehen
## verschiebt sie, Neues setzt nur die rechte. Die Leiste rechts zeigt den gewählten Effekt.
##
## Die Werkbank schreibt erst mit „Speichern" — der Test drückt ihn nie, map.json und die
## Masken bleiben.

const LAB_SCENE := preload("res://scenes/dev/map_lab.tscn")

var _lab: Control
var _canvas: MapCanvas


func before_test() -> void:
	_lab = auto_free(LAB_SCENE.instantiate()) as Control
	add_child(_lab)
	_canvas = _lab.get_node("%Canvas") as MapCanvas
	await get_tree().process_frame
	# Eine eigene Gebietskarte im Speicher statt der echten: Unit 1 mit Wasser und Rauch.
	_lab._unit = 1
	_lab._masks.clear()
	_lab._undo.clear()
	_lab._content = {"ambience": {"1": [{"kind": "water"},
			{"kind": "smoke", "x": 0.6, "y": 0.6}]}}
	_lab._fill_ambience_select(1)
	_lab._redraw()


func _entries() -> Array:
	return _lab._content["ambience"]["1"]


func _press(at: Vector2, pressed := true, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	_lab._on_canvas_input(event)


func _drag_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	_lab._on_canvas_input(event)


## Der Wert der Wasser-Maske an `at` (Anteil des Bildes), 0..255.
func _water_at(at: Vector2) -> int:
	var mask: Dictionary = _lab._masks["water"]
	var size: Vector2i = mask["size"]
	var texel := Vector2i(at * Vector2(size))
	return (mask["bytes"] as PackedByteArray)[texel.y * size.x + texel.x]


func test_the_lab_builds_with_its_controls() -> void:
	for unique_name in ["Canvas", "Handles", "UndoButton", "EffectGroup", "BrushGroup",
			"DeleteSelectionButton", "AmbienceSelect", "KindSelect", "OutlineToggle", "PointSelect",
			"Inspector", "KindEdit", "IntensitySlider", "StyleSelect", "SizeSlider", "ShapePreview",
			"ShapeMask", "BrushSlider", "HardnessSlider", "StrengthSlider"]:
		assert_object(_lab.get_node("%" + unique_name)).override_failure_message(
				"Werkbank findet '%s' nicht" % unique_name).is_not_null()


func test_painting_fills_the_mask_and_the_right_button_erases() -> void:
	var at := Vector2(0.3, 0.3)
	_press(_canvas.to_local_point(at))
	_press(_canvas.to_local_point(at), false)
	assert_int(_water_at(at)).is_equal(255)
	assert_int(_water_at(Vector2(0.8, 0.8))).is_equal(0)
	_press(_canvas.to_local_point(at), true, MOUSE_BUTTON_RIGHT)
	_press(_canvas.to_local_point(at), false, MOUSE_BUTTON_RIGHT)
	assert_int(_water_at(at)).is_equal(0)


func test_a_stroke_fills_the_gap_between_two_mouse_positions() -> void:
	_press(_canvas.to_local_point(Vector2(0.2, 0.5)))
	_drag_to(_canvas.to_local_point(Vector2(0.6, 0.5)))
	_press(Vector2.ZERO, false)
	assert_int(_water_at(Vector2(0.4, 0.5))).is_equal(255)
	# Nach dem Loslassen malt die Maus nicht mehr.
	_drag_to(_canvas.to_local_point(Vector2(0.4, 0.8)))
	assert_int(_water_at(Vector2(0.4, 0.8))).is_equal(0)


func test_undo_takes_back_the_last_stroke() -> void:
	_press(_canvas.to_local_point(Vector2(0.3, 0.3)))
	_press(Vector2.ZERO, false)
	_press(_canvas.to_local_point(Vector2(0.7, 0.3)))
	_press(Vector2.ZERO, false)
	(_lab.get_node("%UndoButton") as Button).pressed.emit()
	assert_int(_water_at(Vector2(0.7, 0.3))).is_equal(0)
	assert_int(_water_at(Vector2(0.3, 0.3))).is_equal(255)


## Ein Strich mit halber Stärke bleibt halb, wie oft er auch über dieselbe Stelle geht; die
## Härte macht den Rand weich.
func test_a_stamp_never_goes_past_its_strength() -> void:
	var size := Vector2i(40, 40)
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y)
	for i in 3:
		bytes = _lab.stamp(bytes, size, Vector2(20, 20), 10.0, 0.5, 0.5, false)
	assert_int(bytes[20 * size.x + 20]).is_equal(128)
	var edge := bytes[20 * size.x + 28]
	assert_int(edge).is_greater(0)
	assert_int(edge).is_less(128)
	assert_int(bytes[20 * size.x + 35]).is_equal(0)


func test_a_left_click_on_a_spot_selects_it_and_adds_nothing() -> void:
	(_lab.get_node("%AmbienceSelect") as OptionButton).select(0)
	_press(_canvas.to_local_point(Vector2(0.6, 0.6)) + Vector2(3, 2))
	_press(Vector2.ZERO, false)
	assert_int(_entries().size()).is_equal(2)
	assert_dict(_lab._selection).is_equal({"type": "spot", "entry": 1})


func test_dragging_moves_the_spot() -> void:
	(_lab.get_node("%AmbienceSelect") as OptionButton).select(2)
	_press(_canvas.to_local_point(Vector2(0.6, 0.6)))
	_drag_to(_canvas.to_local_point(Vector2(0.7, 0.65)))
	_press(Vector2.ZERO, false)
	assert_vector(MapLayout.point(_entries()[1])).is_equal_approx(Vector2(0.7, 0.65), Vector2(0.002, 0.002))


func test_a_left_click_into_the_empty_sets_nothing() -> void:
	(_lab.get_node("%AmbienceSelect") as OptionButton).select(2)
	_press(_canvas.to_local_point(Vector2(0.9, 0.9)))
	assert_vector(MapLayout.point(_entries()[1])).is_equal(Vector2(0.6, 0.6))
	assert_dict(_lab._selection).is_empty()


func test_a_right_click_puts_the_spot_there() -> void:
	(_lab.get_node("%AmbienceSelect") as OptionButton).select(2)
	_press(_canvas.to_local_point(Vector2(0.2, 0.3)), true, MOUSE_BUTTON_RIGHT)
	_press(Vector2.ZERO, false, MOUSE_BUTTON_RIGHT)
	assert_vector(MapLayout.point(_entries()[1])).is_equal_approx(Vector2(0.2, 0.3), Vector2(0.002, 0.002))
	assert_dict(_lab._selection).is_equal({"type": "spot", "entry": 1})


func test_the_sidebar_shows_only_what_fits_the_effect() -> void:
	var select := _lab.get_node("%AmbienceSelect") as OptionButton
	for case in [[1, true, true, false], [2, false, false, true]]:
		select.select(case[0])
		_lab._redraw()
		assert_bool((_lab.get_node("%BrushGroup") as Control).visible).is_equal(case[1])
		assert_bool((_lab.get_node("%StyleGroup") as Control).visible).is_equal(case[2])
		assert_bool((_lab.get_node("%SizeGroup") as Control).visible).is_equal(case[3])
	select.select(0)
	_lab._redraw()
	assert_bool((_lab.get_node("%EffectGroup") as Control).visible).is_false()


func test_the_sidebar_writes_only_what_differs() -> void:
	assert_str((_lab.get_node("%AmbienceSelect") as OptionButton).text).contains("Wasser")
	var effect: Dictionary = _entries()[0]
	(_lab.get_node("%IntensitySlider") as HSlider).value = 1.5
	assert_float(float(effect["intensity"])).is_equal(1.5)
	(_lab.get_node("%IntensitySlider") as HSlider).value = 1.0
	assert_bool(effect.has("intensity")).is_false()
	var style := _lab.get_node("%StyleSelect") as OptionButton
	style.select(1)
	style.item_selected.emit(1)
	assert_str(str(effect["style"])).is_equal("rings")
	style.select(0)
	style.item_selected.emit(0)
	assert_bool(effect.has("style")).is_false()


func test_changing_the_kind_of_an_area_takes_its_mask_along() -> void:
	_press(_canvas.to_local_point(Vector2(0.3, 0.3)))
	_press(Vector2.ZERO, false)
	var kind := _lab.get_node("%KindEdit") as OptionButton
	kind.select(2)
	kind.item_selected.emit(2)
	assert_str(str(_entries()[0]["kind"])).is_equal("mist")
	assert_bool(_lab._masks.has("water")).is_false()
	assert_bool(_lab._masks.has("mist")).is_true()


## Eine zweite Fläche derselben Art ist ein eigener Eintrag mit eigener Maske (`water2`),
## eigenen Einstellungen und eigenem Pinsel.
func test_adding_an_area_kind_twice_makes_a_second_field() -> void:
	_press(_canvas.to_local_point(Vector2(0.3, 0.3)))
	_press(Vector2.ZERO, false)
	var kinds := _lab.get_node("%KindSelect") as OptionButton
	kinds.select(0)
	(_lab.get_node("%AddAmbienceButton") as Button).pressed.emit()
	assert_int(_entries().size()).is_equal(3)
	assert_str(str(_entries()[2]["mask"])).is_equal("water2")
	assert_int((_lab.get_node("%AmbienceSelect") as OptionButton).selected).is_equal(3)
	_press(_canvas.to_local_point(Vector2(0.7, 0.7)))
	_press(Vector2.ZERO, false)
	var second: Dictionary = _lab._masks["water2"]
	var texel := Vector2i(Vector2(0.7, 0.7) * Vector2(second["size"]))
	assert_int((second["bytes"] as PackedByteArray)[texel.y * second["size"].x + texel.x]).is_equal(255)
	assert_int(_water_at(Vector2(0.7, 0.7))).is_equal(0)
	assert_int(_water_at(Vector2(0.3, 0.3))).is_equal(255)
	(_lab.get_node("%IntensitySlider") as HSlider).value = 1.5
	assert_bool(_entries()[0].has("intensity")).is_false()
	# Beide Felder gehen als eigene Ebenen auf die Karte.
	assert_int(_lab._mask_textures().size()).is_equal(2)


## Wechselt das zweite Wasser die Art, heißt seine Maske wie die neue Art, solange die frei ist.
func test_a_second_field_changing_kind_takes_the_free_name() -> void:
	var kinds := _lab.get_node("%KindSelect") as OptionButton
	kinds.select(0)
	(_lab.get_node("%AddAmbienceButton") as Button).pressed.emit()
	var kind := _lab.get_node("%KindEdit") as OptionButton
	kind.select(2)
	kind.item_selected.emit(2)
	assert_bool(_entries()[2].has("mask")).is_false()
	assert_bool(_lab._masks.has("mist")).is_true()
	assert_bool(_lab._masks.has("water2")).is_false()


func _param_slider(key: String) -> HSlider:
	return _lab._param_rows[key]["slider"] if _lab._param_rows.has(key) else null


func test_water_params_follow_the_style_and_write_only_what_differs() -> void:
	assert_object(_param_slider("wave_size")).is_not_null()
	assert_object(_param_slider("ring_rate")).is_null()
	var effect: Dictionary = _entries()[0]
	var slider := _param_slider("speed")
	slider.value = 2.0
	assert_float(float(effect["speed"])).is_equal(2.0)
	# Der Regler unter der Maus bleibt derselbe, während er schreibt.
	assert_object(_param_slider("speed")).is_same(slider)
	slider.value = 1.0
	assert_bool(effect.has("speed")).is_false()
	var style := _lab.get_node("%StyleSelect") as OptionButton
	style.select(1)
	style.item_selected.emit(1)
	assert_object(_param_slider("ring_rate")).is_not_null()
