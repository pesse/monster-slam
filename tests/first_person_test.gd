extends GdUnitTestSuite
## Die Ich-Sicht (Späher-Baum): Freischaltung, Laufen, „nur was im Bild ist" und die
## Eingabe, die zwischen zwei Antworten zu ist. Ohne Welle — geprüft werden die Regeln
## und die Eingabe für sich (kein Test fährt eine ganze Welle).

const AnswerInputScene := preload("res://scenes/ui/answer_input.tscn")


func after_test() -> void:
	RunRequest.want_first_person(false)
	RunRequest.start_expert()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Freischaltung und Tempo ---------------------------------------------------

func test_unlocked_only_with_the_root_node() -> void:
	assert_bool(FirstPersonView.unlocked({})).is_false()
	assert_bool(FirstPersonView.unlocked({"walk_speed": 0.25})).is_false()
	assert_bool(FirstPersonView.unlocked({"first_person": 1.0})).is_true()


func test_walk_speed_adds_shares_on_the_base() -> void:
	assert_float(FirstPersonView.speed_for({})).is_equal_approx(FirstPersonView.BASE_SPEED, 0.001)
	assert_float(FirstPersonView.speed_for({"walk_speed": 0.5})).is_equal_approx(
			FirstPersonView.BASE_SPEED * 1.5, 0.001)


## Der Schalter auf der Karte ist nur ein Wunsch: er gilt mit gelerntem Knoten und nur
## für ein Level — der Expertenmodus hat keinen Schalter.
func test_run_request_needs_wish_level_and_skill() -> void:
	var skill := {"first_person": 1.0}
	RunRequest.start_level({"key": "t1", "book": "b", "unit": 1, "scope": []})
	assert_bool(RunRequest.first_person_with(skill)).is_false()
	RunRequest.want_first_person(true)
	assert_bool(RunRequest.first_person_with(skill)).is_true()
	assert_bool(RunRequest.first_person_with({})).is_false()
	RunRequest.start_expert()
	assert_bool(RunRequest.first_person_with(skill)).is_false()


## Im Debug-Build steht der Schalter immer da und gilt auch ohne Knoten — im
## veröffentlichten Build nur mit.
func test_debug_build_offers_it_without_the_skill() -> void:
	assert_bool(RunRequest.first_person_selectable_with({}, true)).is_true()
	assert_bool(RunRequest.first_person_selectable_with({}, false)).is_false()
	assert_bool(RunRequest.first_person_selectable_with({"first_person": 1.0}, false)).is_true()
	RunRequest.start_level({"key": "t1", "book": "b", "unit": 1, "scope": []})
	RunRequest.want_first_person(true)
	assert_bool(RunRequest.first_person_with({}, true)).is_true()
	assert_bool(RunRequest.first_person_with({}, false)).is_false()


func test_charge_needs_its_node() -> void:
	assert_bool(FirstPersonView.charges_for({})).is_false()
	assert_bool(FirstPersonView.charges_for({"charge": 1.0})).is_true()
	assert_str(SkillTree.effect_label("charge", 1.0)).is_not_empty()


## Der Anlauf endet kurz VOR dem Monster, auf der Linie dorthin, und nie außerhalb des Felds.
func test_charge_stops_in_front_of_the_monster() -> void:
	var field := Rect2(-10.0, -25.0, 20.0, 30.0)
	var end := FirstPersonView.charge_end(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, -10.0), field)
	assert_vector(end).is_equal_approx(Vector3(0.0, 0.0, -10.0 + FirstPersonView.CHARGE_STOP),
			Vector3.ONE * 0.001)
	# Schon ganz nah: stehen bleiben statt zurückzuweichen.
	var near := Vector3(0.0, 0.0, -0.5)
	assert_vector(FirstPersonView.charge_end(Vector3.ZERO, near, field)).is_equal(Vector3.ZERO)
	var outside := FirstPersonView.charge_end(Vector3.ZERO, Vector3(0.0, 0.0, -60.0), field)
	assert_float(outside.z).is_equal(-25.0)


func test_charge_turns_towards_the_monster() -> void:
	assert_float(FirstPersonView.yaw_towards(Vector3.ZERO, Vector3(0.0, 0.0, -5.0))).is_equal_approx(0.0, 0.001)
	# Rechts (+x) liegt bei einem Gierwinkel von -90°.
	assert_float(FirstPersonView.yaw_towards(Vector3.ZERO, Vector3(5.0, 0.0, 0.0))).is_equal_approx(-PI / 2.0, 0.001)


## Der Anlauf kommt an, und ein zweiter Treffer während des ersten lässt den ersten sofort
## ankommen, statt ihn hängen zu lassen.
func test_charge_arrives_and_a_second_one_completes_the_first() -> void:
	var view := auto_free(preload("res://scenes/battle/first_person_view.tscn").instantiate()) as FirstPersonView
	add_child(view)
	await await_idle_frame()
	var arrived: Array = []
	var first := func() -> void:
		await view.charge_at(Vector3(0.0, 0.0, -20.0))
		arrived.append("first")
	first.call()
	await await_idle_frame()
	assert_bool(view.is_charging()).is_true()
	await view.charge_at(Vector3(5.0, 0.0, -20.0))
	arrived.append("second")
	assert_array(arrived).contains_exactly(["first", "second"])
	assert_bool(view.is_charging()).is_false()
	assert_float(view.position.distance_to(Vector3(5.0, 0.0, -20.0))).is_less(FirstPersonView.CHARGE_STOP + 0.2)


func test_new_effects_have_labels() -> void:
	assert_str(SkillTree.effect_label("first_person", 1.0)).is_not_empty()
	assert_str(SkillTree.effect_label("walk_speed", 0.25)).contains("25")


# --- Laufen ----------------------------------------------------------------------

func test_forward_follows_the_yaw() -> void:
	var ahead := FirstPersonView.walk_direction(Vector2(0.0, 1.0), 0.0)
	assert_vector(ahead).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)
	# Um 90° nach links gedreht blickt man nach -x.
	var turned := FirstPersonView.walk_direction(Vector2(0.0, 1.0), PI / 2.0)
	assert_vector(turned).is_equal_approx(Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)
	var right := FirstPersonView.walk_direction(Vector2(1.0, 0.0), 0.0)
	assert_vector(right).is_equal_approx(Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.001)


## Schräg ist nicht schneller als geradeaus.
func test_diagonal_is_not_faster() -> void:
	var diag := FirstPersonView.walk_direction(Vector2(1.0, 1.0), 0.3)
	assert_float(diag.length()).is_equal_approx(1.0, 0.001)
	assert_vector(FirstPersonView.walk_direction(Vector2.ZERO, 0.3)).is_equal(Vector3.ZERO)


func test_the_field_holds_the_player() -> void:
	var bounds := Rect2(-10.0, -25.0, 20.0, 30.0)
	var out := FirstPersonView.clamp_to(bounds, Vector3(40.0, 2.0, -90.0))
	assert_float(out.x).is_equal(10.0)
	assert_float(out.z).is_equal(-25.0)
	assert_float(out.y).is_equal(2.0)


# --- Sichtbar ------------------------------------------------------------------

func test_sees_what_is_in_front_not_behind() -> void:
	var view := auto_free(preload("res://scenes/battle/first_person_view.tscn").instantiate()) as FirstPersonView
	add_child(view)
	await await_idle_frame()
	var cam := view.camera
	var eye := cam.global_position
	assert_bool(FirstPersonView.sees(cam, eye + Vector3(0.0, 0.0, -10.0))).is_true()
	assert_bool(FirstPersonView.sees(cam, eye + Vector3(0.0, 0.0, 10.0))).is_false()
	assert_bool(FirstPersonView.sees(cam, eye + Vector3(30.0, 0.0, -1.0))).is_false()


func test_marker_points_to_the_side_of_a_monster_behind() -> void:
	var view := auto_free(preload("res://scenes/battle/first_person_view.tscn").instantiate()) as FirstPersonView
	add_child(view)
	await await_idle_frame()
	var cam := view.camera
	var behind_right := cam.global_position + Vector3(2.0, 0.0, 10.0)
	assert_float(OffscreenMarkers.edge_direction(cam, behind_right).x).is_greater(0.0)
	var behind_left := cam.global_position + Vector3(-2.0, 0.0, 10.0)
	assert_float(OffscreenMarkers.edge_direction(cam, behind_left).x).is_less(0.0)


func test_marker_sits_on_the_edge() -> void:
	var rect := Rect2(0.0, 0.0, 200.0, 100.0)
	assert_vector(OffscreenMarkers.edge_point(rect, Vector2.RIGHT)).is_equal(Vector2(200.0, 50.0))
	assert_vector(OffscreenMarkers.edge_point(rect, Vector2.UP)).is_equal(Vector2(100.0, 0.0))


# --- Eingabe: Enter auf, Enter ab ----------------------------------------------

func _enter() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	return key


func test_gated_input_opens_on_enter_and_closes_on_submit() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	input.set("gated", true)
	assert_bool(input.call("is_typing")).is_false()
	assert_bool(input.editable).is_false()
	var started: Array = []
	var on_start := func() -> void: started.append(true)
	EventBus.typing_started.connect(on_start)
	input.call("_input", _enter())
	EventBus.typing_started.disconnect(on_start)
	assert_bool(input.call("is_typing")).is_true()
	# Das Öffnen startet die Zeitlupe, nicht erst der erste Buchstabe.
	assert_int(started.size()).is_equal(1)
	var answers: Array = []
	var catch := func(text: String) -> void: answers.append(text)
	EventBus.answer_submitted.connect(catch)
	input.text = "house"
	input.text_submitted.emit(input.text)
	EventBus.answer_submitted.disconnect(catch)
	assert_array(answers).contains_exactly(["house"])
	assert_bool(input.call("is_typing")).is_false()
	assert_str(input.text).is_empty()


## Verschwindet die offene Eingabe (Rückfrage „Schnell auflösen", Wellenende), endet auch
## die Zeitlupe, die ihr Öffnen gestartet hat.
func test_hiding_the_open_input_stops_slow_motion() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	input.set("gated", true)
	input.call("_input", _enter())
	var stopped: Array = []
	var on_stop := func() -> void: stopped.append(true)
	EventBus.typing_stopped.connect(on_stop)
	input.visible = false
	EventBus.typing_stopped.disconnect(on_stop)
	assert_int(stopped.size()).is_equal(1)
	assert_bool(input.call("is_typing")).is_false()


func test_escape_closes_without_sending() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	input.set("gated", true)
	input.call("_input", _enter())
	input.text = "hou"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	input.call("_input", escape)
	assert_bool(input.call("is_typing")).is_false()
	assert_str(input.text).is_empty()


## Ohne Ich-Sicht bleibt alles wie immer: die Eingabe ist offen und bleibt es.
func test_ungated_input_stays_open() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	assert_bool(input.editable).is_true()
	assert_bool(input.call("is_typing")).is_false()
	input.text_submitted.emit("x")
	assert_bool(input.editable).is_true()


## Bei offener Eingabe ist die Maus frei — für „Schnell auflösen"; beim Laufen gefangen.
func test_mouse_is_free_while_typing() -> void:
	var view := auto_free(preload("res://scenes/battle/first_person_view.tscn").instantiate()) as FirstPersonView
	add_child(view)
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	input.set("gated", true)
	view.answer_input = input
	view.set_active(true)
	assert_bool(view.mouse_captured()).is_true()
	input.call("_input", _enter())
	assert_bool(view.mouse_captured()).is_false()
	input.text_submitted.emit("")
	assert_bool(view.mouse_captured()).is_true()
	view.set_active(false)
