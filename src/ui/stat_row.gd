class_name StatRow
extends HBoxContainer
## Eine Zeile der Statistik-Listen: Bezeichnung links, Wert und Markierung rechts.
##
## Das Layout liegt in stat_row.tscn (im Editor gestaltbar), die Listen befüllen es über
## setup() — dieselbe Aufteilung wie bei LegendEntry. Die festen Mindestbreiten von Wert
## und Markierung stehen in der Szene, damit die Spalten über alle Zeilen hinweg
## untereinander stehen.

## `hint` wird zum Mouseover der ganzen Zeile — dort steht, was in der Zeile nur als
## Zeichen steht (siehe ProgressRow: Haken und Sternchen).
func setup(name_text: String, value_text: String, mark_text := "", hint := "") -> void:
	($Name as Label).text = name_text
	($Value as Label).text = value_text
	($Mark as Label).text = mark_text
	tooltip_text = hint


## Breitere Markierungsspalte für Listen, die dort mehr als ein Zeichen zeigen. Die
## Mindestbreite ist eine Knoten-Eigenschaft und steht sonst in der Szene; hier kommt sie
## von der Liste, weil sie zu deren Inhalt gehört und nicht zur Zeile.
func set_mark_width(px: int) -> void:
	($Mark as Label).custom_minimum_size.x = px
