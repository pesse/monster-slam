extends GdUnitTestSuite
## Statistik-Screen: Auswahlregeln der Listen und Rekorde, Aufbau der Szene (Issue #5, #9, #11).
##
## Die Auswahl wird an der statischen wanted_rows() geprüft — mit erfundenen Zeilen im
## Format von PlayerProgress.records_for_display(), also ohne den echten Lernstand des
## Spielers anzufassen. Der Szenen-Test hängt den Screen einmal in den Baum: er soll
## Tippfehler in den Knotennamen der handgeschriebenen .tscn auffallen lassen.

const STATS_SCREEN := preload("res://src/ui/stats_screen.gd")
const STATS_SCENE := preload("res://scenes/ui/stats_screen.tscn")


func _row(label: String, confidence: float, attempts: int, correct: int, mastered_at := 0) -> Dictionary:
	return {
		"id": label, "label": label, "confidence": confidence,
		"mastered": confidence >= 0.8, "attempts": attempts, "correct": correct,
		"mastered_at": mastered_at,
	}


## Ein neues Wort mit niedriger Confidence, das noch nie falsch beantwortet wurde, ist
## kein Fahndungsfall — sonst stünde die Fahndungsliste voller Wörter, die der Spieler
## noch gar nicht gesehen hat.
func test_words_without_a_miss_are_no_wanted_case() -> void:
	var rows := [_row("neu", 0.2, 1, 1), _row("entwischt", 0.5, 4, 2)]
	var wanted := STATS_SCREEN.wanted_rows(rows)
	assert_int(wanted.size()).is_equal(1)
	assert_str(str(wanted[0]["label"])).is_equal("entwischt")


func test_weakest_confidence_comes_first() -> void:
	var rows := [_row("mittel", 0.5, 4, 2), _row("schwach", 0.1, 3, 1), _row("stark", 0.7, 5, 4)]
	var wanted := STATS_SCREEN.wanted_rows(rows)
	assert_str(str(wanted[0]["label"])).is_equal("schwach")
	assert_str(str(wanted[2]["label"])).is_equal("stark")


## Bei gleicher Confidence entscheidet die Zahl der Fehlversuche.
func test_ties_are_broken_by_misses() -> void:
	var rows := [_row("einmal", 0.4, 2, 1), _row("dreimal", 0.4, 6, 3)]
	var wanted := STATS_SCREEN.wanted_rows(rows)
	assert_str(str(wanted[0]["label"])).is_equal("dreimal")


func test_list_is_capped() -> void:
	var rows: Array = []
	for i in 12:
		rows.append(_row("wort%d" % i, 0.1 * float(i), 5, 1))
	assert_int(STATS_SCREEN.wanted_rows(rows).size()).is_equal(STATS_SCREEN.WANTED_COUNT)
	assert_int(STATS_SCREEN.wanted_rows(rows, 3).size()).is_equal(3)


func test_no_misses_at_all_yields_an_empty_list() -> void:
	assert_array(STATS_SCREEN.wanted_rows([_row("sitzt", 0.9, 5, 5)])).is_empty()


func test_misses_are_attempts_minus_correct() -> void:
	assert_int(STATS_SCREEN.misses(_row("x", 0.5, 7, 3))).is_equal(4)


# --- „Frisch gemeistert" und „Comeback" (Issue #9) ------------------------------

## Records ohne Zeitstempel (Altbestand von vor der Zeitmessung) sind nicht „frisch" —
## sonst stünde dort eine Meisterung vom 01.01.1970.
func test_rows_without_a_timestamp_are_not_fresh() -> void:
	var rows := [_row("alt", 0.9, 5, 5, 0), _row("neu", 0.9, 5, 5, 2000)]
	var fresh := STATS_SCREEN.fresh_rows(rows, 1000)
	assert_int(fresh.size()).is_equal(1)
	assert_str(str(fresh[0]["label"])).is_equal("neu")


func test_masteries_before_the_window_are_not_fresh() -> void:
	var rows := [_row("vorher", 0.9, 5, 5, 500), _row("drin", 0.9, 5, 5, 1500)]
	assert_int(STATS_SCREEN.fresh_rows(rows, 1000).size()).is_equal(1)


## Jüngste zuerst — oben steht, was gerade gesessen hat.
func test_fresh_list_is_newest_first_and_capped() -> void:
	var rows: Array = []
	for i in 8:
		rows.append(_row("wort%d" % i, 0.9, 5, 5, 1000 + i))
	var fresh := STATS_SCREEN.fresh_rows(rows, 0)
	assert_int(fresh.size()).is_equal(STATS_SCREEN.LIST_COUNT)
	assert_str(str(fresh[0]["label"])).is_equal("wort7")
	assert_int(STATS_SCREEN.fresh_rows(rows, 0, 2).size()).is_equal(2)


func test_a_week_without_a_mastery_yields_an_empty_fresh_list() -> void:
	assert_array(STATS_SCREEN.fresh_rows([_row("alt", 0.9, 5, 5, 100)], 1000)).is_empty()


## Ein Comeback ist beides: dreimal entwischt UND jetzt gemeistert.
func test_comeback_needs_misses_and_mastery() -> void:
	var rows := [
		_row("noch offen", 0.4, 6, 2, 0),       # dreimal entwischt, sitzt aber nicht
		_row("glatt", 0.9, 5, 5, 2000),         # gemeistert, nie entwischt
		_row("comeback", 0.9, 8, 5, 3000),      # dreimal entwischt und gemeistert
	]
	var comeback := STATS_SCREEN.comeback_rows(rows)
	assert_int(comeback.size()).is_equal(1)
	assert_str(str(comeback[0]["label"])).is_equal("comeback")


## Zwei Fehlversuche sind noch kein Comeback.
func test_two_misses_are_not_yet_a_comeback() -> void:
	assert_array(STATS_SCREEN.comeback_rows([_row("knapp", 0.9, 7, 5, 2000)])).is_empty()


## Das größte Comeback zuerst, bei gleichem Stand die jüngere Meisterung.
func test_comeback_list_is_sorted_by_misses_then_recency() -> void:
	var rows := [
		_row("dreimal alt", 0.9, 8, 5, 1000),
		_row("dreimal neu", 0.9, 8, 5, 5000),
		_row("fünfmal", 0.9, 10, 5, 2000),
	]
	var comeback := STATS_SCREEN.comeback_rows(rows)
	assert_str(str(comeback[0]["label"])).is_equal("fünfmal")
	assert_str(str(comeback[1]["label"])).is_equal("dreimal neu")


# --- Kampf-Rekorde (Issue #11) -------------------------------------------------

func _records(extra := {}) -> Dictionary:
	var out := {
		"sessions": 3, "highest_wave_cleared": 7, "best_no_leak_streak": 12,
		"monsters_defeated": 140, "monsters_leaked": 9, "min_fortress_health": 30,
		"best_fortress_floor": 80,
	}
	out.merge(extra, true)
	return out


## Ohne Sitzung gibt es keine Rekord-Zeilen — „0 Monster besiegt" ist kein leerer Block,
## sondern ein falscher.
func test_without_a_session_there_are_no_record_rows() -> void:
	assert_array(STATS_SCREEN.record_rows(_records({"sessions": 0}))).is_empty()


func test_the_records_read_their_values_from_the_session_log() -> void:
	var rows := STATS_SCREEN.record_rows(_records())
	assert_int(rows.size()).is_equal(4)
	assert_str(str(rows[0]["value"])).is_equal("7")
	assert_str(str(rows[1]["value"])).is_equal("12 Monster")
	assert_str(str(rows[2]["value"])).is_equal("140")


## Der schonendste Lauf ist der höchste der lauf-eigenen Tiefstände — NICHT der tiefste
## Stand überhaupt, der daneben im selben Dictionary steht.
func test_the_gentlest_run_is_shown_not_the_lowest_health_ever() -> void:
	var rows := STATS_SCREEN.record_rows(_records())
	assert_str(str(rows[3]["value"])).is_equal("nie unter 80 HP")


## Die Auszeichnung hängt an der Schwelle und sonst an nichts.
func test_the_shield_comes_with_the_threshold() -> void:
	var under := STATS_SCREEN.record_rows(
			_records({"best_fortress_floor": STATS_SCREEN.SPOTLESS_FORTRESS_HP - 1}))
	assert_str(str(under[3]["mark"])).is_empty()
	var at := STATS_SCREEN.record_rows(
			_records({"best_fortress_floor": STATS_SCREEN.SPOTLESS_FORTRESS_HP}))
	assert_str(str(at[3]["mark"])).is_not_empty()


## Gespielt, aber kein Lauf ordentlich beendet: die drei gezählten Bestwerte stehen da,
## die Zeile über die Festung bleibt weg statt einen erfundenen Stand zu behaupten.
func test_an_unknown_fortress_low_drops_its_row() -> void:
	var rows := STATS_SCREEN.record_rows(_records({"best_fortress_floor": -1}))
	assert_int(rows.size()).is_equal(3)


# --- Sitzungs-Genauigkeit (Issue #13) ------------------------------------------

func _accuracy(extra := {}) -> Dictionary:
	var out := {"answers": 20, "correct": 17, "accuracy": 0.85, "baseline": 0.75,
			"baseline_kind": "week", "live": false}
	out.merge(extra, true)
	return out


func test_without_a_session_the_accuracy_shows_no_number() -> void:
	var lines := STATS_SCREEN.accuracy_lines(_accuracy({"answers": 0, "accuracy": -1.0}))
	assert_str(str(lines["title"])).not_contains("%")


## Unter der Mindestzahl an Antworten steht die Sitzung als Bruch da, ohne Prozent und
## ohne Pfeil — auch wenn es einen Vergleichswert gäbe.
func test_too_few_answers_show_a_count_instead_of_a_percentage() -> void:
	var lines := STATS_SCREEN.accuracy_lines(_accuracy({"answers": 3, "correct": 2, "accuracy": -1.0}))
	assert_str(str(lines["title"])).contains("2 von 3")
	assert_str(str(lines["title"])).not_contains("%")
	for arrow in ["↑", "↓", "→"]:
		assert_str(str(lines["title"])).not_contains(arrow)


## Ohne Vorsitzung kein Pfeil — kein Vergleich gegen „0 %".
func test_without_a_baseline_there_is_no_arrow() -> void:
	var lines := STATS_SCREEN.accuracy_lines(_accuracy({"baseline": -1.0, "baseline_kind": ""}))
	assert_str(str(lines["title"])).contains("85 %")
	for arrow in ["↑", "↓", "→"]:
		assert_str(str(lines["title"])).not_contains(arrow)
	assert_str(str(lines["detail"])).not_contains("0 %")


func test_the_arrow_follows_the_difference_to_the_baseline() -> void:
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy())["title"])).ends_with("↑")
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy({"baseline": 0.95}))["title"])).ends_with("↓")
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy({"baseline": 0.84}))["title"])).ends_with("→")
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy())["detail"])).contains("10 Punkte")


func test_the_detail_names_what_it_compares_against() -> void:
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy())["detail"])).contains("7 Tagen")
	assert_str(str(STATS_SCREEN.accuracy_lines(
			_accuracy({"baseline_kind": "previous"}))["detail"])).contains("Sitzung davor")


## Die Unterzeile nennt, WELCHE Sitzung gemeint ist — die Kopfzahl trägt nur die Quote.
func test_the_subline_names_the_session() -> void:
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy())["which"])).is_equal("Letzte Sitzung")
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy({"live": true}))["which"])).is_equal("Diese Sitzung")
	assert_str(str(STATS_SCREEN.accuracy_lines(_accuracy())["title"])).not_contains("Sitzung")


## Die Szene muss sich bauen lassen und ihre Listen über die eindeutigen Namen finden —
## genau das geht in einer handgeschriebenen .tscn leicht schief.
func test_scene_builds_and_finds_its_lists() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	for list in ["%WantedList", "%FreshList", "%ComebackList", "%TaskList", "%RecordList",
			"%CloseButton", "%CoinStrip", "%XpBar"]:
		assert_object(screen.get_node(list)).override_failure_message(list).is_not_null()
	# Vier Lebenszeitwerte füllt _refresh_totals — die Gesamt-Genauigkeit steht dort und
	# nicht mehr oben (Issue #13).
	assert_int(screen.get_node("%TotalLines").get_child_count()).is_equal(4)
	# Die Wort-Serie erklärt sich zusätzlich am Zeiger — ohne Karte verwechselt man sie mit der
	# Tages-Serie und der Serie ohne Durchlass. Ohne MOUSE_FILTER_PASS käme die Karte nie.
	var streak := screen.get_node("%TotalLines").get_child(3) as Label
	assert_str(streak.text).starts_with("Längste Wort-Serie")
	assert_str(str(Hints.hint_of(streak).get("body", ""))).contains("einzelne Aufgabe")
	assert_int(streak.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_str((screen.get_node("%AccuracyLabel") as Label).text).is_not_empty()
	remove_child(screen)


## Level, Gold und Punkte kommen aus den Autoloads — die Zahlen stehen also, wie sie dort
## stehen, und der Balken zeigt den Anteil im Level.
func test_the_numbers_follow_level_and_wallet() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var progress := PlayerLevel.progress()
	assert_str((screen.get_node("%LevelLabel") as Label).text).is_equal(
			"Level %d" % int(progress["level"]))
	assert_str((screen.get_node("%XpLabel") as Label).text).is_equal("%d / %d XP" % [
			int(progress["xp_in_level"]), int(progress["xp_for_level_up"])])
	assert_float((screen.get_node("%XpBar") as ProgressBar).value).is_between(0.0, 1.0)
	assert_str((screen.get_node("%GoldValue") as Label).text).is_equal(Wallet.digits())
	assert_str((screen.get_node("%PointsValue") as Label).text).is_equal(str(SkillBook.available()))
	assert_str((screen.get_node("%DueValue") as Label).text).is_equal(str(PlayerProgress.due_count()))
	remove_child(screen)


## Ein Reiter zeigt seine Seite und nur sie; das Fenster bleibt dabei gleich groß.
func test_the_tabs_switch_pages() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var overview := screen.get_node("%OverviewPage") as Control
	var progress := screen.get_node("%ProgressPage") as Control
	var tasks := screen.get_node("%TaskPage") as Control
	assert_bool(overview.visible).is_true()
	assert_bool(progress.visible or tasks.visible).is_false()
	var before := (screen.get_node("%Window") as Control).size
	(screen.get_node("%ProgressTab") as Button).button_pressed = true
	assert_bool(progress.visible).is_true()
	assert_bool(overview.visible or tasks.visible).is_false()
	assert_bool((screen.get_node("%OverviewTab") as Button).button_pressed).is_false()
	(screen.get_node("%TaskTab") as Button).button_pressed = true
	assert_bool(tasks.visible).is_true()
	assert_bool(progress.visible).is_false()
	assert_vector((screen.get_node("%Window") as Control).size).is_equal(before)
	remove_child(screen)


## Die Sortierwahl steht in beiden Reitern und zeigt dort dasselbe; von Haus aus
## „Beste zuerst".
func test_both_sort_bars_follow_one_choice() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var word_alpha := screen.get_node("%WordSort/Alpha") as Button
	var task_alpha := screen.get_node("%TaskSort/Alpha") as Button
	assert_bool((screen.get_node("%WordSort/Best") as Button).button_pressed).is_true()
	assert_bool((screen.get_node("%TaskSort/Best") as Button).button_pressed).is_true()
	word_alpha.button_pressed = true
	word_alpha.pressed.emit()
	assert_bool(task_alpha.button_pressed).is_true()
	assert_bool((screen.get_node("%TaskSort/Best") as Button).button_pressed).is_false()
	(screen.get_node("%TaskSort/Best") as Button).pressed.emit()
	assert_bool((screen.get_node("%WordSort/Best") as Button).button_pressed).is_true()
	remove_child(screen)


## Schließen-X und Escape melden `closed` — das Menü nimmt das Fenster dann weg.
func test_close_and_escape_tell_the_opener() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var count := [0]
	screen.connect("closed", func() -> void: count[0] += 1)
	(screen.get_node("%CloseButton") as BaseButton).pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_int(count[0]).is_equal(2)
	assert_str(str(Hints.hint_of(screen.get_node("%CloseButton")).get("note", ""))).is_equal("Esc")
	remove_child(screen)


## Das Fenster passt in die Bezugsgröße: Kopf und Reiter stehen, der Rest scrollt.
func test_the_window_fits_the_reference_size() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var need := (screen.get_node("%Layout") as Control).get_combined_minimum_size() + Vector2(32, 32)
	assert_float(need.x).is_less_equal(1152.0)
	assert_float(need.y).is_less_equal(648.0)
	remove_child(screen)


## Zur Wahl stehen die Sprachen der Bücher, in der Reihenfolge des Bücherregals:
## Englisch zuerst, je Sprache ein Knopf.
func test_language_choices_come_from_the_books() -> void:
	var books := {"zz-latein": "la", "zz-access1": "en", "zz-aplusx": "fr", "zz-access2": "en"}
	var choices := STATS_SCREEN.language_choices(books.keys(), func(b): return books[b])
	assert_array(choices).is_equal(["en", "fr", "la"])


func test_filtered_titles_name_the_languages() -> void:
	assert_str(STATS_SCREEN.filtered_title("Lernkurve", [])).is_equal("Lernkurve")
	assert_str(STATS_SCREEN.filtered_title("Lernkurve", ["la"])).is_equal("Lernkurve · Latein")
	assert_str(STATS_SCREEN.filtered_title("Lernkurve", ["fr", "la"])).is_equal(
			"Lernkurve · Französisch, Latein")


## Sind alle Sprachen gewählt, wird nicht gefiltert — dann zählt auch, was keiner Sprache
## zugeordnet ist.
func test_all_languages_selected_means_no_filter() -> void:
	assert_array(STATS_SCREEN.language_filter(["en", "fr", "la"], ["en", "fr", "la"])).is_empty()
	assert_array(STATS_SCREEN.language_filter(["en", "la"], ["en", "fr", "la"])).is_equal(["en", "la"])


## Flaggen statt Text, mehrere zugleich; die letzte lässt sich nicht abschalten. Die Wahl
## benennt die gefilterten Abschnitte und lässt das Fenster gleich groß.
func test_the_language_flags_toggle_without_resizing() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	var bar := screen.get_node("%LanguageBar") as LanguageBar
	if not bar.visible:
		remove_child(screen)
		return  # Nur eine Sprache im Katalog: keine Wahl.
	var flags: Array = bar.get_children().filter(func(c): return c is Button)
	assert_int(flags.size()).is_greater_equal(2)
	for flag: Button in flags:
		assert_object(flag.icon).is_not_null()
		assert_str(flag.text).is_empty()
		assert_bool(flag.button_pressed).is_true()
	var before := (screen.get_node("%Window") as Control).size
	(flags[0] as Button).button_pressed = false
	assert_str((screen.get_node("%CurveTitle") as Label).text).contains(" · ")
	assert_str((screen.get_node("%AccuracyWhich") as Label).text).contains("alle Sprachen")
	assert_vector((screen.get_node("%Window") as Control).size).is_equal(before)
	# Bis auf eine abschalten — die letzte bleibt gedrückt.
	for flag: Button in flags:
		flag.button_pressed = false
	assert_array(bar.selected()).has_size(1)
	for flag: Button in flags:
		flag.button_pressed = true
	assert_str((screen.get_node("%CurveTitle") as Label).text).is_equal("Lernkurve")
	remove_child(screen)
