extends GdUnitTestSuite
## Das Vorwärmen beim Kampfstart (FxWarmup): es stellt auf, wartet und räumt wieder ab —
## im Kampf bleibt davon nichts stehen, das man sähe oder das mitspielte.

const MONSTER_DEF := {"id": "zz-warm", "model": "res://assets/models/monsters/Skeleton_Minion.glb"}


func test_run_leaves_nothing_visible_behind() -> void:
	var parent: Node3D = auto_free(Node3D.new())
	add_child(parent)
	var label := Label3D.new()
	await FxWarmup.run(parent, Vector3.ZERO, [MONSTER_DEF], [label])
	await get_tree().process_frame
	for child in parent.get_children():
		# Übrig bleibt nur die Explosion, die ihren eigenen Timer abwartet — unsichtbar.
		assert_object(child).is_instanceof(Explosion)
		assert_bool((child as Node3D).visible).is_false()
	assert_bool(is_instance_valid(label)).is_false()
	remove_child(parent)


## Die Monster stehen: ohne Tempo erreichen sie die Festung nie und melden nichts.
func test_warm_monsters_never_reach_the_fortress() -> void:
	var reached := [0]
	var count := func(_d: Dictionary, _t: Dictionary, _dmg: int) -> void: reached[0] += 1
	EventBus.monster_reached_fortress.connect(count)
	var parent: Node3D = auto_free(Node3D.new())
	add_child(parent)
	await FxWarmup.run(parent, Vector3.ZERO, [MONSTER_DEF])
	EventBus.monster_reached_fortress.disconnect(count)
	assert_int(reached[0]).is_equal(0)
	remove_child(parent)


func test_point_in_view_keeps_what_the_camera_sees() -> void:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.position = Vector3(0.0, 0.0, 10.0)
	assert_vector(FxWarmup.point_in_view(camera, Vector3.ZERO)).is_equal(Vector3.ZERO)
	var behind := FxWarmup.point_in_view(camera, Vector3(0.0, 0.0, 30.0))
	assert_float(behind.z).is_less(10.0)
	remove_child(camera)
