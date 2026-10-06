extends GdUnitTestSuite
## Gemeisterte WÖRTER und die Fortschrittsbalken pro Unit und Thema (Issue #8).
##
## Zwei Dinge werden geprüft: die Regel, wann ein Lexem als gemeistert gilt (beide
## Übersetzungsrichtungen), und die Gruppierung darüber. Beides an statischen Funktionen
## mit erfundenen Records und Lexemen — ohne den echten Lernstand des Spielers und ohne
## den Sprachkatalog, dessen Wortlaut hier nichts zu suchen hat.

const PROGRESS := preload("res://src/learning/player_progress.gd")
const STATS_SCREEN := preload("res://src/ui/stats_screen.gd")
const STATS_SCENE := preload("res://scenes/ui/stats_screen.tscn")
const PROGRESS_ROW_SCENE := preload("res://scenes/ui/progress_row.tscn")


## Buch-Benennung für die Zeilen-Labels; im Spiel liefert sie ContentRegistry.book_label.
static func _book_label(book: String) -> String:
	return book.capitalize()


func _record(confidence: float) -> Dictionary:
	return {
		"confidence": confidence, "attempts": 5, "correct_total": 4,
		"current_streak": 2, "best_streak": 3, "last_correct": true,
		"last_response_time_ms": 1500, "last_seen_at": 1000, "next_review_at": 0,
		"first_seen_at": 900, "mastered_at": 1000,
	}


func _lexeme(id: String, book: String, unit: int, tags: Array = []) -> Dictionary:
	var entry := {"id": id, "tags": tags, "lemma_en": id, "lemma_de": id.to_upper()}
	if not book.is_empty():
		entry["book"] = book
		entry["unit"] = unit
	return entry


# --- Die Regel: wann gilt ein WORT als gemeistert -------------------------------

## Beide Richtungen sitzen — das Wort zählt.
func test_both_translation_directions_make_a_lexeme_mastered() -> void:
	var records := {
		"translate:de_to_en:lex_a": _record(0.9),
		"translate:en_to_de:lex_a": _record(0.85),
	}
	assert_bool(PROGRESS.mastered_lexemes_in(records).has("lex_a")).is_true()


## Nur eine Richtung ist kein gemeistertes Wort: erkennen ist leichter als produzieren.
func test_one_direction_alone_is_not_enough() -> void:
	var records := {"translate:de_to_en:lex_a": _record(0.95)}
	assert_dict(PROGRESS.mastered_lexemes_in(records)).is_empty()


func test_below_the_threshold_does_not_count() -> void:
	var records := {
		"translate:de_to_en:lex_a": _record(0.9),
		"translate:en_to_de:lex_a": _record(0.5),
	}
	assert_dict(PROGRESS.mastered_lexemes_in(records)).is_empty()


## Andere Aufgaben-Arten zum selben Wort ersetzen keine Übersetzungsrichtung — sonst
## wäre ein Wort „gemeistert", weil sein Past Simple und sein Gegenteil sitzen.
func test_other_task_types_do_not_substitute_a_direction() -> void:
	var records := {
		"translate:de_to_en:lex_a": _record(0.9),
		"conjugation:lex_a:past_simple": _record(0.9),
		"opposite:lex_a:lex_b": _record(0.9),
	}
	assert_dict(PROGRESS.mastered_lexemes_in(records)).is_empty()


func test_empty_progress_yields_no_mastered_lexemes() -> void:
	assert_dict(PROGRESS.mastered_lexemes_in({})).is_empty()


# --- Unregelmäßige Verben: die Formen gehören dazu (ADR 0009) ---------------------

## So sieht ContentRegistry.form_requirements() für ein unregelmäßiges Verb aus.
const IRREGULAR := {"go": [
	"translate:de_to_en:go", "translate:en_to_de:go",
	"conjugation:go:past_simple", "conjugation:go:past_participle",
]}


func test_an_irregular_verb_needs_its_forms_too() -> void:
	var records := {
		"translate:de_to_en:go": _record(0.9),
		"translate:en_to_de:go": _record(0.9),
		"conjugation:go:past_simple": _record(0.9),
	}
	assert_dict(PROGRESS.mastered_lexemes_in(records, PROGRESS.MASTERY_CONFIDENCE, IRREGULAR)).is_empty()
	# Ohne Anforderung (ein regelmäßiges Verb) reichen die Richtungen wie bisher.
	assert_bool(PROGRESS.mastered_lexemes_in(records).has("go")).is_true()
	records["conjugation:go:past_participle"] = _record(0.85)
	assert_bool(PROGRESS.mastered_lexemes_in(records, PROGRESS.MASTERY_CONFIDENCE, IRREGULAR) \
			.has("go")).is_true()


## Die letzte Form schließt das Wort ab — die Feier kommt dann bei ihr, nicht bei einer
## Richtung, die schon lange saß.
func test_the_last_form_completes_an_irregular_verb() -> void:
	var records := {
		"translate:de_to_en:go": _record(0.9),
		"translate:en_to_de:go": _record(0.9),
		"conjugation:go:past_simple": _record(0.9),
	}
	var threshold := PROGRESS.MASTERY_CONFIDENCE
	assert_str(PROGRESS.mastered_lexeme_in(records, "translate:de_to_en:go", threshold, IRREGULAR)).is_empty()
	assert_str(PROGRESS.mastered_lexeme_in(records, "conjugation:go:past_simple", threshold, IRREGULAR)).is_empty()
	records["conjugation:go:past_participle"] = _record(0.9)
	assert_str(PROGRESS.mastered_lexeme_in(records, "conjugation:go:past_participle", threshold, IRREGULAR)) \
			.is_equal("go")
	# Eine Form, die das Wort nicht braucht, schließt nichts ab.
	assert_str(PROGRESS.mastered_lexeme_in(records, "conjugation:go:present_participle", threshold, IRREGULAR)) \
			.is_empty()


## Die Wortliste zeigt bei einem unregelmäßigen Verb dieselbe Rechnung: die schwächste
## Form zieht den Prozentstand, sonst stünde ein Haken an einem nicht gemeisterten Wort.
func test_the_word_row_of_an_irregular_verb_counts_its_forms() -> void:
	var stands := {
		"translate:de_to_en:go": 0.9, "translate:en_to_de:go": 0.9,
		"conjugation:go:past_simple": 0.5,
	}
	var lexeme := _lexeme("go", "access2", 6)
	var rows := STATS_SCREEN.word_rows([lexeme], _conf(stands), Callable(), IRREGULAR)
	# Die nie geübte Form zählt wie 0, nicht wie „ungeübt" — die Richtungen sind geübt.
	assert_float(float(rows[0]["confidence"])).is_equal_approx(0.0, 0.001)
	stands["conjugation:go:past_participle"] = 0.7
	rows = STATS_SCREEN.word_rows([lexeme], _conf(stands), Callable(), IRREGULAR)
	assert_float(float(rows[0]["confidence"])).is_equal_approx(0.5, 0.001)
	assert_float(float(STATS_SCREEN.word_rows([lexeme], _conf(stands))[0]["confidence"])) \
			.is_equal_approx(0.9, 0.001)


## Die Daten: `irregular` steht nur an Verben, jedes davon hat Formaufgaben (sonst wäre das
## Feld wirkungslos; ausgenommen Formen, die alle in einem Bonus stehen), und jedes Verb mit dem Thementag „irregular" der Access-Bände trägt es.
func test_irregular_verbs_in_the_catalog_have_form_tasks() -> void:
	var requirements := ContentRegistry.form_requirements()
	for id in ContentRegistry.lexemes:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		var flagged := bool(entry.get("irregular", false))
		# Eine Wendung („take a break") trägt den Tag, hat aber keine Konjugationsaufgabe.
		if "irregular" in entry.get("tags", []) and str(entry.get("type", "")) == "verb":
			assert_bool(flagged).override_failure_message("%s: Tag ohne Feld" % id).is_true()
		if not flagged:
			assert_bool(requirements.has(id)).is_false()
			continue
		assert_str(str(entry.get("type", ""))).override_failure_message(str(id)).is_equal("verb")
		# Stehen alle seine Formen in einem Bonus (später gelehrt, ADR 0012), zählt keine zur
		# Meisterung — dann muss es aber Formen haben.
		var forms := ContentRegistry.forms_for(str(id))
		if not requirements.has(id) and not forms.is_empty() \
				and forms.all(func(f): return not ContentRegistry.bonus_of_form(f).is_empty()):
			continue
		assert_bool(requirements.has(id)).override_failure_message("%s: keine Formaufgabe" % id).is_true()
		var needed: Array = requirements.get(id, [])
		assert_int(needed.filter(func(t): return str(t).begins_with("translate:")).size()).is_equal(2)
		assert_int(needed.size()).is_greater(2)


# --- Die Gruppierung: Balken je Unit und Thema ----------------------------------

func test_unit_rows_count_mastered_against_the_whole_unit() -> void:
	var pool := [
		_lexeme("a", "access2", 6), _lexeme("b", "access2", 6), _lexeme("c", "access2", 6),
	]
	var rows := STATS_SCREEN.unit_rows(pool, {"a": true}, _book_label)
	assert_int(rows.size()).is_equal(1)
	assert_int(int(rows[0]["done"])).is_equal(1)
	assert_int(int(rows[0]["total"])).is_equal(3)
	assert_str(str(rows[0]["label"])).is_equal("Access 2, Unit 6")


## Units werden numerisch sortiert, nicht als Text — sonst stünde Unit 10 vor Unit 2.
func test_unit_rows_are_sorted_numerically() -> void:
	var pool := [
		_lexeme("a", "access2", 10), _lexeme("b", "access2", 2), _lexeme("c", "access2", 1),
	]
	var rows := STATS_SCREEN.unit_rows(pool, {}, _book_label)
	assert_str(str(rows[0]["label"])).is_equal("Access 2, Unit 1")
	assert_str(str(rows[1]["label"])).is_equal("Access 2, Unit 2")
	assert_str(str(rows[2]["label"])).is_equal("Access 2, Unit 10")


## Lexeme ohne Buch/Unit (Grundwortschatz) haben keinen Balken — sie gehören zu keiner
## Unit und dürfen keine erfinden.
func test_lexemes_without_unit_get_no_row() -> void:
	var rows := STATS_SCREEN.unit_rows([_lexeme("a", "", 0, ["body"])], {"a": true}, _book_label)
	assert_array(rows).is_empty()


## Ein gemeistertes Wort, das nicht im Bereich liegt, hebt keinen fremden Balken —
## „18 von 24" kann nie über 100 % gehen.
func test_mastered_words_outside_the_pool_do_not_count() -> void:
	var rows := STATS_SCREEN.unit_rows([_lexeme("a", "access2", 6)],
			{"a": true, "fremd": true}, _book_label)
	assert_int(int(rows[0]["done"])).is_equal(1)
	assert_int(int(rows[0]["total"])).is_equal(1)


func test_stats_scene_has_the_progress_lists() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	assert_object(screen.get_node("%UnitList")).is_not_null()
	remove_child(screen)


# --- Die Wortliste unter einem Balken -------------------------------------------

## Confidence-Nachschlag wie im Spiel (PlayerProgress.confidence mit -1 als Vorgabe):
## `stands` bildet die learnable_id auf einen Wert ab, alles andere ist ungeübt.
static func _conf(stands: Dictionary) -> Callable:
	return func(task_id: String) -> float: return float(stands.get(task_id, -1.0))


func test_the_word_row_takes_the_weaker_direction() -> void:
	var rows := STATS_SCREEN.word_rows([_lexeme("a", "access2", 6)], _conf({
		"translate:de_to_en:a": 0.9, "translate:en_to_de:a": 0.4,
	}))
	assert_float(float(rows[0]["confidence"])).is_equal_approx(0.4, 0.001)


## Eine Richtung geübt, die andere nie: das Wort steht mit 0 % da und nicht mit der
## einen guten Hälfte — gemeistert ist es erst in beiden Richtungen.
func test_a_missing_direction_pulls_the_stand_to_zero() -> void:
	var rows := STATS_SCREEN.word_rows([_lexeme("a", "access2", 6)],
			_conf({"translate:de_to_en:a": 0.9}))
	assert_float(float(rows[0]["confidence"])).is_equal_approx(0.0, 0.001)


## Noch nie geübt ist kein gemessener Stand: -1 statt 0, und in der Anzeige ein Satz
## statt einer Zahl.
func test_an_untouched_word_has_no_percentage() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)], _conf({}))
	assert_str(str(lines[0]["value"])).is_equal("noch nicht geübt")
	assert_str(str(lines[0]["mark"])).is_empty()


## Von Haus aus steht das Sicherste oben; nie Geübtes steht auch unter einem 0-%-Wort,
## denn 0 % ist gemessen.
func test_the_best_word_comes_first_and_untouched_ones_last() -> void:
	var rows := STATS_SCREEN.word_rows(_sort_pool(), _sort_conf())
	assert_array(_labels(rows)).is_equal(["stark", "schwach", "null", "neu"])


func test_weakest_first_still_puts_untouched_words_last() -> void:
	var rows := STATS_SCREEN.word_rows(_sort_pool(), _sort_conf(), Callable(), {},
			STATS_SCREEN.SortMode.WEAKEST_FIRST)
	assert_array(_labels(rows)).is_equal(["null", "schwach", "stark", "neu"])


func test_alphabetical_ignores_the_confidence() -> void:
	var rows := STATS_SCREEN.word_rows(_sort_pool(), _sort_conf(), Callable(), {},
			STATS_SCREEN.SortMode.ALPHABETICAL)
	assert_array(_labels(rows)).is_equal(["neu", "null", "schwach", "stark"])


func _sort_pool() -> Array:
	return [
		_lexeme("stark", "access2", 6), _lexeme("neu", "access2", 6),
		_lexeme("schwach", "access2", 6), _lexeme("null", "access2", 6),
	]


func _sort_conf() -> Callable:
	return _conf({
		"translate:de_to_en:stark": 0.9, "translate:en_to_de:stark": 0.85,
		"translate:de_to_en:schwach": 0.5, "translate:en_to_de:schwach": 0.6,
		"translate:de_to_en:null": 0.0, "translate:en_to_de:null": 0.0,
	})


## Das Wort vor dem Strich — die Labels sind „fremd — deutsch".
func _labels(rows: Array) -> Array:
	return rows.map(func(row): return str(row["label"]).get_slice(" — ", 0))


## Der Haken steht genau ab der Schwelle, aus der auch die Meisterung kommt — sonst
## erklärte die Liste den Balken darüber nicht.
func test_the_mark_follows_the_mastery_threshold() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)], _conf({
		"translate:de_to_en:a": 0.85, "translate:en_to_de:a": 0.8,
	}))
	assert_str(str(lines[0]["value"])).is_equal("80 %")
	assert_str(str(lines[0]["mark"])).is_equal("✓")


## Die Gruppen tragen ihre Lexeme mit — daraus baut die Zeile beim Aufklappen die Liste.
func test_the_groups_carry_their_lexemes() -> void:
	var pool := [_lexeme("a", "access2", 6), _lexeme("b", "access2", 6, ["body"])]
	var unit: Array = STATS_SCREEN.unit_rows(pool, {}, _book_label)[0]["lexemes"]
	assert_int(unit.size()).is_equal(2)


## Aufklappen zeigt die Wörter, nochmal klappt sie weg — und gebaut werden sie erst beim
## ersten Mal (der Fortschritts-Reiter hat eine Zeile je Unit).
func test_the_progress_row_unfolds_its_word_list() -> void:
	var row: ProgressRow = auto_free(PROGRESS_ROW_SCENE.instantiate())
	add_child(row)
	var calls := [0]
	row.setup("Access 2, Unit 6", 1, 2, func():
		calls[0] += 1
		return [{"label": "a — A", "value": "40 %", "mark": ""}])
	var list := row.get_node("Words/WordList")
	assert_int(calls[0]).is_equal(0)
	assert_bool(row.is_expanded()).is_false()
	assert_int(list.get_child_count()).is_equal(0)

	row.toggle()
	assert_bool(row.is_expanded()).is_true()
	assert_int(list.get_child_count()).is_equal(1)
	assert_int(calls[0]).is_equal(1)

	row.toggle()
	assert_bool(row.is_expanded()).is_false()
	row.toggle()
	# Zweites Aufklappen baut die Liste nicht erneut.
	assert_int(calls[0]).is_equal(1)
	assert_int(list.get_child_count()).is_equal(1)
	remove_child(row)


## Ohne Wortliste bleibt die Zeile ein reiner Balken: kein Pfeil, kein Aufklappen.
func test_a_row_without_words_stays_closed() -> void:
	var row: ProgressRow = auto_free(PROGRESS_ROW_SCENE.instantiate())
	add_child(row)
	row.setup("Access 2, Unit 6", 1, 2)
	row.toggle()
	assert_bool(row.is_expanded()).is_false()
	assert_str((row.get_node("Row/Header") as Button).text).is_equal("Access 2, Unit 6")
	remove_child(row)


# --- Sternchen: die übrigen Aufgaben zum Wort ------------------------------------

## Auffächerung wie im Spiel (WaveGenerator.learnables_of): `tasks` bildet die Lexem-Id
## auf ihre learnable_ids ab.
static func _learnables(tasks: Dictionary) -> Callable:
	return func(entry: Dictionary) -> Array: return tasks.get(str(entry.get("id", "")), [])


## Je weiterer Aufgabe ein Sternchen, ausgefüllt wenn sie sitzt — und die beiden
## Übersetzungsrichtungen sind KEINE davon, sonst wäre jedes Wort mindestens zweisternig.
func test_extra_tasks_become_stars() -> void:
	var lex := _lexeme("a", "access2", 6)
	var lines := STATS_SCREEN.word_lines([lex], _conf({
		"translate:de_to_en:a": 0.9, "translate:en_to_de:a": 0.85,
		"conjugation:a:past_simple": 0.9, "opposite:a:b": 0.4,
	}), _learnables({"a": [
		"translate:de_to_en:a", "translate:en_to_de:a",
		"conjugation:a:past_simple", "opposite:a:b",
	]}))
	assert_str(str(lines[0]["mark"])).is_equal("✓★☆")


## Ohne Auffächerung bleibt es beim Haken — die Liste ist auch ohne Katalog benutzbar.
func test_without_learnables_there_are_no_stars() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)], _conf({
		"translate:de_to_en:a": 0.9, "translate:en_to_de:a": 0.85,
	}))
	assert_str(str(lines[0]["mark"])).is_equal("✓")


## Ein Wort kann offen sein UND ein Sternchen haben: die Zusatzaufgaben hängen nicht an
## der Meisterung.
func test_an_unmastered_word_can_still_carry_a_star() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)], _conf({
		"translate:de_to_en:a": 0.3, "translate:en_to_de:a": 0.9,
		"conjugation:a:past_simple": 0.9,
	}), _learnables({"a": ["translate:de_to_en:a", "translate:en_to_de:a", "conjugation:a:past_simple"]}))
	assert_str(str(lines[0]["mark"])).is_equal("★")
	assert_str(str(lines[0]["value"])).is_equal("30 %")


## Das Mouseover sagt, was die Zeichen verschweigen: beide Richtungen einzeln und je
## Sternchen die Aufgabe mit ihrem Stand.
func test_the_tooltip_spells_out_the_marks() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)], _conf({
		"translate:de_to_en:a": 0.9, "translate:en_to_de:a": 0.63,
		"conjugation:a:past_simple": 0.85,
	}), _learnables({"a": ["translate:de_to_en:a", "translate:en_to_de:a", "conjugation:a:past_simple"]}),
			func(id: String) -> String: return "Aufgabe " + id)
	# Eine echte Liste: je Aufgabe eine Zeile, Zeichen und Stand in eigenen Spalten.
	var hint: Array = lines[0]["hint_list"]
	assert_array(hint).contains([["✓", "Übersetzung de→en", "90 %"]])
	assert_array(hint).contains([["", "Übersetzung en→de", "63 %"]])
	assert_array(hint).contains([["★", "Aufgabe conjugation:a:past_simple", "85 %"]])


## Eine Richtung ohne Record steht auch im Mouseover als solche da und nicht als 0 %.
func test_the_tooltip_names_an_unpractised_direction() -> void:
	var lines := STATS_SCREEN.word_lines([_lexeme("a", "access2", 6)],
			_conf({"translate:de_to_en:a": 0.9}))
	assert_array(lines[0]["hint_list"]).contains(
			[["", "Übersetzung en→de", "noch nicht geübt"]])


## Die Auffächerung selbst: dieselbe, aus der der Wave-Pool spawnt.
func test_learnables_of_covers_both_directions_and_the_extras() -> void:
	var gen := WaveGenerator.new()
	var lexemes: Array = ContentRegistry.lexemes.values()
	if lexemes.is_empty():
		return  # Ohne Sprachdaten (CI ohne Submodule) nicht prüfbar.
	var counts: Array = []
	for entry in lexemes:
		# Ein Wort ohne Übersetzungsaufgabe (excluded_task_types, siehe
		# tests/excluded_task_types_test.gd) hat die beiden Richtungen bewusst nicht.
		if PROGRESS.masterable(entry):
			counts.append(gen.learnables_of(entry).size())
	counts.sort()
	# Jedes Wort hat mindestens die beiden Übersetzungsrichtungen.
	assert_int(int(counts[0])).is_greater_equal(2)
	# Und mindestens eines hat mehr — sonst wären die Sternchen tote Zeichen.
	assert_int(int(counts[counts.size() - 1])).is_greater(2)
