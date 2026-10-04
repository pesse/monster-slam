extends GdUnitTestSuite
## „Wer spielt?" und das Hauptmenü: das Spiel beginnt in der Profilwahl, das Hauptmenü
## zeigt nur, wer spielt, und führt mit „Profil wechseln" zurück. Beide sind Seiten
## desselben Start-Screens (profile_menu.tscn) vor einer Kulisse.
##
## „Weiter" wird hier nicht gedrückt: es schaltet das aktive Profil um — das träfe das
## Entwicklungsprofil.

const PICK_SCENE := preload("res://scenes/ui/profile_pick.tscn")
const MENU_SCENE := preload("res://scenes/ui/profile_menu.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")


func test_the_game_starts_with_the_profile_pick() -> void:
	assert_str(str(ProjectSettings.get_setting("application/run/main_scene"))) \
			.is_equal("res://scenes/ui/profile_menu.tscn")


func test_one_card_per_profile_and_the_last_player_is_selected() -> void:
	var screen := auto_free(PICK_SCENE.instantiate()) as ProfilePick
	add_child(screen)
	await await_idle_frame()
	var cards := screen.get_node("%Profiles").get_children()
	var profiles := UserSettings.profiles()
	assert_int(cards.size()).is_equal(profiles.size())
	for i in profiles.size():
		var card := cards[i] as ProfileCard
		assert_str(card.profile_id).is_equal(profiles[i])
		assert_str((card.get_node("%NameLabel") as Label).text) \
				.is_equal(UserSettings.display_name(profiles[i]))
		assert_bool(card.button_pressed).is_equal(profiles[i] == UserSettings.active_profile())
	assert_str(screen.selected()).is_equal(UserSettings.active_profile())


## Ein Klick auf eine andere Kachel wählt nur — gespielt wird erst mit „Weiter".
func test_a_click_selects_without_switching() -> void:
	var screen := auto_free(PICK_SCENE.instantiate()) as ProfilePick
	add_child(screen)
	await await_idle_frame()
	var active := UserSettings.active_profile()
	var cards := screen.get_node("%Profiles").get_children()
	var picked: Array = []
	screen.picked.connect(func(id): picked.append(id))
	var other := cards[-1] as ProfileCard
	other.button_pressed = true
	assert_str(screen.selected()).is_equal(other.profile_id)
	assert_float((other.get_node("%Selected") as Label).modulate.a).is_equal(1.0)
	assert_array(picked).is_empty()
	assert_str(UserSettings.active_profile()).is_equal(active)


## Nur instanziert, nicht eingehängt: `_ready` fragt ContentService beim Server an.
func test_the_menu_page_offers_the_switch_instead_of_the_pick() -> void:
	var screen := auto_free(MENU_SCENE.instantiate()) as Control
	var page := screen.get_node("%MenuPage") as Control
	var layer := screen.get_node("%BadgeLayer") as Control
	assert_object(layer.find_child("ProfileLabel", true, false)).is_not_null()
	assert_object(layer.find_child("SwitchButton", true, false)).is_not_null()
	assert_array(screen.find_children("*", "ProfileBadge", true, false)).has_size(1)
	assert_object(page.find_child("NameInput", true, false)).is_null()
	assert_object(screen.get_node("%Intro").find_child("NameInput", true, false)).is_not_null()


func test_the_settings_rename_but_do_not_pick() -> void:
	var screen := auto_free(SETTINGS_SCENE.instantiate()) as Control
	assert_object(screen.find_child("RenameInput", true, false)).is_not_null()
	assert_object(screen.find_child("ProfileSelect", true, false)).is_null()


## „Auf Updates prüfen" steht immer unten rechts, unter den beiden Abzeichen (Issue #53).
## Das Menü kommt nicht in den Baum: sein _ready prüft still die Inhalte, und kein Test
## spricht mit dem Netz.
func test_the_update_check_is_always_in_the_menu() -> void:
	var screen := auto_free(MENU_SCENE.instantiate()) as Control
	var link := screen.get_node("%UpdateCheckButton") as Button
	assert_bool(link.visible).is_true()
	assert_str(link.theme_type_variation).is_equal("MenuLink")
	var column := link.get_parent()
	assert_int(link.get_index()).is_equal(column.get_child_count() - 1)
	assert_int(link.get_index()).is_greater(screen.get_node("%ContentUpdateButton").get_index())


func test_the_update_check_says_what_came_out() -> void:
	assert_str(ProfileMenu.update_check_text(false, false, false, false, "1.2.3")) \
			.is_equal("Auf Updates prüfen\nVersion 1.2.3")
	assert_str(ProfileMenu.update_check_text(true, false, false, true, "1.2.3")) \
			.starts_with("Suche nach Updates")
	assert_str(ProfileMenu.update_check_text(false, false, false, true, "1.2.3")) \
			.starts_with("Alles aktuell")
	assert_str(ProfileMenu.update_check_text(false, false, true, true, "1.2.3")) \
			.starts_with("Prüfen ging nicht")
	# Ein Fund steht als Abzeichen darüber — der Link bietet wieder das Prüfen an.
	assert_str(ProfileMenu.update_check_text(false, true, false, true, "1.2.3")) \
			.starts_with("Auf Updates prüfen")
	# Ohne Klick benennt er keinen Fehlschlag der stillen Startprüfung.
	assert_str(ProfileMenu.update_check_text(false, false, true, false, "1.2.3")) \
			.starts_with("Auf Updates prüfen")
