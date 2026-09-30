extends GdUnitTestSuite
## Der Knall des Explosionspfeils (Blast) und das Zucken der Nachbarn: beides nur Bild.

const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func test_the_blast_builds_its_layers_and_frees_itself() -> void:
	var fx := Blast.new()
	fx.setup(Color(0.3, 0.6, 1.0))
	add_child(fx)
	await get_tree().process_frame
	# Funken, Glut und zwei Rauchschübe.
	assert_int(fx.find_children("*", "CPUParticles3D", false, false).size()).is_equal(4)
	assert_int(fx.find_children("*", "OmniLight3D", false, false).size()).is_equal(1)
	await get_tree().create_timer(Blast.LIFETIME + 0.5).timeout
	assert_bool(is_instance_valid(fx)).is_false()


## Jeder Knall hat eigene Materialien: die Glut trägt die Wortfarbe seines Monsters, und
## der Feuerball verglüht für sich (progress).
func test_two_blasts_share_no_material() -> void:
	var a: Blast = auto_free(Blast.new())
	var b: Blast = auto_free(Blast.new())
	a.setup(Color.RED)
	b.setup(Color.BLUE)
	add_child(a)
	add_child(b)
	await get_tree().process_frame
	var mats := func(fx: Blast) -> Array:
		var out := []
		for p in fx.find_children("*", "CPUParticles3D", false, false):
			out.append((p as CPUParticles3D).mesh.surface_get_material(0))
		return out
	for m in mats.call(a):
		assert_bool(m in mats.call(b)).is_false()
	remove_child(a)
	remove_child(b)


## Ein Nachbar zuckt, aber bleibt, wo er ist, und steht danach wieder gerade.
func test_a_flinch_moves_only_the_body() -> void:
	var monster: Monster = auto_free(MONSTER_SCENE.instantiate())
	monster.setup(FxWarmup.monster_defs()[0], {"prompt": "house"}, 1000.0, 0.0)
	add_child(monster)
	monster.halt()
	monster.position = Vector3(3.0, 0.0, 0.0)
	var body: Node3D = monster._body
	var rest := body.transform
	monster.flinch(Vector3.ZERO)
	await get_tree().create_timer(0.1).timeout
	assert_bool(body.transform.is_equal_approx(rest)).is_false()
	assert_vector(monster.position).is_equal(Vector3(3.0, 0.0, 0.0))
	await get_tree().create_timer(0.6).timeout
	assert_bool(body.transform.basis.is_equal_approx(rest.basis)).is_true()
	remove_child(monster)
