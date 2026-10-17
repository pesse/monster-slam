extends GdUnitTestSuite
## Neue Aufgaben mit Lösung auf dem Schild und ihre Wiederholung (ADR 0027).
##
## Statisch mit erfundenen Kandidaten wie wave_shown_order_test: weder Sprachdaten noch
## der Lernstand des Entwicklungsprofils spielen mit.

const GENERATOR := preload("res://src/battle/wave_generator.gd")
const NOW := 1790877600


func _translate(source_id: String, direction := "de_to_en") -> Dictionary:
	return {"source": {"id": source_id},
		"learnable_id": TaskResolver.learnable_id("translate", direction, source_id),
		"definition": {"task_type": "translate", "direction": direction}, "extra": {}}


func _form(source_id: String) -> Dictionary:
	return {"source": {"id": source_id}, "learnable_id": "forms:%s:la_perfect" % source_id,
		"definition": {"task_type": "forms", "direction": "la", "requires_form": "la_perfect"},
		"extra": {}}


func _seen() -> Dictionary:
	return {"confidence": 0.5, "last_seen": NOW - 86400, "due_at": NOW - 3600}


## `seen`: learnable_ids mit Lernstand, alle anderen nie beantwortet.
func _state(seen: Array) -> Callable:
	return func(id: String) -> Dictionary: return _seen() if id in seen else {}


func _sources(order: Array) -> Array:
	return order.map(func(c): return str(c["source"]["id"]))


func test_a_never_answered_task_shows_its_answer() -> void:
	assert_bool(GENERATOR.needs_help(_translate("a"), _state([]), Introductions.new())).is_true()


## Ohne Einführungen (Expertenwerkzeuge, has_playable) steht nie eine Lösung da.
func test_without_introductions_nothing_is_shown() -> void:
	assert_bool(GENERATOR.needs_help(_translate("a"), _state([]), null)).is_false()


func test_an_answered_task_shows_nothing() -> void:
	var c := _translate("a")
	assert_bool(GENERATOR.needs_help(c, _state([c["learnable_id"]]), Introductions.new())).is_false()


## Wer eine Richtung kennt, kennt beide Seiten des Worts.
func test_a_known_reverse_direction_shows_nothing() -> void:
	var reverse: String = _translate("a", "en_to_de")["learnable_id"]
	assert_bool(GENERATOR.needs_help(_translate("a"), _state([reverse]), Introductions.new())) \
			.is_false()


## Eine Form folgt meist aus dem Wort: nie mit Lösung, auch nicht bei einem neuen Wort.
func test_a_form_never_shows_its_answer() -> void:
	assert_bool(GENERATOR.needs_help(_form("a"), _state([]), Introductions.new())).is_false()


## Im Lauf eingeführt heißt: keine Lösung mehr, auch nicht für die Gegenrichtung.
func test_an_introduced_word_shows_nothing_in_either_direction() -> void:
	var intro := Introductions.new()
	var task := {"learnable_id": _translate("a")["learnable_id"], "help": true,
		"help_key": GENERATOR.help_key(_translate("a"))}
	intro.note_spawn(task)
	assert_bool(GENERATOR.needs_help(_translate("a"), _state([]), intro)).is_false()
	assert_bool(GENERATOR.needs_help(_translate("a", "en_to_de"), _state([]), intro)).is_false()
	assert_int(intro.in_wave).is_equal(1)


func _introduce(intro: Introductions, count: int) -> void:
	for i in count:
		intro.note_spawn({"learnable_id": "x%d" % i, "help": true, "help_key": "x%d" % i})


## Ist die Welle voll, kommen erst die bekannten Wörter, die noch nicht dran waren.
func test_a_full_wave_puts_known_words_first() -> void:
	var intro := Introductions.new()
	_introduce(intro, GENERATOR.INTRODUCTIONS_PER_WAVE)
	var known := _translate("k")
	var cands := [_translate("n1"), _translate("n2"), known, _translate("n3")]
	var order := GENERATOR.ordered(cands, _state([known["learnable_id"]]), {}, NOW, intro)
	assert_str(str(_sources(order)[0])).is_equal("k")
	assert_array(order).has_size(4)


## Nur neue Wörter in der Unit: die Grenze greift nicht, es geht mit Lösung weiter.
func test_a_full_wave_without_known_words_keeps_introducing() -> void:
	var intro := Introductions.new()
	_introduce(intro, GENERATOR.INTRODUCTIONS_PER_WAVE)
	var order := GENERATOR.ordered([_translate("n1"), _translate("n2")], _state([]), {}, NOW, intro)
	assert_array(order).has_size(2)
	assert_bool(order.all(func(c): return bool(c["help"]))).is_true()


func test_the_limit_counts_per_wave() -> void:
	var intro := Introductions.new()
	_introduce(intro, GENERATOR.INTRODUCTIONS_PER_WAVE)
	intro.new_wave()
	assert_int(intro.in_wave).is_equal(0)


## Nach dem Abtippen kommt die Aufgabe RETEST_AFTER Spawns später, auch über die Welle hinaus.
func test_a_copied_task_is_due_after_the_gap() -> void:
	var intro := Introductions.new()
	var task := {"learnable_id": "t", "help": true, "help_key": "t"}
	intro.note_spawn(task)
	intro.note_copied(task)
	for i in GENERATOR.RETEST_AFTER - 1:
		intro.note_spawn({"learnable_id": "o%d" % i})
		assert_array(intro.due()).is_empty()
	intro.new_wave()
	intro.note_spawn({"learnable_id": "last"})
	assert_array(intro.due()).is_equal(["t"])
	intro.note_spawn({"learnable_id": "t"})
	assert_array(intro.due()).is_empty()


func test_a_due_retest_goes_first() -> void:
	var cands := [_translate("a"), _translate("b"), _translate("c")]
	var order := GENERATOR.retests_first(cands, [cands[2]["learnable_id"]])
	assert_array(_sources(order)).is_equal(["c", "a", "b"])
	assert_bool(bool(order[0].get("retest", false))).is_true()

