extends GdUnitTestSuite
## Statistik-Screen: Auswahlregeln der Listen und Aufbau der Szene (Issue #5, #9).
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


## Die Szene muss sich bauen lassen und ihre drei Listen über die eindeutigen Namen
## finden — genau das geht in einer handgeschriebenen .tscn leicht schief.
func test_scene_builds_and_finds_its_lists() -> void:
	var screen: Control = auto_free(STATS_SCENE.instantiate())
	add_child(screen)
	assert_object(screen.get_node("%StatLines")).is_not_null()
	assert_object(screen.get_node("%WantedList")).is_not_null()
	assert_object(screen.get_node("%FreshList")).is_not_null()
	assert_object(screen.get_node("%ComebackList")).is_not_null()
	assert_object(screen.get_node("%WordList")).is_not_null()
	assert_object(screen.get_node("%BackButton")).is_not_null()
	# Sechs Kennzahlen-Zeilen füllt _refresh_numbers beim Betreten (Gold zuerst).
	assert_int(screen.get_node("%StatLines").get_child_count()).is_equal(6)
	remove_child(screen)
