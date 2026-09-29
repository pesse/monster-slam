extends GdUnitTestSuite
## „Wer spielt?" und das Hauptmenü: das Spiel beginnt in der Profilwahl, das Hauptmenü
## zeigt nur, wer spielt, und führt mit „Profil wechseln" zurück.
##
## Gedrückt wird hier nichts: ein Profil-Knopf schaltet das aktive Profil um und wechselt
## die Szene — beides träfe das Entwicklungsprofil und den Testlauf.

const PICK_SCENE := preload("res://scenes/ui/profile_pick.tscn")
const MENU_SCENE := preload("res://scenes/ui/profile_menu.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")


func test_the_game_starts_with_the_profile_pick() -> void:
	assert_str(str(ProjectSettings.get_setting("application/run/main_scene"))) \
			.is_equal("res://scenes/ui/profile_pick.tscn")


func test_one_button_per_profile_and_the_last_player_has_the_focus() -> void:
	var screen := auto_free(PICK_SCENE.instantiate()) as Control
	add_child(screen)
	await await_idle_frame()
	var buttons := screen.get_node("%Profiles").get_children()
	var profiles := UserSettings.profiles()
	assert_int(buttons.size()).is_equal(profiles.size())
	var active := profiles.find(UserSettings.active_profile())
	for i in profiles.size():
		assert_str((buttons[i] as Button).text).is_equal(UserSettings.display_name(profiles[i]))
	assert_bool((buttons[active] as Button).has_focus()).is_true()


## Nur instanziert, nicht eingehängt: `_ready` fragt ContentService beim Server an.
func test_the_menu_offers_the_switch_instead_of_the_pick() -> void:
	var screen := auto_free(MENU_SCENE.instantiate()) as Control
	assert_object(screen.find_child("ProfileLabel", true, false)).is_not_null()
	assert_object(screen.find_child("SwitchButton", true, false)).is_not_null()
	assert_object(screen.find_child("ProfileSelect", true, false)).is_null()
	assert_object(screen.find_child("NameInput", true, false)).is_null()


func test_the_settings_rename_but_do_not_pick() -> void:
	var screen := auto_free(SETTINGS_SCENE.instantiate()) as Control
	assert_object(screen.find_child("RenameInput", true, false)).is_not_null()
	assert_object(screen.find_child("ProfileSelect", true, false)).is_null()
