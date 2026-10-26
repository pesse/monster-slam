extends GdUnitTestSuite
## Erfolge (Achievements, AchievementBook, Issue #74): die Regeln über Fakten, das Nachtragen
## schon erfüllter Erfolge und die Datei auf einem `zz-`-Profil.

const BOOK := preload("res://src/progression/achievement_book.gd")
const PROFILE := "zz-achievements-test"
const TOAST := preload("res://scenes/ui/achievement_toast.tscn")
const ROW := preload("res://scenes/ui/achievement_row.tscn")


func after_test() -> void:
	var path := "user://progress/%s_achievements.json" % PROFILE
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _book() -> Node:
	var book: Node = auto_free(BOOK.new())
	book.player_id = PROFILE
	book._load()
	return book


func test_catalog_ids_are_unique_and_words_come_per_language() -> void:
	var catalog := Achievements.catalog(["en", "fr"])
	var ids := {}
	for entry: Dictionary in catalog:
		assert_bool(ids.has(entry["id"])).override_failure_message(str(entry["id"])).is_false()
		ids[entry["id"]] = true
	assert_bool(ids.has("words_en_50")).is_true()
	assert_bool(ids.has("words_fr_1000")).is_true()
	assert_str(str(Achievements.find(["fr"], "words_fr_100")["title"])).is_equal("Französisch-Vokabeljäger")


func test_badge_collector_needs_every_daily_kind() -> void:
	assert_int(int(Achievements.find([], "badges_all")["need"])).is_equal(Badges.DAY_ORDER.size())


func test_progress_caps_at_need_and_moments_have_none() -> void:
	var entry := Achievements.find([], "streak_7")
	assert_array(Achievements.progress(entry, {"best_streak": 3})).is_equal([3, 7])
	assert_array(Achievements.progress(entry, {"best_streak": 12})).is_equal([7, 7])
	assert_bool(Achievements.reached(entry, {"best_streak": 7})).is_true()
	var moment := Achievements.find([], "wave_last_hp")
	assert_array(Achievements.progress(moment, {})).is_equal([0, 0])
	assert_bool(Achievements.reached(moment, {})).is_false()


func test_longest_run_counts_consecutive_days() -> void:
	assert_int(Achievements.longest_run([])).is_equal(0)
	assert_int(Achievements.longest_run([10, 3, 4, 5, 5, 12, 11])).is_equal(3)
	assert_int(Achievements.longest_run([1, 3, 5])).is_equal(1)


func test_unit_facts_take_the_best_unit_and_the_best_whole_book() -> void:
	var units := {
		"a/1": {"book": "a", "tier": 4}, "a/2": {"book": "a", "tier": 1},
		"b/1": {"book": "b", "tier": 2}, "b/2": {"book": "b", "tier": 3},
	}
	assert_dict(Achievements.unit_facts(units)).is_equal({"best_unit_tier": 4, "best_book_tier": 2})
	assert_dict(Achievements.unit_facts({})).is_equal({"best_unit_tier": 0, "best_book_tier": 0})


func test_finished_branch_is_a_learned_leaf_beyond_the_root() -> void:
	var entries := [
		{"id": "tree.t", "kind": "tree"},
		{"id": "s.root", "kind": "skill", "tier": 1, "requires": []},
		{"id": "s.mid", "kind": "skill", "tier": 2, "requires": ["s.root"]},
		{"id": "s.end", "kind": "skill", "tier": 3, "requires": ["s.mid"]},
		{"id": "s.solo", "kind": "skill", "tier": 1, "requires": []},
	]
	assert_int(Achievements.finished_branches(entries, PackedStringArray(["s.root", "s.mid"]))).is_equal(0)
	assert_int(Achievements.finished_branches(entries, PackedStringArray(["s.solo"]))).is_equal(0)
	assert_int(Achievements.finished_branches(entries,
			PackedStringArray(["s.root", "s.mid", "s.end"]))).is_equal(1)


func test_badge_kinds_count_kinds_with_a_day() -> void:
	var tally := {"hits": {"days": 3}, "kept": {"days": 0}, "revenge": {"days": 1}}
	assert_int(Achievements.badge_kinds(tally)).is_equal(2)


func test_check_backfills_what_is_reached_and_only_once() -> void:
	var book := _book()
	var facts := {"level": 11, "words_en": 120}
	var first: Array = book.check(facts, ["en"])
	assert_array(first).contains_exactly_in_any_order(
			["level_5", "level_10", "words_en_50", "words_en_100"])
	assert_bool(book.is_unlocked("level_10")).is_true()
	assert_int(book.unlocked_at("level_10")).is_greater(0)
	assert_array(book.check(facts, ["en"])).is_empty()


func test_check_only_looks_at_the_requested_facts() -> void:
	var book := _book()
	var facts := {"level": 5, "words_en": 50}
	assert_array(book.check(facts, ["en"], ["words"])).is_equal(["words_en_50"])
	assert_array(book.check(facts, ["en"], ["level"])).is_equal(["level_5"])


func test_unlocked_facts_are_not_computed_again() -> void:
	var book := _book()
	var calls := [0]
	var chests := func() -> int:
		calls[0] += 1
		return 10
	book.check({"chests": chests}, [], ["chests"])
	assert_int(calls[0]).is_equal(1)
	book.check({"chests": chests}, [], ["chests"])
	assert_int(calls[0]).is_equal(1)


func test_moment_unlocks_once_and_never_from_facts() -> void:
	var book := _book()
	assert_array(book.check({}, [])).not_contains(["boss_flawless"])
	assert_bool(book.unlock("boss_flawless")).is_true()
	assert_bool(book.unlock("boss_flawless")).is_false()


func test_unlocked_survive_reload() -> void:
	var book := _book()
	book.check({"level": 5}, [])
	var at: int = book.unlocked_at("level_5")
	var again := _book()
	assert_bool(again.is_unlocked("level_5")).is_true()
	assert_int(again.unlocked_at("level_5")).is_equal(at)


func test_unreadable_file_unlocks_nothing() -> void:
	DirAccess.make_dir_recursive_absolute("user://progress")
	var file := FileAccess.open("user://progress/%s_achievements.json" % PROFILE, FileAccess.WRITE)
	file.store_string("{kaputt")
	file.close()
	var book := _book()
	assert_array(book.check({"level": 20}, [])).is_empty()
	assert_bool(book.unlock("boss_flawless")).is_false()


# --- Moment-Erfolge -----------------------------------------------------------

func test_a_wave_won_on_a_thread() -> void:
	var book := _book()
	book.on_wave_cleared("w", Achievements.THREAD_HP + 1)
	assert_bool(book.is_unlocked("wave_last_hp")).is_false()
	book.on_wave_cleared("w", Achievements.THREAD_HP)
	assert_bool(book.is_unlocked("wave_last_hp")).is_true()


func test_untouched_needs_waves_without_any_damage() -> void:
	var book := _book()
	book.on_run_started()
	book.on_wave_cleared("1", 100)
	book.on_fortress_damaged(4)
	book.on_wave_cleared("2", 96)
	book.on_wave_cleared("3", 96)
	assert_bool(book.is_unlocked("run_untouched")).is_false()
	book.on_run_started()
	for wave in Achievements.UNTOUCHED_WAVES:
		book.on_fortress_damaged(0)
		book.on_wave_cleared(str(wave), 100)
	assert_bool(book.is_unlocked("run_untouched")).is_true()


func test_flawless_boss_needs_judged_answers_and_no_miss() -> void:
	var book := _book()
	book.on_boss_started("b")
	book.on_boss_won("b", "u")
	assert_bool(book.is_unlocked("boss_flawless")).is_false()
	book.on_boss_started("b")
	book.on_boss_answer("s1", "x", {"hit": true})
	book.on_boss_answer("s2", "y", {"hit": false})
	book.on_boss_won("b", "u")
	assert_bool(book.is_unlocked("boss_flawless")).is_false()
	book.on_boss_started("b")
	book.on_boss_answer("s1", "x", {"hit": true})
	book.on_boss_won("b", "u")
	assert_bool(book.is_unlocked("boss_flawless")).is_true()


# --- Einblendung --------------------------------------------------------------

func test_toast_shows_queued_achievements_in_turn() -> void:
	var toast: CanvasLayer = auto_free(TOAST.instantiate())
	add_child(toast)
	var seen: Array = []
	toast.shown.connect(func(id: String) -> void: seen.append(id))
	toast.announce("level_5")
	toast.announce("streak_7")
	assert_bool(toast.is_busy()).is_true()
	await await_millis(100)
	assert_bool((toast.get_node("%Card") as Control).visible).is_true()
	assert_str((toast.get_node("%Title") as Label).text).is_equal("Level 5")
	await await_millis(int(1000 * 2 * (toast.SHOW_S + toast.SLIDE_S + toast.FADE_S)) + 300)
	assert_array(seen).is_equal(["level_5", "streak_7"])
	assert_bool(toast.is_busy()).is_false()
	assert_bool((toast.get_node("%Card") as Control).visible).is_false()
	remove_child(toast)


func test_a_long_queue_runs_faster() -> void:
	var toast: CanvasLayer = auto_free(TOAST.instantiate())
	add_child(toast)
	var seen: Array = []
	toast.shown.connect(func(id: String) -> void: seen.append(id))
	for id in ["level_5", "level_10", "level_20"]:
		toast.announce(id)
	await await_millis(int(1000 * 3 * (toast.FAST_S + toast.SLIDE_S + toast.FADE_S)) + 400)
	assert_array(seen).is_equal(["level_5", "level_10", "level_20"])
	remove_child(toast)


# --- Ansicht ------------------------------------------------------------------

func test_every_achievement_has_a_picture() -> void:
	for entry: Dictionary in Achievements.catalog(["en"]):
		assert_object(Achievements.icon(entry)).override_failure_message(str(entry["id"])).is_not_null()
	assert_object(Achievements.icon(Achievements.HIDDEN_ICON)).is_not_null()


func test_a_locked_row_is_grey_with_progress_and_an_unlocked_one_has_a_stamp() -> void:
	var row: AchievementRow = auto_free(ROW.instantiate())
	add_child(row)
	var entry := Achievements.find(["en"], "words_en_500")
	row.setup(entry, 0, [170, 500])
	assert_object((row.get_node("%Icon") as CanvasItem).material).is_not_null()
	assert_bool((row.get_node("%Progress") as Control).visible).is_true()
	assert_str((row.get_node("%Count") as Label).text).is_equal("170 / 500")
	row.setup(entry, 1_700_000_000, [500, 500])
	assert_object((row.get_node("%Icon") as CanvasItem).material).is_null()
	assert_bool((row.get_node("%Progress") as Control).visible).is_false()
	assert_str((row.get_node("%State") as Label).text).starts_with("Freigeschaltet")
	remove_child(row)
