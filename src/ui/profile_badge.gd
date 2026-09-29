class_name ProfileBadge
extends PanelContainer
## Wer spielt, oben rechts in Hauptmenü und Bibliothek (scenes/ui/profile_badge.tscn):
## Büste, Name, Level und ein Balken mit dem Stand im Level, darunter „Profil wechseln".
## Eine Szene für beide Screens, damit die Plakette überall gleich aussieht.
##
## Was „Profil wechseln" tut, entscheidet der Screen (`switch_pressed`).

signal switch_pressed

@onready var _profile_label: Label = %ProfileLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel


func _ready() -> void:
	(%SwitchButton as Button).pressed.connect(switch_pressed.emit)
	PlayerLevel.changed.connect(func(_total_xp, _level): refresh())
	refresh()


## Liest Name und Erfahrung des aktiven Profils neu — nach einem Profilwechsel.
func refresh() -> void:
	_profile_label.text = UserSettings.display_name()
	var progress := PlayerLevel.progress()
	var in_level := int(progress["xp_in_level"])
	var for_up := int(progress["xp_for_level_up"])
	_level_label.text = "Level %d" % int(progress["level"])
	_xp_bar.max_value = maxi(for_up, 1)
	_xp_bar.value = in_level
	_xp_label.text = "%d / %d XP" % [in_level, for_up]
