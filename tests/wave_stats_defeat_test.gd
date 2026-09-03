extends GdUnitTestSuite
## Nach einer gefallenen Festung ist der Lauf zu Ende (Issue #2): der Statistik-Screen
## darf dann keine nächste Welle mehr anbieten, sonst startete der Spieler mit 0 HP in
## eine Welle, die der erste Treffer wieder beendet.
##
## Geprüft wird der Screen selbst (show_stats mit won=false/true) — dort sitzt die
## Bedienungsentscheidung; den Riegel dahinter hat WaveRunner._on_next_wave_requested.

const STATS_SCENE := preload("res://scenes/ui/wave_stats.tscn")


func _show(won: bool) -> PanelContainer:
	var stats := auto_free(STATS_SCENE.instantiate()) as PanelContainer
	add_child(stats)  # löst _ready aus
	stats.show_stats({"won": won, "wave_number": 3, "difficulty": 3})
	return stats


func test_defeat_hides_next_wave_controls() -> void:
	var stats := _show(false)
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_false()
	assert_bool((stats.get_node("%ChoiceRow") as HBoxContainer).visible).is_false()
	assert_bool((stats.get_node("%DiffLabel") as Label).visible).is_false()


## Der Weg ins Menü bleibt — sonst gäbe es aus dem Screen keinen Ausgang.
func test_defeat_keeps_menu_button() -> void:
	var stats := _show(false)
	assert_bool((stats.get_node("%MenuButton") as Button).visible).is_true()


func test_victory_offers_next_wave() -> void:
	var stats := _show(true)
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_true()
	assert_bool((stats.get_node("%ChoiceRow") as HBoxContainer).visible).is_true()
	assert_bool((stats.get_node("%DiffLabel") as Label).visible).is_true()


## Ein Sieg nach einer Niederlage im selben Screen-Objekt zeigt die Wahl wieder — die
## Sichtbarkeit hängt am übergebenen Ergebnis, nicht an einem Einbahn-Schalter.
func test_controls_return_after_defeat_screen() -> void:
	var stats := _show(false)
	stats.show_stats({"won": true, "wave_number": 4, "difficulty": 3})
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_true()
