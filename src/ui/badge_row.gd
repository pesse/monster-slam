class_name BadgeRow
extends HBoxContainer
## Eine Zeile der Plaketten-Sammlung in der Statistik: links Name und Stand, rechts die
## Plaketten der Art (`BadgeChip`).

const CHIP_SCENE := preload("res://scenes/ui/badge_chip.tscn")


func setup(title: String, detail: String) -> void:
	(%Name as Label).text = title
	(%Detail as Label).text = detail


func add_chip() -> BadgeChip:
	var chip := CHIP_SCENE.instantiate() as BadgeChip
	(%Chips as Container).add_child(chip)
	return chip
