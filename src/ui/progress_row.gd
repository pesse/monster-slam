class_name ProgressRow
extends HBoxContainer
## Eine Fortschrittszeile der Statistik: Bezeichnung links, Balken in der Mitte, Zählung
## rechts — „Access 2, Unit 6 | ████████░░ | 18 von 24" (Issue #8).
##
## Das Layout liegt in progress_row.tscn (im Editor gestaltbar), die Listen befüllen es
## über setup() — dieselbe Aufteilung wie bei StatRow. Der Balken macht aus der Summe ein
## Ziel: „18 von 24" liest man anders als „18 gemeistert".

func setup(name_text: String, done: int, total: int) -> void:
	($Name as Label).text = name_text
	var bar := $Bar as ProgressBar
	# Ohne Wörter kein Balken-Maximum von 0 — der Balken wäre sonst voll statt leer.
	bar.max_value = maxi(1, total)
	bar.value = done
	($Count as Label).text = "%d von %d" % [done, total]
	tooltip_text = "%s — %d von %d Wörtern gemeistert" % [name_text, done, total]
