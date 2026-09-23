class_name RunBalance
extends RefCounted
## Sitzungsbilanz am Laufende (Issue #12): was dieser Lauf gebracht hat, für Stufe 2
## des Wellenabschlusses (WaveStats).
##
## Hier wird nichts gezählt, sondern zusammengelesen: die Zähler kommen aus der laufenden
## Sitzung (SessionLog.current()), die Wörter aus den Zeilen von
## PlayerProgress.records_for_display() — mit DENSELBEN Regeln wie im Statistik-Screen
## (StatsScreen.fresh_rows, StatsScreen.comeback_rows), nur auf den Zeitraum ab
## Sitzungsbeginn eingeschränkt. Eine zweite Regel daneben liefe irgendwann auseinander.
##
## Gelesen wird VOR SessionLog.end(): das leert die laufende Sitzung. Der WaveRunner baut
## die Bilanz deshalb beim Wellenende, nicht beim Rückweg ins Menü.
##
## Statisch und ohne Autoload, damit die Regel mit erfundenen Zeilen prüfbar ist
## (tests/run_balance_test.gd) — dieselbe Aufteilung wie SessionLog.accuracy_trend.

const STATS_SCREEN := preload("res://src/ui/stats_screen.gd")


## Rückgabe: {} ohne laufende Sitzung, sonst
##   waves_cleared, wave_reached, answers, correct: int
##   mastered: int   — in dieser Sitzung erstmals gemeisterte Aufgaben
##   comeback: int   — davon zurückerobert (Comeback-Regel des Statistik-Screens)
##   words: Array von { label: String, misses: int, comeback: bool } — Comebacks zuerst
##                    (sie sind der Fund), danach die übrigen, jüngste zuerst; ungekappt,
##                    gedeckelt wird in der Anzeige.
## `wave_reached` ist die Welle, in der der Lauf gerade steht: nach einer Niederlage ist
## sie noch nicht geräumt, steht also noch nicht in der Sitzung.
static func build(session: Dictionary, rows: Array, wave_reached := 0) -> Dictionary:
	if session.is_empty():
		return {}
	var since := int(session.get("started_at", 0))
	# Ungekappt: gedeckelt wird erst in der Anzeige, gezählt wird alles.
	var fresh: Array = STATS_SCREEN.fresh_rows(rows, since, rows.size())
	# „In dieser Sitzung zurückerobert" = die Comeback-Regel über die Aufgaben, deren
	# Meisterung in diese Sitzung fällt. Altbestand ohne Zeitstempel fällt damit weg —
	# der kann nicht heute zurückerobert worden sein.
	var comeback: Array = STATS_SCREEN.comeback_rows(fresh, fresh.size())
	var comeback_ids := {}
	var words: Array = []
	for row in comeback:
		comeback_ids[row["id"]] = true
		words.append({"label": str(row["label"]), "misses": STATS_SCREEN.misses(row), "comeback": true})
	for row in fresh:
		if not comeback_ids.has(row["id"]):
			words.append({"label": str(row["label"]), "misses": STATS_SCREEN.misses(row), "comeback": false})
	return {
		"waves_cleared": int(session.get("waves_cleared", 0)),
		"wave_reached": maxi(int(session.get("wave_reached", 1)), wave_reached),
		"answers": int(session.get("answers", 0)),
		"correct": int(session.get("correct", 0)),
		"mastered": fresh.size(),
		"comeback": comeback.size(),
		"words": words,
	}
