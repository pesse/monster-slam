extends GdUnitTestSuite
## Die Auflösung schneidet nichts ab — und lässt der Vokabel den Platz.
##
## Die Karte hing in einer Bühne mit fester Größe, und keine ihrer Zeilen brach um:
## eine Aufgabe mit mehreren Alternativantworten (oder eine lange Bedeutung) lief aus
## der Bühne heraus, und die schneidet hart ab (`clip_contents`). Sichtbar war dann die
## halbe Lösung — in einem Screen, der genau dafür da ist, die Lösung zu zeigen.
##
## Geprüft wird deshalb mit dem längsten Inhalt, den die Daten hergeben (gemessen über
## alle Lexeme: Aufgabenzeile bis ~110 Zeichen bei Verwechslungsaufgaben, „auch:"-Zeile
## bis ~60, Bedeutung bis ~100), gegen die ECHTE Bühne aus der Szene — nicht gegen eine
## hier hingeschriebene Zahl.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")

## Füllwörter statt echter Vokabeln: die Sprachdaten liegen im privaten Submodule und
## gehören nicht ins öffentliche Repo. Gebraucht wird hier nur die Länge.
const LONG_PROMPT := "Lorem ipsum dolor sit amet — consetetur oder elitrsed diamnonumy?"
const LONG_ANSWERS := ["consetetur", "elitrsed", "diamnonumy", "eirmodtempor", "invidunt"]
const LONG_MEANING := "consetetur = lorem ipsum / dolor sit amet / consetetur sadipscing elitr"


## Zeigt die Auflösung mit EINER (richtig beantworteten) Vokabel: dieser Weg legt die
## Karte ohne Auto-Durchlauf hin. `play()` wird bewusst nicht erwartet — es wartet am
## Ende auf „Weiter"; hier interessiert nur, was es vorher aufgebaut hat.
func _show_card(item: Dictionary) -> Array:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var reveal := auto_free(REVEAL_SCENE.instantiate()) as PanelContainer
	layer.add_child(reveal)
	reveal.play([item])
	for i in 10:
		await get_tree().process_frame
	var stage := reveal.get_node("%Stage") as Control
	return [reveal, stage.get_child(0) as Control]


func _worst_case_item() -> Dictionary:
	return {
		"prompt": LONG_PROMPT, "answers": LONG_ANSWERS, "lexeme_type": "verb",
		"meaning": LONG_MEANING, "source_id": "zz-test", "learnable_id": "zz-test",
		"leaked": false,
	}


## Die Kernprüfung: die längste denkbare Karte bleibt vollständig in der Bühne.
##
## Zwei Wege hinaus gibt es. Erstens die Karte selbst: `Control.size` wird an der
## Mindestgröße geklemmt, eine zu groß gerechnete Karte bleibt also größer als die
## Bühne, so wie es die umbrechenden Labels ohne RevealCard.set_width() tun (gemessen
## 5881 statt 340 Pixel Höhe). Zweitens der Inhalt in der Karte: die VBox zentriert ihn,
## passt er nicht, rutscht die erste Zeile über die Oberkante und die letzte unter die
## Unterkante — beides schneidet die Bühne ab (`clip_contents`).
func test_the_longest_card_stays_inside_the_stage() -> void:
	var parts := await _show_card(_worst_case_item())
	var stage := (parts[0] as PanelContainer).get_node("%Stage") as Control
	var card := parts[1] as Control
	# Je Achse geprüft: `assert_vector(...).is_less_equal(...)` vergleicht lexikografisch.
	assert_float(card.size.x).is_less_equal(stage.size.x)
	assert_float(card.size.y).is_less_equal(stage.size.y)
	var box := card.get_node("Box") as VBoxContainer
	var first := box.get_child(0) as Control
	var last := box.get_child(box.get_child_count() - 1) as Control
	assert_float(first.position.y).is_greater_equal(0.0)
	assert_float(last.position.y + last.size.y).is_less_equal(box.size.y)


## Umbrechen statt überstehen: die Zeilen mit den Alternativen und der Bedeutung sind
## die langen, und genau sie brauchen `autowrap_mode`. Ohne ihn meldet der Test oben
## nichts — eine Zeile, die seitlich hinausläuft, ist so hoch wie jede andere.
func test_the_long_lines_wrap() -> void:
	var parts := await _show_card(_worst_case_item())
	var card := parts[1] as Control
	for name in ["%Prompt", "%Alt", "%Meaning"]:
		var label := card.get_node(name) as Label
		assert_int(label.autowrap_mode).is_not_equal(TextServer.AUTOWRAP_OFF)
		# Jede Zeile bleibt in der Breite des Labels — sonst schneidet die Bühne sie ab.
		var font := label.get_theme_font("font")
		var size := label.get_theme_font_size("font_size")
		for line in label.text.split("\n"):
			for word in str(line).split(" "):
				assert_float(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) \
						.is_less_equal(label.size.x)


## Der Screen hängt in der Bildmitte und wird nicht gescrollt — was über die
## Grundauflösung hinauswächst, hängt aus dem Bild. Geprüft im breitesten Zustand:
## mit aufgeklapptem Kommentarfeld.
func test_the_reveal_fits_into_the_base_resolution() -> void:
	var parts := await _show_card(_worst_case_item())
	var reveal := parts[0] as PanelContainer
	(reveal.get_node("%FlagInput") as Control).visible = true
	for i in 3:
		await get_tree().process_frame
	var base := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	# Je Achse geprüft: `assert_vector(...).is_less_equal(...)` vergleicht Vektoren
	# lexikografisch, eine zu hohe Seite wäre über die x-Achse durchgerutscht.
	var min_size := reveal.get_combined_minimum_size()
	assert_float(min_size.x).is_less_equal(base.x)
	assert_float(min_size.y).is_less_equal(base.y)


## Der Rand um die Karte herum (Titel, Zähler, Knöpfe) darf ihr nicht den Platz nehmen:
## die Vokabel ist der Inhalt des Screens, alles andere führt nur hin.
func test_the_card_gets_the_larger_half_of_the_screen() -> void:
	var parts := await _show_card(_worst_case_item())
	var reveal := parts[0] as PanelContainer
	var stage := reveal.get_node("%Stage") as Control
	assert_float(stage.size.y).is_greater_equal(reveal.size.y * 0.55)
