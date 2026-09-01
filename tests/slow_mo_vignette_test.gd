extends GdUnitTestSuite
## Tests für die Slow-Mo-Vignette.

const VIGNETTE_SCENE := preload("res://scenes/ui/slow_mo_vignette.tscn")

var _vignette: ColorRect


func before_test() -> void:
	_vignette = auto_free(VIGNETTE_SCENE.instantiate()) as ColorRect
	add_child(_vignette)


func test_hidden_at_normal_speed() -> void:
	assert_bool(_vignette.visible).is_false()


func test_follows_intensity() -> void:
	EventBus.slow_motion_changed.emit(0.6)
	assert_bool(_vignette.visible).is_true()
	assert_float(_shader_strength()).is_equal_approx(0.6, 0.001)


func test_hides_again_at_zero() -> void:
	EventBus.slow_motion_changed.emit(1.0)
	EventBus.slow_motion_changed.emit(0.0)
	assert_bool(_vignette.visible).is_false()


func _shader_strength() -> float:
	return float((_vignette.material as ShaderMaterial).get_shader_parameter("strength"))
