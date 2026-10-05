extends GdUnitTestSuite
## Die Antwort-Eingabe, in beiden Sichten dieselbe (ADR 0016): zu zwischen zwei Antworten,
## Enter öffnet, Enter schickt ab und schließt, Escape schließt ohne abzuschicken.

const AnswerInputScene := preload("res://scenes/ui/answer_input.tscn")


func _enter() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	return key


func test_enter_opens_and_submit_closes() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	# Zu von Anfang an, in beiden Sichten.
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
	input.call("_input", _enter())
	input.text = "hou"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	input.call("_input", escape)
	assert_bool(input.call("is_typing")).is_false()
	assert_str(input.text).is_empty()


## Die geschlossene Eingabe sagt, was geht: in der Iso-Sicht nur Enter, in der Ich-Sicht
## auch Laufen, mit zwei Waffen statt dessen Tab.
func test_closed_placeholder_names_what_the_view_allows() -> void:
	var input := auto_free(AnswerInputScene.instantiate()) as LineEdit
	add_child(input)
	await await_idle_frame()
	assert_str(input.placeholder_text).is_equal("Enter: antworten")
	input.set("first_person", true)
	assert_str(input.placeholder_text).contains("WASD")
	input.set("weapon_switch", true)
	assert_str(input.placeholder_text).contains("Tab")
	input.call("_input", _enter())
	assert_str(input.placeholder_text).is_equal("Übersetzung eingeben…")
	input.text_submitted.emit("")
