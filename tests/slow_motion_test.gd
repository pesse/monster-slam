extends GdUnitTestSuite
## Die Wartezeiten laufen über Time.get_ticks_msec() + process_frame, nicht über
## Timer: SceneTreeTimer hängt selbst an time_scale und würde mitgebremst.

var _sm: SlowMotion


func before_test() -> void:
	_sm = SlowMotion.new()
	add_child(_sm)


func after_test() -> void:
	_sm.free()
	# time_scale ist global: darf nicht in den nächsten Test lecken.
	Engine.time_scale = 1.0


## Echtzeit, bis das Vorspulen voll steht — plus Luft für Frames, die länger dauern.
func _ramp_up_ms() -> int:
	return int((SlowMotion.FAST_FORWARD_FACTOR - 1.0) / SlowMotion.FAST_FORWARD_RAMP_PER_SEC * 1000.0) + 400


## Lässt `ms` ECHTE Millisekunden Frames laufen.
func _pump(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_typing_slows_time_down() -> void:
	EventBus.typing_activity.emit()
	await _pump(250)
	assert_float(Engine.time_scale).is_equal_approx(SlowMotion.BASE_FACTOR, 0.01)


func test_slow_motion_ends_after_hold() -> void:
	EventBus.typing_activity.emit()
	await _pump(SlowMotion.BASE_HOLD_MS + 400)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_further_typing_renews_hold() -> void:
	EventBus.typing_activity.emit()
	await _pump(700)
	EventBus.typing_activity.emit()
	# 700 + 700 ms liegen über der Haltedauer — durch das zweite Zeichen läuft sie weiter.
	await _pump(700)
	assert_float(Engine.time_scale).is_equal_approx(SlowMotion.BASE_FACTOR, 0.01)


func test_submit_ends_slow_motion_immediately() -> void:
	EventBus.typing_activity.emit()
	await _pump(250)
	EventBus.typing_stopped.emit()
	# Ohne einen einzigen weiteren Frame: Enter beendet sofort, ohne Ausblenden.
	assert_float(Engine.time_scale).is_equal(1.0)


func test_removing_the_node_restores_normal_speed() -> void:
	EventBus.typing_activity.emit()
	await _pump(250)
	remove_child(_sm)
	assert_float(Engine.time_scale).is_equal(1.0)
	add_child(_sm)  # after_test gibt den Node frei


func test_intensity_is_reported_for_the_vignette() -> void:
	var seen: Array[float] = []
	EventBus.slow_motion_changed.connect(func(v: float) -> void: seen.append(v))
	EventBus.typing_activity.emit()
	await _pump(250)
	# Volle Verlangsamung ⇒ Intensität 1.0; zwischendurch wurden Werte < 1 gemeldet
	# (der Übergang), nie aber einer außerhalb von 0..1.
	assert_float(seen[-1]).is_equal_approx(1.0, 0.01)
	for v in seen:
		assert_float(v).is_between(0.0, 1.0)
	EventBus.typing_stopped.emit()
	assert_float(seen[-1]).is_equal(0.0)


## „Schnell auflösen": time_scale gehört diesem Knoten, also spult er auch vor.
func test_fast_forward_speeds_time_up() -> void:
	_sm.fast_forward()
	await _pump(_ramp_up_ms())
	assert_float(Engine.time_scale).is_equal_approx(SlowMotion.FAST_FORWARD_FACTOR, 0.01)


## Das Vorspulen nimmt Fahrt auf, statt auf einen Schlag loszurasen.
func test_fast_forward_rises_gradually() -> void:
	_sm.fast_forward()
	await _pump(500)
	assert_float(Engine.time_scale).is_greater(1.0)
	assert_float(Engine.time_scale).is_less(SlowMotion.FAST_FORWARD_FACTOR / 2.0)


## Tippen während des Vorspulens bremst nicht — sonst fiele die Welle mitten im
## Zeitraffer in die Zeitlupe.
func test_typing_does_not_interrupt_fast_forward() -> void:
	_sm.fast_forward()
	EventBus.typing_activity.emit()
	await _pump(_ramp_up_ms())
	assert_float(Engine.time_scale).is_equal_approx(SlowMotion.FAST_FORWARD_FACTOR, 0.01)


## _finish_wave ruft stop(): Auflösung und Statistik laufen wieder in Normaltempo, und
## die nächste Welle beginnt ohne Zeitraffer.
func test_stop_ends_fast_forward() -> void:
	_sm.fast_forward()
	await _pump(300)
	_sm.stop()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(_sm.is_fast_forwarding()).is_false()
	await _pump(200)
	assert_float(Engine.time_scale).is_equal(1.0)


## Die Vignette gehört zur Zeitlupe: beim Vorspulen bleibt sie aus.
func test_fast_forward_reports_no_slow_motion_intensity() -> void:
	var seen: Array[float] = []
	EventBus.slow_motion_changed.connect(func(v: float) -> void: seen.append(v))
	_sm.fast_forward()
	await _pump(600)
	for v in seen:
		assert_float(v).is_equal(0.0)


## Der Zeitwandler-Baum verzweigt sich in Dauer und Tiefe — beide Äste landen hier.
## Geprüft wird mit einem einfachen Dictionary, also ohne SkillBook und ohne Inhalte:
## genau dafür nimmt apply_skills keine Autoload-Referenz.
func test_skills_deepen_the_factor_and_lengthen_the_hold() -> void:
	_sm.apply_skills({"slow_factor": -0.05, "slow_hold_ms": 700})
	assert_float(_sm.factor).is_equal_approx(SlowMotion.BASE_FACTOR - 0.05, 0.001)
	assert_int(_sm.hold_ms).is_equal(SlowMotion.BASE_HOLD_MS + 700)
	EventBus.typing_activity.emit()
	await _pump(250)
	assert_float(Engine.time_scale).is_equal_approx(_sm.factor, 0.01)


## Ein Baum darf beliebig tief gehen, nur nicht bis zum Stillstand: time_scale 0 wäre ein
## eingefrorenes Spiel, in dem die Haltedauer trotzdem weiterliefe — der Lauf käme nie
## zum Ende.
func test_the_factor_never_reaches_a_standstill() -> void:
	_sm.apply_skills({"slow_factor": -99.0})
	assert_float(_sm.factor).is_equal_approx(SkillTree.MIN_SLOW_FACTOR, 0.001)


## Ohne gelernte Skills bleibt alles beim Grundwert — ein leeres Dictionary ist der
## Normalfall, nicht ein Sonderfall.
func test_without_skills_the_base_values_stand() -> void:
	_sm.apply_skills({})
	assert_float(_sm.factor).is_equal_approx(SlowMotion.BASE_FACTOR, 0.001)
	assert_int(_sm.hold_ms).is_equal(SlowMotion.BASE_HOLD_MS)
