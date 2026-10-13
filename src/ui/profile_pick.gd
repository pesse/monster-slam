class_name ProfilePick
extends Control
## „Wer spielt?": die erste Seite des Start-Screens. Eine Kachel je Profil, das zuletzt
## gespielte ist vorgewählt; darunter legt man ein neues an. Die Seite schaltet selbst nichts
## um, sie meldet nur `picked`.

## Dieses Profil soll spielen (bestehend oder eben angelegt).
signal picked(id: String)

const CARD_SCENE := preload("res://scenes/ui/profile_card.tscn")

@onready var _profiles: HFlowContainer = %Profiles
@onready var _name_input: LineEdit = %NameInput
@onready var _next: Button = %NextButton

var _group := ButtonGroup.new()


func _ready() -> void:
	_name_input.text_submitted.connect(func(_t): _on_create_profile())
	(%AddButton as Button).pressed.connect(_on_create_profile)
	_next.pressed.connect(_on_next)
	refresh()


## Baut die Kacheln neu (Level und Namen können sich geändert haben), vorgewählt ist das
## aktive Profil.
func refresh() -> void:
	for card in _profiles.get_children():
		_profiles.remove_child(card)
		card.queue_free()
	var active := UserSettings.active_profile()
	for id in UserSettings.profiles():
		var card := CARD_SCENE.instantiate() as ProfileCard
		card.setup(id, PlayerLevel.level_of(id))
		card.button_group = _group
		card.button_pressed = id == active
		_profiles.add_child(card)
	_name_input.clear()


## Enter reicht, um als der zuletzt Spielende weiterzumachen.
func focus_next() -> void:
	_next.grab_focus()


func selected() -> String:
	var card := _group.get_pressed_button() as ProfileCard
	return card.profile_id if card != null else UserSettings.active_profile()


func _on_next() -> void:
	picked.emit(selected())


func _on_create_profile() -> void:
	var id := UserSettings.create_profile(_name_input.text)
	if id.is_empty():
		return
	picked.emit(id)
