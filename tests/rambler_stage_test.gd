extends GdUnitTestSuite
## Die Bühne des Schreib-Kampfs (RamblerStage, ADR 0023 §3): sie baut so viele Stapel, wie
## Kriterien gezählt werden, jede Methode läuft ohne Absturz, ein gefallener Stapel bleibt
## gefallen, und „neuer Kampf" hängt alle wieder an. Nur das Bild — kein Profil, kein Dienst.

const StageScene := preload("res://scenes/battle/rambler_stage.tscn")


func _stage() -> RamblerStage:
	var stage := auto_free(StageScene.instantiate()) as RamblerStage
	add_child(stage)
	return stage


func _hanging(stage: RamblerStage) -> int:
	return stage.get_node("Boss/Body/Belt").find_children("Stack*", "Node3D", false, false).size()


func test_builds_one_stack_per_criterion() -> void:
	var stage := _stage()
	await await_idle_frame()
	assert_int(stage.stack_count).is_equal(5)
	assert_int(stage.stacks_left()).is_equal(5)
	assert_int(_hanging(stage)).is_equal(5)
	stage.stack_count = 3
	stage.restore_all()
	await await_idle_frame()
	assert_int(stage.stacks_left()).is_equal(3)
	assert_int(_hanging(stage)).is_equal(3)


func test_dropped_stack_stays_dropped_and_he_shrinks() -> void:
	var stage := _stage()
	await await_idle_frame()
	var body := stage.get_node("Boss/Body") as Node3D
	stage.drop_stack(1)
	stage.drop_stack(1)
	assert_int(stage.stacks_left()).is_equal(4)
	assert_int(_hanging(stage)).is_equal(4)
	# Ein gehaltener Stapel bleibt hängen; Unsinn wird ignoriert.
	stage.hold_stack(0)
	stage.hold_stack(1)
	stage.drop_stack(-1)
	stage.drop_stack(99)
	stage.hold_stack(99)
	assert_int(stage.stacks_left()).is_equal(4)
	await await_millis(600)
	assert_float(body.scale.y).is_less(1.0)


func test_every_method_runs() -> void:
	var stage := _stage()
	await await_idle_frame()
	await stage.warm_up()
	assert_bool(stage.mouth_on_screen().is_finite()).is_true()
	stage.set_focus(false)
	stage.speak()
	stage.hold_stack(2)
	await await_millis(200)
	stage.set_focus(true)
	stage.gloat()
	stage.drop_stack(0)
	await await_millis(200)
	stage.fall()
	assert_int(stage.stacks_left()).is_equal(0)
	# Besiegt redet und freut er sich nicht mehr — und stürzt dabei nicht ab.
	stage.speak()
	stage.gloat()
	await await_millis(200)
	stage.restore_all()
	await await_idle_frame()
	assert_int(stage.stacks_left()).is_equal(5)
	assert_int(_hanging(stage)).is_equal(5)
	assert_bool(stage.mouth_on_screen().is_finite()).is_true()


## Hinten wandert er los; vorn kommt er zurück in die Mitte.
func test_wanders_in_the_back_and_returns_to_the_front() -> void:
	var stage := _stage()
	await await_idle_frame()
	var boss := stage.get_node("Boss") as Node3D
	var front := boss.position
	stage.set_focus(false)
	await await_millis(1500)
	assert_float(boss.position.distance_to(front)).is_greater(0.3)
	stage.set_focus(true)
	await await_millis(3500)
	assert_float(Vector2(boss.position.x, boss.position.z).distance_to(Vector2(front.x, front.z))).is_less(0.1)
