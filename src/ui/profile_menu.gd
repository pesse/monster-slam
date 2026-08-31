extends Control
## Start-Screen (run/main_scene): Titel, aktive Profilauswahl und Einstieg ins Spiel.
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar); hier wird nur bedient und
## angezeigt. Einstellungen (Profil, Standard-Schwierigkeit, Reset) und Statistik sind in
## den eigenen settings_menu-Screen ausgelagert.

const SESSION_SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"
const CONTENT_SCENE := "res://scenes/ui/content_manager.tscn"

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _name_input: LineEdit = %NameInput
@onready var _update_button: Button = %UpdateButton
@onready var _content_button: Button = %ContentButton


func _ready() -> void:
	(%PlayButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SESSION_SETUP_SCENE))
	(%SettingsButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(SETTINGS_SCENE))
	_profile_select.item_selected.connect(_on_profile_selected)
	_name_input.text_submitted.connect(func(_t): _on_create_profile())
	(%AddButton as Button).pressed.connect(_on_create_profile)
	_update_button.pressed.connect((%UpdateDialog as Control).open)
	_content_button.pressed.connect(func(): get_tree().change_scene_to_file(CONTENT_SCENE))
	UpdateService.changed.connect(_refresh_update_badge)
	ContentService.changed.connect(_refresh_content_badge)
	_refresh_profiles()
	_refresh_update_badge()
	_refresh_content_badge()
	# Beide Kanäle still prüfen: das Abzeichen soll dastehen, ohne dass jemand nachsieht.
	# Netzfehler bleiben in der Konsole (siehe UpdateService._fail / ContentService._fail).
	ContentService.refresh()


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


## Das Abzeichen erscheint nur, wenn es etwas zu tun gibt. Ein Fehlschlag der Prüfung wird
## hier NICHT gezeigt — die Startprüfung soll niemanden mit einem Netzproblem behelligen,
## das ihn nicht betrifft.
func _refresh_update_badge() -> void:
	_update_button.visible = UpdateService.state in [
		UpdateService.State.AVAILABLE,
		UpdateService.State.READY,
	]
	if UpdateService.state == UpdateService.State.READY:
		_update_button.text = "⬆ Update %s bereit" % UpdateService.version
	else:
		_update_button.text = "⬆ Update auf %s" % UpdateService.version


## Zeigt an, wenn Inhalte nachzuziehen sind. „Programm zu alt" zählt hier nicht mit — dagegen
## hilft das Update-Abzeichen, nicht dieses.
func _refresh_content_badge() -> void:
	var count := ContentService.attention_count()
	_content_button.text = "📚 Inhalte (%d neu)" % count if count > 0 else "📚 Inhalte"
