extends GdUnitTestSuite
## Boss-Siege je Unit: gespeichert wird je Sieg ein Eintrag, gezählt beim Lesen.

const PROFILE := "zz-boss-record"


func before_test() -> void:
	DirAccess.remove_absolute(BossRecord.path(PROFILE))


func after_test() -> void:
	DirAccess.remove_absolute(BossRecord.path(PROFILE))


func test_no_file_no_wins() -> void:
	assert_dict(BossRecord.wins(PROFILE)).is_empty()


func test_wins_are_counted_per_unit() -> void:
	BossRecord.record_win("access4/2", PROFILE)
	BossRecord.record_win("access4/2", PROFILE)
	BossRecord.record_win("access4/3", PROFILE)
	assert_dict(BossRecord.wins(PROFILE)).is_equal({"access4/2": 2, "access4/3": 1})
	assert_int(BossRecord.entries(PROFILE).size()).is_equal(3)
	assert_bool((BossRecord.entries(PROFILE)[0] as Dictionary).has("won_at")).is_true()


func test_a_win_without_unit_is_not_recorded() -> void:
	BossRecord.record_win("", PROFILE)
	assert_bool(FileAccess.file_exists(BossRecord.path(PROFILE))).is_false()


func test_medals_follow_the_thresholds() -> void:
	assert_array([0, 1, 2, 3, 4, 5, 9].map(func(n): return BossRecord.medal(n))).is_equal(
			[0, 1, 1, 2, 2, 3, 3])
