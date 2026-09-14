extends GdUnitTestSuite
## Verifiziert, dass der Session-Setup-Screen den hierarchischen Buch/Unit/Teil-Picker
## datengetrieben aufbaut (Regression gegen kaputte %ScopeList-Verdrahtung) und dass die
## beiden Ebenen zusammenhängen: Unit an = alle Teile an, ein Teil ab = Unit ab.

const SCENE := "res://scenes/ui/session_setup.tscn"


## Ohne Sprachdaten gibt es keine Bücher, also auch keinen Picker zu prüfen — die ganze
## Suite entfällt dann (siehe LanguageData).
func before(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	pass


## Der Screen liest den Scope des AKTIVEN Profils; für Determinismus vor jedem Test leeren.
func before_test() -> void:
	UserSettings.set_selected_scope(PackedStringArray([]))


func after() -> void:
	UserSettings.set_selected_scope(PackedStringArray([]))


## Alle Checkboxen unter %ScopeList einsammeln — Units und Teile stehen in verschiedenen
## Zeilen, gesucht wird deshalb über den ganzen Teilbaum.
func _checks(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is CheckBox:
			found.append(child)
		found.append_array(_checks(child))
	return found


func _values(node: Node) -> Array:
	return _checks(node).map(func(c): return str(c.get_meta("value")))


func _check_for(node: Node, value: String) -> CheckBox:
	for check in _checks(node):
		if str(check.get_meta("value")) == value:
			return check
	return null


func test_scope_picker_lists_access2_unit6() -> void:
	var runner := scene_runner(SCENE)
	assert_bool("access2/6" in _values(runner.scene().get_node("%ScopeList"))).is_true()


## Die Unit zerfällt in Teile; Teil 1 muss anwählbar sein.
func test_scope_picker_lists_the_parts_of_a_unit() -> void:
	var runner := scene_runner(SCENE)
	assert_bool("access2/6/1" in _values(runner.scene().get_node("%ScopeList"))).is_true()


func test_scope_checkboxes_default_unchecked() -> void:
	# Leerer gespeicherter Scope = keine Einschränkung -> Checkboxen aus.
	var runner := scene_runner(SCENE)
	for check in _checks(runner.scene().get_node("%ScopeList")):
		assert_bool(check.button_pressed).is_false()


## Eine angehakte Unit deckt ihre Teile schon ab — gespeichert wird nur der kurze
## Schlüssel, angehakt sind trotzdem sichtbar alle Teile.
func test_checking_a_unit_checks_its_parts_and_saves_only_the_unit() -> void:
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	_check_for(scope_list, "access2/6").button_pressed = true
	assert_array(Array(UserSettings.selected_scope())).contains_exactly(["access2/6"])
	assert_bool(_check_for(scope_list, "access2/6/1").button_pressed).is_true()
	assert_bool(_check_for(scope_list, "access2/6/2").button_pressed).is_true()


## Ein abgehakter Teil nimmt die Unit mit heraus und lässt die übrigen Teile stehen.
func test_unchecking_a_part_drops_the_unit_but_keeps_the_others() -> void:
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	_check_for(scope_list, "access2/6").button_pressed = true
	_check_for(scope_list, "access2/6/1").button_pressed = false
	var saved := Array(UserSettings.selected_scope())
	assert_bool("access2/6" in saved).is_false()
	assert_bool("access2/6/1" in saved).is_false()
	assert_bool("access2/6/2" in saved).is_true()
	assert_bool(_check_for(scope_list, "access2/6").button_pressed).is_false()


## Alle Teile wieder an = die ganze Unit an, und gespeichert steht wieder der kurze
## Schlüssel da.
func test_checking_every_part_checks_the_unit() -> void:
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	for part in range(1, ContentRegistry.parts_for("access2", 6) + 1):
		_check_for(scope_list, "access2/6/%d" % part).button_pressed = true
	assert_bool(_check_for(scope_list, "access2/6").button_pressed).is_true()
	assert_array(Array(UserSettings.selected_scope())).contains_exactly(["access2/6"])


## Ein gespeicherter Teil-Schlüssel kommt angehakt zurück, die Unit bleibt es nicht.
func test_a_saved_part_comes_back_checked() -> void:
	UserSettings.set_selected_scope(PackedStringArray(["access2/6/2"]))
	var runner := scene_runner(SCENE)
	var scope_list := runner.scene().get_node("%ScopeList")
	assert_bool(_check_for(scope_list, "access2/6/2").button_pressed).is_true()
	assert_bool(_check_for(scope_list, "access2/6").button_pressed).is_false()
