extends GdUnitTestSuite
## Die Einstellungen als Fenster über dem Hauptmenü — derselbe Rahmen wie Statistik und
## Fähigkeiten. Geprüft wird nur, was das Fenster zeigt und wie es zugeht; geklickt wird
## nichts, was in das Entwicklungsprofil schriebe.

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")


func _window() -> Control:
	var screen: Control = auto_free(SETTINGS_SCENE.instantiate())
	add_child(screen)
	return screen


func test_the_tabs_switch_pages() -> void:
	var screen := _window()
	var profile := screen.get_node("%ProfilePage") as Control
	var report := screen.get_node("%ReportPage") as Control
	var trace := screen.get_node("%TracePage") as Control
	assert_bool(profile.visible).is_true()
	assert_bool(report.visible or trace.visible).is_false()
	var before := (screen.get_node("%Window") as Control).size
	(screen.get_node("%ReportTab") as Button).button_pressed = true
	assert_bool(report.visible).is_true()
	assert_bool(profile.visible or trace.visible).is_false()
	(screen.get_node("%TraceTab") as Button).button_pressed = true
	assert_bool(trace.visible).is_true()
	assert_bool(report.visible).is_false()
	assert_vector((screen.get_node("%Window") as Control).size).is_equal(before)
	remove_child(screen)


## Schließen-X und Escape melden `closed` — das Menü nimmt das Fenster dann weg.
func test_close_and_escape_tell_the_opener() -> void:
	var screen := _window()
	var count := [0]
	screen.connect("closed", func() -> void: count[0] += 1)
	(screen.get_node("%CloseButton") as BaseButton).pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_int(count[0]).is_equal(2)
	assert_str(str(Hints.hint_of(screen.get_node("%CloseButton")).get("note", ""))).is_equal("Esc")
	remove_child(screen)


## Die gewählte Stufe steht gedrückt, genau eine — die Knöpfe sind eine Gruppe.
func test_the_default_difficulty_is_the_pressed_choice() -> void:
	var screen := _window()
	var pressed: Array[int] = []
	var buttons := screen.get_node("%DiffRow").get_children()
	for i in buttons.size():
		if (buttons[i] as Button).button_pressed:
			pressed.append(i + 1)
	assert_array(pressed).is_equal([UserSettings.default_difficulty()])
	remove_child(screen)


## Die Rückfrage ist ein Overlay im Fenster, kein Godot-`Window` (CLAUDE.md).
func test_the_reset_asks_inside_the_window() -> void:
	var screen := _window()
	var dialog := screen.get_node("%ResetDialog")
	assert_object(dialog).is_instanceof(ConfirmDialog)
	assert_bool((dialog as Control).visible).is_false()
	(screen.get_node("%ResetButton") as Button).pressed.emit()
	assert_bool((dialog as Control).visible).is_true()
	(dialog.get_node("%CancelButton") as Button).pressed.emit()
	assert_bool((dialog as Control).visible).is_false()
	remove_child(screen)


## Das Fenster passt in die Bezugsgröße: Kopf und Reiter stehen, der Rest scrollt.
func test_the_window_fits_the_reference_size() -> void:
	var screen := _window()
	for tab in ["%ProfileTab", "%ReportTab", "%TraceTab"]:
		(screen.get_node(tab) as Button).button_pressed = true
		var need := (screen.get_node("%Layout") as Control).get_combined_minimum_size() \
				+ Vector2(32, 32)
		assert_float(need.x).is_less_equal(1152.0)
		assert_float(need.y).is_less_equal(648.0)
	remove_child(screen)
