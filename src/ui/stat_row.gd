class_name StatRow
extends HBoxContainer
## Eine Zeile der Statistik-Listen: Bezeichnung links, Wert und Markierung rechts.
##
## Das Layout liegt in stat_row.tscn (im Editor gestaltbar), die Listen befüllen es über
## setup() — dieselbe Aufteilung wie bei LegendEntry. Die festen Mindestbreiten von Wert
## und Markierung stehen in der Szene, damit die Spalten über alle Zeilen hinweg
## untereinander stehen.

func setup(name_text: String, value_text: String, mark_text := "") -> void:
	($Name as Label).text = name_text
	($Value as Label).text = value_text
	($Mark as Label).text = mark_text
