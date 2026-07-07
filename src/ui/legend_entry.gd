class_name LegendEntry
extends HBoxContainer
## Ein Eintrag der Wortart-Legende: Farb-Swatch + Name. Das Layout liegt in
## legend_entry.tscn (im Editor gestaltbar); die Legende befüllt Farbe & Text via setup().

func setup(color: Color, text: String) -> void:
	($Swatch as ColorRect).color = color
	($Label as Label).text = text
