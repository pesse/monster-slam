class_name StatRow
extends HBoxContainer
## Eine Zeile der Statistik-Listen: Bezeichnung links, Wert und Markierung rechts.
## Layout und Spaltenbreiten in stat_row.tscn.

## `hint` wird zur Karte am Zeiger mit der Bezeichnung als Überschrift; `hint_list` sind
## Zeilen `[zeichen, bezeichnung, wert]` (siehe `HintCard`). Angehängt an die ganze Zeile.
func setup(name_text: String, value_text: String, mark_text := "", hint := "",
		hint_list := []) -> void:
	($Name as Label).text = name_text
	($Value as Label).text = value_text
	($Mark as Label).text = mark_text
	var has_hint := not hint.is_empty() or not hint_list.is_empty()
	Hints.attach(self, name_text if has_hint else "", hint, "", hint_list)


## Breitere Markierungsspalte für Listen, die dort mehr als ein Zeichen zeigen.
func set_mark_width(px: int) -> void:
	($Mark as Label).custom_minimum_size.x = px
