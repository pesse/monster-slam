extends GdUnitTestSuite
## Die Sitzungsbilanz am Laufende (Issue #12): RunBalance.build liest zusammen, was der
## Lauf gebracht hat — mit den Regeln des Statistik-Screens, eingeschränkt auf die
## Sitzung. Geprüft mit erfundenen Zeilen, ohne Autoload und ohne Inhalte.

const STARTED := 1000


func _row(label: String, confidence: float, attempts: int, correct: int, mastered_at := 0) -> Dictionary:
	return {
		"id": label, "label": label, "confidence": confidence,
		"mastered": confidence >= 0.8, "attempts": attempts, "correct": correct,
		"mastered_at": mastered_at,
	}


func _session(extra := {}) -> Dictionary:
	var s := {"started_at": STARTED, "waves_cleared": 3, "wave_reached": 3,
			"answers": 40, "correct": 31}
	s.merge(extra, true)
	return s


## Ohne laufende Sitzung keine Bilanz — der Screen blendet sie dann aus.
func test_no_session_means_no_balance() -> void:
	assert_dict(RunBalance.build({}, [_row("a", 0.9, 1, 1, 2000)])).is_empty()


func test_the_counters_come_from_the_session() -> void:
	var balance := RunBalance.build(_session(), [])
	assert_int(int(balance["waves_cleared"])).is_equal(3)
	assert_int(int(balance["answers"])).is_equal(40)
	assert_int(int(balance["correct"])).is_equal(31)
	assert_int(int(balance["mastered"])).is_equal(0)
	assert_array(balance["words"]).is_empty()


## Nach einer Niederlage steht der Lauf in einer Welle, die noch nicht geräumt ist — die
## kennt nur der WaveRunner.
func test_the_reached_wave_can_exceed_the_cleared_ones() -> void:
	assert_int(int(RunBalance.build(_session(), [], 4)["wave_reached"])).is_equal(4)
	assert_int(int(RunBalance.build(_session({"wave_reached": 5}), [], 4)["wave_reached"])).is_equal(5)


## Neu gemeistert ist nur, was in DIESER Sitzung zum ersten Mal saß: vorher Gemeistertes
## und Altbestand ohne Zeitstempel bleiben draußen.
func test_only_masteries_since_the_start_count() -> void:
	var rows := [
		_row("heute", 0.9, 2, 2, STARTED + 10),
		_row("gestern", 0.9, 2, 2, STARTED - 10),
		_row("altbestand", 0.9, 2, 2, 0),
		_row("offen", 0.4, 2, 1, 0),
	]
	var balance := RunBalance.build(_session(), rows)
	assert_int(int(balance["mastered"])).is_equal(1)
	assert_str(str(balance["words"][0]["label"])).is_equal("heute")


## Zurückerobert = die Comeback-Regel des Statistik-Screens (drei Fehlversuche), aber nur
## über die Meisterungen dieser Sitzung. Ein altes Comeback ist keins von heute.
func test_comebacks_follow_the_stats_rule_within_the_session() -> void:
	var rows := [
		_row("knapp", 0.9, 4, 2, STARTED + 10),        # 2 Fehlversuche: kein Comeback
		_row("zurueck", 0.9, 7, 3, STARTED + 20),      # 4 Fehlversuche: Comeback
		_row("frueher", 0.9, 9, 3, STARTED - 50),      # Comeback, aber vor der Sitzung
	]
	var balance := RunBalance.build(_session(), rows)
	assert_int(int(balance["mastered"])).is_equal(2)
	assert_int(int(balance["comeback"])).is_equal(1)
	# Comebacks zuerst — sie sind der Fund —, und keine Aufgabe steht zweimal da.
	var labels: Array = balance["words"].map(func(w): return w["label"])
	assert_array(labels).is_equal(["zurueck", "knapp"])
	assert_bool(bool(balance["words"][0]["comeback"])).is_true()
	assert_int(int(balance["words"][0]["misses"])).is_equal(4)


## Gezählt wird alles, gedeckelt erst in der Anzeige — sonst stimmte „und N weitere" nicht.
func test_the_word_list_is_not_capped_here() -> void:
	var rows: Array = []
	for i in 12:
		rows.append(_row("wort-%02d" % i, 0.9, 1, 1, STARTED + i))
	var balance := RunBalance.build(_session(), rows)
	assert_int(int(balance["mastered"])).is_equal(12)
	assert_int((balance["words"] as Array).size()).is_equal(12)
