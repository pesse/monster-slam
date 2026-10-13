extends GdUnitTestSuite
## Verdrahtung der Wortart-Outline: ein instanziiertes Monster legt die Outline als
## material_overlay mit der Farbe seiner Wortart auf. Getestet über den Placeholder-Pfad
## (monster_def ohne "model"), damit kein GLB/Skeleton nötig ist. Läuft im vollen
## Projektkontext (Autoloads vorhanden), daher ist EventBus etc. verfügbar.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func test_placeholder_gets_word_type_outline() -> void:
	var monster := auto_free(MONSTER_SCENE.instantiate()) as Monster
	# Leeres monster_def -> Placeholder-Zweig; Wortart "verb".
	monster.setup({}, {"prompt": "gehen", "lexeme_type": "verb"}, 0.0, 40.0)
	add_child(monster)  # löst _ready -> _apply_model aus

	var placeholder := monster.get_node("Placeholder") as MeshInstance3D
	var mat := placeholder.material_overlay as ShaderMaterial
	assert_object(mat).override_failure_message("Kein material_overlay am Placeholder").is_not_null()
	assert_object(mat.shader).is_not_null()
	var col: Color = mat.get_shader_parameter("outline_color")
	assert_bool(col.is_equal_approx(WordTypePalette.color_for("verb"))).override_failure_message(
		"Outline-Farbe %s != verb-Farbe %s" % [col, WordTypePalette.color_for("verb")]
	).is_true()


func test_unknown_type_uses_fallback_color() -> void:
	var monster := auto_free(MONSTER_SCENE.instantiate()) as Monster
	monster.setup({}, {"prompt": "?", "lexeme_type": ""}, 0.0, 40.0)
	add_child(monster)

	var placeholder := monster.get_node("Placeholder") as MeshInstance3D
	var mat := placeholder.material_overlay as ShaderMaterial
	var col: Color = mat.get_shader_parameter("outline_color")
	assert_bool(col.is_equal_approx(WordTypePalette.FALLBACK)).is_true()


## Gemeistert: kein leuchtender Rand, der Körper halb durchsichtig — auf einer Kopie, das
## Material der Szene bleibt deckend.
func test_mastered_monster_is_translucent_without_outline() -> void:
	var monster := auto_free(MONSTER_SCENE.instantiate()) as Monster
	monster.setup({}, {"prompt": "gehen", "lexeme_type": "verb"}, 0.0, 40.0)
	monster.mastered = true
	add_child(monster)

	var placeholder := monster.get_node("Placeholder") as MeshInstance3D
	assert_object(placeholder.material_overlay).is_null()
	var mat := placeholder.get_active_material(0) as BaseMaterial3D
	assert_int(mat.transparency).is_not_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_float(mat.albedo_color.a).is_equal_approx(Monster.MASTERED_ALPHA, 0.001)
	var fresh := MONSTER_SCENE.instantiate() as Monster
	var scene_mat := (fresh.get_node("Placeholder") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	assert_float(scene_mat.albedo_color.a).is_equal(1.0)
	fresh.free()
