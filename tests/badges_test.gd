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
	assert_int(Badges.step_tier(Badges.WORD_STEPS, 250)).is_equal(4)


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
	assert_str(str(badge["mark"])).is_equal("20")
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
