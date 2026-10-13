class_name LegendEntry
extends HBoxContainer
## Ein Eintrag der Wortart-Legende: Farbraute und Name.

func setup(color: Color, text: String) -> void:
	($Swatch as Diamond).color = color
	($Label as Label).text = text
