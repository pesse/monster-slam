class_name ProfileCard
extends Button
## Eine Kachel in „Wer spielt?" (profile_pick): Büste, Name und Level eines Profils.
## Gewählt ist die Kachel golden und die Büste farbig, sonst silbern.
##
## „✓ Ausgewählt" steht auf jeder Kachel und wird nur sichtbar geschaltet — so behält die
## Kachel ihre Höhe, wenn die Wahl wechselt.

var profile_id := ""

@onready var _bust: TextureRect = %Bust
@onready var _silver: Material = _bust.material


func _ready() -> void:
	toggled.connect(_show_selected)
	_show_selected(button_pressed)


## Vor dem Einhängen aufrufen; `level` kommt von PlayerLevel.level_of.
func setup(id: String, level: int) -> void:
	profile_id = id
	(get_node("%NameLabel") as Label).text = UserSettings.display_name(id)
	(get_node("%LevelLabel") as Label).text = "Level %d" % level


func _show_selected(on: bool) -> void:
	_bust.material = null if on else _silver
	(%Selected as Label).modulate.a = 1.0 if on else 0.0
