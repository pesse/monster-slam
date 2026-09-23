extends Node
## Verlauf je Spiel-Sitzung (Autoload `SessionLog`).
##
## PlayerProgress hält den Lernstand PRO AUFGABE, GameState den Zustand DES LAUFENDEN
## LAUFS — beides ohne Zeitachse. Dieses Log ist die dritte Ebene: ein Eintrag je Lauf,
## damit „heute", „diese Woche" und jeder Trend überhaupt darstellbar sind (Issue #3).
## Ein Lauf ist alles zwischen `EventBus.run_started` und `run_ended`, also über mehrere
## Wellen hinweg bis zur gefallenen Festung oder zum Rückweg ins Menü.
##
## Hier wird nur erfasst und persistiert; die Anzeige liegt bei den Statistik-Screens.
## Persistenz: JSON unter user://progress/<player_id>_sessions.json — Spielerdaten
## gehören nach user://, nicht in die Quell-JSON unter res://data/.
##
## Was NICHT hier steht: die Zahl neu gemeisterter Aufgaben wird nicht mitgezählt,
## sondern am Laufende bei PlayerProgress erfragt (`mastered_since`, Issue #4). Eine
## zweite Buchführung über dieselbe Sache läuft irgendwann auseinander.

const SAVE_DIR := "user://progress"
## Bis zu dieser Antwortzeit gilt eine Antwort als „Blitzantwort".
const FAST_ANSWER_MS := 2000
## Unter so vielen Antworten ist die Genauigkeit einer Sitzung kein Wert, sondern Rauschen.
const MIN_ACCURACY_ANSWERS := 5
## Der Vergleichswert der Sitzungs-Genauigkeit mittelt über so viele Tage davor.
const ACCURACY_WINDOW_DAYS := 7

## Abgeschlossene Sitzungen, älteste zuerst. Felder eines Eintrags:
##   started_at, ended_at, last_activity_at: int (unix)
##   waves_cleared: int          — geräumte Wellen; zugleich die höchste geräumte Welle,
##                                 weil Wellen strikt in Folge gespielt werden
##   wave_reached, difficulty_last: int
##   last_wave_won: bool         — Ausgang der letzten Welle des Laufs
##   answers, correct: int
##   newly_mastered: int         — in dieser Sitzung erstmals gemeisterte Aufgaben
##   response_time_sum_ms, timed_answers, fast_answers: int
##   monsters_defeated, monsters_leaked, best_no_leak_streak: int
##   min_fortress_health: int    — tiefster HP-Stand des Laufs; -1 heißt „unbekannt"
##                                 (der Wert wird erst in end() von GameState abgelesen,
##                                 eine laufende oder abgebrochene Sitzung hat ihn nicht)
##   aborted: bool               — nur bei hart beendeten Läufen (siehe load_sessions)
var _sessions: Array = []
## Die laufende Sitzung; leer = gerade kein Lauf.
var _current: Dictionary = {}
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_sessions()
	# Profilwechsel mitschalten, damit Sitzungen nicht im falschen Profil landen. Über das
	# Signal statt über einen Aufruf im UI: der Wechsel wird an drei Stellen ausgelöst.
	UserSettings.active_profile_changed.connect(switch_to)
	EventBus.run_started.connect(begin)
	EventBus.run_ended.connect(end)
	EventBus.wave_cleared.connect(func(_wave_id): note_wave_cleared())
	EventBus.item_reviewed.connect(func(_id, correct, response_time_ms): note_answer(correct, response_time_ms))


# --- Erfassung ----------------------------------------------------------------
#
# Öffentliche Methoden, die die Signal-Handler oben nur weiterreichen: so ist das Log
# ohne EventBus und ohne Szene prüfbar (siehe tests/session_log_test.gd).

## Beginnt eine neue Sitzung. Ein noch offener Lauf wird vorher ordentlich beendet —
## ohne das würde ein Szenenwechsel ohne Rückweg über das Menü die alte Sitzung
## überschreiben, statt sie aufzuschreiben.
func begin() -> void:
	if not _current.is_empty():
		end()
	var now := int(Time.get_unix_time_from_system())
	_current = {
		"started_at": now, "ended_at": 0, "last_activity_at": now,
		"waves_cleared": 0, "wave_reached": 1, "difficulty_last": 0, "last_wave_won": false,
		"answers": 0, "correct": 0, "newly_mastered": 0,
		"response_time_sum_ms": 0, "timed_answers": 0, "fast_answers": 0,
		"monsters_defeated": 0, "monsters_leaked": 0, "best_no_leak_streak": 0,
		# -1 und nicht der volle Stand: solange der Lauf läuft, ist der tiefste HP-Stand
		# UNBEKANNT — end() liest ihn von GameState ab. Stünde hier das Maximum, trüge
		# jede abgebrochene Sitzung (load_sessions) einen makellosen Lauf in die Rekorde.
		"min_fortress_health": -1,
	}


## Verbucht eine beantwortete Aufgabe (richtig oder falsch).
func note_answer(correct: bool, response_time_ms: int = 0) -> void:
	if _current.is_empty():
		return
	_current["answers"] = int(_current["answers"]) + 1
	if correct:
		_current["correct"] = int(_current["correct"]) + 1
	# Zeiten nur zählen, wo eine gemessen wurde: ein durchgelassenes Monster meldet 0 ms
	# (Konvention aus PlayerProgress.record) und würde jeden Mittelwert nach unten ziehen.
	if response_time_ms > 0:
		_current["timed_answers"] = int(_current["timed_answers"]) + 1
		_current["response_time_sum_ms"] = int(_current["response_time_sum_ms"]) + response_time_ms
		if response_time_ms < FAST_ANSWER_MS:
			_current["fast_answers"] = int(_current["fast_answers"]) + 1
	_touch()


## Verbucht eine geräumte Welle und schreibt die Sitzung fort. Das Fortschreiben ist der
## Grund, aus dem hier überhaupt gespeichert wird: bricht der Prozess mitten im Lauf ab,
## ist die Sitzung bis zur letzten Welle erhalten (siehe load_sessions).
func note_wave_cleared() -> void:
	if _current.is_empty():
		return
	var cleared := int(_current["waves_cleared"]) + 1
	_current["waves_cleared"] = cleared
	_current["wave_reached"] = maxi(int(_current["wave_reached"]), cleared)
	_touch()
	_save()


## Beendet die Sitzung und schreibt sie fest. `summary` trägt, was nur der WaveRunner
## weiß: wave_reached, difficulty_last, last_wave_won. Ohne laufende Sitzung ein No-op,
## damit ein doppeltes Laufende (Abbruch nach dem Statistik-Screen) nichts anrichtet.
func end(summary: Dictionary = {}) -> void:
	if _current.is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	_current["ended_at"] = now
	_current["last_activity_at"] = now
	_current["wave_reached"] = maxi(
			int(_current["wave_reached"]), int(summary.get("wave_reached", 0)))
	_current["difficulty_last"] = int(summary.get("difficulty_last", _current["difficulty_last"]))
	_current["last_wave_won"] = bool(summary.get("last_wave_won", false))
	# Die Lauf-Zähler gehören GameState; hier werden sie nur abgelesen und fortgeschrieben.
	_current["monsters_defeated"] = GameState.monsters_defeated
	_current["monsters_leaked"] = GameState.monsters_leaked
	_current["best_no_leak_streak"] = GameState.best_no_leak_streak
	_current["min_fortress_health"] = GameState.min_fortress_health
	_current["newly_mastered"] = PlayerProgress.mastered_since(int(_current["started_at"])).size()

	# Eine Sitzung ohne jede Antwort und ohne geräumte Welle wird nicht aufgeschrieben:
	# sie hätte keine Aussage und würde die Tages-Serie mit einem Tag füllen, an dem
	# nichts geübt wurde (Kampfszene betreten und sofort abgebrochen).
	if int(_current["answers"]) == 0 and int(_current["waves_cleared"]) == 0:
		_current = {}
		_save()
		return
	_sessions.append(_current)
	_current = {}
	_save()


func _touch() -> void:
	_current["last_activity_at"] = int(Time.get_unix_time_from_system())


# --- Abfragen -----------------------------------------------------------------

## Abgeschlossene Sitzungen, älteste zuerst (Kopie).
func sessions() -> Array:
	return _sessions.duplicate(true)


## Die laufende Sitzung (Kopie) oder ein leeres Dictionary.
func current() -> Dictionary:
	return _current.duplicate(true)


## Sitzungen mit `started_at` im Zeitraum [from_unix, to_unix]. Die laufende Sitzung ist
## dabei — sonst fehlt in jeder „heute"-Anzeige genau der Lauf, der gerade läuft.
func sessions_between(from_unix: int, to_unix: int) -> Array:
	var out: Array = []
	for entry in _all_entries():
		var at := int(entry.get("started_at", 0))
		if at >= from_unix and at <= to_unix:
			out.append(entry)
	return out


## Lokale Tagesindizes (Tage seit Epoche) mit mindestens einer Sitzung im Zeitraum,
## aufsteigend. Grundlage für die Tages-Leiste (siehe CoinStrip).
func played_days(from_unix: int, to_unix: int) -> Array:
	var seen := {}
	for entry in sessions_between(from_unix, to_unix):
		seen[local_day(int(entry.get("started_at", 0)))] = true
	var days: Array = seen.keys()
	days.sort()
	return days


## Aufeinanderfolgende Tage mit mindestens einer Sitzung, rückwärts gezählt.
##
## Der heutige Tag ist keine Lücke, solange er läuft: gespielt wurde entweder heute (dann
## zählt heute mit) oder zuletzt gestern (dann bleibt die Serie stehen und endet gestern).
## Erst ein ganzer ausgelassener Tag bricht sie. Eine zurückgestellte Systemuhr kann die
## Zählung nicht ins Absurde treiben — gezählt wird ab heute rückwärts, Sitzungen mit
## einem Datum in der Zukunft bleiben unberücksichtigt.
func current_streak() -> int:
	var days := {}
	for entry in _all_entries():
		days[local_day(int(entry.get("started_at", 0)))] = true
	if days.is_empty():
		return 0
	var cursor := local_day(int(Time.get_unix_time_from_system()))
	if not days.has(cursor):
		cursor -= 1
		if not days.has(cursor):
			return 0
	var n := 0
	while days.has(cursor):
		n += 1
		cursor -= 1
	return n


## Wurde heute (lokal) schon geübt? Für die Nachfrage, ob die Serie heute noch wartet —
## die Serie selbst bricht deshalb nicht (siehe current_streak).
func played_today() -> bool:
	var today := local_day(int(Time.get_unix_time_from_system()))
	for entry in _all_entries():
		if local_day(int(entry.get("started_at", 0))) == today:
			return true
	return false


## Zahl der Tage mit mindestens einer Sitzung — der Vorrat, aus dem die Münzen der
## Tages-Leiste kommen (ein geübter Tag = eine Münze, mehrere Sitzungen am selben Tag
## sind eines). Sollen die Stücke später eingesammelt und ausgegeben werden können,
## braucht das einen EIGENEN Zähler für Ausgegebenes; Sitzungen zu löschen wäre der
## falsche Weg — sie sind die Lernhistorie, nicht die Geldbörse.
func played_day_count() -> int:
	var days := {}
	for entry in _all_entries():
		days[local_day(int(entry.get("started_at", 0)))] = true
	return days.size()


## Bestwerte über alle Sitzungen — die Grundlage der Kampf-Rekorde (Issue #11).
##
## Zwei Größen über DENSELBEN Wert, und sie sagen Verschiedenes: `min_fortress_health`
## ist der tiefste Stand, den die Festung je hatte (über alle Läufe hinweg), während
## `best_fortress_floor` der HÖCHSTE der lauf-eigenen Tiefstände ist — der schonendste
## Lauf, also das, was als Auszeichnung taugt. Beide sind -1, solange keine Sitzung einen
## Stand mitgebracht hat („unbekannt", nicht 0 HP).
func records() -> Dictionary:
	var out := {
		"sessions": 0, "highest_wave_cleared": 0, "best_no_leak_streak": 0,
		"monsters_defeated": 0, "monsters_leaked": 0, "min_fortress_health": -1,
		"best_fortress_floor": -1,
	}
	for entry in _all_entries():
		out["sessions"] = int(out["sessions"]) + 1
		out["highest_wave_cleared"] = maxi(int(out["highest_wave_cleared"]), int(entry.get("waves_cleared", 0)))
		out["best_no_leak_streak"] = maxi(int(out["best_no_leak_streak"]), int(entry.get("best_no_leak_streak", 0)))
		out["monsters_defeated"] = int(out["monsters_defeated"]) + int(entry.get("monsters_defeated", 0))
		out["monsters_leaked"] = int(out["monsters_leaked"]) + int(entry.get("monsters_leaked", 0))
		var low := int(entry.get("min_fortress_health", -1))
		if low >= 0:
			out["min_fortress_health"] = low if int(out["min_fortress_health"]) < 0 \
					else mini(int(out["min_fortress_health"]), low)
			out["best_fortress_floor"] = maxi(int(out["best_fortress_floor"]), low)
	return out


## Genauigkeit der jüngsten Sitzung und ihr Vergleichswert (Issue #13). Siehe
## accuracy_trend() — hier nur mit dem echten Verlauf, laufende Sitzung eingeschlossen.
func session_accuracy() -> Dictionary:
	return accuracy_trend(_all_entries())


## Genauigkeit der jüngsten Sitzung mit Antworten und ein Vergleichswert dazu.
##
## Die Lebenszeit-Genauigkeit taugt nicht als Kopfzahl: sie sinkt, sobald schwere Wörter
## geübt werden, und bewegt sich nach ein paar hundert Antworten kaum noch. Die Sitzung
## dagegen sagt, wie es HEUTE lief, und der Vergleich, ob das besser war als zuletzt.
##
## Vergleichswert ist das Mittel der Sitzungen aus den `window_days` Tagen VOR der
## jüngsten — gerechnet ab deren Beginn, nicht ab jetzt, damit eine Woche Pause den
## Vergleich nicht leert. Gibt es dort keine, ist es die Sitzung direkt davor, wie alt sie
## auch sei. Gemittelt wird über die Antworten (Summe richtig / Summe Antworten), nicht
## über die Sitzungen: ein Lauf mit drei Antworten wöge sonst so viel wie einer mit achtzig.
##
## Unter `min_answers` Antworten ist ein Anteil Rauschen (zwei von drei = 67 %). Dann ist
## `accuracy` -1, und ebenso `baseline`, wenn der Vergleich so dünn ist — „kein Wert" und
## nicht 0 %, siehe die Anzeige. Felder: answers, correct, accuracy, baseline,
## baseline_kind ("week" | "previous" | ""), live (die jüngste läuft noch).
##
## Statisch und über die Einträge statt über den Zustand: so ist die Regel mit erfundenen
## Sitzungen prüfbar, ohne ein Log zu füllen (dieselbe Aufteilung wie StatsScreen.record_rows).
static func accuracy_trend(entries: Array, min_answers := MIN_ACCURACY_ANSWERS,
		window_days := ACCURACY_WINDOW_DAYS) -> Dictionary:
	var out := {"answers": 0, "correct": 0, "accuracy": -1.0, "baseline": -1.0,
			"baseline_kind": "", "live": false}
	# Einträge ohne Antwort (nur geräumte Wellen) haben keine Genauigkeit.
	var answered: Array = entries.filter(func(e): return int(e.get("answers", 0)) > 0)
	if answered.is_empty():
		return out
	answered.sort_custom(func(a, b): return int(a.get("started_at", 0)) < int(b.get("started_at", 0)))
	var latest: Dictionary = answered.pop_back()
	out["answers"] = int(latest["answers"])
	out["correct"] = int(latest.get("correct", 0))
	out["live"] = int(latest.get("ended_at", 0)) == 0
	if int(out["answers"]) >= min_answers:
		out["accuracy"] = float(out["correct"]) / float(out["answers"])

	if answered.is_empty():
		return out
	var since := int(latest.get("started_at", 0)) - window_days * 86400
	var window: Array = answered.filter(func(e): return int(e.get("started_at", 0)) >= since)
	out["baseline_kind"] = "week"
	if window.is_empty():
		window = [answered.back()]
		out["baseline_kind"] = "previous"
	var answers := 0
	var correct := 0
	for entry in window:
		answers += int(entry["answers"])
		correct += int(entry.get("correct", 0))
	if answers >= min_answers:
		out["baseline"] = float(correct) / float(answers)
	else:
		out["baseline_kind"] = ""
	return out


## Lokaler Tagesindex (Tage seit Epoche) eines Unix-Zeitstempels. Bewusst lokal und nicht
## UTC: sonst wechselt der Tag abends mitten in der Sitzung und die Serie bricht grundlos.
func local_day(unix: int) -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias * 60) / 86400.0)


## Abgeschlossene Sitzungen plus die laufende — alles, was zählt, auch mitten im Lauf.
func _all_entries() -> Array:
	var all := _sessions.duplicate()
	if not _current.is_empty():
		all.append(_current)
	return all


# --- Persistenz ---------------------------------------------------------------

## Beendet die laufende Sitzung im alten Profil und lädt das Log des neuen.
func switch_to(id: String) -> void:
	end()
	player_id = id
	_sessions.clear()
	_current = {}
	load_sessions()


func _save_path() -> String:
	return "%s/%s_sessions.json" % [SAVE_DIR, player_id]


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {"player_id": player_id, "sessions": _sessions, "current": _current}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("SessionLog: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Lädt das Log und schließt dabei eine offen liegende Sitzung ab.
##
## Eine offene Sitzung in der Datei heißt: der Lauf wurde hart beendet (Absturz, Fenster
## zu). Sie wird hier geschlossen (Ende = letzte Aktivität) und als `aborted` markiert,
## statt als halber Eintrag stehen zu bleiben oder verloren zu gehen.
func load_sessions() -> void:
	_sessions.clear()
	_current = {}
	if not FileAccess.file_exists(_save_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (parsed is Dictionary):
		push_warning("SessionLog: ungültige Sitzungsdatei '%s'" % _save_path())
		return
	var payload: Dictionary = parsed
	var loaded: Variant = payload.get("sessions", [])
	if loaded is Array:
		_sessions = loaded
	var open: Variant = payload.get("current", {})
	if open is Dictionary and not (open as Dictionary).is_empty():
		var entry: Dictionary = open
		entry["ended_at"] = int(entry.get("last_activity_at", entry.get("started_at", 0)))
		entry["aborted"] = true
		# Dieselbe Regel wie in end(): eine Sitzung ohne Antwort und ohne Welle fällt weg.
		if int(entry.get("answers", 0)) > 0 or int(entry.get("waves_cleared", 0)) > 0:
			_sessions.append(entry)
		_save()
