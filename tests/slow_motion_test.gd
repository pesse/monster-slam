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
