extends GdUnitTestSuite
## Rasten und Fortsetzen (ADR 0020): ein Platz je Buch, fester Bereich, gerechnete Maxima.
##
## RunSave läuft auf einem `zz-`-Profil; GameState ist Autoload und geteilter Zustand,
## deshalb vorher und nachher reset(). RunRequest ist statisch und wird hinterher geleert.

const PROFILE := "zz-run-save"
const WAVE_RUNNER := preload("res://src/battle/wave_runner.gd")
const SESSION_LOG := preload("res://src/learning/session_log.gd")
const STATS_SCENE := preload("res://scenes/ui/wave_stats.tscn")


func before_test() -> void:
	GameState.reset()
	DirAccess.remove_absolute(RunSave.path(PROFILE))


func after_test() -> void:
	GameState.reset()
	DirAccess.remove_absolute(RunSave.path(PROFILE))
	DirAccess.remove_absolute("user://progress/%s_sessions.json" % PROFILE)
	RunRequest.start_expert()


func _levels(unit := 1, parts := 4) -> Array:
	return MapLevel.levels_for("zz_book", unit, parts)


func _state(keys: Array, unit := 1, next_wave := 7, book := "zz_book") -> Dictionary:
	var level := MapLevel.combine(MapLevel.levels_for(book, unit, 4), keys)
	return RunSave.build(level, next_wave, 4, {"fortress_health": 60, "fortress_armor": 5,
			"score": 900, "monsters_defeated": 40, "monsters_leaked": 3, "no_leak_streak": 12,
			"best_no_leak_streak": 20, "min_fortress_health": 35}, 1000, 2000)


# --- Speicherplätze -------------------------------------------------------------

func test_no_file_no_runs() -> void:
	assert_dict(RunSave.all(PROFILE)).is_empty()
	assert_dict(RunSave.of_unit("zz_book", 1, PROFILE)).is_empty()
	assert_array(RunSave.of_book("zz_book", PROFILE)).is_empty()


func test_one_slot_per_unit() -> void:
	RunSave.store(_state(["t1"]), PROFILE)
	RunSave.store(_state(["t2"], 2, 5), PROFILE)
	RunSave.store(_state(["t2"], 3, 9, "zz_other"), PROFILE)
	# Ein neuer Stand derselben Unit ersetzt den alten, die anderen Units bleiben.
	RunSave.store(_state(["t3"], 1, 4), PROFILE)
	assert_array(RunSave.all(PROFILE).keys()).contains_exactly_in_any_order(
			["zz_book/1", "zz_book/2", "zz_other/3"])
	assert_int(int(RunSave.of_unit("zz_book", 1, PROFILE)["next_wave"])).is_equal(4)
	assert_int(int(RunSave.of_unit("zz_book", 2, PROFILE)["next_wave"])).is_equal(5)
	assert_int(int(RunSave.of_unit("zz_other", 3, PROFILE)["next_wave"])).is_equal(9)


func test_discard_leaves_the_other_units_alone() -> void:
	RunSave.store(_state(["t1"]), PROFILE)
	RunSave.store(_state(["t2"], 2, 5), PROFILE)
	RunSave.discard("zz_book", 1, PROFILE)
	assert_dict(RunSave.of_unit("zz_book", 1, PROFILE)).is_empty()
	assert_dict(RunSave.of_unit("zz_book", 2, PROFILE)).is_not_empty()
	RunSave.discard("zz_book", 2, PROFILE)
	assert_bool(FileAccess.file_exists(RunSave.path(PROFILE))).is_false()


func test_of_book_newest_first() -> void:
	var older := MapLevel.combine(_levels(1), ["t1"])
	var newer := MapLevel.combine(_levels(2), ["t1"])
	RunSave.store(RunSave.build(older, 3, 4, {}, 1000, 2000), PROFILE)
	RunSave.store(RunSave.build(newer, 8, 4, {}, 1000, 3000), PROFILE)
	RunSave.store(_state(["t2"], 3, 9, "zz_other"), PROFILE)
	var runs := RunSave.of_book("zz_book", PROFILE)
	assert_array(runs.map(func(s): return int(s["next_wave"]))).is_equal([8, 3])


func test_a_file_with_one_slot_per_book_is_read_per_unit() -> void:
	# So lag es vor dem Nachtrag „Ein Platz je Unit": Buch -> Stand.
	DirAccess.make_dir_recursive_absolute(RunSave.SAVE_DIR)
	SaveStore.write(RunSave.path(PROFILE), {"runs": {"zz_book": _state(["t1"], 2, 6)}})
	assert_int(int(RunSave.of_unit("zz_book", 2, PROFILE)["next_wave"])).is_equal(6)
	RunSave.store(_state(["t1"], 1, 3), PROFILE)
	assert_array(RunSave.all(PROFILE).keys()).contains_exactly_in_any_order(
			["zz_book/1", "zz_book/2"])


func test_the_state_keeps_places_not_scope() -> void:
	var state := _state(["t2", "t3"])
	var level: Dictionary = state["level"]
	assert_dict(level).is_equal({"book": "zz_book", "unit": 1, "keys": ["t2", "t3"]})
	assert_dict(state["run"]).contains_keys(["fortress_health", "score"])
	assert_bool((state["run"] as Dictionary).has("fortress_max_health")).is_false()


# --- Fortsetzen -----------------------------------------------------------------

func test_the_same_places_resume_in_any_order() -> void:
	var state := _state(["t2", "t3"])
	assert_bool(RunSave.continues(state, 1, ["t3", "t2"], _levels())).is_true()
	assert_array(RunSave.added(state, ["t3", "t2"], _levels())).is_empty()
	assert_bool(RunSave.continues({}, 1, ["t2", "t3"], _levels())).is_false()


func test_a_run_grows_by_more_places() -> void:
	var state := _state(["t1"])
	assert_bool(RunSave.continues(state, 1, ["t1", "t2"], _levels())).is_true()
	assert_array(RunSave.added(state, ["t1", "t2", "t3"], _levels())).is_equal(["t2", "t3"])


func test_whole_unit_continues_a_run_over_its_parts() -> void:
	var state := _state(["t1", "t2"])
	assert_bool(RunSave.continues(state, 1, ["all"], _levels())).is_true()
	assert_array(RunSave.added(state, ["all"], _levels())).is_equal(["t3", "t4"])
	# Andersherum ist es dieselbe Unit: alle Teile setzen einen Gesamt-Lauf fort.
	assert_bool(RunSave.continues(_state(["all"]), 1, ["t1", "t2", "t3", "t4"], _levels())).is_true()


func test_taking_a_place_away_is_a_new_run() -> void:
	var state := _state(["t2", "t3"])
	assert_bool(RunSave.continues(state, 1, ["t2"], _levels())).is_false()
	# Getauscht ist auch weggenommen.
	assert_bool(RunSave.continues(state, 1, ["t2", "t4"], _levels())).is_false()
	assert_bool(RunSave.continues(_state(["all"]), 1, ["t1", "t2"], _levels())).is_false()


func test_another_unit_never_continues() -> void:
	assert_bool(RunSave.continues(_state(["t2"]), 2, ["t2"], _levels(2))).is_false()


func test_the_boss_belongs_to_no_run() -> void:
	assert_bool(RunSave.continues(_state(["t1"]), 1, ["boss"], _levels())).is_false()
	assert_bool(RunSave.continues(_state(["all"]), 1, ["boss"], _levels())).is_false()


func test_the_scope_is_rebuilt_from_todays_levels() -> void:
	var level := RunSave.resumable_level(_state(["t2", "t3"]), _levels())
	assert_array(level["scope"]).is_equal(["zz_book/1/2", "zz_book/1/3"])
	assert_array(level["keys"]).is_equal(["t2", "t3"])


func test_a_place_that_is_gone_cannot_resume() -> void:
	# Ein Pack-Update hat die Unit auf drei Teile gekürzt: t4 gibt es nicht mehr.
	assert_dict(RunSave.resumable_level(_state(["t3", "t4"]), _levels(1, 3))).is_empty()


func test_a_state_from_a_newer_app_cannot_resume() -> void:
	var state := _state(["t1"])
	state["app_version"] = "999.0.0"
	assert_dict(RunSave.resumable_level(state, _levels())).is_empty()
	state["app_version"] = SemVer.app_version()
	state["format"] = RunSave.FORMAT + 1
	assert_dict(RunSave.resumable_level(state, _levels())).is_empty()


func test_the_resume_is_taken_once() -> void:
	var state := _state(["t1"])
	RunRequest.start_level(MapLevel.combine(_levels(), ["t1"]), state)
	assert_int(int(RunRequest.take_resume()["next_wave"])).is_equal(7)
	assert_dict(RunRequest.take_resume()).is_empty()
	RunRequest.start_level(MapLevel.combine(_levels(), ["t1"]), state)
	RunRequest.start_expert()
	assert_dict(RunRequest.take_resume()).is_empty()


# --- Festung --------------------------------------------------------------------

func test_the_maximum_is_computed_and_the_stand_capped() -> void:
	GameState.apply_skills({"max_health": 20, "fortress_armor": 10})
	GameState.restore_run({"fortress_health": 200, "fortress_armor": 30, "score": 5,
			"min_fortress_health": 300})
	assert_int(GameState.fortress_max_health).is_equal(120)
	assert_int(GameState.fortress_health).is_equal(120)
	assert_int(GameState.fortress_armor).is_equal(10)
	assert_int(GameState.min_fortress_health).is_equal(120)
	assert_int(GameState.score).is_equal(5)


func test_new_skills_raise_the_maximum_on_resume() -> void:
	GameState.apply_skills({})
	GameState.restore_run({"fortress_health": 60})
	var snapshot := GameState.run_snapshot()
	GameState.reset()
	GameState.apply_skills({"max_health": 50})
	GameState.restore_run(snapshot)
	assert_int(GameState.fortress_max_health).is_equal(150)
	assert_int(GameState.fortress_health).is_equal(60)


func test_a_rested_fortress_never_resumes_fallen() -> void:
	GameState.apply_skills({})
	GameState.restore_run({"fortress_health": 0})
	assert_int(GameState.fortress_health).is_equal(1)


# --- Wann gerastet und gefragt wird ---------------------------------------------

func test_only_a_standing_run_from_the_map_rests() -> void:
	assert_bool(WAVE_RUNNER.can_rest(true, true)).is_true()
	assert_bool(WAVE_RUNNER.can_rest(true, false)).is_false()
	assert_bool(WAVE_RUNNER.can_rest(false, true)).is_false()


func test_escape_rests_from_the_second_wave_of_a_map_run() -> void:
	assert_bool(WAVE_RUNNER.escape_rests(true, 1)).is_false()
	assert_bool(WAVE_RUNNER.escape_rests(true, 2)).is_true()
	assert_bool(WAVE_RUNNER.escape_rests(false, 9)).is_false()


func test_the_stage_two_button_says_rest_on_the_map() -> void:
	RunRequest.start_level(MapLevel.combine(_levels(), ["t1"]))
	var stats := auto_free(STATS_SCENE.instantiate()) as PanelContainer
	add_child(stats)
	var data := {"won": true, "wave_number": 2, "correct": 5, "total": 5,
			"chest": ChestReward.for_wave(60, 5, 0)}
	stats.show_stats(data)
	var button := stats.get_node("%MenuButton") as Button
	assert_str(button.text).is_equal(stats.REST_TEXT)
	data["won"] = false
	stats.show_stats(data)
	assert_str(button.text).is_equal("⟵ Zurück zur Karte")


# --- Sitzungen ------------------------------------------------------------------

func test_sessions_carry_suspended_and_continues() -> void:
	var sessions: Node = auto_free(SESSION_LOG.new())
	sessions.player_id = PROFILE
	sessions.begin()
	sessions.note_resumed(1234)
	sessions.note_wave_cleared()
	sessions.note_suspended()
	sessions.end({"wave_reached": 8, "last_wave_won": true})
	var entry: Dictionary = sessions.sessions().back()
	assert_int(int(entry["continues"])).is_equal(1234)
	assert_bool(bool(entry["suspended"])).is_true()
	assert_int(int(entry["wave_reached"])).is_equal(8)


func test_the_trace_tells_an_extended_resume() -> void:
	var plain := TraceView.describe({"e": "run_resume", "next_wave": 5, "hp": 40})
	var grown := TraceView.describe({"e": "run_resume", "next_wave": 5, "hp": 40,
			"added": ["t3"]})
	assert_str(str(plain["text"])).not_contains("erweitert")
	assert_str(str(grown["text"])).contains("erweitert")
	assert_str(str(grown["hint"]["body"])).contains("t3")


# --- Rasten mitten in der Welle (ADR 0020 Nachtrag) -------------------------------

func _open_wave(remaining := 17) -> Dictionary:
	return {"remaining": remaining, "total": 42, "correct": 20, "leaked": 5,
			"score_gained": 300, "xp": 80, "level_at_start": 6, "low_hp": 30,
			"fortress_tier": 2, "pace": 0.5, "alts": true,
			"played": [{"prompt": "dog", "answers": ["Hund"], "leaked": true}]}


func test_a_rest_in_the_wave_keeps_the_open_wave() -> void:
	var level := MapLevel.combine(_levels(), ["t1"])
	RunSave.store(RunSave.build(level, 23, 4, {"fortress_health": 60}, 1000, 2000,
			_open_wave()), PROFILE)
	var state := RunSave.of_unit("zz_book", 1, PROFILE)
	assert_int(int(state["next_wave"])).is_equal(23)
	var wave := RunSave.open_wave(state)
	assert_int(int(wave["remaining"])).is_equal(17)
	assert_int(int(wave["fortress_tier"])).is_equal(2)
	assert_array(wave["played"]).has_size(1)


func test_a_rest_at_the_wave_end_has_no_open_wave() -> void:
	assert_dict(RunSave.open_wave(_state(["t1"]))).is_empty()
	assert_bool(_state(["t1"]).has("wave")).is_false()
	var level := MapLevel.combine(_levels(), ["t1"])
	var done := RunSave.build(level, 23, 4, {}, 1000, 2000, _open_wave(0))
	assert_dict(RunSave.open_wave(done)).is_empty()


func test_a_continued_wave_gets_no_second_repair() -> void:
	GameState.apply_skills({"fortress_armor": 10, "armor_regen": 4})
	GameState.restore_run({"fortress_health": 60, "fortress_armor": 3})
	EventBus.wave_started.emit("procedural_23")
	assert_int(GameState.fortress_armor).is_equal(7)
	GameState.continue_wave(25, 3)
	assert_int(GameState.fortress_armor).is_equal(3)
	assert_int(GameState.wave_resolved).is_equal(25)


func test_the_trace_tells_a_rest_in_the_wave() -> void:
	var at_end := TraceView.describe({"e": "run_suspend", "next_wave": 24, "hp": 40})
	var in_wave := TraceView.describe({"e": "run_suspend", "next_wave": 23, "hp": 40,
			"remaining": 17})
	assert_str(str(at_end["text"])).contains("weiter mit Welle 24")
	assert_str(str(in_wave["text"])).contains("noch 17 Monster")
