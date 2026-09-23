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


## Themen sind Sichten, keine Aufteilung: ein Lexem mit zwei Tags zählt in beiden.
func test_tag_rows_count_a_lexeme_in_each_of_its_tags() -> void:
	var pool := [_lexeme("a", "access2", 6, ["body", "school"]), _lexeme("b", "access2", 6, ["body"])]
	var rows := STATS_SCREEN.tag_rows(pool, {"a": true})
	assert_int(rows.size()).is_equal(2)
	# Alphabetisch: body vor school.
	assert_str(str(rows[0]["label"])).is_equal("body")
	assert_int(int(rows[0]["done"])).is_equal(1)
	assert_int(int(rows[0]["total"])).is_equal(2)
	assert_str(str(rows[1]["label"])).is_equal("school")
	assert_int(int(rows[1]["total"])).is_equal(1)


func test_a_pool_without_tags_yields_no_tag_rows() -> void:
	assert_array(STATS_SCREEN.tag_rows([_lexeme("a", "access2", 6)], {})).is_empty()


func test_stats_scene_has_the_progress_lists() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	assert_object(screen.get_node("%UnitList")).is_not_null()
	assert_object(screen.get_node("%TagList")).is_not_null()
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


func test_the_weakest_word_comes_first_and_untouched_ones_last() -> void:
	var pool := [
		_lexeme("stark", "access2", 6), _lexeme("neu", "access2", 6),
		_lexeme("schwach", "access2", 6),
	]
	var rows := STATS_SCREEN.word_rows(pool, _conf({
		"translate:de_to_en:stark": 0.9, "translate:en_to_de:stark": 0.85,
		"translate:de_to_en:schwach": 0.5, "translate:en_to_de:schwach": 0.6,
	}))
	assert_str(str(rows[0]["label"])).contains("schwach")
	assert_str(str(rows[1]["label"])).contains("stark")
	assert_str(str(rows[2]["label"])).contains("neu")


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
	var tag: Array = STATS_SCREEN.tag_rows(pool, {})[0]["lexemes"]
	assert_int(tag.size()).is_equal(1)


## Aufklappen zeigt die Wörter, nochmal klappt sie weg — und gebaut werden sie erst beim
## ersten Mal (der Fortschritts-Reiter hat eine Zeile je Unit und je Thema).
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
