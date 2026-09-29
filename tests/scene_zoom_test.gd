extends GdUnitTestSuite
## Der Zoom zwischen Karte und Kampf (SceneZoom): der Schleier geht und kommt, die Szene
## bekommt ihren Anteil, und ein langer Frame überspringt nichts.

const SCENE := preload("res://scenes/ui/scene_zoom.tscn")


func test_reveal_lifts_the_veil_and_hands_the_scene_its_share() -> void:
	var zoom: SceneZoom = auto_free(SCENE.instantiate())
	add_child(zoom)
	var seen: Array = []
	zoom.reveal(func(k: float) -> void: seen.append(k))
	var veil := zoom.get_node("Veil") as ColorRect
	assert_float(veil.modulate.a).is_equal(1.0)
	zoom.advance(10.0)
	assert_bool(zoom.is_running()).is_true()
	assert_float(veil.modulate.a).is_greater(0.0)
	for i in 20:
		zoom.advance(MapCanvas.MAX_ZOOM_STEP)
	assert_bool(zoom.is_running()).is_false()
	assert_float(veil.modulate.a).is_equal(0.0)
	assert_float(float(seen.back())).is_equal(1.0)
	remove_child(zoom)


func test_cover_darkens_and_then_says_so() -> void:
	var zoom: SceneZoom = auto_free(SCENE.instantiate())
	add_child(zoom)
	zoom.cover()
	var done := [false]
	zoom.finished.connect(func() -> void: done[0] = true)
	for i in 20:
		zoom.advance(MapCanvas.MAX_ZOOM_STEP)
	assert_bool(done[0]).is_true()
	assert_float((zoom.get_node("Veil") as ColorRect).modulate.a).is_equal(1.0)
	remove_child(zoom)


## Vor dem Einblenden bleibt es dunkel, solange die Szene hinter dem Schleier vorwärmt.
func test_hold_keeps_the_veil_closed_until_reveal() -> void:
	var zoom: SceneZoom = auto_free(SCENE.instantiate())
	add_child(zoom)
	zoom.hold()
	var veil := zoom.get_node("Veil") as ColorRect
	assert_float(veil.modulate.a).is_equal(1.0)
	assert_bool(zoom.is_running()).is_false()
	await get_tree().process_frame
	assert_float(veil.modulate.a).is_equal(1.0)
	remove_child(zoom)
