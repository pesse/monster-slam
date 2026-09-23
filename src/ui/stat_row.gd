class_name StatRow
extends HBoxContainer
## Eine Zeile der Statistik-Listen: Bezeichnung links, Wert und Markierung rechts.
##
## Das Layout liegt in stat_row.tscn (im Editor gestaltbar), die Listen befüllen es über
## setup() — dieselbe Aufteilung wie bei LegendEntry. Die festen Mindestbreiten von Wert
## und Markierung stehen in der Szene, damit die Spalten über alle Zeilen hinweg
## untereinander stehen.

## `hint` wird zur Karte am Zeiger — dort steht, was in der Zeile nur als Zeichen steht
## (siehe ProgressRow: Haken und Sternchen). Die Bezeichnung trägt die Karte als
## Überschrift, der Hinweis muss sie also nicht wiederholen. `hint_list` ist eine
## Aufzählung in der Karte, Zeilen `[zeichen, bezeichnung, wert]` (siehe `HintCard`).
##
## Angehängt wird an die ZEILE und nicht an ihre Labels: die Suche geht von dem, was unter
## dem Zeiger liegt, nach oben (`Hints`), und die Karte soll über der ganzen Zeile stehen.
func setup(name_text: String, value_text: String, mark_text := "", hint := "",
		hint_list := []) -> void:
	($Name as Label).text = name_text
	($Value as Label).text = value_text
	($Mark as Label).text = mark_text
	var has_hint := not hint.is_empty() or not hint_list.is_empty()
	Hints.attach(self, name_text if has_hint else "", hint, "", hint_list)


## Breitere Markierungsspalte für Listen, die dort mehr als ein Zeichen zeigen. Die
## Mindestbreite ist eine Knoten-Eigenschaft und steht sonst in der Szene; hier kommt sie
## von der Liste, weil sie zu deren Inhalt gehört und nicht zur Zeile.
func set_mark_width(px: int) -> void:
	($Mark as Label).custom_minimum_size.x = px
