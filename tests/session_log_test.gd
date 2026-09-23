extends GdUnitTestSuite
## Sitzungs-Log: Erfassung, Tages-Serie, Bestwerte, Wiederaufnahme (Issue #3).
##
## Geprüft wird auf einer EIGENEN SessionLog-Instanz mit eigenem Profil, nicht am
## Autoload: dessen Datei ist der echte Verlauf des Spielers. Die Instanz liegt nicht im
## Szenenbaum, also läuft kein _ready() und nichts hängt am EventBus — die öffentlichen
## note_*/begin/end sind genau deshalb öffentlich.
##
## GameState ist Autoload und geteilter Zustand (die Lauf-Zähler kommen von dort) ->
## vorher und nachher reset().

const SESSION_LOG := preload("res://src/learning/session_log.gd")
const TEST_PROFILE := "zz-session-test"

var _log: Node


func before_test() -> void:
	GameState.reset()
	_log = auto_free(SESSION_LOG.new())
	_log.player_id = TEST_PROFILE
	_remove_file()


func after_test() -> void:
	GameState.reset()
	_remove_file()


func _remove_file() -> void:
	DirAccess.remove_absolute("user://progress/%s_sessions.json" % TEST_PROFILE)


## Unix-Zeitstempel zur Tagesmitte des Tages `day_offset` relativ zu heute. Über
## local_day() gerechnet, damit der Test dieselbe Zeitzonen-Regel benutzt wie der Code.
func _midday(day_offset: int) -> int:
	var today: int = _log.local_day(int(Time.get_unix_time_from_system()))
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return (today + day_offset) * 86400 + 43200 - bias * 60


func _fake_session(day_offset: int, extra := {}) -> Dictionary:
	var entry := {"started_at": _midday(day_offset), "answers": 5, "waves_cleared": 1}
	entry.merge(extra, true)
	return entry


# --- Erfassung ----------------------------------------------------------------

func test_session_carries_all_documented_fields() -> void:
	_log.begin()
	_log.note_answer(true, 1500)
	_log.end({"wave_reached": 3, "difficulty_last": 4, "last_wave_won": true})
	var sessions: Array = _log.sessions()
	assert_int(sessions.size()).is_equal(1)
	for key in ["started_at", "ended_at", "last_activity_at", "waves_cleared",
			"wave_reached", "difficulty_last", "last_wave_won", "answers", "correct",
			"newly_mastered", "response_time_sum_ms", "timed_answers", "fast_answers",
			"monsters_defeated", "monsters_leaked", "best_no_leak_streak",
			"min_fortress_health"]:
		assert_bool((sessions[0] as Dictionary).has(key)) \
				.override_failure_message("Feld '%s' fehlt im Sitzungseintrag" % key).is_true()
	assert_int(int(sessions[0]["wave_reached"])).is_equal(3)
	assert_int(int(sessions[0]["difficulty_last"])).is_equal(4)


## Kampfszene betreten und sofort abgebrochen: kein Eintrag. Sonst füllt ein Lauf ohne
## eine einzige Antwort die Tages-Serie mit einem Tag, an dem nichts geübt wurde.
func test_empty_session_is_not_recorded() -> void:
	_log.begin()
	_log.end()
	assert_array(_log.sessions()).is_empty()


## Eine Antwort ohne gemessene Zeit (durchgelassenes Monster, 0 ms) zählt als Antwort,
## aber nicht in Antwortzeit-Summe und Blitzantworten — sonst zieht sie jeden Mittelwert
## nach unten.
func test_untimed_answers_stay_out_of_the_time_aggregates() -> void:
	_log.begin()
	_log.note_answer(false, 0)
	_log.note_answer(true, 1200)
	_log.note_answer(true, 3000)
	_log.end()
	var s: Dictionary = _log.sessions()[0]
	assert_int(int(s["answers"])).is_equal(3)
	assert_int(int(s["correct"])).is_equal(2)
	assert_int(int(s["timed_answers"])).is_equal(2)
	assert_int(int(s["response_time_sum_ms"])).is_equal(4200)
	assert_int(int(s["fast_answers"])).is_equal(1)


func test_cleared_waves_are_counted_and_raise_the_reached_wave() -> void:
	_log.begin()
	_log.note_wave_cleared()
	_log.note_wave_cleared()
	_log.end({"wave_reached": 1})   # der Runner meldet weniger als geräumt wurde
	var s: Dictionary = _log.sessions()[0]
	assert_int(int(s["waves_cleared"])).is_equal(2)
	assert_int(int(s["wave_reached"])).is_equal(2)


## Die Lauf-Zähler gehören GameState; das Log liest sie am Laufende ab.
func test_run_counters_are_taken_from_game_state() -> void:
	_log.begin()
	_log.note_answer(true, 900)
	GameState.monsters_defeated = 7
	GameState.monsters_leaked = 2
	GameState.best_no_leak_streak = 5
	GameState.min_fortress_health = 88
	_log.end()
	var s: Dictionary = _log.sessions()[0]
	assert_int(int(s["monsters_defeated"])).is_equal(7)
	assert_int(int(s["monsters_leaked"])).is_equal(2)
	assert_int(int(s["best_no_leak_streak"])).is_equal(5)
	assert_int(int(s["min_fortress_health"])).is_equal(88)


## Ein zweites begin() ohne end() darf die laufende Sitzung nicht verschlucken.
func test_begin_closes_a_still_open_session() -> void:
	_log.begin()
	_log.note_answer(true, 1000)
	_log.begin()
	assert_int(_log.sessions().size()).is_equal(1)


## end() ohne laufende Sitzung ist ein No-op — beide Ausgänge des Kampfes melden das
## Laufende, und nach dem Statistik-Screen kann noch ein Abbruch hinterherkommen.
func test_end_without_session_is_a_noop() -> void:
	_log.end()
	_log.end({"wave_reached": 9})
	assert_array(_log.sessions()).is_empty()


# --- Tages-Serie --------------------------------------------------------------

func test_streak_is_zero_without_sessions() -> void:
	assert_int(_log.current_streak()).is_equal(0)


func test_streak_counts_consecutive_days_including_today() -> void:
	_log._sessions = [_fake_session(-2), _fake_session(-1), _fake_session(0)]
	assert_int(_log.current_streak()).is_equal(3)


## Heute noch nicht gespielt, gestern schon: die Serie steht, der laufende Tag ist noch
## keine Lücke.
func test_streak_survives_a_running_day_without_a_session() -> void:
	_log._sessions = [_fake_session(-2), _fake_session(-1)]
	assert_int(_log.current_streak()).is_equal(2)


## Ein ganzer ausgelassener Tag bricht sie.
func test_streak_breaks_after_a_full_missed_day() -> void:
	_log._sessions = [_fake_session(-5), _fake_session(-4), _fake_session(-2)]
	assert_int(_log.current_streak()).is_equal(0)


## Zwei Sitzungen am selben Tag sind ein Tag.
func test_two_sessions_on_one_day_count_once() -> void:
	_log._sessions = [_fake_session(0), _fake_session(0)]
	assert_int(_log.current_streak()).is_equal(1)


## Eine Systemuhr, die zurückgestellt wurde, hinterlässt Sitzungen in der Zukunft. Die
## dürfen die Zählung nicht ins Absurde treiben (und keine Endlosschleife auslösen).
func test_future_sessions_do_not_inflate_the_streak() -> void:
	_log._sessions = [_fake_session(3), _fake_session(4)]
	assert_int(_log.current_streak()).is_equal(0)


## Die laufende Sitzung zählt mit — sonst fehlt in „heute" genau der Lauf, der läuft.
func test_running_session_counts_for_the_streak() -> void:
	_log.begin()
	_log.note_answer(true, 800)
	assert_int(_log.current_streak()).is_equal(1)


## „Heute schon geübt?" — die Frage hinter dem Hinweis unter der Serie. Sie ist nicht
## dasselbe wie eine gebrochene Serie: gestern gespielt heißt Serie ja, heute nein.
func test_played_today_distinguishes_today_from_yesterday() -> void:
	_log._sessions = [_fake_session(-1)]
	assert_bool(_log.played_today()).is_false()
	assert_int(_log.current_streak()).is_equal(1)
	_log._sessions.append(_fake_session(0))
	assert_bool(_log.played_today()).is_true()


func test_played_today_is_false_without_sessions() -> void:
	assert_bool(_log.played_today()).is_false()


## Die laufende Sitzung zählt auch hier mit.
func test_played_today_sees_the_running_session() -> void:
	_log.begin()
	_log.note_answer(true, 900)
	assert_bool(_log.played_today()).is_true()


func test_played_days_are_unique_and_sorted() -> void:
	_log._sessions = [_fake_session(-1), _fake_session(-3), _fake_session(-1)]
	var days: Array = _log.played_days(_midday(-7), _midday(0))
	assert_int(days.size()).is_equal(2)
	assert_bool(int(days[0]) < int(days[1])).is_true()


## Der Vorrat der Goldstück-Leiste: ein geübter Tag ist ein Stück, zwei Sitzungen am
## selben Tag sind eines — und die Spanne der Leiste begrenzt ihn nicht, sie ist nur das
## Fenster (siehe CoinStrip).
func test_played_day_count_counts_days_not_sessions() -> void:
	_log._sessions = [_fake_session(-1), _fake_session(-1), _fake_session(-40)]
	assert_int(_log.played_day_count()).is_equal(2)


func test_played_day_count_is_zero_without_sessions() -> void:
	assert_int(_log.played_day_count()).is_equal(0)


func test_sessions_between_filters_by_start() -> void:
	_log._sessions = [_fake_session(-10), _fake_session(-1)]
	assert_int(_log.sessions_between(_midday(-3), _midday(0)).size()).is_equal(1)


# --- Bestwerte ----------------------------------------------------------------

func test_records_take_maximum_and_sum_over_sessions() -> void:
	_log._sessions = [
		_fake_session(-2, {"waves_cleared": 3, "best_no_leak_streak": 4,
				"monsters_defeated": 20, "monsters_leaked": 3, "min_fortress_health": 70}),
		_fake_session(-1, {"waves_cleared": 5, "best_no_leak_streak": 2,
				"monsters_defeated": 30, "monsters_leaked": 1, "min_fortress_health": 95}),
	]
	var r: Dictionary = _log.records()
	assert_int(int(r["sessions"])).is_equal(2)
	assert_int(int(r["highest_wave_cleared"])).is_equal(5)
	assert_int(int(r["best_no_leak_streak"])).is_equal(4)
	assert_int(int(r["monsters_defeated"])).is_equal(50)
	assert_int(int(r["monsters_leaked"])).is_equal(4)
	assert_int(int(r["min_fortress_health"])).is_equal(70)


## Ohne Sitzung ist der tiefste HP-Stand unbekannt (-1), nicht 0 — „nie unter 90 HP"
## darf nicht aus einer leeren Datei entstehen.
func test_records_report_unknown_fortress_low_without_sessions() -> void:
	assert_int(int(_log.records()["min_fortress_health"])).is_equal(-1)
	assert_int(int(_log.records()["best_fortress_floor"])).is_equal(-1)


## Der schonendste Lauf ist der HÖCHSTE der lauf-eigenen Tiefstände — der tiefste Stand
## überhaupt steht daneben und ist etwas anderes. Beide aus denselben Sitzungen.
func test_the_gentlest_run_is_the_highest_of_the_per_run_lows() -> void:
	_log._sessions = [
		_fake_session(-3, {"min_fortress_health": 40}),
		_fake_session(-2, {"min_fortress_health": 95}),
		_fake_session(-1, {"min_fortress_health": 70}),
	]
	var r: Dictionary = _log.records()
	assert_int(int(r["best_fortress_floor"])).is_equal(95)
	assert_int(int(r["min_fortress_health"])).is_equal(40)


## Eine Sitzung ohne mitgeschriebenen Stand (-1) zählt für keinen der beiden Werte.
func test_a_session_without_a_fortress_low_counts_for_neither() -> void:
	_log._sessions = [_fake_session(-2, {"min_fortress_health": -1}),
			_fake_session(-1, {"min_fortress_health": 60})]
	var r: Dictionary = _log.records()
	assert_int(int(r["best_fortress_floor"])).is_equal(60)
	assert_int(int(r["min_fortress_health"])).is_equal(60)


## Die laufende Sitzung darf keinen makellosen Lauf behaupten: ihren Tiefstand liest erst
## end() von GameState ab. Bis dahin ist er unbekannt — sonst trüge jeder Absturz mitten
## im Lauf (load_sessions schreibt die offene Sitzung als `aborted` fest) die volle
## Festung in die Rekorde.
func test_a_running_session_claims_no_fortress_record() -> void:
	_log.begin()
	_log.note_answer(true, 900)
	assert_int(int(_log.records()["best_fortress_floor"])).is_equal(-1)
	GameState.min_fortress_health = 55
	_log.end()
	assert_int(int(_log.records()["best_fortress_floor"])).is_equal(55)


# --- Sitzungs-Genauigkeit (Issue #13) ------------------------------------------

func _answered(day_offset: int, answers: int, correct: int) -> Dictionary:
	return _fake_session(day_offset, {"answers": answers, "correct": correct, "ended_at": 1})


func test_accuracy_trend_is_empty_without_sessions() -> void:
	var t := SESSION_LOG.accuracy_trend([])
	assert_int(int(t["answers"])).is_equal(0)
	assert_float(float(t["accuracy"])).is_equal(-1.0)
	assert_float(float(t["baseline"])).is_equal(-1.0)


## Die jüngste Sitzung ist die Kopfzahl, egal in welcher Reihenfolge die Einträge kommen.
func test_accuracy_trend_takes_the_latest_session() -> void:
	var t := SESSION_LOG.accuracy_trend([_answered(-1, 10, 9), _answered(-3, 10, 5)])
	assert_float(float(t["accuracy"])).is_equal_approx(0.9, 0.001)
	assert_float(float(t["baseline"])).is_equal_approx(0.5, 0.001)
	assert_str(str(t["baseline_kind"])).is_equal("week")


## Ohne Vorsitzung gibt es keinen Vergleich — die Anzeige lässt dann den Pfeil weg.
func test_a_single_session_has_no_baseline() -> void:
	var t := SESSION_LOG.accuracy_trend([_answered(0, 10, 8)])
	assert_float(float(t["accuracy"])).is_equal_approx(0.8, 0.001)
	assert_float(float(t["baseline"])).is_equal(-1.0)
	assert_str(str(t["baseline_kind"])).is_empty()


## Gemittelt über die ANTWORTEN: ein kurzer Lauf wiegt wenig.
func test_the_weekly_baseline_is_weighted_by_answers() -> void:
	var t := SESSION_LOG.accuracy_trend([
		_answered(-4, 90, 90), _answered(-2, 10, 0), _answered(0, 10, 5)])
	assert_float(float(t["baseline"])).is_equal_approx(0.9, 0.001)


## Liegt die Woche davor leer, vergleicht die Sitzung mit der Sitzung davor.
func test_an_old_previous_session_becomes_the_baseline() -> void:
	var t := SESSION_LOG.accuracy_trend([_answered(-30, 10, 6), _answered(-20, 10, 4), _answered(0, 10, 8)])
	assert_float(float(t["baseline"])).is_equal_approx(0.4, 0.001)
	assert_str(str(t["baseline_kind"])).is_equal("previous")


## Sitzungen außerhalb des Fensters fallen aus dem Wochenmittel.
func test_sessions_before_the_window_stay_out_of_the_week() -> void:
	var t := SESSION_LOG.accuracy_trend([_answered(-10, 10, 0), _answered(-2, 10, 7), _answered(0, 10, 8)])
	assert_float(float(t["baseline"])).is_equal_approx(0.7, 0.001)


## Unter der Mindestzahl steht kein Anteil — weder für die Sitzung noch für den Vergleich.
func test_too_few_answers_yield_no_accuracy() -> void:
	var few := SESSION_LOG.MIN_ACCURACY_ANSWERS - 1
	var t := SESSION_LOG.accuracy_trend([_answered(-1, few, few), _answered(0, few, 1)])
	assert_int(int(t["answers"])).is_equal(few)
	assert_float(float(t["accuracy"])).is_equal(-1.0)
	assert_float(float(t["baseline"])).is_equal(-1.0)
	assert_str(str(t["baseline_kind"])).is_empty()


## Eine Sitzung ohne Antwort (nur Wellen) ist nicht „die letzte Sitzung" der Genauigkeit.
func test_sessions_without_answers_are_skipped() -> void:
	var t := SESSION_LOG.accuracy_trend([_answered(-1, 10, 7),
			_fake_session(0, {"answers": 0, "ended_at": 1})])
	assert_float(float(t["accuracy"])).is_equal_approx(0.7, 0.001)


## Mitten im Lauf ist die laufende Sitzung die jüngste und als `live` markiert.
func test_the_running_session_is_the_live_one() -> void:
	_log._sessions = [_answered(-1, 10, 5)]
	_log.begin()
	for i in 6:
		_log.note_answer(true, 900)
	var t: Dictionary = _log.session_accuracy()
	assert_bool(bool(t["live"])).is_true()
	assert_float(float(t["accuracy"])).is_equal_approx(1.0, 0.001)
	assert_float(float(t["baseline"])).is_equal_approx(0.5, 0.001)


# --- Persistenz ---------------------------------------------------------------

func test_sessions_survive_a_reload() -> void:
	_log.begin()
	_log.note_answer(true, 1100)
	_log.end({"wave_reached": 2, "difficulty_last": 3, "last_wave_won": true})
	_log.load_sessions()
	assert_int(_log.sessions().size()).is_equal(1)
	assert_int(int(_log.sessions()[0]["answers"])).is_equal(1)


## Geräumte Wellen schreiben fort: bricht der Prozess mitten im Lauf ab, liegt die
## Sitzung offen in der Datei und wird beim Laden abgeschlossen statt verworfen.
func test_hard_stop_is_salvaged_on_load() -> void:
	_log.begin()
	_log.note_answer(true, 1000)
	_log.note_wave_cleared()       # schreibt die offene Sitzung fort
	_log.load_sessions()           # wie ein Neustart nach dem Absturz
	var sessions: Array = _log.sessions()
	assert_int(sessions.size()).is_equal(1)
	assert_bool(bool(sessions[0].get("aborted", false))).is_true()
	assert_int(int(sessions[0]["ended_at"])).is_equal(int(sessions[0]["last_activity_at"]))
	assert_dict(_log.current()).is_empty()


## Ein Absturz vor der ersten Antwort hinterlässt keinen Eintrag — dieselbe Regel wie
## in end().
func test_hard_stop_without_answers_leaves_nothing() -> void:
	_log.begin()
	_log._save()
	_log.load_sessions()
	assert_array(_log.sessions()).is_empty()


## Profilwechsel: die laufende Sitzung wird im alten Profil abgeschlossen, danach ist
## das Log des neuen Profils geladen (hier: leer).
func test_switch_to_closes_the_session_in_the_old_profile() -> void:
	_log.begin()
	_log.note_answer(true, 1000)
	_log.switch_to("zz-session-test-other")
	assert_array(_log.sessions()).is_empty()
	_log.switch_to(TEST_PROFILE)
	assert_int(_log.sessions().size()).is_equal(1)
	DirAccess.remove_absolute("user://progress/zz-session-test-other_sessions.json")
