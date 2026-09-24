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


## Der Screen hängt in der Bildmitte und wird nicht gescrollt: was über die
## Grundauflösung hinauswächst, hängt aus dem Bild — und ist damit unerreichbar. Genau
## das war der Fall, solange das Niederlage-Label keine Mindestbreite hatte: ein
## umbrechendes Label meldet 1 Pixel Breite und die Höhe für DIESE Breite (1737 px), der
## PageStack nahm sie als Seitenhöhe, und der Menü-Knopf lag 800 Pixel unter dem
## Bildrand. Geprüft wird die Mindestgröße gegen die Grundauflösung des Projekts,
## nicht gegen eine hier hingeschriebene Zahl.
func test_the_defeat_screen_fits_into_the_base_resolution() -> void:
	# Wie im Spiel in einem CanvasLayer: der Screen hängt an den Ankern der Bildmitte
	# und bekommt seine Breite von niemandem vorgegeben. Hängt er dagegen an einem
	# Container, der ihm eine Breite aufzwingt, rechnet ein umbrechendes Label seine
	# Höhe schon aus dieser Breite — dann fällt der Fehler hier gar nicht auf.
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var stats := auto_free(STATS_SCENE.instantiate()) as PanelContainer
	layer.add_child(stats)
	# Mit Kiste, also die volle Ergebnisseite: die Niederlage bringt ihre Beute mit.
	stats.show_stats({"won": false, "wave_number": 3, "difficulty": 3, "correct": 4,
			"leaked": 2, "total": 6, "accuracy": 66.0, "score_gained": 40,
			"score_total": 120, "fortress_health": 0, "mastered": 3, "fortress_tier": 0,
			"chest": ChestReward.for_wave(40, 4, 2),
			# Die Sitzungsbilanz mit einer langen Liste überlanger Einträge: die Bilanz
			# liegt auf Stufe 2 und zählt über den PageStack auch für Stufe 1 (Issue #12).
			"session": _long_balance()})
	for i in 5:
		await get_tree().process_frame
	var base := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	# Je Achse geprüft: `assert_vector(...).is_less_equal(...)` vergleicht Vektoren
	# lexikografisch (Godots `<=`), eine zu hohe Seite wäre über die x-Achse durchgerutscht.
	var min_size := stats.get_combined_minimum_size()
	assert_float(min_size.x).is_less_equal(base.x)
	assert_float(min_size.y).is_less_equal(base.y)


## Dasselbe mit dem Trostwort statt der Kiste: der zweizeilige Titel darf die Seite nicht
## über die Grundauflösung schieben.
func test_the_consolation_screen_fits_into_the_base_resolution() -> void:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	var stats := auto_free(STATS_SCENE.instantiate()) as PanelContainer
	layer.add_child(stats)
	stats.show_stats({"won": false, "wave_number": 3, "difficulty": 3, "correct": 0,
			"leaked": 6, "total": 6, "accuracy": 0.0, "score_gained": 0,
			"score_total": 120, "fortress_health": 0, "mastered": 3, "fortress_tier": 0,
			"chest": ChestReward.for_wave(0, 0, 6), "session": _long_balance()})
	for i in 5:
		await get_tree().process_frame
	var base := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 648)))
	var min_size := stats.get_combined_minimum_size()
	assert_float(min_size.x).is_less_equal(base.x)
	assert_float(min_size.y).is_less_equal(base.y)


func _long_balance() -> Dictionary:
	var words: Array = []
	for i in 30:
		words.append({"label": "wort-%02d mit einem ausgesprochen langen Etikett, " % i
				+ "das weit über die Breite jeder Zeile hinausreicht und nirgends umbricht",
				"misses": 12, "comeback": i % 2 == 0})
	return {"waves_cleared": 99, "wave_reached": 100, "answers": 9999, "correct": 9998,
			"mastered": 30, "comeback": 15, "words": words}
