extends GdUnitTestSuite
## Meister-Feier im Kampf (Issue #23): welche Feier läuft, und dass jede drankommt.
##
## Geprüft wird die Szene für sich, ohne Welle: die Signale werden einzeln gefeuert. Das
## Anhalten des Spiels prüft slow_motion_test.gd, den Anlass player_progress_timestamps_test.gd.
## Die Ids sind erfunden und nicht geladen — das Detail bleibt dann leer bzw. die Id.

const SCENE := preload("res://scenes/ui/mastery_celebration.tscn")
const TASK := "translate:en_to_de:zz.lex.a"
const LEXEME := "zz.lex.a"

var _c: MasteryCelebration
var _started: Array[int] = []


func before_test() -> void:
	_started.clear()
	_c = auto_free(SCENE.instantiate())
	add_child(_c)
	_c.started.connect(func(ms: int) -> void: _started.append(ms))


func after_test() -> void:
	remove_child(_c)


func _frame() -> void:
	await get_tree().process_frame


## Lässt `ms` echte Millisekunden Frames laufen.
func _pump(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_a_task_gets_the_small_celebration() -> void:
	EventBus.task_mastered.emit(TASK)
	await _frame()
	assert_array(_started).is_equal([MasteryCelebration.TASK_MS])
	assert_bool(_c.visible).is_true()
	assert_str(str(_c.get_node("%Headline").theme_type_variation)).is_equal("CelebrateTask")


## Beides in derselben Antwort: nur die Wort-Feier, nicht beide nacheinander.
func test_a_word_beats_its_task() -> void:
	EventBus.task_mastered.emit(TASK)
	EventBus.lexeme_mastered.emit(LEXEME)
	await _frame()
	assert_array(_started).is_equal([MasteryCelebration.WORD_MS])
	assert_str(str(_c.get_node("%Headline").theme_type_variation)).is_equal("CelebrateWord")


## Jede Meisterung wird gefeiert: eine zweite während der Feier stellt sich an, und
## `finished` kommt erst nach der letzten.
func test_a_second_mastery_waits_its_turn() -> void:
	var finished := [0]
	_c.finished.connect(func() -> void: finished[0] += 1)
	EventBus.task_mastered.emit(TASK)
	await _frame()
	EventBus.lexeme_mastered.emit(LEXEME)
	await _frame()
	assert_array(_started).is_equal([MasteryCelebration.TASK_MS])
	await _pump(MasteryCelebration.TASK_MS + 200)
	assert_array(_started).is_equal([MasteryCelebration.TASK_MS, MasteryCelebration.WORD_MS])
	assert_int(finished[0]).is_equal(0)
	await _pump(MasteryCelebration.WORD_MS + 200)
	assert_int(finished[0]).is_equal(1)
	assert_bool(_c.visible).is_false()
	assert_bool(_c.is_busy()).is_false()


## Direkt nach der Meldung, noch vor dem Frame-Ende, gilt die Feier schon als anstehend:
## daran hält der WaveRunner das Wellenende zurück, damit auch das letzte Monster feiert.
func test_a_reported_mastery_is_busy_before_it_starts() -> void:
	EventBus.task_mastered.emit(TASK)
	assert_bool(_c.is_busy()).is_true()


## Der Weg des Debug-Panels: feiern ohne Signal auf dem EventBus.
func test_celebrate_works_without_the_event_bus() -> void:
	_c.celebrate(MasteryCelebration.Kind.WORD, "")
	await _frame()
	assert_array(_started).is_equal([MasteryCelebration.WORD_MS])


func test_the_styles_exist_in_the_theme() -> void:
	var theme: Theme = load("res://scenes/ui/ui_theme.tres")
	for variation in ["CelebrateTask", "CelebrateWord", "CelebrateDetail"]:
		assert_bool(theme.get_type_variation_list(&"Label").has(StringName(variation))) \
				.append_failure_message(variation).is_true()


## Die Wort-Feier zündet ihre eigenen Partikel, nicht die der Aufgabe.
func test_a_word_fires_the_word_particles() -> void:
	_c.celebrate(MasteryCelebration.Kind.WORD, "")
	await _frame()
	assert_bool((_c.get_node("Origin/WordSparks") as GPUParticles2D).emitting).is_true()
	assert_bool((_c.get_node("Bottom/WordEmbers") as GPUParticles2D).emitting).is_true()
	assert_bool((_c.get_node("Origin/TaskSparks") as GPUParticles2D).emitting).is_false()
	assert_bool((_c.get_node("Origin/Lightning") as Lightning).is_running()).is_true()


func test_a_task_fires_the_task_particles() -> void:
	_c.celebrate(MasteryCelebration.Kind.TASK, "")
	await _frame()
	assert_bool((_c.get_node("Origin/TaskSparks") as GPUParticles2D).emitting).is_true()
	assert_bool((_c.get_node("Origin/WordSparks") as GPUParticles2D).emitting).is_false()
	assert_bool((_c.get_node("Origin/Lightning") as Lightning).is_running()).is_false()


# --- Was in der Baum-Pause weiterlaufen muss -----------------------------------
#
# Die Pause selbst setzt der WaveRunner, und kein Test fährt eine Welle. Geprüft wird
# deshalb, dass die Knoten, die während der Feier arbeiten, auf ALWAYS stehen: ohne das
# stünde die Feier mit dem Kampf still, die Eingabe nähme keine Tasten an, und ein
# Treffer-Sound hielte mitten im Klang an.

func test_the_celebration_runs_while_paused() -> void:
	assert_int(_c.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_the_answer_input_runs_while_paused() -> void:
	var state := (load("res://scenes/battle/battle.tscn") as PackedScene).get_state()
	var mode := -1
	for i in state.get_node_count():
		if state.get_node_name(i) != &"AnswerInput":
			continue
		for j in state.get_node_property_count(i):
			if state.get_node_property_name(i, j) == &"process_mode":
				mode = int(state.get_node_property_value(i, j))
	assert_int(mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_sounds_play_while_paused() -> void:
	assert_int(Sfx.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
