class_name HintCard
extends PanelContainer
## Die Karte am Zeiger — im ganzen Spiel dieselbe.
##
## Sie kennt vier Teile und sonst nichts: Überschrift, Text, Liste, Nachsatz. Was leer
## ist, steht nicht da. Die Liste ist eine echte Tabelle (Zeichen | Bezeichnung | Wert) und
## kein Text mit „·" dazwischen: eine Aufzählung liest man Zeile für Zeile, und die Werte
## sollen untereinander stehen, damit man sie vergleichen kann. Sie weiß nicht, ob sie einen Fähigkeitsknoten, eine Wortzeile oder eine
## Schatzkiste erklärt — das ist genau der Grund, aus dem es sie nur einmal gibt. Was in
## ihr steht, entscheidet die Stelle, die sie anmeldet (`Hints.attach`); Regeln wie
## `SkillTree.state_label` bleiben dort, wo sie hingehören.
##
## Gehalten wird sie vom Autoload `Hints`, das sie über allem einblendet und dem Zeiger
## nachführt. Godots eigener Tooltip erscheint verzögert, bleibt stehen, wo er aufgegangen
## ist, und bringt die Typografie der Engine mit — diese Karte erscheint sofort, folgt dem
## Zeiger und kommt aus dem Theme.

## So breit wie ihr Text, höchstens so breit: gut ein Viertel der Grundauflösung (1152).
## Darüber wird aus einer Auskunft am Zeiger ein Absatz quer über das Bild.
const MAX_WIDTH := 320.0
## Und mindestens so breit: „Umlernen" allein wäre sonst ein Stummel, und beim Streichen
## über ein Netz zappelte die Karte bei jedem Knoten auf eine andere Breite.
const MIN_WIDTH := 140.0

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _note: Label = %Note
@onready var _list: GridContainer = %List


## Trägt die vier Teile ein und stellt die Karte auf die Breite ein, die ihr Text braucht.
##
## Nur an einer EINGEHÄNGTEN Karte aufrufen: `update_minimum_size()` steigt ohne Baum aus,
## und dann misst `_fit()` einen alten Stand. `Hints` hängt sie beim Start ein, also immer
## erfüllt — deshalb gibt es hier kein Merken-und-später-eintragen mehr.
##
## `list` ist ein Array von Zeilen, jede `[zeichen, bezeichnung, wert]`; ein leeres Zeichen
## lässt die Spalte in dieser Zeile frei, die Bezeichnungen stehen trotzdem untereinander.
func fill(title: String, body := "", note := "", list := []) -> void:
	# Eine leere Zeile verschwindet, statt eine leere Zeile zu hinterlassen: die Karte für
	# eine Münze ist eine Zeile hoch und kein Kasten mit Luft.
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	_note.text = note
	_note.visible = not note.is_empty()
	_fill_list(list)
	_fit()


## Die Zellen kommen bei jedem Aufruf neu: eine Karte zeigt mal zwei, mal sechs Zeilen.
## `remove_child` vor `queue_free`, sonst misst `_fit()` die alten Zellen noch mit.
func _fill_list(list: Array) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for row in list:
		for i in 3:
			var cell := Label.new()
			cell.theme_type_variation = &"Hint"
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.text = str(row[i]) if i < row.size() else ""
			if i == 2:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_list.add_child(cell)
	_list.visible = not list.is_empty()


## Die Bezeichnungen der Liste — die mittlere Spalte, die einzige, die umbrechen darf.
## Zeichen und Werte sind kurz und bleiben einzeilig, damit sie in einer Flucht stehen.
func _list_names() -> Array:
	var names := []
	var cells := _list.get_children()
	for i in range(1, cells.size(), 3):
		names.append(cells[i])
	return names


## Breite der Liste ohne ihre mittlere Spalte: Zeichen, Werte und die zwei Abstände.
func _list_frame_width() -> float:
	var cells := _list.get_children()
	var mark := 0.0
	var value := 0.0
	for i in range(0, cells.size(), 3):
		mark = maxf(mark, (cells[i] as Control).get_combined_minimum_size().x)
		value = maxf(value, (cells[i + 2] as Control).get_combined_minimum_size().x)
	return mark + value + 2.0 * _list.get_theme_constant("h_separation")


## Die Breitenregel, in der einzigen Reihenfolge, in der sie funktioniert.
##
## Ein `Label` mit `autowrap_mode` meldet als Mindestbreite 1 Pixel und dazu die Höhe, die
## der Text bei EINEM Pixel Breite braucht (CLAUDE.md, dieselbe Falle wie bei
## `RevealCard.set_width()`). Man kann also nicht in einem Zug fragen, wie breit der Text
## gern wäre und wie hoch er dann wird. Zum MESSEN wird der Umbruch deshalb abgeschaltet.
func _fit() -> void:
	var labels := [_title, _body, _note]
	var names := _list_names()
	# 1. Ohne Umbruch messen — und die Breite des VORIGEN Aufrufs vorher weg. Ohne diese
	#    Null wäre jede Karte so breit wie die breiteste, die je zu sehen war.
	for label: Label in labels + names:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0.0
	# Gemessen wird an der Tafel, der Innenabstand aus `PanelContainer/styles/panel` steckt
	# also schon drin. Mehrzeilige Hinweise messen sich über ihre längste Zeile.
	var outer := clampf(get_combined_minimum_size().x, MIN_WIDTH, MAX_WIDTH)
	var inner := outer - get_theme_stylebox("panel").get_minimum_size().x
	# 2. Umbruch wieder an und die Breite in die Labels DRÜCKEN, bevor jemand nach der
	#    Höhe fragt. `size.x` löst den Umbruch aus, `custom_minimum_size.x` hält ihn, wenn
	#    der Container gleich neu sortiert — beides, nicht eins von beidem.
	for label: Label in labels:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = inner
		label.size.x = inner
	# Die Bezeichnungen der Liste bekommen, was neben Zeichen und Werten übrig bleibt —
	# damit rücken die Werte zugleich an den rechten Rand, in eine Flucht.
	var name_width := maxf(0.0, inner - _list_frame_width())
	for label: Label in names:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = name_width
		label.size.x = name_width
	# 3. Den Umbruch JETZT erzwingen. `get_minimum_size()` rechnet ihn NICHT nach — es gibt
	#    den Stand der letzten Umbruchrechnung zurück, und die lief noch mit der Breite von
	#    vorhin. `get_line_count()` bricht dagegen sofort um; ohne diese Schleife meldete
	#    die Karte die Höhe für die Breite der VORIGEN Karte (beim ersten Mal: für einen
	#    Pixel, also 2056 statt 133).
	for label: Label in labels + names:
		label.get_line_count()
	# 4. Erst jetzt die Höhe lesen: sie ist für DIESE Breite gerechnet.
	size = Vector2(outer, get_combined_minimum_size().y)
