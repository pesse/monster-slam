extends GdUnitTestSuite
## Die Karten: wo das Bild steht, wo die Orte liegen, was sie zeigen, und dass die Screens
## laden (ADR 0006).

const BOOKS_SCENE := preload("res://scenes/ui/book_select.tscn")
const BACKDROP_SCENE := preload("res://scenes/ui/menu_backdrop.tscn")
const BOOK_SCENE := preload("res://scenes/ui/book_map.tscn")
const AREA_SCENE := preload("res://scenes/ui/area_map.tscn")


func after_test() -> void:
	RunRequest.start_expert()


# --- Bildfläche ---------------------------------------------------------------

## Im Fenster (1152×648 abzüglich Rand und Kopf) ist die Höhe knapp: das Bild füllt sie
## und steht mittig.
func test_map_rect_letterboxes_a_wide_area() -> void:
	var rect := MapCanvas.map_rect(Vector2(1104, 540))
	assert_float(rect.size.y).is_equal_approx(540.0, 0.01)
	assert_float(rect.size.x).is_equal_approx(960.0, 0.01)
	assert_float(rect.position.x).is_equal_approx(72.0, 0.01)


func test_map_rect_letterboxes_a_tall_area() -> void:
	var rect := MapCanvas.map_rect(Vector2(640, 600))
	assert_float(rect.size.x).is_equal_approx(640.0, 0.01)
	assert_float(rect.size.y).is_equal_approx(360.0, 0.01)
	assert_float(rect.position.y).is_equal_approx(120.0, 0.01)


## Selbst ausgelegte Orte berühren sich nicht und bleiben mit Beschriftung im Bild — auch
## im schmalsten Fall, dem 16:9-Vollbild mit Rand und Kopfzeile.
func test_default_positions_fit_and_do_not_touch() -> void:
	var rect := MapCanvas.map_rect(Vector2(1104, 540))
	for count in [1, 2, 6, 7, 12, 20]:
		var points := MapCanvas.default_positions(count)
		assert_int(points.size()).is_equal(count)
		var centers := points.map(func(p): return rect.position + (p as Vector2) * rect.size)
		for i in centers.size():
			var c: Vector2 = centers[i]
			assert_bool(rect.grow(-MapCanvas.NODE_RADIUS).has_point(c)).override_failure_message(
					"%d Orte: Ort %d liegt am Rand (%s)" % [count, i, c]).is_true()
			for j in range(i + 1, centers.size()):
				assert_float(c.distance_to(centers[j])).override_failure_message(
						"%d Orte: %d und %d berühren sich" % [count, i, j]
						).is_greater(MapCanvas.NODE_RADIUS * 2.0 + 8.0)


func test_map_points_round_trip() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	canvas.size = Vector2(1104, 540)
	var local := canvas.to_local_point(Vector2(0.25, 0.5))
	assert_vector(canvas.to_map_point(local)).is_equal_approx(Vector2(0.25, 0.5), Vector2(0.001, 0.001))


# --- Punkte aus map.json -----------------------------------------------------

func test_layout_reads_units_areas_and_path() -> void:
	var content := {
		"units": {"2": {"x": 0.4, "y": 0.6}, "3": {"x": "kaputt"}},
		"areas": {"2": {"t1": {"x": 0.1, "y": 0.2}, "boss": {"x": 0.9, "y": 0.8},
				"path": [{"x": 0.0, "y": 0.5}, {"x": 1.0, "y": 0.5}]}},
	}
	assert_dict(MapLayout.unit_points(content)).is_equal({"2": Vector2(0.4, 0.6)})
	assert_dict(MapLayout.area_points(content, 2)).is_equal(
			{"t1": Vector2(0.1, 0.2), "boss": Vector2(0.9, 0.8)})
	assert_int(MapLayout.area_path(content, 2).size()).is_equal(2)
	assert_dict(MapLayout.area_points(content, 7)).is_empty()
	assert_dict(MapLayout.unit_points({})).is_empty()


## Die Buchkarte hat ihren Weg unter "units" — er ist kein Punkt einer Unit.
func test_layout_reads_the_book_path_apart_from_the_units() -> void:
	var content := {"units": {"1": {"x": 0.2, "y": 0.3},
			"path": [{"x": 0.2, "y": 0.3}, {"x": 0.5, "y": 0.5}, {"x": 0.8, "y": 0.4}]}}
	assert_dict(MapLayout.unit_points(content)).is_equal({"1": Vector2(0.2, 0.3)})
	assert_int(MapLayout.book_path(content).size()).is_equal(3)
	assert_array(MapLayout.book_path({})).is_empty()


# --- Weg ------------------------------------------------------------------------

## Die Kurve geht durch jeden Wegpunkt und endet am letzten.
func test_the_smoothed_path_passes_through_every_waypoint() -> void:
	var points := [Vector2(0, 0), Vector2(100, 50), Vector2(200, 0)]
	var line := MapCanvas.smooth_path(points)
	assert_int(line.size()).is_equal(2 * MapCanvas.SMOOTH_STEPS + 1)
	for at in points:
		assert_bool(line.has(at)).is_true()


## Striche und Lücken wechseln über die ganze Linie, nicht je Abschnitt neu.
func test_dashes_run_on_across_segments() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(40, 0)])
	var dashes := MapCanvas.dashes(line, 10.0)
	assert_int(dashes.size()).is_equal(2)
	assert_vector(dashes[1][0]).is_equal(Vector2(20, 0))
	assert_vector(dashes[1][1]).is_equal(Vector2(30, 0))


## Unter dem Zeiger wächst ein Ort auf hover_radius und schrumpft danach wieder.
func test_a_hovered_node_grows_and_shrinks_back() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	add_child(canvas)
	canvas.size = Vector2(1104, 540)
	canvas.node_radius = MapCanvas.AREA_NODE_RADIUS
	canvas.hover_radius = MapCanvas.NODE_RADIUS
	canvas.setup(null, [{"key": "t1", "pos": Vector2(0.5, 0.5)}], [], func(_n): return {})
	canvas._set_hovered(0)
	canvas._process(MapCanvas.HOVER_TIME * 0.5)
	assert_float(canvas.radius_of(0)).is_between(MapCanvas.AREA_NODE_RADIUS + 1.0, MapCanvas.NODE_RADIUS - 1.0)
	canvas._process(MapCanvas.HOVER_TIME)
	assert_float(canvas.radius_of(0)).is_equal_approx(MapCanvas.NODE_RADIUS, 0.01)
	canvas._set_hovered(-1)
	canvas._process(MapCanvas.HOVER_TIME * 2.0)
	assert_float(canvas.radius_of(0)).is_equal_approx(MapCanvas.AREA_NODE_RADIUS, 0.01)
	remove_child(canvas)


## Liegt ein Ort unter dem Kopf oben links, rückt der Kopf nach unten links; liegt keiner
## darunter, bleibt er oben.
func test_the_header_moves_down_when_a_node_lies_under_it() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	parent.size = Vector2(1104, 540)
	var canvas := MapCanvas.new()
	parent.add_child(canvas)
	canvas.size = parent.size
	canvas.node_radius = MapCanvas.AREA_NODE_RADIUS
	canvas.hover_radius = MapCanvas.NODE_RADIUS
	var header := Control.new()
	parent.add_child(header)
	header.custom_minimum_size = Vector2(300, 80)
	header.size = header.custom_minimum_size
	canvas.place_header(header, [Vector2(0.8, 0.8)])
	assert_float(header.position.y).is_equal(0.0)
	canvas.place_header(header, [Vector2(0.05, 0.05), Vector2(0.8, 0.8)])
	assert_float(header.position.y).is_equal_approx(540.0 - 80.0, 0.5)
	remove_child(parent)


## Mit `prefer_bottom` (Gebietskarte) steht der Kopf unten links und rückt nur nach oben,
## wenn unten ein Ort liegt und oben keiner.
func test_a_bottom_header_moves_up_only_when_a_node_lies_under_it() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	parent.size = Vector2(1104, 540)
	var canvas := MapCanvas.new()
	parent.add_child(canvas)
	canvas.size = parent.size
	canvas.node_radius = MapCanvas.AREA_NODE_RADIUS
	canvas.hover_radius = MapCanvas.NODE_RADIUS
	for case in [[[Vector2(0.8, 0.8)], 540.0 - 80.0],
			[[Vector2(0.05, 0.05), Vector2(0.05, 0.95)], 540.0 - 80.0],
			[[Vector2(0.05, 0.95)], 0.0]]:
		var header := Control.new()
		parent.add_child(header)
		header.custom_minimum_size = Vector2(300, 80)
		header.size = header.custom_minimum_size
		canvas.place_header(header, case[0], true)
		assert_float(header.position.y).is_equal_approx(case[1], 0.5)
		header.free()
	remove_child(parent)


## Unten ist auch belegt: dann bleibt der Kopf oben — unten wäre nichts gewonnen.
func test_the_header_stays_when_both_corners_are_taken() -> void:
	var parent: Control = auto_free(Control.new())
	add_child(parent)
	parent.size = Vector2(1104, 540)
	var canvas := MapCanvas.new()
	parent.add_child(canvas)
	canvas.size = parent.size
	var header := Control.new()
	parent.add_child(header)
	header.custom_minimum_size = Vector2(300, 80)
	header.size = header.custom_minimum_size
	canvas.place_header(header, [Vector2(0.05, 0.05), Vector2(0.05, 0.95)])
	assert_float(header.position.y).is_equal(0.0)
	remove_child(parent)


## Der Zoom endet mit zoom_finished; hinein blendet aus, heraus blendet ein.
func test_the_zoom_fades_and_finishes() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	add_child(canvas)
	canvas.size = Vector2(1104, 540)
	canvas.setup(null, [{"key": "b/1", "pos": Vector2(0.3, 0.4)}], [], func(_n): return {})
	canvas.zoom_into("b/1")
	await canvas.zoom_finished
	assert_float(canvas.modulate.a).is_equal_approx(0.0, 0.01)
	canvas.zoom_from()
	await canvas.zoom_finished
	assert_float(canvas.modulate.a).is_equal_approx(1.0, 0.01)
	canvas.zoom_out()
	await canvas.zoom_finished
	assert_float(canvas.modulate.a).is_equal_approx(0.0, 0.01)
	canvas.zoom_back_to(Vector2(0.3, 0.4))
	await canvas.zoom_finished
	assert_float(canvas.modulate.a).is_equal_approx(1.0, 0.01)
	assert_bool(canvas.is_zooming()).is_false()
	remove_child(canvas)


## Ein langer Frame (die nächste Karte wird aufgebaut) schiebt den Zoom nur um einen
## gedeckelten Schritt weiter, statt ihn zu überspringen.
func test_a_long_frame_does_not_skip_the_zoom() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	add_child(canvas)
	canvas.size = Vector2(1104, 540)
	canvas.setup(null, [{"key": "b/1", "pos": Vector2(0.3, 0.4)}], [], func(_n): return {})
	canvas.zoom_from()
	canvas._process(0.5)
	assert_bool(canvas.is_zooming()).is_true()
	assert_float(canvas.modulate.a).is_less(0.6)
	remove_child(canvas)


## Nach dem Zoom springen die Orte der Reihe nach auf: am Anfang ist noch keiner da, der
## zweite kommt nach dem ersten, am Ende stehen alle in voller Größe.
func test_nodes_pop_up_one_after_another() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	add_child(canvas)
	canvas.size = Vector2(1104, 540)
	canvas.setup(null, [{"key": "a", "pos": Vector2(0.3, 0.4)}, {"key": "b", "pos": Vector2(0.6, 0.4)}],
			[], func(_n): return {})
	canvas.appear()
	assert_float(canvas.appear_scale(0)).is_equal(0.0)
	canvas._process(MapCanvas.APPEAR_STAGGER)
	assert_float(canvas.appear_scale(0)).is_greater(0.0)
	assert_float(canvas.appear_scale(1)).is_equal(0.0)
	for i in 20:
		canvas._process(MapCanvas.MAX_ZOOM_STEP)
	assert_float(canvas.appear_scale(0)).is_equal(1.0)
	assert_float(canvas.appear_scale(1)).is_equal(1.0)
	remove_child(canvas)


## Randlos: das Bild deckt die ganze Fläche, mittig und im eigenen Seitenverhältnis.
func test_cover_fills_the_area_and_crops_the_long_side() -> void:
	var rect := MapCanvas.map_rect(Vector2(1152, 648), 1.5, true)
	assert_float(rect.size.x).is_equal_approx(1152.0, 0.01)
	assert_float(rect.size.y).is_equal_approx(768.0, 0.01)
	assert_float(rect.position.y).is_equal_approx(-60.0, 0.01)


## Ein Bild in 3:2 steht in 3:2 da, ohne Bild gilt 16:9.
func test_the_canvas_takes_the_aspect_of_its_image() -> void:
	var canvas: MapCanvas = auto_free(MapCanvas.new())
	assert_float(canvas.aspect()).is_equal_approx(MapCanvas.ASPECT, 0.001)
	var image := Image.create(300, 200, false, Image.FORMAT_RGB8)
	canvas.setup(ImageTexture.create_from_image(image), [], [], func(_n): return {})
	assert_float(canvas.aspect()).is_equal_approx(1.5, 0.001)


# --- Orte ---------------------------------------------------------------------

func test_book_nodes_carry_tier_points_and_medal() -> void:
	var units := [{"key": "b/2", "unit": 2, "done": 3, "total": 10, "tier": 1}]
	var nodes := BookMap.nodes_for("b", units, {"2": Vector2(0.3, 0.4)}, {"b/2": 3})
	assert_vector(nodes[0]["pos"]).is_equal(Vector2(0.3, 0.4))
	assert_int(int(nodes[0]["medal"])).is_equal(2)
	assert_int(int(nodes[0]["tier"])).is_equal(1)
	assert_vector(BookMap.nodes_for("b", units, {}, {})[0]["pos"]).is_equal(Vector2.INF)


## Eine Unit mit Punkt, aber ohne Inhalt steht grau und gesperrt an ihrem Platz in der Reihe.
func test_a_unit_without_content_is_a_grey_locked_point() -> void:
	var units := [{"key": "b/1", "unit": 1, "done": 0, "total": 5, "tier": 0}]
	var nodes := BookMap.nodes_for("b", units, {"1": Vector2(0.2, 0.2), "3": Vector2(0.6, 0.6),
			"2": Vector2(0.4, 0.4)}, {})
	assert_array(nodes.map(func(n): return n["key"])).is_equal(["b/1", "b/2", "b/3"])
	assert_bool(bool(nodes[0].get("disabled", false))).is_false()
	assert_bool(bool(nodes[1]["disabled"])).is_true()
	assert_str(str(BookMap.hint_lines(nodes[2], "B")["body"])).contains("noch keine Wörter")
	# Auch gesperrt zeigt die Karte das Gebiet, sofern es ein Bild hat.
	var locked := BookMap.nodes_for("access3", [], {"2": Vector2(0.5, 0.5)}, {})
	assert_object(BookMap.hint_lines(locked[0], "Access 3")["image"]) \
			.is_same(MapLayout.unit_texture("access3", 2))
	assert_object(BookMap.hint_lines(locked[0], "Access 3")["image"]).is_not_null()


func test_the_book_hint_shows_words_boss_wins_and_a_preview_but_no_fortress() -> void:
	var lines := BookMap.hint_lines(
			{"key": "access4/2", "unit": 2, "done": 14, "total": 40, "tier": 2, "wins": 2}, "Access 4")
	assert_str(str(lines["title"])).is_equal("Access 4, Unit 2")
	assert_str(str(lines["body"])).contains("14 von 40 Wörtern")
	assert_str(str(lines["body"])).contains("2× besiegt")
	assert_str(str(lines["body"])).not_contains("Stufe")
	assert_str(str(lines["body"])).not_contains("🏰")
	assert_object(lines["image"]).is_same(MapLayout.unit_texture("access4", 2))
	assert_object(lines["image"]).is_not_null()


func test_book_units_are_sorted_by_number() -> void:
	var tiers := {
		"access2/10": {"book": "access2", "unit": 10, "done": 0, "total": 1, "tier": 0},
		"access2/2": {"book": "access2", "unit": 2, "done": 0, "total": 1, "tier": 0},
	}
	var shelves := BookMap.book_units(tiers)
	assert_array((shelves["access2"] as Array).map(func(u): return u["unit"])).is_equal([2, 10])


func test_area_nodes_show_tiers_and_lock_a_boss_without_sentences() -> void:
	var levels := MapLevel.levels_for("b", 1, 2)
	var units := {"b/1": {"tier": 2, "done": 5, "total": 10}}
	var parts := {"b/1/1": {"tier": 4, "done": 5, "total": 5}}
	var nodes := AreaMap.nodes_for(levels, units, parts, 5, false, {"t1": Vector2(0.1, 0.1)})
	assert_array(nodes.map(func(n): return n["key"])).is_equal(["t1", "t2", "all", "boss"])
	assert_int(int(nodes[0]["tier"])).is_equal(4)
	assert_vector(nodes[0]["pos"]).is_equal(Vector2(0.1, 0.1))
	assert_int(int(nodes[2]["tier"])).is_equal(2)
	assert_bool(bool(nodes[3]["boss"])).is_true()
	assert_bool(bool(nodes[3]["disabled"])).is_true()
	assert_int(int(nodes[3]["medal"])).is_equal(3)
	assert_str(str(AreaMap.hint_lines(nodes[3])["body"])).contains("keine Sätze")


## Ein Teil zeigt Sterne, Gesamt nur Wörter; von der Festung spricht keiner — sie steht im
## Kopf der Gebietskarte.
func test_level_hints_speak_of_stars_and_never_of_the_fortress() -> void:
	var levels := MapLevel.levels_for("b", 1, 2)
	var units := {"b/1": {"tier": 2, "done": 5, "total": 10}}
	var parts := {"b/1/1": {"tier": 1, "done": 1, "total": 5}}
	var nodes := AreaMap.nodes_for(levels, units, parts, 0, true, {})
	var part := str(AreaMap.hint_lines(nodes[0])["body"])
	assert_str(part).contains("1 von 4 Sternen")
	var whole := str(AreaMap.hint_lines(nodes[2])["body"])
	assert_str(whole).contains("5 von 10")
	assert_str(whole).not_contains("Stern")
	for text in [part, whole]:
		assert_str(text).not_contains("Festung")
		assert_str(text).not_contains("Stufe")
		assert_str(text).not_contains("HP")
	assert_bool(bool(nodes[0].get("stars", true))).is_true()
	assert_bool(bool(nodes[2].get("stars", true))).is_false()


func test_the_fortress_badge_fills_from_one_tier_to_the_next() -> void:
	# 10 Wörter: Stufe 1 ab 1, Stufe 2 ab 4 — mit 2 ist ein Drittel des Wegs geschafft.
	var state := AreaMap.fortress_state({"tier": 1, "done": 2, "total": 10})
	assert_int(int(state["tier"])).is_equal(1)
	assert_str("%s %s %s" % [state["before"], state["count"], state["after"]]).is_equal(
			"Noch 2 Wörter bis Stufe 2")
	assert_float(float(state["share"])).is_equal_approx(1.0 / 3.0, 0.001)
	var top := AreaMap.fortress_state({"tier": 4, "done": 10, "total": 10})
	assert_str(str(top["before"])).is_equal("Höchste Stufe")
	assert_str(str(top["count"])).is_empty()
	assert_float(float(top["share"])).is_equal(1.0)
	assert_int(int(AreaMap.fortress_state({})["tier"])).is_equal(0)


## Jede Stufe hat ihr Bild im Medaillon, gerendert aus derselben Festung wie im Kampf.
func test_every_fortress_tier_has_its_image() -> void:
	for tier in FortressTier.THRESHOLDS_PERCENT.size() + 1:
		var image := AreaMap.fortress_image(tier)
		assert_object(image).override_failure_message("Stufe %d ohne Bild" % tier).is_not_null()
		assert_int(image.get_width()).is_equal(72)
	assert_object(AreaMap.fortress_image(99)).is_same(AreaMap.fortress_image(4))


func test_unit_images_load_ahead_and_stay_the_same_instance() -> void:
	MapLayout.preload_unit_textures("access4", [1, 2, 3, 4])
	var first := MapLayout.unit_texture("access4", 3)
	assert_object(first).is_not_null()
	assert_object(MapLayout.unit_texture("access4", 3)).is_same(first)
	assert_object(MapLayout.unit_texture("access4", 99)).is_null()


func test_the_hint_card_shows_an_image_at_full_width() -> void:
	var card := Hints.card()
	var image := ImageTexture.create_from_image(Image.create(160, 90, false, Image.FORMAT_RGB8))
	card.fill("Titel", "Text", "", [], image)
	var picture := card.get_node("%Image") as TextureRect
	assert_bool(picture.visible).is_true()
	assert_float(card.size.x).is_equal(HintCard.MAX_WIDTH)
	assert_float(picture.custom_minimum_size.y).is_equal_approx(picture.custom_minimum_size.x * 90.0 / 160.0, 0.5)
	card.fill("Titel")
	assert_bool(picture.visible).is_false()
	assert_float(card.size.x).is_less(HintCard.MAX_WIDTH)
	card.hide()


## Hat die Karte mehr Stationen als der Inhalt Teile (Latein: sechs Lektionen je Unit),
## zeigt sie alle; ein Teil ohne Wörter steht gesperrt da und sagt, warum.
func test_an_empty_part_is_shown_locked() -> void:
	var layout := {"areas": {"1": {"t1": {"x": 0.1, "y": 0.1}, "t3": {"x": 0.3, "y": 0.3},
			"all": {"x": 0.5, "y": 0.5}, "boss": {"x": 0.9, "y": 0.9}, "path": []}}}
	assert_int(MapLayout.area_parts(layout, 1)).is_equal(3)
	assert_int(MapLayout.area_parts(layout, 2)).is_equal(0)
	var levels := MapLevel.levels_for("b", 1, 3)
	var parts := {"b/1/2": {"tier": 1, "done": 1, "total": 5}}
	var nodes := AreaMap.nodes_for(levels, {}, parts, 0, true, {})
	assert_bool(bool(nodes[0].get("disabled", false))).is_true()
	assert_bool(bool(nodes[0].get("stars", true))).is_false()
	assert_str(str(AreaMap.hint_lines(nodes[0])["body"])).contains("keine Wörter")
	assert_bool(bool(nodes[1].get("disabled", false))).is_false()


## Latein zählt Lektionen: sechs je Unit, die Gebietskarte hat für jede eine Station —
## auch für die, deren Wörter noch fehlen.
func test_a_latin_unit_shows_all_six_lessons(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	if not "latein" in ContentRegistry.all_books():
		return
	for unit in ContentRegistry.units_for("latein"):
		var levels := MapLevel.levels_for("latein", int(unit),
				AreaMap.part_count("latein", int(unit), MapLayout.data("latein")))
		assert_array(levels.map(func(l): return l["key"])) \
				.is_equal(["t1", "t2", "t3", "t4", "t5", "t6", "all", "boss"])


func test_the_boss_hint_names_the_next_medal() -> void:
	var nodes := AreaMap.nodes_for(MapLevel.levels_for("b", 1, 1), {}, {}, 1, true, {})
	var body := str(AreaMap.hint_lines(nodes[1])["body"])
	assert_str(body).contains("1× besiegt · Bronze")
	assert_str(body).contains("Silber ab 3 Siegen")


func test_book_stats_count_crowns() -> void:
	var units := [
		{"key": "b/1", "unit": 1, "done": 2, "total": 10, "tier": 1},
		{"key": "b/2", "unit": 2, "done": 8, "total": 10, "tier": 3},
	]
	var stats: Dictionary = load("res://src/ui/book_select.gd").stats(units, {"b/2": 1})
	assert_int(int(stats["units"])).is_equal(2)
	assert_int(int(stats["done"])).is_equal(10)
	assert_int(int(stats["total"])).is_equal(20)
	assert_bool(stats.has("lowest")).is_false()
	assert_int(int(stats["crowns"])).is_equal(1)


## Die Profile des Einbands: der Rücken wölbt sich über die Deckel hinaus, und hinter dem
## Scharnier liegt im Deckel die Rinne des Falzes.
func test_the_binding_has_a_round_spine_and_a_groove() -> void:
	var spine := BookMesh.spine_profile(-0.43, 0.12, 0.07, 0.03)
	var xs: Array = Array(spine["points"]).map(func(p): return p.x)
	assert_float(xs.min()).is_equal_approx(-0.5, 0.001)
	var board := BookMesh.board_profile(0.93, 0.03, 0.012, 0.035, 0.012)
	var outer: Array = Array(board["points"]).filter(func(p): return p.x > 0.012 and p.x < 0.047)
	assert_bool(outer.any(func(p): return p.y < 0.03 - 0.01)).is_true()
	var mesh := BookMesh.extrude(board, -0.7, 0.7)
	assert_int(mesh.get_surface_count()).is_equal(1)


## Die Reihe auf dem Pult geht nach Sprache: Englisch zuerst, die übrigen alphabetisch
## danach; innerhalb einer Sprache bleibt die Reihenfolge der Bücher.
func test_each_language_gets_its_own_shelf_row() -> void:
	var language := {"b1": "la", "a1": "en", "a2": "en", "c1": "fr"}
	var rows: Array = load("res://src/ui/book_select.gd").shelf_rows(
			["a1", "b1", "c1", "a2"], func(b): return language[b])
	assert_array(rows).is_equal([["a1", "a2"], ["c1"], ["b1"]])


## Das Cover nennt die Sprache, und ein Buch ohne Boss (Latein, Issue #31) zählt keine
## Bosse, die es nicht gibt.
func test_the_cover_names_the_language_and_a_missing_boss() -> void:
	var book: Book3D = auto_free(load("res://scenes/ui/book_3d.tscn").instantiate())
	add_child(book)
	book.fill("Buch", null, 0, {"units": 2, "done": 0, "total": 10, "crowns": 0,
			"language": "Latein", "bosses": 0})
	assert_str((book.get_node("%Language") as Label).text).is_equal("Latein")
	assert_str((book.get_node("%Crowns") as Label).text).is_equal("Noch kein Bosskampf")
	remove_child(book)


## Auf dem Pult steht das Buch leicht schräg; ausgewählt kommt es nach vorn, steht gerade,
## rückt ein Stück zur Bildmitte und zeigt seinen Stand. Aufgeschlagen steht der Bund dort.
func test_a_selected_book_comes_out_and_turns() -> void:
	var book: Book3D = auto_free(load("res://scenes/ui/book_3d.tscn").instantiate())
	add_child(book)
	book.center_x = 1.0
	book.fill("Buch", null, 0, {"units": 2, "done": 3, "total": 10, "crowns": 1})
	assert_str((book.get_node("%Crowns") as Label).text).contains("1 / 2")
	var body := book.get_node("%Body") as Node3D
	var stats := book.get_node("%Stats") as Control
	# Cover (+Z der Buchlage) um SLOT_ANGLE gedreht, der Stand verborgen.
	assert_float((body.global_basis * Vector3.BACK).z).is_equal_approx(cos(deg_to_rad(Book3D.SLOT_ANGLE)), 0.001)
	assert_float(stats.modulate.a).is_equal(0.0)
	book.set_selected(true)
	for i in 40:
		book._process(0.02)
	assert_float(book.lift).is_equal(1.0)
	assert_float((body.global_basis * Vector3.BACK).z).is_equal_approx(1.0, 0.001)
	assert_float(body.position.z).is_equal_approx(Book3D.PULL, 0.001)
	assert_float(body.position.x).is_equal_approx(Book3D.TOWARD, 0.001)
	assert_float(stats.modulate.a).is_equal(1.0)
	# Aufschlagen: der Deckel geht nach links auf, der Bund steht in der Bildmitte.
	book.open_book()
	for i in 80:
		book._process(0.02)
	assert_bool(book.is_facing()).is_true()
	assert_bool(book.is_spread_open()).is_true()
	var hinge := book.get_node("%Hinge") as Node3D
	assert_float((hinge.global_basis * Vector3.RIGHT).x).is_equal_approx(-1.0, 0.001)
	var bund := body.global_transform * Vector3(Book3D.hinge_x(), 0, 0)
	assert_float(bund.x).is_equal_approx(book.center_x, 0.001)
	# Der Blick ins Buch: mittig vor dem Bund, senkrecht auf die Doppelseite, so nah, dass die
	# Karte an der knapperen Achse gerade randlos ist.
	var view := book.spread_view(40.0, 16.0 / 9.0)
	assert_float(view.origin.x).is_equal_approx(bund.x, 0.001)
	assert_float(view.basis.z.z).is_equal_approx(1.0, 0.001)
	var visible_height := 2.0 * (view.origin.z - bund.z - book.thickness * 0.5 + Book3D.BOARD) * tan(deg_to_rad(20.0))
	assert_float(visible_height).is_less_equal(book.spread_height() + 0.01)
	book.hold_forward(false)
	for i in 80:
		book._process(0.02)
	assert_bool(book.is_spread_open()).is_false()
	book.set_selected(false)
	for i in 40:
		book._process(0.02)
	assert_float(book.lift).is_equal(0.0)
	remove_child(book)


## Gezielt wird auf den Platz in der Reihe: ein Strahl von vorn trifft das schräge Cover,
## daneben nichts. Herausgenommen trifft `hit` weiter den Platz, `hit_body` das Buch vorn.
func test_a_ray_hits_the_book_on_its_place() -> void:
	var book: Book3D = auto_free(load("res://scenes/ui/book_3d.tscn").instantiate())
	add_child(book)
	var on_place := 5.0 - book.thickness * 0.5 / cos(deg_to_rad(Book3D.SLOT_ANGLE))
	assert_float(book.hit(Vector3(0, 0, 5), Vector3.FORWARD)).is_equal_approx(on_place, 0.001)
	assert_float(book.hit(Vector3(1, 0, 5), Vector3.FORWARD)).is_equal(INF)
	book.set_selected(true)
	for i in 40:
		book._process(0.02)
	assert_float(book.hit(Vector3(0, 0, 5), Vector3.FORWARD)).is_equal_approx(on_place, 0.001)
	assert_float(book.hit_body(Vector3(0, 0, 5), Vector3.FORWARD)) \
			.is_equal_approx(5.0 - Book3D.PULL - book.thickness * 0.5, 0.001)
	remove_child(book)


## Jede Seite der Reihe steht mittig auf dem Pult, auch eine letzte, nicht volle.
func test_each_page_of_the_row_is_centered() -> void:
	var slot_x := BookSelect.slot_x
	var width := BookSelect.SLOT_WIDTH
	assert_float(slot_x.call(0, 1)).is_equal_approx(0.0, 0.001)
	assert_float(slot_x.call(0, 4) + slot_x.call(3, 4)).is_equal_approx(0.0, 0.001)
	# Die zweite Seite beginnt eine Seitenbreite weiter; zwei Bücher darauf stehen um ihre Mitte.
	var page := BookSelect.SLOTS * width
	assert_float(slot_x.call(BookSelect.SLOTS, 2) - page).is_equal_approx(-width * 0.5, 0.001)
	assert_float(slot_x.call(BookSelect.SLOTS + 1, 2) - page).is_equal_approx(width * 0.5, 0.001)


# --- Screens ------------------------------------------------------------------

## Die Screens laden auch ohne Sprachdaten; die Auskunft hängt an der Karte, nicht an der
## Screen-Wurzel.
func test_the_map_screens_load_with_hints_on_the_canvas() -> void:
	MapSelection.book = "zz-kein-buch"
	MapSelection.unit = 1
	for scene in [BOOK_SCENE, AREA_SCENE]:
		var screen: Control = auto_free((scene as PackedScene).instantiate())
		add_child(screen)
		await get_tree().process_frame
		assert_bool(screen.has_meta(Hints.META)).is_false()
		assert_bool((screen.get_node("%Canvas") as Control).has_meta(Hints.META)).is_true()
		remove_child(screen)


## Auf der Gebietskarte sind die Orte klein und der Weg kommt aus dem Bild; die Buchkarte
## hat dieselben kleinen Orte, aber ihren gestrichelten Weg.
func test_the_area_map_draws_small_bare_nodes_without_its_own_path() -> void:
	MapSelection.book = "zz-kein-buch"
	MapSelection.unit = 1
	var area: Control = auto_free(AREA_SCENE.instantiate())
	add_child(area)
	await get_tree().process_frame
	var canvas := area.get_node("%Canvas") as MapCanvas
	assert_float(canvas.node_radius).is_equal(MapCanvas.AREA_NODE_RADIUS)
	assert_float(canvas.hover_radius).is_equal(MapCanvas.NODE_RADIUS)
	assert_bool(canvas.path_over_image).is_false()
	assert_bool(canvas.show_captions).is_false()
	assert_bool(canvas.cover).is_true()
	remove_child(area)
	var book: Control = auto_free(BOOK_SCENE.instantiate())
	add_child(book)
	await get_tree().process_frame
	var book_canvas := book.get_node("%Canvas") as MapCanvas
	assert_float(book_canvas.node_radius).is_equal(MapCanvas.AREA_NODE_RADIUS)
	assert_float(book_canvas.hover_radius).is_equal(MapCanvas.NODE_RADIUS)
	assert_bool(book_canvas.show_captions).is_false()
	remove_child(book)


## Das Level des letzten Kampfes bleibt in RunRequest stehen. Der Zoom aus der Buchkarte
## zeigt trotzdem die angeklickte Unit, nicht die zuletzt gespielte — nur der Rückweg aus
## dem Kampf nimmt sie aus RunRequest.
func test_the_area_map_shows_the_clicked_unit_not_the_last_played() -> void:
	RunRequest.start_level({"book": "zz-alt", "unit": 2, "key": "t1"})
	MapSelection.book = "zz-neu"
	MapSelection.unit = 1
	MapSelection.zoom_in = true
	var area: Control = auto_free(AREA_SCENE.instantiate())
	add_child(area)
	assert_str(MapSelection.book).is_equal("zz-neu")
	assert_int(MapSelection.unit).is_equal(1)
	remove_child(area)
	MapSelection.zoom_in = false
	MapSelection.zoom_out = true
	var back: Control = auto_free(AREA_SCENE.instantiate())
	add_child(back)
	assert_str(MapSelection.book).is_equal("zz-alt")
	assert_int(MapSelection.unit).is_equal(2)
	remove_child(back)
	MapSelection.zoom_out = false


## Hat eine Gebietskarte ein Bild, sitzt jedes ihrer Level auf einem gesetzten Punkt —
## sonst legte die Karte alle Orte selbst aus, quer über das Bild.
func test_every_area_image_has_a_point_for_every_level(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for book in ContentRegistry.all_books():
		var layout := MapLayout.data(book)
		for unit in ContentRegistry.units_for(book):
			if MapLayout.unit_texture(book, int(unit)) == null:
				continue
			var points := MapLayout.area_points(layout, int(unit))
			for level in MapLevel.levels_for(book, int(unit), ContentRegistry.parts_for(book, int(unit))):
				assert_bool(points.has(str(level["key"]))) \
						.override_failure_message("%s Unit %d: kein Punkt für %s" % [book, int(unit), level["key"]]) \
						.is_true()


## Die Bibliothek stellt ihre Bücher in den Turm der Menü-Kulisse. Nach dem Hereinfahren
## ist keines herausgenommen — das tut erst die Maus (oder ←/→).
func test_the_library_fills_the_tower_and_takes_no_book_out() -> void:
	var backdrop: MenuBackdrop = auto_free(BACKDROP_SCENE.instantiate())
	add_child(backdrop)
	var screen: BookSelect = auto_free(BOOKS_SCENE.instantiate())
	add_child(screen)
	screen.setup(backdrop)
	screen.enter()
	await get_tree().process_frame
	var books := backdrop.library_books()
	assert_int(books.get_child_count()).is_equal(ContentRegistry.all_books().size())
	for book: Book3D in books.get_children():
		assert_bool(book.selected).is_false()
	remove_child(screen)
	remove_child(backdrop)


## Mit Sprachdaten zeigt eine echte Unit ihre Level.
func test_a_real_unit_has_its_levels(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var book := ContentRegistry.all_books()[0]
	var unit := int(ContentRegistry.units_for(book)[0])
	var levels := MapLevel.levels_for(book, unit, ContentRegistry.parts_for(book, unit))
	assert_int(levels.size()).is_equal(6)
	var scoped := ContentRegistry.lexemes_scoped(levels[0]["scope"], [])
	assert_bool(scoped.is_empty()).is_false()


## Jedes Level jeder echten Unit gibt dem Kampf etwas zu tun, und in einem Buch mit Sätzen
## hat jeder Boss welche. Ein Buch ganz ohne Sätze (Latein, Issue #31) zeigt den Boss
## gesperrt — das ist kein Datenfehler einer Unit.
func test_every_real_level_is_playable(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	var generator := WaveGenerator.new()
	for book in ContentRegistry.all_books():
		var has_sentences := ContentRegistry.units_for(book).any(
				func(u): return AreaMap.has_boss_sentences(book, int(u)))
		for unit in ContentRegistry.units_for(book):
			for level in MapLevel.levels_for(book, int(unit), ContentRegistry.parts_for(book, int(unit))):
				# Ein Teil ohne Wörter steht gesperrt auf der Karte (Latein: Unit 2 beginnt
				# mit Lektion 10, ihrem vierten Teil).
				if str(level["kind"]) == MapLevel.KIND_PART \
						and not ContentRegistry.part_has_words(book, int(unit), int(level["part"])):
					continue
				RunRequest.start_level(level)
				if str(level["kind"]) == MapLevel.KIND_BOSS:
					if not has_sentences:
						continue
					assert_bool(AreaMap.has_boss_sentences(book, int(unit))).override_failure_message(
							"%s/%s: Boss ohne Sätze" % [book, unit]).is_true()
				else:
					assert_bool(generator.has_playable(RunRequest.task_pool())).override_failure_message(
							"%s/%s %s: nichts spielbar" % [book, unit, level["key"]]).is_true()


## Ort und Festung sind EIN Schild unten in der Mitte; unten rechts stehen nur der
## Ich-Sicht-Schalter und „Spielen", gleich hoch, der Schalter direkt davor.
func test_place_and_fortress_share_one_plate_and_the_toggle_sits_before_play() -> void:
	MapSelection.book = "zz-kein-buch"
	MapSelection.unit = 1
	var area: Control = auto_free(AREA_SCENE.instantiate())
	add_child(area)
	await get_tree().process_frame
	await get_tree().process_frame
	var plate := area.get_node("%Plate") as Control
	assert_bool(plate.is_ancestor_of(area.get_node("%Title"))).is_true()
	assert_bool(plate.is_ancestor_of(area.get_node("%FortressBar"))).is_true()
	var p := plate.get_global_rect()
	assert_float(p.get_center().x).is_equal_approx(area.get_global_rect().get_center().x, 1.0)
	var toggle := area.get_node("%FirstPersonToggle") as Button
	var play := area.get_node("%PlayButton") as Control
	# Der Testlauf ist ein Debug-Build: der Schalter steht immer da.
	assert_bool(toggle.visible).is_true()
	assert_object(toggle.get_parent()).is_same(play.get_parent())
	assert_int(play.get_index()).is_equal(toggle.get_index() + 1)
	var t := toggle.get_global_rect()
	var r := play.get_global_rect()
	assert_float(t.size.y).is_equal_approx(r.size.y, 0.5)
	assert_float(t.position.y).is_equal_approx(r.position.y, 0.5)
	assert_float(r.position.x - t.end.x).is_less_equal(8.0)
	# Das Schild in der Mitte und die Knöpfe rechts überdecken sich nicht.
	assert_float(p.end.x).is_less_equal(t.position.x)
	remove_child(area)


## Ein Klick markiert nur; „Spielen" ganz unten rechts ist ohne Auswahl gesperrt und
## startet erst mit einer.
func test_a_click_marks_and_play_sits_right_of_the_fortress() -> void:
	MapSelection.book = "zz-kein-buch"
	MapSelection.unit = 1
	var area: AreaMap = auto_free(AREA_SCENE.instantiate())
	add_child(area)
	await get_tree().process_frame
	await get_tree().process_frame
	var play := area.get_node("%PlayButton") as Button
	assert_object(play.get_parent()).is_same(area.get_node("%BottomRight"))
	assert_int(play.get_index()).is_equal(play.get_parent().get_child_count() - 1)
	assert_bool(play.disabled).is_true()
	area._levels = MapLevel.levels_for("zz-kein-buch", 1, 4)
	area._on_level_clicked("t2")
	area._on_level_clicked("t3")
	var canvas := area.get_node("%Canvas") as MapCanvas
	assert_bool(canvas.is_selected("t2")).is_true()
	assert_bool(canvas.is_selected("t3")).is_true()
	assert_bool(play.disabled).is_false()
	assert_bool(RunRequest.is_level()).is_false()
	assert_str(str(Hints.hint_of(play).get("body", ""))).contains("Teil 2 + 3")
	area._on_level_clicked("all")
	assert_bool(canvas.is_selected("t2")).is_false()
	assert_bool(canvas.is_selected("all")).is_true()
	area._on_level_clicked("all")
	assert_bool(play.disabled).is_true()
	remove_child(area)


## Der Bosskampf hat keine Ich-Sicht: ist der Boss markiert, ist der Schalter gesperrt —
## nicht versteckt, die Ecke behält ihre Größe.
func test_the_first_person_toggle_is_locked_for_the_boss() -> void:
	MapSelection.book = "zz-kein-buch"
	MapSelection.unit = 1
	var area: AreaMap = auto_free(AREA_SCENE.instantiate())
	add_child(area)
	await get_tree().process_frame
	var toggle := area.get_node("%FirstPersonToggle") as Button
	area._levels = MapLevel.levels_for("zz-kein-buch", 1, 4)
	assert_bool(toggle.disabled).is_false()
	area._select(["boss"])
	assert_bool(toggle.disabled).is_true()
	assert_bool(toggle.visible).is_true()
	area._select(["t1"])
	assert_bool(toggle.disabled).is_false()
	remove_child(area)


## Nach dem Kampf steht die gespielte Auswahl wieder markiert da.
func test_the_last_run_comes_back_marked() -> void:
	RunRequest.start_level(MapLevel.combine(MapLevel.levels_for("zz-kein-buch", 1, 4), ["t2", "t3"]))
	assert_array(AreaMap.played_keys()).is_equal(["t2", "t3"])
	RunRequest.start_level({"book": "b", "unit": 1, "key": "t1"})
	assert_array(AreaMap.played_keys()).is_equal(["t1"])
