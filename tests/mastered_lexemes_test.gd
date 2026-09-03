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
	var entry := {"id": id, "tags": tags}
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
