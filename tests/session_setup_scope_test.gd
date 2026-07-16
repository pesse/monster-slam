extends GdUnitTestSuite
## Verifiziert, dass der Session-Setup-Screen den hierarchischen Buch/Unit-Picker
## datengetrieben aufbaut (Regression gegen kaputte %ScopeList-Verdrahtung).

const SCENE := "res://scenes/ui/session_setup.tscn"


## Der Screen liest den Scope des AKTIVEN Profils; für Determinismus vor jedem Test leeren.
func before_test() -> void:
	UserSettings.set_selected_scope(PackedStringArray([]))


## Alle Checkbox-Werte (Meta "value") unter %ScopeList einsammeln.
func _scope_values(scope_list: Node) -> Array:
	var values: Array = []
	for child in scope_list.get_children():
		if child is GridContainer:
			for check in child.get_children():
				if check is CheckButton:
					values.append(str(check.get_meta("value")))
	return values


func test_scope_picker_lists_access2_unit6() -> void:
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	assert_bool("access2/6" in _scope_values(scope_list)).is_true()


func test_scope_checkboxes_default_unchecked() -> void:
	# Leerer gespeicherter Scope = keine Einschränkung -> Checkboxen aus.
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	for child in scope_list.get_children():
		if child is GridContainer:
			for check in child.get_children():
				if check is CheckButton:
					assert_bool(check.button_pressed).is_false()
