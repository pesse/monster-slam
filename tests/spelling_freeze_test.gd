extends GdUnitTestSuite
## Das Standbild nach einem nachsichtigen Treffer (ADR 0010): welche Stellen markiert
## werden und dass die Szene steht, fährt und wieder geht. Einzelne Allerweltswörter als
## Beispiele, keine Wortliste.

const SCENE := preload("res://scenes/ui/spelling_freeze.tscn")

var _f: SpellingFreeze
var _started: Array[int] = []


func before_test() -> void:
	_started.clear()
	_f = auto_free(SCENE.instantiate())
	add_child(_f)
	_f.started.connect(func(ms: int) -> void: _started.append(ms))


func after_test() -> void:
	remove_child(_f)


func _pump(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


static func _marks(canonical: String, typed: String) -> Array:
	return Array(AnswerEvaluator.spelling_marks(canonical, typed))


# --- Was markiert wird --------------------------------------------------------

func test_a_missing_accent_marks_its_letter() -> void:
	assert_array(_marks("l'école", "l'ecole")).is_equal([2])


func test_a_missing_apostrophe_or_one_typed_as_space_is_marked() -> void:
	assert_array(_marks("l'école", "lecole")).is_equal([1, 2])
	assert_array(_marks("l'école", "l ecole")).is_equal([1, 2])
	assert_array(_marks("aujourd'hui", "aujourdhui")).is_equal([7])


func test_a_cedilla_and_a_ligature_are_marked() -> void:
	assert_array(_marks("ils reçoivent", "ils recoivent")).is_equal([6])
	# œ ist ein Zeichen und wird als eines markiert, auch wenn „oe" getippt wurde.
	assert_array(_marks("le cœur", "le coeur")).is_equal([4])


func test_hyphens_count_like_apostrophes() -> void:
	assert_array(_marks("est-ce que", "est ce que")).is_equal([3])


## Was weggelassen werden durfte (Artikel, Platzhalter), ist kein Schreibfehler.
func test_omitted_optional_parts_are_not_marked() -> void:
	assert_array(_marks("l'école", "école")).is_equal([])
	assert_array(_marks("recevoir qn", "recevoir")).is_equal([])
	assert_array(_marks("préparer qc", "preparer")).is_equal([2])


func test_case_and_typographic_apostrophes_do_not_count() -> void:
	assert_array(_marks("L’École", "l'école")).is_equal([])
	assert_array(_marks("l'école", "L'ECOLE")).is_equal([2])


# --- Fehlende Teile (blau) ----------------------------------------------------

func _missing(canonical: String, typed: String) -> String:
	var out := ""
	for i in AnswerEvaluator.missing_marks(canonical, typed):
		out += canonical[i]
	return out


func test_a_left_out_group_is_marked_with_its_brackets() -> void:
	assert_str(_missing("die Meinung (zu etwas)", "meinung")).is_equal("(zuetwas)")


func test_only_the_part_nobody_typed_is_missing() -> void:
	assert_str(_missing("die Meinung (zu etwas)", "meinung zu")).is_equal("etwas")


func test_placeholders_and_optional_groups_are_missing() -> void:
	assert_str(_missing("criticize sb. (for)", "criticize")).is_equal("sb.(for)")


## Artikel, Auslassungspunkte und ein vollständiger Treffer: nichts blau.
func test_what_does_not_count_for_completeness_stays_unmarked() -> void:
	assert_str(_missing("l'école", "ecole")).is_empty()
	assert_str(_missing("not only … but also", "not only but also")).is_empty()
	assert_str(_missing("die Meinung (zu etwas)", "meinung zu etwas")).is_empty()


# --- Die Szene ----------------------------------------------------------------

func test_markup_colors_and_underlines_only_the_marked_letters() -> void:
	var text := SpellingFreeze.markup("l'école", PackedInt32Array([2]), Color(1, 0, 0))
	assert_str(text).is_equal("l'[color=#ff0000][u]é[/u][/color]cole")
	assert_str(SpellingFreeze.markup("[x]", PackedInt32Array(), Color.RED)).is_equal("[lb]x]")


func test_markup_colors_missing_parts_in_their_own_color() -> void:
	var text := SpellingFreeze.markup("ab", PackedInt32Array([0]), Color(1, 0, 0),
			PackedInt32Array([1]), Color(0, 0, 1))
	assert_str(text).is_equal("[color=#ff0000][u]a[/u][/color][color=#0000ff][u]b[/u][/color]")


func test_the_styles_exist_in_the_theme() -> void:
	var theme: Theme = load("res://scenes/ui/ui_theme.tres")
	assert_str(theme.get_type_variation_base(&"SpellingWord")).is_equal("RichTextLabel")
	assert_str(theme.get_type_variation_base(&"SpellingMark")).is_equal("Label")
	assert_str(theme.get_type_variation_base(&"SpellingMissing")).is_equal("Label")
	assert_bool(theme.has_color(&"font_color", &"SpellingMissing")).is_true()


func test_the_freeze_runs_while_paused() -> void:
	assert_int(_f.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## Erst der Vorlauf (die Explosion läuft noch), dann `started` mit der Standzeit, die
## Kamera fährt hin und zurück, und am Ende steht sie genau wie vorher.
func test_it_stands_zooms_and_returns() -> void:
	var seen: Array[float] = []
	var finished := [0]
	_f.finished.connect(func() -> void: finished[0] += 1)
	_f.play("l'école", PackedInt32Array([2]), func(k: float) -> void: seen.append(k))
	assert_bool(_f.is_busy()).is_true()
	assert_array(_started).is_empty()
	await _pump(SpellingFreeze.LEAD_MS + 100)
	assert_array(_started).is_equal([SpellingFreeze.duration_ms()])
	assert_bool(_f.visible).is_true()
	await _pump(SpellingFreeze.duration_ms() + 200)
	assert_int(finished[0]).is_equal(1)
	assert_bool(_f.visible).is_false()
	assert_bool(_f.is_busy()).is_false()
	assert_float(seen.max()).is_equal_approx(1.0, 0.001)
	assert_float(seen[-1]).is_equal_approx(0.0, 0.001)


## Zwei kurz nacheinander: das zweite folgt, `finished` kommt einmal am Ende.
func test_a_second_freeze_follows_the_first() -> void:
	var finished := [0]
	_f.finished.connect(func() -> void: finished[0] += 1)
	_f.play("l'école", PackedInt32Array([2]))
	_f.play("le cœur", PackedInt32Array([4]))
	await _pump(2 * (SpellingFreeze.LEAD_MS + SpellingFreeze.duration_ms()) + 300)
	assert_int(_started.size()).is_equal(2)
	assert_int(finished[0]).is_equal(1)


func test_the_battle_carries_the_freeze() -> void:
	var state := (load("res://scenes/battle/battle.tscn") as PackedScene).get_state()
	var found := false
	for i in state.get_node_count():
		found = found or state.get_node_name(i) == &"SpellingFreeze"
	assert_bool(found).is_true()


# --- Die Namen der Akzente ----------------------------------------------------

func test_each_marked_accent_gets_its_name() -> void:
	var groups := SpellingFreeze.accent_groups("ils reçoivent", PackedInt32Array([6]))
	assert_array(groups).is_equal([{"name": "cédille", "first": 6, "last": 6}])
	assert_str(str(SpellingFreeze.accent_groups("l'École", PackedInt32Array([2]))[0]["name"])) \
			.is_equal("accent aigu")


## Apostroph und Bindestrich sind keine Akzente: markiert ja, benannt nein.
func test_joiners_get_no_name() -> void:
	assert_array(SpellingFreeze.accent_groups("l'école", PackedInt32Array([1, 2]))) \
			.is_equal([{"name": "accent aigu", "first": 2, "last": 2}])


func test_the_same_accent_close_together_is_named_once() -> void:
	assert_array(SpellingFreeze.accent_groups("été", PackedInt32Array([0, 2]))) \
			.is_equal([{"name": "accent aigu", "first": 0, "last": 2}])
	assert_int(SpellingFreeze.accent_groups("élève", PackedInt32Array([0, 2])).size()).is_equal(2)


## Jedes Zeichen, das der nachsichtige Vergleich nachsieht, hat einen Namen.
func test_every_folded_accent_has_a_name() -> void:
	for c in AnswerEvaluator._DIACRITICS:
		assert_bool(SpellingFreeze.ACCENT_NAMES.has(c)).override_failure_message(c).is_true()


## Ein Name, der niemandem im Weg ist, bleibt direkt über dem Wort.
func test_a_single_name_stays_on_the_lower_row() -> void:
	_f.play("ils reçoivent", PackedInt32Array([6]))
	var names := _f.get_node("%Names") as Control
	var label := names.get_child(0) as Label
	assert_float(label.position.y + label.get_combined_minimum_size().y) \
			.is_equal_approx(names.custom_minimum_size.y, 0.5)
	await _pump(SpellingFreeze.LEAD_MS + SpellingFreeze.duration_ms() + 200)


func test_the_names_stand_over_the_word() -> void:
	_f.play("élève", PackedInt32Array([0, 2]))
	var names := _f.get_node("%Names")
	assert_int(names.get_child_count()).is_equal(2)
	var first := names.get_child(0) as Label
	var second := names.get_child(1) as Label
	assert_str(first.text).is_equal("accent aigu")
	assert_str(second.text).is_equal("accent grave")
	# Nebeneinander passen sie nicht: gelesen wird von oben nach unten, der linke steht oben.
	assert_float(first.position.y).is_less(second.position.y)
	assert_float(first.position.x).is_less(second.position.x)
	await _pump(SpellingFreeze.LEAD_MS + SpellingFreeze.duration_ms() + 200)
