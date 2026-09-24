extends GdUnitTestSuite
## Wo die Units auf der Landkarte liegen — reine Zahlen, dazu ein Blick auf den Screen.
##
## `UnitPath.layout()` rechnet die Plätze; in der Szene stehen keine. Geprüft wird, dass
## sich keine zwei Knoten berühren, dass alles in die Grundbreite passt und dass der Pfad
## ohne Sprung weiterläuft.

const MAP_SCENE := preload("res://scenes/ui/unit_map.tscn")


## Die Breite, die ein Pfad im Vollbild bekommt: Grundbreite minus Bildschirmrand und
## Rinne des Scrollbereichs (siehe CLAUDE.md, „Das Vollbild ist der schmalste Fall").
func _base_width() -> float:
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	return width - 2.0 * 24.0 - 8.0


func test_nodes_do_not_overlap() -> void:
	for count in [1, 5, 12, 30]:
		for width in [200.0, 640.0, _base_width()]:
			var places := UnitPath.layout(count, width)
			assert_int(places.size()).is_equal(count)
			for i in places.size():
				for j in range(i + 1, places.size()):
					var gap := (places[i] as Vector2).distance_to(places[j])
					assert_float(gap).override_failure_message(
							"%d Knoten bei %d px: %d und %d liegen %.0f px auseinander"
							% [count, width, i, j, gap]).is_greater_equal(
							2.0 * UnitPath.NODE_RADIUS + 16.0)


func test_everything_fits_the_base_width() -> void:
	var width := _base_width()
	var places := UnitPath.layout(30, width)
	var height := UnitPath.height_for(30, width)
	for at: Vector2 in places:
		assert_float(at.x - UnitPath.NODE_RADIUS).is_greater_equal(0.0)
		assert_float(at.x + UnitPath.NODE_RADIUS).is_less_equal(width)
		assert_float(at.y - UnitPath.NODE_RADIUS).is_greater_equal(0.0)
		assert_float(at.y + UnitPath.NODE_RADIUS).is_less_equal(height)
	# Die Beschriftung unter dem Knoten ist STEP_X breit — auch sie bleibt in der Fläche.
	assert_float(places.map(func(p): return p.x).min() - UnitPath.STEP_X * 0.5) \
			.is_greater_equal(0.0)


## Aufeinanderfolgende Knoten sind Nachbarn: in der Reihe nebeneinander, am Reihenende
## direkt darunter. Sonst liefe der Pfad quer über die Karte.
func test_the_path_runs_as_a_serpentine() -> void:
	var places := UnitPath.layout(20, 640.0)
	for i in range(1, places.size()):
		var step: Vector2 = places[i] - places[i - 1]
		var sideways := is_equal_approx(absf(step.x), UnitPath.STEP_X) and is_zero_approx(step.y)
		var down := is_zero_approx(step.x) and is_equal_approx(step.y, UnitPath.STEP_Y)
		assert_bool(sideways or down).override_failure_message(
				"Schritt %d -> %d ist %s" % [i - 1, i, step]).is_true()


func test_a_narrow_area_still_gets_one_node_per_row() -> void:
	var places := UnitPath.layout(3, 10.0)
	assert_int(places.size()).is_equal(3)
	assert_float((places[1] as Vector2).y).is_greater((places[0] as Vector2).y)


## Die Karte am Zeiger nennt Stand und Weg zur nächsten Stufe.
func test_the_hint_names_the_next_tier() -> void:
	var map_script: GDScript = load("res://src/ui/unit_map.gd")
	var lines: Dictionary = map_script.hint_lines(
			{"key": "access2/6", "unit": 6, "done": 14, "total": 40, "tier": 2}, "Access 2")
	assert_str(str(lines["title"])).is_equal("Access 2, Unit 6")
	assert_str(str(lines["body"])).contains("14 von 40 Wörtern")
	assert_str(str(lines["body"])).contains("Noch 10 Wörter bis Stufe 3 (+25 HP)")


func test_book_units_are_sorted_by_number() -> void:
	var map_script: GDScript = load("res://src/ui/unit_map.gd")
	var tiers := {
		"access2/10": {"book": "access2", "unit": 10, "done": 0, "total": 1, "tier": 0},
		"access2/2": {"book": "access2", "unit": 2, "done": 0, "total": 1, "tier": 0},
	}
	var shelves: Dictionary = map_script.book_units(tiers)
	assert_array((shelves["access2"] as Array).map(func(u): return u["unit"])).is_equal([2, 10])


## Der Screen lädt auch ohne Sprachdaten und hängt die Auskunft an den Pfad, nicht an die
## Screen-Wurzel.
func test_the_map_screen_loads() -> void:
	var map: Control = auto_free(MAP_SCENE.instantiate())
	add_child(map)
	await get_tree().process_frame
	assert_bool(map.has_meta(Hints.META)).is_false()
	var books := map.get_node("%Books") as VBoxContainer
	for section in books.get_children():
		var path := (section as Node).get_node("Path") as UnitPath
		assert_bool(path.has_meta(Hints.META)).is_true()
