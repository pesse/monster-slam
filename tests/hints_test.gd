extends GdUnitTestSuite
## Die Auskunft am Zeiger: eine Karte für das ganze Spiel.
##
## Geprüft wird an ERFUNDENEN Controls — die Karte kennt keine Knoten, keine Wortzeilen und
## keine Schatzkisten, nur Zeichenketten. Was an den einzelnen Stellen darin steht, prüfen
## deren eigene Suiten.
##
## Gefahren wird über `Hints.probe()` und nicht mit echten Mausereignissen: Godot befördert
## in der kopflosen Betriebsart keine Eingaben, `gui_get_hovered_control()` bliebe also
## immer leer. Was damit NICHT geprüft ist, ist die Trefferprüfung der Engine — dass sie
## auch einen gesperrten Knopf meldet, tut sie im Spiel längst (Godots eigener Tooltip hing
## bis hierher genau daran). Alles andere ist geprüft: die Suche nach oben, die
## Breitenregel, das Umklappen am Rand, das Abmelden, die lebende Fläche.

var _root: Control


func before_test() -> void:
	_root = auto_free(Control.new())
	_root.size = Vector2(400, 300)
	add_child(_root)


func after_test() -> void:
	Hints.card().hide()


## Zeiger auf eine Stelle des BILDES, über dem Control, das dort liegt. Kein `await`: das
## ist die Zusage — die Karte ist da, sobald die Maus da ist.
func _move_to(control: Control, at: Vector2) -> HintCard:
	Hints.probe(control, at)
	return Hints.card()


func _over(control: Control) -> HintCard:
	return _move_to(control, control.get_global_rect().get_center())


func _button(text: String, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(120, 40)
	_root.add_child(button)
	button.size = Vector2(120, 40)
	return button


func _text(card: HintCard, part: String) -> String:
	return (card.get_node("%" + part) as Label).text


# --- Anmelden und Zeigen ------------------------------------------------------

func test_a_control_with_a_hint_shows_its_card() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text")
	var card := _over(button)
	assert_bool(card.visible).is_true()
	assert_str(_text(card, "Title")).is_equal("Titel")
	assert_str(_text(card, "Body")).is_equal("Text")


## Was leer ist, steht nicht da — sonst wäre die Karte einer Münze ein Kasten mit Luft.
func test_an_empty_line_takes_no_room() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text", "Nachsatz")
	var full := _over(button).size.y
	Hints.attach(button, "Titel")
	assert_float(_over(button).size.y).is_less(full)
	assert_bool((Hints.card().get_node("%Body") as Label).visible).is_false()


## Ein durchweg leerer Hinweis IST das Abmelden: Dutzende Statistikzeilen bekommen gar
## keinen, und die Münzen aus der Kiste auch nicht.
func test_an_empty_hint_shows_nothing() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text")
	assert_bool(_over(button).visible).is_true()
	Hints.attach(button, "")
	assert_bool(_over(button).visible).is_false()
	assert_dict(Hints.hint_of(button)).is_empty()


func test_leaving_the_control_hides_the_card() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text")
	assert_bool(_over(button).visible).is_true()
	assert_bool(_move_to(_root, Vector2(2, 2)).visible).is_false()


## Ein GESPERRTER Knopf muss sagen dürfen, warum er gesperrt ist — im Fähigkeiten-Screen
## steht das ausschließlich in seiner Karte. `disabled` fasst weder `mouse_filter` noch die
## Trefferprüfung an, aber geglaubt wird das hier nicht, sondern gefahren.
func test_a_disabled_button_still_speaks() -> void:
	var button := _button("↺", true)
	Hints.attach(button, "Umlernen", "noch nichts gelernt")
	var card := _over(button)
	assert_bool(card.visible).is_true()
	assert_str(_text(card, "Body")).contains("nichts gelernt")


## Die Suche geht nach OBEN weiter, wo Godots eigene am ersten `MOUSE_FILTER_STOP`-Kind
## abbricht. Genau deshalb reicht ab jetzt EIN Hinweis, wo die Fortschrittszeile ihren
## vorher zweimal setzen musste — einmal für sich und einmal für ihren Knopf.
func test_a_hint_on_a_row_covers_its_button() -> void:
	var row := VBoxContainer.new()
	_root.add_child(row)
	row.size = Vector2(200, 60)
	var inner := Button.new()
	inner.custom_minimum_size = Vector2(200, 60)
	row.add_child(inner)
	Hints.attach(row, "Zeile", "Text der Zeile")
	var card := _over(inner)
	assert_bool(card.visible).is_true()
	assert_str(_text(card, "Title")).is_equal("Zeile")


## Hängt an beiden etwas, gewinnt das NÄHERE: die Suche hört beim ersten Treffer auf.
func test_the_nearest_hint_wins() -> void:
	var row := VBoxContainer.new()
	_root.add_child(row)
	row.size = Vector2(200, 60)
	var inner := Button.new()
	inner.custom_minimum_size = Vector2(200, 60)
	row.add_child(inner)
	Hints.attach(row, "Zeile")
	Hints.attach(inner, "Knopf")
	assert_str(_text(_over(inner), "Title")).is_equal("Knopf")


## Eine Fläche, die ihre Treffer selbst sucht, antwortet selbst — und ein leeres Ergebnis
## heißt wirklich nichts, nicht „frag weiter oben".
func test_a_live_surface_answers_for_itself() -> void:
	Hints.attach(_root, "Hintergrund", "sollte verdeckt bleiben")
	var area := Control.new()
	area.custom_minimum_size = Vector2(200, 100)
	_root.add_child(area)
	area.size = Vector2(200, 100)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	Hints.attach_live(area, func(local: Vector2) -> Dictionary:
			if local.x < 100.0:
				return {"title": "links"}
			return {})
	assert_str(_text(_move_to(area, area.global_position + Vector2(10, 10)), "Title")
			).is_equal("links")
	assert_bool(_move_to(area, area.global_position + Vector2(150, 10)).visible).is_false()


## Ein freigegebenes Control lässt nichts zurück. Es gibt keine Liste, aus der es
## auszutragen wäre: die Auskunft hängt als Meta AN ihm und stirbt mit ihm — und gefragt
## wird, was unter dem Zeiger liegt, nicht was sich einmal angemeldet hat.
func test_a_freed_control_leaves_nothing_behind() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text")
	assert_bool(_over(button).visible).is_true()
	button.queue_free()
	await get_tree().process_frame
	# Nach dem Freigeben liegt dort nichts mehr — genau das meldet der Viewport im Spiel,
	# und genau das reicht der Karte als Antwort.
	assert_bool(_move_to(_root, Vector2(2, 2)).visible).is_false()


# --- Maß ----------------------------------------------------------------------

## So breit wie ihr Text: ein Dreiworthinweis ist kein Brett über ein Viertel des Bildes.
func test_a_short_hint_is_no_slab() -> void:
	var button := _button("A")
	Hints.attach(button, "Umlernen")
	assert_float(_over(button).size.x).is_less(HintCard.MAX_WIDTH)


func test_a_long_hint_stops_at_the_maximum() -> void:
	var button := _button("A")
	Hints.attach(button, "Ein langer Titel", " ".join(_many_words()))
	assert_float(_over(button).size.x).is_equal(HintCard.MAX_WIDTH)


## Und er wächst in die BREITE bis zum Deckel und danach in die Höhe — nicht andersherum.
## Ohne die Mess-Reihenfolge in `HintCard._fit()` käme hier die Höhe für EINEN Pixel Breite
## heraus, also ein paar tausend (CLAUDE.md, dieselbe Falle wie bei der Reveal-Karte).
## Die Achsen einzeln, weil `assert_vector(...).is_less_equal(...)` lexikografisch
## vergleicht.
func test_a_long_hint_wraps_instead_of_growing_tall() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", " ".join(_many_words()))
	var card := _over(button)
	assert_float(card.size.x).is_less_equal(HintCard.MAX_WIDTH)
	assert_float(card.size.y).is_less(400.0)


## Der Wächter gegen die Breite, die vom letzten Mal hängen bleibt: ohne das Zurücksetzen
## der Label-Mindestbreite wäre jede Karte so breit wie die breiteste, die je zu sehen war.
func test_the_width_does_not_stick_from_the_last_card() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", " ".join(_many_words()))
	var wide := _over(button).size.x
	Hints.attach(button, "Kurz")
	assert_float(_over(button).size.x).is_less(wide)


## Und die HÖHE hängt nicht an der Karte davor. Das ist eine eigene Falle neben der
## Breite: `Label.get_minimum_size()` rechnet den Umbruch NICHT nach, sondern gibt den
## Stand der letzten Rechnung zurück — die noch mit der Breite der vorigen Karte lief.
## Ohne das erzwungene Umbrechen in `HintCard._fit()` meldete die Statistik-Wortzeile
## 2056 statt 133 Pixel Höhe, und die Karte hing weit außerhalb des Bildes.
##
## Geprüft wird das an DEMSELBEN Text zweimal hintereinander: beim zweiten Mal stimmt die
## Breite der Labels zufällig schon, beim ersten Mal nicht. Wer nur zwei verschiedene Texte
## abwechselt, sieht den Fehler nicht — beide sind dann gleich falsch (gemessen: 201 statt
## 109 Pixel, aber jedes Mal 201).
func test_the_height_does_not_lag_behind_the_last_card() -> void:
	var button := _button("A")
	var long_text := "Übersetzung:  de→en 90 %   ·   en→de 63 %\n★ Vergangenheit — 85 %"
	Hints.attach(button, "Titel", "geübt")
	var flat := _over(button).size
	Hints.attach(button, "Titel", long_text)
	var first := _over(button).size
	Hints.attach(button, "Titel", long_text)
	assert_vector(_over(button).size).is_equal(first)
	# Und der breitere Text ist auch der höhere — die Karte wächst mit ihrem Inhalt.
	assert_float(first.x).is_greater(flat.x)
	assert_float(first.y).is_greater(flat.y)


## Eine Aufzählung steht als Tabelle da: je Zeile eine Reihe, die Werte rechtsbündig in
## EINER Flucht. Vorher klebten die Richtungen mit „·" in einer Zeile zusammen.
func test_a_list_is_set_as_a_table() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "", "", [
		["✓", "Übersetzung de→en", "90 %"],
		["", "Übersetzung en→de", "noch nicht geübt"],
		["★", "Vergangenheit", "85 %"],
	])
	var card := _over(button)
	var list := card.get_node("%List") as GridContainer
	# Drei Spalten, also je Eintrag eine Reihe. Die Lage selbst sortiert der Container
	# erst im nächsten Frame; hier zählt, dass die Zellen in dieser Ordnung dastehen.
	assert_int(list.columns).is_equal(3)
	var cells := list.get_children()
	assert_int(cells.size()).is_equal(9)
	assert_str((cells[3] as Label).text).is_equal("")
	assert_str((cells[4] as Label).text).is_equal("Übersetzung en→de")
	assert_str((cells[5] as Label).text).is_equal("noch nicht geübt")
	for i in [2, 5, 8]:
		assert_int((cells[i] as Label).horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_RIGHT)


## Eine lange Bezeichnung bricht in ihrer Spalte um, statt die Karte breiter zu machen —
## und die Karte ist hoch genug für den Umbruch.
func test_a_long_list_entry_wraps_inside_the_card() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "", "", [["☆", " ".join(_many_words()), "85 %"]])
	var card := _over(button)
	assert_float(card.size.x).is_equal(HintCard.MAX_WIDTH)
	var list := card.get_node("%List") as Control
	assert_float(list.get_combined_minimum_size().x).is_less_equal(HintCard.MAX_WIDTH)
	assert_float(card.size.y).is_greater_equal(list.get_combined_minimum_size().y)


## Ohne Liste steht auch keine leere Tabelle in der Karte.
func test_no_list_no_table() -> void:
	var button := _button("A")
	Hints.attach(button, "Titel", "Text", "", [["✓", "x", "1 %"]])
	_over(button)
	Hints.attach(button, "Titel", "Text")
	assert_bool((_over(button).get_node("%List") as Control).visible).is_false()


func _many_words() -> PackedStringArray:
	var words := PackedStringArray()
	for i in 40:
		words.append("Silbenwort")
	return words


# --- Platz --------------------------------------------------------------------

## Am Rand klappt die Karte auf die andere Seite des Zeigers. Eine halb abgeschnittene
## Auskunft ist keine.
func test_the_card_stays_inside_the_screen() -> void:
	Hints.attach(_root, "Titel", "Ein Text, der ein paar Zeilen breit werden darf.")
	var room := get_viewport().get_visible_rect().size
	for at: Vector2 in [Vector2(2, 2), Vector2(room.x - 2, 2), Vector2(2, room.y - 2),
			room - Vector2(2, 2)]:
		var card := _move_to(_root, at)
		assert_bool(card.visible).is_true()
		assert_float(card.position.x).is_greater_equal(0.0)
		assert_float(card.position.y).is_greater_equal(0.0)
		assert_float(card.position.x + card.size.x).is_less_equal(room.x)
		assert_float(card.position.y + card.size.y).is_less_equal(room.y)


## Sie folgt dem Zeiger, statt an einer festen Stelle zu kleben.
func test_the_card_follows_the_pointer() -> void:
	Hints.attach(_root, "Titel", "Text")
	var first := _move_to(_root, Vector2(100, 100)).position
	assert_vector(_move_to(_root, Vector2(140, 130)).position).is_not_equal(first)


## Die Karte darf die Maus NIE fangen: sie läge sonst im nächsten Frame selbst unter dem
## Zeiger, versteckte sich, käme wieder — sechzigmal in der Sekunde.
func test_the_card_does_not_catch_the_mouse() -> void:
	assert_int(Hints.card().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Sie liegt über allem, was die Szenen selbst mitbringen — der Wellenabschluss samt
## Schatzkiste hängt in der UI-Schicht des Kampfes.
func test_the_layer_lies_above_the_scenes() -> void:
	var battle: PackedScene = load("res://scenes/battle/battle.tscn")
	var state := battle.get_state()
	for i in state.get_node_count():
		if state.get_node_type(i) != &"CanvasLayer":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"layer":
				assert_int(int(state.get_node_property_value(i, p))).is_less(Hints.LAYER)
	assert_int(Hints.LAYER).is_greater(1)
