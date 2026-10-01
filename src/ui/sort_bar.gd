class_name SortBar
extends HBoxContainer
## Die kleine Sortierwahl über den Wortlisten der Statistik: „Beste zuerst",
## „Schwächste zuerst", „A–Z". Das Layout liegt in sort_bar.tscn; die Reihenfolge der
## Knöpfe ist die von `StatsScreen.SortMode`.
##
## Die Leiste sortiert nicht selbst, sie meldet nur die Wahl — die Regel steht einmal in
## `StatsScreen.sort_rows`.

signal changed(mode: int)

@onready var _buttons: Array[Button] = [$Best as Button, $Weakest as Button, $Alpha as Button]


func _ready() -> void:
	for i in _buttons.size():
		var mode := i
		_buttons[i].pressed.connect(func() -> void: changed.emit(mode))
	Hints.attach($Best as Control, "Beste zuerst",
			"Was am sichersten sitzt, steht oben. Noch nicht Geübtes steht immer am Ende.")
	Hints.attach($Weakest as Control, "Schwächste zuerst",
			"Woran gerade am meisten zu holen ist, steht oben. Noch nicht Geübtes steht "
			+ "immer am Ende.")
	Hints.attach($Alpha as Control, "Alphabetisch", "Nach dem Wort sortiert.")


## Drückt den Knopf zu `mode`, ohne `changed` zu melden. Alle Knöpfe einzeln, weil
## `set_pressed_no_signal` die übrigen der ButtonGroup nicht löst.
func set_mode(mode: int) -> void:
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == mode)
