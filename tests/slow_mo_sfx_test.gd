extends GdUnitTestSuite
## Tests für den Slow-Mo-Swoosh: kommt je Ereignis genau EIN Sound, und schweigt der
## Node beim Verlassen der Szene?
##
## Geprüft wird über `Sfx.last_played` — headless läuft der Dummy-Audio-Treiber, hörbar
## ist hier nichts, und Audiodateien müssen für den Test auch keine vorhanden sein.

var _gap_ms: int = Sfx.COOLDOWN_MS + 20
var _sfx: Node


func before_test() -> void:
	_sfx = auto_free(preload("res://src/battle/slow_mo_sfx.gd").new())
	add_child(_sfx)
	# Der Cooldown in Sfx gilt pro Id und über Testgrenzen hinweg: ohne diese Pause
	# könnte ein Aufruf am Anfang eines Tests am Nachbartest hängen bleiben.
	await _pump(_gap_ms)
	Sfx.last_played = &""


## Lässt `ms` ECHTE Millisekunden Frames laufen (time_scale-unabhängig, wie im
## SlowMotion-Test).
func _pump(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_swoosh_in_when_slow_motion_starts() -> void:
	EventBus.slow_motion_changed.emit(0.3)
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_in")


func test_no_repeat_while_already_slowed() -> void:
	EventBus.slow_motion_changed.emit(0.3)
	Sfx.last_played = &""
	EventBus.slow_motion_changed.emit(0.7)
	EventBus.slow_motion_changed.emit(1.0)
	assert_str(String(Sfx.last_played)).is_empty()


func test_swoosh_out_at_zero() -> void:
	EventBus.slow_motion_changed.emit(1.0)
	EventBus.slow_motion_changed.emit(0.0)
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_out")


func test_interrupted_ramp_down_does_not_swoosh_in_again() -> void:
	EventBus.slow_motion_changed.emit(1.0)
	# Ausrampen beginnt, wird aber vom nächsten Zeichen aufgefangen, bevor 0 erreicht ist.
	EventBus.slow_motion_changed.emit(0.4)
	Sfx.last_played = &""
	EventBus.slow_motion_changed.emit(1.0)
	assert_str(String(Sfx.last_played)).is_empty()


func test_leaving_the_tree_stays_silent() -> void:
	# Aufbau wie in battle.tscn: der Sfx-Node hängt UNTER der SlowMotion.
	remove_child(_sfx)
	var sm := SlowMotion.new()
	sm.add_child(_sfx)
	add_child(sm)
	EventBus.typing_activity.emit()
	await _pump(250)
	assert_str(String(Sfx.last_played)).is_equal("slow_mo_in")
	Sfx.last_played = &""

	# Szenenwechsel mitten in der Slow-Mo: SlowMotion._exit_tree() meldet noch eine 0.
	# Sie darf keinen Swoosh ins Menü hinein auslösen.
	remove_child(sm)
	assert_str(String(Sfx.last_played)).is_empty()

	sm.remove_child(_sfx)
	add_child(_sfx)
	sm.free()
	# time_scale ist global: darf nicht in den nächsten Test lecken.
	Engine.time_scale = 1.0
