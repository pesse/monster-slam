extends Control
## Start-Screen (run/main_scene): Titel, aktive Profilauswahl und Einstieg ins Spiel.
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar); hier wird nur bedient und
## angezeigt. Einstellungen (Profil, Standard-Schwierigkeit, Reset) und Statistik sind in
## den eigenen settings_menu-Screen ausgelagert.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _name_input: LineEdit = %NameInput


func _ready() -> void:
	(%PlayButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SESSION_SETUP_SCENE))
	(%SettingsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SETTINGS_SCENE))
	_profile_select.item_selected.connect(_on_profile_selected)
	_name_input.text_submitted.connect(func(_t): _on_create_profile())
	(%AddButton as Button).pressed.connect(_on_create_profile)
	_refresh_profiles()


func _refresh_profiles() -> void:
	_profile_select.clear()
	var active := UserSettings.active_profile()
	var profiles := UserSettings.profiles()
	for i in profiles.size():
		# Anzeigename im Dropdown, player_id als Metadaten (für die Auswahl-Rückabbildung).
		_profile_select.add_item(UserSettings.display_name(profiles[i]))
		_profile_select.set_item_metadata(i, profiles[i])
		if profiles[i] == active:
			_profile_select.select(i)


func _on_profile_selected(index: int) -> void:
	var id := str(_profile_select.get_item_metadata(index))
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)


func _on_create_profile() -> void:
	var id := UserSettings.create_profile(_name_input.text)
	if id.is_empty():
		return
	_name_input.clear()
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	_refresh_profiles()
