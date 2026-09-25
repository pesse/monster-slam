extends GdUnitTestSuite
## Zeitachse des Lernstands: first_seen_at und mastered_at (Issue #4).
##
## Geprüft wird auf einer EIGENEN PlayerProgress-Instanz, nicht am Autoload: dessen
## Records sind der echte Fortschritt des Spielers, und ein Test darf ihn weder lesen
## noch überschreiben. Die Instanz landet nicht im Szenenbaum, also läuft kein _ready()
## und es wird nichts gespeichert, außer der Test tut es ausdrücklich.

const PROGRESS := preload("res://src/learning/player_progress.gd")
## Eigenes Profil für den Persistenz-Fall — nie das echte „default".
const TEST_PROFILE := "zz-progress-test"
const TASK := "translate:de-en:lex_test"

var _pp: Node


func before_test() -> void:
	_pp = auto_free(PROGRESS.new())
	_pp.player_id = TEST_PROFILE


func after_test() -> void:
	DirAccess.remove_absolute("user://progress/%s.json" % TEST_PROFILE)


## Genug korrekte Antworten, um die Meisterungs-Schwelle sicher zu reißen.
func _master(task := TASK) -> void:
	for i in 10:
		_pp.record(task, true, 1500)


func test_first_seen_at_is_set_on_first_contact() -> void:
	_pp.record(TASK, true, 1200)
	assert_int(int(_pp._records[TASK]["first_seen_at"])).is_greater(0)


## Solange die Confidence unter der Schwelle liegt, gibt es keinen Meisterungs-Zeitpunkt.
func test_mastered_at_stays_zero_below_threshold() -> void:
	_pp.record(TASK, false, 0)
	assert_float(_pp.confidence(TASK)).is_less(PROGRESS.MASTERY_CONFIDENCE)
	assert_int(int(_pp._records[TASK]["mastered_at"])).is_equal(0)


func test_mastered_at_is_set_when_threshold_is_crossed() -> void:
	_master()
	assert_float(_pp.confidence(TASK)).is_greater_equal(PROGRESS.MASTERY_CONFIDENCE)
	assert_int(int(_pp._records[TASK]["mastered_at"])).is_greater(0)


## Die Kernregel: der Zeitpunkt der ERSTEN Meisterung bleibt stehen. Ohne sie tauchte
## dasselbe Wort nach jedem Rückfall wieder unter „frisch gemeistert" auf.
func test_mastered_at_survives_a_relapse() -> void:
	_master()
	# Auf einen alten Zeitpunkt setzen, damit ein erneutes Setzen auffällt (die Sekunden-
	# Auflösung der Systemzeit würde ihn im Testlauf sonst gleich aussehen lassen).
	_pp._records[TASK]["mastered_at"] = 1000
	_pp.record(TASK, false, 0)   # Confidence halbiert -> unter der Schwelle
	assert_float(_pp.confidence(TASK)).is_less(PROGRESS.MASTERY_CONFIDENCE)
	_master()                    # wieder hoch
	assert_int(int(_pp._records[TASK]["mastered_at"])).is_equal(1000)


func test_mastered_since_only_returns_the_new_ones() -> void:
	_master("alt")
	_pp._records["alt"]["mastered_at"] = 1000
	_master("neu")
	var now := int(Time.get_unix_time_from_system())
	var recent: Array = _pp.mastered_since(now - 60)
	assert_array(recent).contains(["neu"])
	assert_array(recent).not_contains(["alt"])


## Jüngste zuerst — die Anzeige „frisch gemeistert" soll oben das Neueste zeigen.
func test_mastered_since_is_sorted_newest_first() -> void:
	_master("a")
	_master("b")
	_pp._records["a"]["mastered_at"] = 5000
	_pp._records["b"]["mastered_at"] = 9000
	assert_array(_pp.mastered_since(0)).is_equal(["b", "a"])


## Altbestand ohne Zeitstempel: nicht in „frisch gemeistert", aber im Startwert der
## Lernkurve. Sonst fiele der Fortschritt von vor der Zeitmessung unter den Tisch.
func test_records_without_timestamp_count_as_mastered_before() -> void:
	_master("alt")
	_pp._records["alt"]["mastered_at"] = 0
	var now := int(Time.get_unix_time_from_system())
	assert_array(_pp.mastered_since(0)).is_empty()
	assert_int(_pp.mastered_count_before(now)).is_equal(1)


## Eine Fortschrittsdatei von vor dieser Änderung hat die Felder nicht. Sie darf weder
## beim Laden noch beim nächsten Verbuchen stören, und die Meisterung wird ab jetzt
## normal datiert.
func test_progress_file_without_timestamps_still_works() -> void:
	DirAccess.make_dir_recursive_absolute("user://progress")
	var legacy := {
		"player_id": TEST_PROFILE,
		"records": {TASK: {
			"confidence": 0.75, "attempts": 4, "correct_total": 3,
			"current_streak": 1, "best_streak": 2, "last_correct": true,
			"last_response_time_ms": 1800, "last_seen_at": 1700000000, "next_review_at": 0,
		}},
		"sr": {},
	}
	var file := FileAccess.open("user://progress/%s.json" % TEST_PROFILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	_pp.load_progress()
	assert_int(int(_pp._records[TASK].get("mastered_at", 0))).is_equal(0)
	assert_int(int(_pp._records[TASK].get("first_seen_at", 0))).is_equal(0)

	_pp.record(TASK, true, 1200)   # 0.75 -> 0.81, reißt die Schwelle
	assert_int(int(_pp._records[TASK]["mastered_at"])).is_greater(0)


# --- Der Anlass der Feier (Issue #23) ------------------------------------------

## record() meldet genau die EINE Antwort, die die Schwelle zum ersten Mal reißt.
func test_record_reports_the_first_mastery_exactly_once() -> void:
	var reports: Array = []
	for i in 10:
		reports.append(_pp.record(TASK, true, 1500))
	assert_int(reports.count(true)).is_equal(1)
	# Rückfall und Wiederaufstieg: keine zweite Meldung.
	_pp.record(TASK, false, 0)
	for i in 10:
		assert_bool(_pp.record(TASK, true, 1500)).is_false()


## Ein Altbestand-Record ohne Zeitstempel, der schon über der Schwelle stand, bekommt sein
## Datum — gefeiert wird er nicht, er war nicht eben erst gemeistert.
func test_a_legacy_record_above_the_threshold_is_not_reported() -> void:
	_pp.record(TASK, true, 1200)
	_pp._records[TASK]["confidence"] = 0.85
	_pp._records[TASK]["mastered_at"] = 0
	assert_bool(_pp.record(TASK, true, 1200)).is_false()
	assert_int(int(_pp._records[TASK]["mastered_at"])).is_greater(0)


## Das Wort ist erst gemeistert, wenn die zweite Richtung dazukommt.
func test_the_second_direction_completes_the_word() -> void:
	var de_en := "translate:de_to_en:zz.lex.a"
	var en_de := "translate:en_to_de:zz.lex.a"
	_master(de_en)
	assert_str(_pp.mastered_lexeme_of(de_en)).is_empty()
	_master(en_de)
	assert_str(_pp.mastered_lexeme_of(en_de)).is_equal("zz.lex.a")


## Andere Aufgabentypen schließen kein Wort ab, auch wenn beide Richtungen sitzen.
func test_other_task_types_complete_no_word() -> void:
	var records := {
		"translate:de_to_en:zz.lex.a": {"confidence": 0.9},
		"translate:en_to_de:zz.lex.a": {"confidence": 0.9},
		"conjugation:zz.lex.a:past": {"confidence": 0.9},
	}
	assert_str(PROGRESS.mastered_lexeme_in(records, "conjugation:zz.lex.a:past")).is_empty()
	assert_str(PROGRESS.mastered_lexeme_in(records, "translate:de_to_en:zz.lex.a")).is_equal("zz.lex.a")
