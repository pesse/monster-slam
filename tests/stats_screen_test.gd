extends GdUnitTestSuite
## Statistik-Screen: Auswahlregel der Fahndungsliste und Aufbau der Szene (Issue #5).
##
## Die Auswahl wird an der statischen wanted_rows() geprüft — mit erfundenen Zeilen im
## Format von PlayerProgress.records_for_display(), also ohne den echten Lernstand des
## Spielers anzufassen. Der Szenen-Test hängt den Screen einmal in den Baum: er soll
## Tippfehler in den Knotennamen der handgeschriebenen .tscn auffallen lassen.

const STATS_SCREEN := preload("res://src/ui/stats_screen.gd")
const STATS_SCENE := preload("res://scenes/ui/stats_screen.tscn")


func _row(label: String, confidence: float, attempts: int, correct: int) -> Dictionary:
	return {
		"id": label, "label": label, "confidence": confidence,
		"mastered": confidence >= 0.8, "attempts": attempts, "correct": correct,
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


## Die Szene muss sich bauen lassen und ihre drei Listen über die eindeutigen Namen
## finden — genau das geht in einer handgeschriebenen .tscn leicht schief.
func test_scene_builds_and_finds_its_lists() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	assert_object(screen.get_node("%StatLines")).is_not_null()
	assert_object(screen.get_node("%WantedList")).is_not_null()
	assert_object(screen.get_node("%WordList")).is_not_null()
	assert_object(screen.get_node("%BackButton")).is_not_null()
	# Fünf Kennzahlen-Zeilen füllt _refresh_numbers beim Betreten.
	assert_int(screen.get_node("%StatLines").get_child_count()).is_equal(5)
	remove_child(screen)
