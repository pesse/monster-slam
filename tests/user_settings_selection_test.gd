extends GdUnitTestSuite
## Tests für die Session-Filter in UserSettings (ausgewählte Tags/Aufgabentypen).
## Nutzt ein Wegwerf-Profil, damit weder das aktive Profil noch dessen Auswahl
## berührt wird (Getter/Setter akzeptieren einen expliziten Profil-Parameter).

const PROFILE := "__test_selection__"


## UserSettings persistiert in user://settings.cfg -> Läufe könnten sich sonst
## gegenseitig sehen. Test-Profil vor jedem Test auf den Default (leer) zurücksetzen.
func before_test() -> void:
	UserSettings.set_selected_tags(PackedStringArray([]), PROFILE)
	UserSettings.set_selected_task_types(PackedStringArray([]), PROFILE)
	UserSettings.set_selected_lexeme_types(PackedStringArray([]), PROFILE)
	UserSettings.set_selected_scope(PackedStringArray([]), PROFILE)


func test_selected_tags_default_empty() -> void:
	assert_int(UserSettings.selected_tags(PROFILE).size()).is_equal(0)


func test_selected_task_types_default_empty() -> void:
	assert_int(UserSettings.selected_task_types(PROFILE).size()).is_equal(0)


func test_selected_tags_roundtrip() -> void:
	UserSettings.set_selected_tags(PackedStringArray(["basics", "food"]), PROFILE)
	var got := UserSettings.selected_tags(PROFILE)
	assert_bool("basics" in got).is_true()
	assert_bool("food" in got).is_true()
	assert_int(got.size()).is_equal(2)


func test_selected_task_types_roundtrip() -> void:
	UserSettings.set_selected_task_types(PackedStringArray(["translate", "opposite"]), PROFILE)
	var got := UserSettings.selected_task_types(PROFILE)
	assert_bool("translate" in got).is_true()
	assert_bool("opposite" in got).is_true()
	assert_int(got.size()).is_equal(2)


func test_selected_lexeme_types_default_empty() -> void:
	assert_int(UserSettings.selected_lexeme_types(PROFILE).size()).is_equal(0)


func test_selected_lexeme_types_roundtrip() -> void:
	UserSettings.set_selected_lexeme_types(PackedStringArray(["noun", "verb"]), PROFILE)
	var got := UserSettings.selected_lexeme_types(PROFILE)
	assert_bool("noun" in got).is_true()
	assert_bool("verb" in got).is_true()
	assert_int(got.size()).is_equal(2)


func test_selected_scope_default_empty() -> void:
	assert_int(UserSettings.selected_scope(PROFILE).size()).is_equal(0)


func test_selected_scope_roundtrip() -> void:
	UserSettings.set_selected_scope(PackedStringArray(["access2/6", "access2/7"]), PROFILE)
	var got := UserSettings.selected_scope(PROFILE)
	assert_bool("access2/6" in got).is_true()
	assert_bool("access2/7" in got).is_true()
	assert_int(got.size()).is_equal(2)


func test_selection_is_per_profile() -> void:
	UserSettings.set_selected_tags(PackedStringArray(["basics"]), PROFILE)
	# Ein anderes Profil bleibt unberührt (Default = leer).
	assert_int(UserSettings.selected_tags("__other_profile__").size()).is_equal(0)
