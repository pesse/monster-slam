extends GdUnitTestSuite
## Bäume und Gras schwanken im Wind (Wind.sway), ohne anders auszusehen und ohne die
## geladenen, geteilten Materialien anzufassen.


func _model(path: String) -> Node3D:
	return auto_free((load("%s/%s" % [BattleTheme.MODEL_DIR, path]) as PackedScene).instantiate())


func _meshes(node: Node3D) -> Array[Node]:
	return node.find_children("*", "MeshInstance3D", true, false)


func test_a_tree_gets_the_wind_shader_with_its_colors() -> void:
	var tree := _model("forge/pine.glb")
	Wind.sway(tree, "forge/pine.glb")
	for mi: MeshInstance3D in _meshes(tree):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			assert_object(mat).is_not_null()
			assert_object(mat.shader).is_same(Wind.SHADER)
			assert_that(mat.get_shader_parameter("albedo")).is_equal(src.albedo_color)
			assert_float(mat.get_shader_parameter("sway")).is_greater(0.0)


## Das Material im Mesh bleibt, was es war: es ist geladen und damit geteilt.
func test_the_loaded_material_stays_untouched() -> void:
	var tree := _model("forge/pine.glb")
	var mi := _meshes(tree)[0] as MeshInstance3D
	var before := mi.mesh.surface_get_material(0)
	Wind.sway(tree, "forge/pine.glb")
	assert_object(mi.mesh.surface_get_material(0)).is_same(before)
	assert_object(before).is_instanceof(BaseMaterial3D)


## Ein Wald teilt sich die Materialien: gleiche Quelle, gleiche Stärke, ein Material.
func test_two_trees_share_their_wind_material() -> void:
	var a := _model("forge/pine.glb")
	var b := _model("forge/pine.glb")
	Wind.sway(a, "forge/pine.glb")
	Wind.sway(b, "forge/pine.glb")
	var ma := (_meshes(a)[0] as MeshInstance3D).get_surface_override_material(0)
	var mb := (_meshes(b)[0] as MeshInstance3D).get_surface_override_material(0)
	assert_object(ma).is_same(mb)


## Häuser stehen in manchen Themen im Platz `trees` — sie schwanken nicht.
func test_a_house_stands_still() -> void:
	var house := _model("forge/roman_house.glb")
	Wind.sway(house, "forge/roman_house.glb")
	for mi: MeshInstance3D in _meshes(house):
		for s in mi.mesh.get_surface_count():
			assert_object(mi.get_surface_override_material(s)).is_null()


func test_without_wind_nothing_changes() -> void:
	var tree := _model("forge/pine.glb")
	Wind.sway(tree, "forge/pine.glb", 0.0)
	assert_object((_meshes(tree)[0] as MeshInstance3D).get_surface_override_material(0)).is_null()


## Laub mit Alpha-Textur (die gekauften Bäume) behält seine Durchsicht, zweiseitige
## Flächen (Palmwedel) ihre Rückseite.
func test_alpha_and_double_sided_surfaces_keep_their_mode() -> void:
	for path: String in ["props/tree.glb", "forge/palm.glb"]:
		var tree := _model(path)
		Wind.sway(tree, path)
		for mi: MeshInstance3D in _meshes(tree):
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
				var shader := (mi.get_surface_override_material(s) as ShaderMaterial).shader
				if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					assert_object(shader).is_same(Wind.SHADER_ALPHA)
				elif src.cull_mode == BaseMaterial3D.CULL_DISABLED:
					assert_object(shader).is_same(Wind.SHADER_DOUBLE)
				else:
					assert_object(shader).is_same(Wind.SHADER)
