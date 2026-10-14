extends GdUnitTestSuite
## Plaketten im Kampf (Badges, Issue #63): die Regeln für sich, der Tag in der Datei, und
## dass die Feier sie hinter der Meisterung zeigt.

const PROFILE := "zz-badges-test"
const SCENE := preload("res://scenes/ui/mastery_celebration.tscn")


func after_test() -> void:
	var path := "user://progress/%s_badges.json" % PROFILE
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _ids(badges: Array) -> Array:
	var out: Array = []
	for badge: Dictionary in badges:
		out.append(str(badge["id"]))
	return out


## Eine Schwelle löst genau dann aus, wenn die Zahl sie trifft — sie steigt je Antwort um eins.
func test_step_tier_hits_exactly_the_steps() -> void:
	assert_int(Badges.step_tier(Badges.HIT_STEPS, 9)).is_equal(0)
	assert_int(Badges.step_tier(Badges.HIT_STEPS, 10)).is_equal(1)
	assert_int(Badges.step_tier(Badges.HIT_STEPS, 11)).is_equal(0)
	assert_int(Badges.step_tier(Badges.HIT_STEPS, 100)).is_equal(4)
	assert_int(Badges.step_tier(Badges.WORD_STEPS, 1000)).is_equal(4)


func test_answer_kind_reads_the_state_before_the_hit() -> void:
	var today := 20000
	# Neu: nichts außer dem Treffer.
	assert_str(Badges.answer_kind({}, 0, today)).is_empty()
	# Fast vergessen geht vor allem anderen.
	assert_str(Badges.answer_kind({"attempts": 4, "confidence": 0.07, "last_correct": false},
			today, today)).is_equal("catch_up")
	# Zuletzt durchgelassen.
	assert_str(Badges.answer_kind({"attempts": 1, "confidence": 0.15, "last_correct": false},
			today, today)).is_equal("revenge")
	# Zuletzt richtig, an einem früheren Tag.
	assert_str(Badges.answer_kind({"attempts": 2, "confidence": 0.5, "last_correct": true},
			today - 3, today)).is_equal("kept")
	# Zuletzt richtig, heute: nichts Besonderes.
	assert_str(Badges.answer_kind({"attempts": 2, "confidence": 0.5, "last_correct": true},
			today, today)).is_empty()


func test_better_needs_both_values() -> void:
	assert_bool(Badges.is_better({"accuracy": 0.9, "baseline": 0.8})).is_true()
	assert_bool(Badges.is_better({"accuracy": 0.8, "baseline": 0.8})).is_false()
	assert_bool(Badges.is_better({"accuracy": 0.9, "baseline": -1.0})).is_false()
	assert_bool(Badges.is_better({"accuracy": -1.0, "baseline": 0.5})).is_false()


func test_make_names_language_milestones() -> void:
	var badge := Badges.make("words", 1, {"lang": "fr"})
	assert_str(str(badge["title"])).is_equal("Französisch-Wortschnüffler")
	assert_str(str(badge["mark"])).is_equal("50")
	assert_str(str(badge["palette"])).is_equal("bronze")
	assert_str(str(Badges.make("revenge", 0, {"word": "x"})["palette"])).is_equal("revenge")


## Gezählt werden Wörter, nicht Richtungen; nur richtig Beantwortetes, nur die Sprache.
func test_lexemes_answered_counts_words_of_one_language() -> void:
	var records := {}
	records["translate:de_to_fr:zz.a"] = {"correct_total": 1}
	records["translate:fr_to_de:zz.a"] = {"correct_total": 2}
	records["translate:fr_to_de:zz.b"] = {"correct_total": 1}
	records["translate:de_to_fr:zz.c"] = {"correct_total": 0}
	records["translate:en_to_de:zz.d"] = {"correct_total": 3}
	records["conjugation:zz.e:present_je"] = {"correct_total": 1}
	assert_int(PlayerProgress.lexemes_answered_in(records, "fr")).is_equal(2)
	assert_int(PlayerProgress.lexemes_answered_in(records, "en")).is_equal(1)


## Das Comeback gibt es einmal am Tag, auch über einen neuen Kampf (neue Instanz) hinweg.
func test_comeback_once_a_day() -> void:
	var first := Badges.new(PROFILE)
	var ids := _ids(first.wave_won(0.2))
	assert_array(ids).contains(["comeback"])
	ids = _ids(first.wave_won(0.1))
	assert_array(ids).not_contains(["comeback"])
	var later := Badges.new(PROFILE)
	ids = _ids(later.wave_won(0.1))
	assert_array(ids).not_contains(["comeback"])


func test_no_comeback_above_the_red_zone() -> void:
	var badges := Badges.new(PROFILE)
	var ids := _ids(badges.wave_won(0.5))
	assert_array(ids).not_contains(["comeback"])


## In letzter Sekunde: der leerende Treffer kam höchstens LAST_SECOND vor dem Einschlag.
func test_last_second_once_a_day() -> void:
	var badges := Badges.new(PROFILE)
	assert_array(_ids(badges.wave_won(1.0, Badges.LAST_SECOND + 0.1))).not_contains(["last_second"])
	assert_array(_ids(badges.wave_won(1.0))).not_contains(["last_second"])
	assert_array(_ids(badges.wave_won(1.0, Badges.LAST_SECOND))).contains(["last_second"])
	assert_array(_ids(badges.wave_won(1.0, 0.2))).not_contains(["last_second"])


## Die Restzeit rechnet mit dem gebremsten Tempo und hängt das Eis an.
func test_seconds_left_counts_pace_and_frost() -> void:
	var monster := Monster.new()
	# 40 Einheiten sind 2 m/s, 3 m vor dem Ziel.
	monster.setup({}, {}, 5.0, 40.0)
	monster.position.z = 2.0
	assert_float(monster.seconds_left()).is_equal_approx(1.5, 0.001)
	monster.pace = 0.5
	monster._frozen_left = 0.5
	assert_float(monster.seconds_left()).is_equal_approx(3.5, 0.001)
	monster.free()


## Eine Plakette derselben Antwort kommt nach der Meister-Feier, und jede läuft.
func test_celebration_plays_badges_after_mastery() -> void:
	var c: MasteryCelebration = auto_free(SCENE.instantiate())
	add_child(c)
	var started: Array[int] = []
	c.started.connect(started.append)
	c.announce(Badges.make("hits", 1))
	EventBus.task_mastered.emit("translate:en_to_de:zz.lex.a")
	assert_bool(c.is_busy()).is_true()
	await get_tree().process_frame
	assert_array(started).is_equal([MasteryCelebration.TASK_MS])
	var until := Time.get_ticks_msec() + MasteryCelebration.TASK_MS + 200
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	assert_array(started).is_equal([MasteryCelebration.TASK_MS, MasteryCelebration.BADGE_MS])
	assert_str(c.get_node("%BadgeTitle").text).is_equal("10 Treffer heute!")
	assert_bool(c.get_node("BadgeContent").visible).is_true()
	assert_bool(c.get_node("Content").visible).is_false()
	remove_child(c)


## Bronze und Silber teilen den Ton, jede besondere Plakette hat einen eigenen — und jeder
## steht in Sfx.SOUNDS, sonst bliebe die Plakette stumm.
func test_every_badge_has_its_sound() -> void:
	var sounds := preload("res://src/core/sfx.gd").SOUNDS
	for badge: Dictionary in Badges.catalog():
		var common: bool = badge["palette"] in [&"bronze", &"silver"]
		assert_bool(badge["sound"] == &"badge_earned").append_failure_message(
				str(badge["palette"])).is_equal(common)
		assert_bool(sounds.has(badge["sound"])).append_failure_message(
				str(badge["sound"])).is_true()


## Jede Palette hat ihre Medaille im Bild.
func test_every_badge_has_its_art() -> void:
	for badge: Dictionary in Badges.samples():
		var path := "%s%s.webp" % [BadgePlate.ART_DIR, badge["palette"]]
		assert_bool(ResourceLoader.exists(path)).append_failure_message(path).is_true()


# --- Historie und Statistik ---------------------------------------------------

## Was am Tag verdient wurde, steht nach einem neuen Kampf (neue Instanz) noch beim Tag.
func test_earned_badges_stay_with_their_day() -> void:
	var first := Badges.new(PROFILE)
	first.wave_won(0.2, Badges.LAST_SECOND)
	var today := SessionLog.local_day(int(Time.get_unix_time_from_system()))
	var later := Badges.new(PROFILE)
	assert_array(_ids_of(later.day_list(today))).contains(["comeback", "last_second"])
	assert_array(later.day_list(today - 1)).is_empty()


## Eine Datei von vor der Historie kennt nur `earned` von heute; das gilt als heutiger Tag.
func test_a_file_without_history_keeps_today() -> void:
	var today := SessionLog.local_day(int(Time.get_unix_time_from_system()))
	SaveStore.write("user://progress/%s_badges.json" % PROFILE,
			{"day": today, "earned": ["better"], "kept": []})
	var badges := Badges.new(PROFILE)
	assert_array(_ids_of(badges.day_list(today))).contains_exactly(["better"])
	assert_array(_ids(badges.wave_won(1.0, Badges.LAST_SECOND))).contains_exactly(["last_second"])


func _ids_of(stored: Array) -> Array:
	return stored.map(func(entry: Array) -> String: return str(entry[0]))


## Je Art eine Zeile: Treffer aus den richtigen Antworten, gestufte mit ihrer höchsten Stufe,
## Wellen-Plaketten gezählt, alles in DAY_ORDER.
func test_day_summary_merges_a_day() -> void:
	var stored := [["revenge", 0], ["kept", 1], ["comeback", 0], ["kept", 2], ["revenge", 0.0]]
	var summary := Badges.day_summary(stored, 30)
	assert_array(summary.map(func(e: Dictionary) -> String: return e["id"])).is_equal(
			["hits", "kept", "comeback", "revenge"])
	assert_int(int(summary[0]["tier"])).is_equal(2)
	assert_int(int(summary[1]["tier"])).is_equal(2)
	assert_int(int(summary[3]["count"])).is_equal(2)
	assert_array(Badges.day_summary([], 9)).is_empty()


## Über alle Tage: Tage je Stufe (eine höhere zählt die niedrigeren mit), Anzahl, letzter Tag.
func test_tally_counts_days_and_badges() -> void:
	var days := {100: [["revenge", 0], ["revenge", 0]], 103: [["revenge", 0], ["better", 0]]}
	var correct := {100: 25, 101: 10, 102: 3}
	var tally := Badges.tally(days, correct)
	assert_array(tally["hits"]["tiers"]).is_equal([2, 1, 0, 0])
	assert_int(int(tally["hits"]["last"])).is_equal(101)
	assert_int(int(tally["revenge"]["count"])).is_equal(3)
	assert_int(int(tally["revenge"]["days"])).is_equal(2)
	assert_int(int(tally["better"]["last"])).is_equal(103)
	assert_int(int(tally["comeback"]["days"])).is_equal(0)
	assert_int(int(tally["comeback"]["last"])).is_equal(-1)


## Jede Plakette hat in der Statistik eine Überschrift ohne „heute“.
func test_describe_names_every_badge() -> void:
	for badge: Dictionary in Badges.catalog():
		var text := Badges.describe(str(badge["id"]), int(badge["tier"]), "en")
		assert_str(str(text["title"])).append_failure_message(str(badge["id"])).is_not_empty()
		assert_str(str(text["title"])).not_contains("heute")
		assert_str(str(text["body"])).is_not_empty()
