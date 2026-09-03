extends GdUnitTestSuite
## Lernkurve: kumulierte Meisterungen je Woche (Issue #7).
##
## Wie in player_progress_timestamps_test.gd auf einer EIGENEN PlayerProgress-Instanz:
## der echte Fortschritt des Spielers wird weder gelesen noch überschrieben. `now` wird
## übergeben, damit die Wochen-Grenzen nicht von der Systemuhr abhängen.

const PROGRESS := preload("res://src/learning/player_progress.gd")
## Fester Zeitpunkt als „jetzt": 2026-06-01 12:00 UTC.
const NOW := 1780315200
const WEEK := 7 * 86400

var _pp: Node


func before_test() -> void:
	_pp = auto_free(PROGRESS.new())
	_pp.player_id = "zz-curve-test"


## Legt einen gemeisterten Record mit gesetztem Meisterungs-Zeitpunkt an, ohne über
## record() zu gehen — hier interessiert nur die Zeitachse, nicht der Scheduler.
func _mastered(id: String, at: int) -> void:
	_pp._records[id] = {
		"confidence": 0.9, "attempts": 5, "correct_total": 5,
		"current_streak": 5, "best_streak": 5, "last_correct": true,
		"last_response_time_ms": 1200, "last_seen_at": at, "next_review_at": 0,
		"first_seen_at": at, "mastered_at": at,
	}


func _counts(curve: Array) -> Array:
	var out: Array = []
	for point in curve:
		out.append(int(point["count"]))
	return out


func test_curve_has_one_point_per_week() -> void:
	assert_int(_pp.mastery_curve(12, NOW).size()).is_equal(12)
	assert_int(_pp.mastery_curve(4, NOW).size()).is_equal(4)


## Die Wochen liegen sieben Tage auseinander, älteste zuerst.
func test_weeks_are_seven_days_apart_and_oldest_first() -> void:
	var curve: Array = _pp.mastery_curve(3, NOW)
	assert_int(int(curve[1]["end"]) - int(curve[0]["end"])).is_equal(WEEK)
	assert_int(int(curve[2]["end"]) - int(curve[1]["end"])).is_equal(WEEK)
	assert_int(int(curve[2]["end"])).is_greater(NOW)


## Ohne Lernstand ist die Kurve flach auf null — und nicht leer.
func test_empty_progress_yields_a_flat_zero_curve() -> void:
	assert_array(_counts(_pp.mastery_curve(3, NOW))).is_equal([0, 0, 0])


## Der Kern: die Kurve ist kumuliert. Eine Meisterung in Woche 2 zählt in Woche 3 mit.
func test_curve_is_cumulative_and_never_falls() -> void:
	_mastered("a", NOW - 2 * WEEK)
	_mastered("b", NOW - 1 * WEEK)
	var counts := _counts(_pp.mastery_curve(4, NOW))
	assert_array(counts).is_equal([0, 1, 2, 2])
	for i in range(1, counts.size()):
		assert_int(counts[i]).is_greater_equal(counts[i - 1])


## Eine Meisterung von heute steht in der letzten Stütze — die Woche endet am Ende des
## heutigen Tages, nicht am letzten Wochenwechsel.
func test_todays_mastery_is_in_the_last_point() -> void:
	_mastered("heute", NOW)
	var counts := _counts(_pp.mastery_curve(3, NOW))
	assert_int(counts[counts.size() - 1]).is_equal(1)
	assert_int(counts[0]).is_equal(0)


## Altbestand ohne Zeitstempel (mastered_at = 0) gehört in den STARTWERT der Kurve: seine
## Meisterung liegt vor dem Messbeginn. Als Meisterung am 01.01.1970 wäre er ein Sprung,
## und weggelassen fiele der Fortschritt von vor der Zeitmessung unter den Tisch.
func test_records_without_timestamp_lift_the_starting_value() -> void:
	_mastered("alt", 0)
	_pp._records["alt"]["mastered_at"] = 0
	assert_array(_counts(_pp.mastery_curve(3, NOW))).is_equal([1, 1, 1])


## Ein Altbestand-Record, der HEUTE nicht mehr gemeistert ist, zählt auch im Startwert
## nicht mit — sonst zeigte die Kurve dauerhaft eine Meisterung, die es nicht mehr gibt.
func test_lapsed_records_without_timestamp_stay_out() -> void:
	_mastered("alt", 0)
	_pp._records["alt"]["mastered_at"] = 0
	_pp._records["alt"]["confidence"] = 0.3
	assert_array(_counts(_pp.mastery_curve(2, NOW))).is_equal([0, 0])
