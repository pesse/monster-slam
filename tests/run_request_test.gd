extends GdUnitTestSuite
## Was der nächste Kampf spielt: ein Level der Karte oder die Auswahl des Expertenmodus.


func after_test() -> void:
	RunRequest.start_expert()


func _level() -> Dictionary:
	return MapLevel.levels_for("access4", 2, 4)[1]


func test_a_level_plays_its_scope_without_filters() -> void:
	RunRequest.start_level(_level())
	var pool := RunRequest.task_pool(3)
	assert_array(pool["scope"]).is_equal(["access4/2/2"])
	assert_array(pool["tags"]).is_empty()
	assert_array(pool["task_types"]).is_empty()
	assert_array(pool["lexeme_types"]).is_empty()
	assert_int(int(pool["difficulty_max"])).is_equal(3)
	assert_array(RunRequest.tags()).is_empty()


func test_a_level_returns_to_the_area_map() -> void:
	RunRequest.start_level(_level())
	assert_str(RunRequest.return_scene()).is_equal(RunRequest.AREA_SCENE)
	assert_str(RunRequest.unit_key()).is_equal("access4/2")


func test_expert_mode_reads_the_profile_selection() -> void:
	RunRequest.start_expert()
	assert_bool(RunRequest.is_level()).is_false()
	assert_str(RunRequest.return_scene()).is_equal(RunRequest.MENU_SCENE)
	assert_str(RunRequest.unit_key()).is_empty()
	assert_dict(RunRequest.task_pool(2)).is_equal(WaveGenerator.pool_from_settings(2))
	assert_array(RunRequest.scope()).is_equal(Array(UserSettings.selected_scope()))


## Der Boss liest denselben Bereich wie der Kampf.
func test_the_boss_pool_follows_the_level() -> void:
	RunRequest.start_level(MapLevel.levels_for("access4", 2, 4)[5])
	var pool := SentenceSelector.pool_for_boss({"id": "boss.test"})
	assert_array(pool["scope"]).is_equal(["access4/2"])
	assert_array(pool["tags"]).is_empty()


## Das Level gehört dem Aufrufer nicht mehr, sobald es gesetzt ist.
func test_the_level_is_copied() -> void:
	var level := _level()
	RunRequest.start_level(level)
	level["scope"] = ["x"]
	assert_array(RunRequest.scope()).is_equal(["access4/2/2"])
