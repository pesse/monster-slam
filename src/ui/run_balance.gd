class_name RunBalance
extends RefCounted
## Sitzungsbilanz am Laufende für den Wellenabschluss (WaveStats). Liest nur zusammen:
## Zähler aus SessionLog.current(), Wörter aus PlayerProgress.records_for_display() nach
## den Regeln von StatsScreen.fresh_rows/comeback_rows, ab Sitzungsbeginn. Muss vor
## SessionLog.end() gebaut werden, das die laufende Sitzung leert.

const STATS_SCREEN := preload("res://src/ui/stats_screen.gd")


## Rückgabe: {} ohne laufende Sitzung, sonst
##   waves_cleared, wave_reached, answers, correct: int
##   mastered: int   — in dieser Sitzung erstmals gemeisterte Aufgaben
##   comeback: int   — davon zurückerobert (Comeback-Regel des Statistik-Screens)
##   words: Array von { label: String, misses: int, comeback: bool } — Comebacks zuerst,
##                    dann die übrigen, jüngste zuerst; ungekappt.
## `wave_reached`: die Welle, in der der Lauf steht (nach einer Niederlage noch nicht in
## der Sitzung).
static func build(session: Dictionary, rows: Array, wave_reached := 0) -> Dictionary:
	if session.is_empty():
		return {}
	var since := int(session.get("started_at", 0))
	var fresh: Array = STATS_SCREEN.fresh_rows(rows, since, rows.size())
	# Comeback-Regel nur über die in dieser Sitzung gemeisterten Aufgaben.
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
