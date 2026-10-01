extends GdUnitTestSuite
## Feuer der Deko (Fire): die Flamme sitzt, wo das Modell es sagt, Lichter gibt es nur so viele
## wie frei sind.

const BARREL := "res://assets/models/forge/burning_barrel.glb"


func _model() -> Node3D:
	var inst := (load(BARREL) as PackedScene).instantiate() as Node3D
	add_child(inst)
	return auto_free(inst) as Node3D


func test_a_forged_fire_brings_its_marker() -> void:
	var markers := _model().find_children(Fire.MARKER + "*", "Node3D", true, false)
	assert_int(markers.size()).is_equal(1)
	assert_float((markers[0] as Node3D).scale.y).is_greater(0.1)


func test_kindle_lights_a_flame_at_each_marker() -> void:
	var model := _model()
	assert_int(Fire.kindle(model, 5)).is_equal(1)
	var flames := model.find_children("Flame", "Node3D", true, false)
	assert_int(flames.size()).is_equal(1)
	assert_object(flames[0].get_node_or_null("Glow")).is_instanceof(OmniLight3D)


## Ist kein Licht mehr frei, brennt die Flamme trotzdem — nur ohne Licht.
func test_without_a_free_light_the_flame_burns_dark() -> void:
	var model := _model()
	assert_int(Fire.kindle(model, 0)).is_equal(0)
	var flames := model.find_children("Flame", "Node3D", true, false)
	assert_int(flames.size()).is_equal(1)
	assert_object(flames[0].get_node_or_null("Glow")).is_null()


func test_a_model_without_fire_stays_as_it_is() -> void:
	var tree := (load("res://assets/models/forge/pine.glb") as PackedScene).instantiate() as Node3D
	auto_free(tree)
	assert_int(Fire.kindle(tree, 5)).is_equal(0)
	assert_array(tree.find_children("Flame", "", true, false)).is_empty()


func test_fewer_lights_on_weaker_quality() -> void:
	var fine := GraphicsQuality.fire_lights(GraphicsQuality.Level.FINE)
	var medium := GraphicsQuality.fire_lights(GraphicsQuality.Level.MEDIUM)
	assert_int(fine).is_greater(medium)
	assert_int(medium).is_greater(GraphicsQuality.fire_lights(GraphicsQuality.Level.FAST))
