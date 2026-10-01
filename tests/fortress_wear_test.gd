extends GdUnitTestSuite
## Die Festung vom Krieg gezeichnet (BattleTheme.fortress_wear, FortressModel.wear_down).


func _build(wear: float) -> Node3D:
	var root := auto_free(Node3D.new()) as Node3D
	FortressModel.build(root, 4, 0.0, func(_x: float, _z: float) -> float: return 0.0,
			FortressModel.SCALE, wear)
	return root


func _meshes(root: Node3D) -> Array[Node]:
	return root.find_children("*", "MeshInstance3D", true, false)


func test_without_wear_the_pack_material_stays() -> void:
	for mi: MeshInstance3D in _meshes(_build(0.0)):
		assert_object(mi.material_override).is_null()


## Alle Teile tragen dasselbe Material mit dem Atlas des Packs — eins für die ganze Festung.
func test_wear_puts_one_material_on_every_part() -> void:
	var meshes := _meshes(_build(0.8))
	assert_int(meshes.size()).is_greater(0)
	var first := (meshes[0] as MeshInstance3D).material_override as ShaderMaterial
	assert_object(first).is_not_null()
	assert_float(first.get_shader_parameter("wear")).is_equal_approx(0.8, 0.001)
	assert_object(first.get_shader_parameter("atlas")).is_not_null()
	for mi: MeshInstance3D in meshes:
		assert_object(mi.material_override).is_same(first)


## Das Material des Packs bleibt, wie es ist: der nächste Kampf ohne Abnutzung sieht es heil.
func test_wear_leaves_the_pack_material_alone() -> void:
	var mi := _meshes(_build(0.8))[0] as MeshInstance3D
	var pack := mi.mesh.surface_get_material(0)
	assert_object(pack).is_not_instanceof(ShaderMaterial)
