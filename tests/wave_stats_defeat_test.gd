extends GdUnitTestSuite
## Nach einer gefallenen Festung ist der Lauf zu Ende (Issue #2): der Wellenabschluss
## darf dann keine nächste Welle mehr anbieten, sonst startete der Spieler mit 0 HP in
## eine Welle, die der erste Treffer wieder beendet.
##
## Geprüft wird der Screen selbst (show_stats mit won=false/true) — dort sitzt die
## Bedienungsentscheidung; den Riegel dahinter hat WaveRunner._on_next_wave_requested.
## Die Wahl steht in der zweiten Stufe, deshalb wird bis dorthin durchgeklickt (siehe
## wave_stats_stages_test.gd für den Ablauf selbst).

const STATS_SCENE := preload("res://scenes/ui/wave_stats.tscn")


## Zeigt den Screen und blättert auf die zweite Stufe — ohne Kiste (kein Gold) ist der
## Weiter-Knopf sofort offen, das ist hier der kürzeste Weg.
func _show_last_stage(won: bool) -> PanelContainer:
	var stats := auto_free(STATS_SCENE.instantiate()) as PanelContainer
	add_child(stats)  # löst _ready aus
	stats.show_stats({"won": won, "wave_number": 3, "difficulty": 3})
	(stats.get_node("%ResultContinue") as Button).pressed.emit()
	return stats


func test_defeat_hides_next_wave_controls() -> void:
	var stats := _show_last_stage(false)
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_false()
	assert_bool((stats.get_node("%ChoiceRow") as HBoxContainer).visible).is_false()
	assert_bool((stats.get_node("%DiffLabel") as Label).visible).is_false()
	# Statt der Wahl steht da, dass der Lauf zu Ende ist — eine leere Stufe wäre eine
	# Sackgasse ohne Begründung.
	assert_bool((stats.get_node("%DefeatLabel") as Label).visible).is_true()


## Der Weg ins Menü bleibt — sonst gäbe es aus dem Screen keinen Ausgang.
func test_defeat_keeps_menu_button() -> void:
	var stats := _show_last_stage(false)
	assert_bool((stats.get_node("%MenuButton") as Button).visible).is_true()


func test_victory_offers_next_wave() -> void:
	var stats := _show_last_stage(true)
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_true()
	assert_bool((stats.get_node("%ChoiceRow") as HBoxContainer).visible).is_true()
	assert_bool((stats.get_node("%DiffLabel") as Label).visible).is_true()
	assert_bool((stats.get_node("%DefeatLabel") as Label).visible).is_false()


## Ein Sieg nach einer Niederlage im selben Screen-Objekt zeigt die Wahl wieder — die
## Sichtbarkeit hängt am übergebenen Ergebnis, nicht an einem Einbahn-Schalter.
func test_controls_return_after_defeat_screen() -> void:
	var stats := _show_last_stage(false)
	stats.show_stats({"won": true, "wave_number": 4, "difficulty": 3})
	(stats.get_node("%ResultContinue") as Button).pressed.emit()
	assert_bool((stats.get_node("%StartButton") as Button).visible).is_true()
