extends Control
## „Wer spielt?" (run/main_scene): hier beginnt das Spiel. Ein Knopf je Profil schaltet
## auf dieses Profil und führt ins Hauptmenü (profile_menu); darunter legt man ein neues an.
##
## Das Layout liegt in profile_pick.tscn, ein Profil-Knopf in profile_button.tscn.
## Umbenennen bleibt in den Einstellungen.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const BUTTON_SCENE := preload("res://scenes/ui/profile_button.tscn")

@onready var _profiles: HFlowContainer = %Profiles
@onready var _name_input: LineEdit = %NameInput


func _ready() -> void:
	_name_input.text_submitted.connect(func(_t): _on_create_profile())
	(%AddButton as Button).pressed.connect(_on_create_profile)
	var active := UserSettings.active_profile()
	for id in UserSettings.profiles():
		var button := BUTTON_SCENE.instantiate() as Button
		button.text = UserSettings.display_name(id)
		button.pressed.connect(_play_as.bind(id))
		_profiles.add_child(button)
		# Wer zuletzt gespielt hat, ist vorgewählt: Enter reicht, um weiterzumachen.
		if id == active:
			button.call_deferred("grab_focus")


func _play_as(id: String) -> void:
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	# Geldbörse, Erfahrung und Fähigkeiten schalten über
	# UserSettings.active_profile_changed selbst um (siehe Wallet._ready / PlayerLevel._ready).
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_create_profile() -> void:
	var id := UserSettings.create_profile(_name_input.text)
	if id.is_empty():
		return
	_play_as(id)
