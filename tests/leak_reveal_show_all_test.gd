extends GdUnitTestSuite
## „Alle anzeigen" in der Vokabel-Auflösung ist immer bedienbar.
##
## play() sperrte den Knopf für den Auto-Durchlauf und gab ihn danach nicht wieder frei:
## nach jeder Welle mit Durchgelassenen stand er grau da. Jetzt bleibt er auch während des
## Durchlaufs frei und hängt die richtigen hinten an — der Durchlauf über die
## durchgelassenen läuft dabei unverändert zu Ende.

const REVEAL_SCENE := preload("res://scenes/ui/leak_reveal.tscn")


func _item(id: String, leaked: bool) -> Dictionary:
	return {
		"prompt": "Frage %s" % id, "answers": ["antwort"], "lexeme_type": "noun",
		"source_id": "zz-%s" % id, "learnable_id": "zz-%s" % id, "leaked": leaked,
	}


func _reveal() -> PanelContainer:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var reveal := auto_free(REVEAL_SCENE.instantiate()) as PanelContainer
	layer.add_child(reveal)
	# Nicht erwartet: play() wartet am Ende auf „Weiter".
	reveal.play([_item("a", true), _item("b", false)])
	await get_tree().process_frame
	await get_tree().process_frame
	return reveal


## Wartet, bis der Durchlauf vorbei ist („Weiter" wird frei). Die Timer laufen headless
## nach Wanduhr — ein Durchlauf über eine Karte dauert gut vier Sekunden.
func _await_autoplay(reveal: PanelContainer) -> void:
	var cont := reveal.get_node("%ContinueBtn") as Button
	var until := Time.get_ticks_msec() + 10000
	while cont.disabled and Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_show_all_is_usable_after_the_autoplay() -> void:
	var reveal := await _reveal()
	await _await_autoplay(reveal)
	var show_all := reveal.get_node("%ShowAllBtn") as Button
	assert_bool(show_all.visible).is_true()
	assert_bool(show_all.disabled).is_false()


func test_show_all_during_the_autoplay_appends_without_interrupting() -> void:
	var reveal := await _reveal()
	var show_all := reveal.get_node("%ShowAllBtn") as Button
	var next := reveal.get_node("%NextBtn") as Button
	assert_bool(show_all.disabled).is_false()
	show_all.pressed.emit()
	# Der Zähler kennt schon beide Karten, die Pfeile bleiben während des Durchlaufs zu.
	assert_str((reveal.get_node("%Progress") as Label).text).is_equal("Karte 1 / 2")
	assert_bool(next.disabled).is_true()
	assert_bool(show_all.visible).is_false()
	await _await_autoplay(reveal)
	# Der Durchlauf endet bei der durchgelassenen, danach geht es zur richtigen weiter.
	assert_bool((reveal.get_node("%ContinueBtn") as Button).disabled).is_false()
	assert_bool(next.disabled).is_false()
