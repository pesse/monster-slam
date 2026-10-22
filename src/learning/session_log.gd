extends Node
## Verlauf je Spiel-Sitzung (Autoload `SessionLog`): ein Eintrag je Lauf, also alles
## zwischen `EventBus.run_started` und `run_ended`. Neu gemeisterte Aufgaben werden nicht
## mitgezählt, sondern am Laufende bei PlayerProgress erfragt (`mastered_since`).
## Persistenz: user://progress/<player_id>_sessions.json.

const SAVE_DIR := "user://progress"
## Bis zu dieser Antwortzeit (ms) gilt eine Antwort als „Blitzantwort“.
const FAST_ANSWER_MS := 2000
## Mindestzahl Antworten, ab der eine Genauigkeit ausgewiesen wird.
const MIN_ACCURACY_ANSWERS := 5
## Der Vergleichswert der Sitzungs-Genauigkeit mittelt über so viele Tage davor.
const ACCURACY_WINDOW_DAYS := 7

## Abgeschlossene Sitzungen, älteste zuerst. Felder eines Eintrags:
##   started_at, ended_at, last_activity_at: int (unix)
##   waves_cleared: int          — geräumte Wellen (zugleich die höchste)
##   wave_reached, difficulty_last: int
##   last_wave_won: bool         — Ausgang der letzten Welle des Laufs
##   answers, correct: int
##   newly_mastered: int         — in dieser Sitzung erstmals gemeisterte Aufgaben
##   response_time_sum_ms, timed_answers, fast_answers: int
##   monsters_defeated, monsters_leaked, best_no_leak_streak: int
##   min_fortress_health: int    — tiefster HP-Stand des Laufs; -1 heißt „unbekannt"
##                                 (erst end() liest ihn von GameState ab)
##   aborted: bool               — nur bei hart beendeten Läufen (siehe load_sessions)
##   suspended: bool             — nur bei begonnenen Läufen (ADR 0020)
##   continues: int              — nur bei fortgesetzten: started_at der ersten Sitzung des Laufs
##   battle_ms: int              — Kampfzeit der Wellen (BattleClock); fehlt = 0
var _sessions: Array = []
## Kampfzeit außerhalb eines Laufs (Bosskämpfe), älteste zuerst: kind (Id des Bosses),
## started_at (unix), battle_ms.
var _battles: Array = []
## Ab hier (unix) misst BattleClock; die Kampfzeit davor ist aus der Spur geschätzt
## (BattleBackfill). 0 = noch nicht nachgetragen.
var _measured_since := 0
## Die laufende Sitzung; leer = gerade kein Lauf.
var _current: Dictionary = {}
var player_id: String = "default"
## Eine verworfene Welle (SaveCoordinator.discard_uncommitted) nimmt dem Log nichts.
var keep_on_discard := true


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_sessions()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)
	EventBus.run_started.connect(begin)
	EventBus.run_ended.connect(end)
	EventBus.run_suspended.connect(func(_next_wave, _remaining): note_suspended())
	EventBus.run_resumed.connect(func(_next_wave, started_at, _added): note_resumed(started_at))
	EventBus.wave_cleared.connect(func(_wave_id): note_wave_cleared())
	EventBus.item_reviewed.connect(func(_id, correct, response_time_ms): note_answer(correct, response_time_ms))
	EventBus.battle_timed.connect(note_battle_time)


# --- Erfassung ----------------------------------------------------------------
#
# Öffentlich, damit das Log ohne EventBus prüfbar ist.

## Beginnt eine neue Sitzung; eine noch offene wird vorher beendet.
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
		"battle_ms": 0,
		# Unbekannt bis end(); sonst trüge eine abgebrochene Sitzung einen makellosen Lauf.
		"min_fortress_health": -1,
	}


## Die laufende Sitzung setzt einen begonnenen Lauf fort, der um `run_started_at` begann.
func note_resumed(run_started_at: int) -> void:
	if _current.is_empty() or run_started_at <= 0:
		return
	_current["continues"] = run_started_at


## Der Lauf wird gerastet; das Ende kommt gleich danach mit `run_ended`.
func note_suspended() -> void:
	if _current.is_empty():
		return
	_current["suspended"] = true


func note_answer(correct: bool, response_time_ms: int = 0) -> void:
	if _current.is_empty():
		return
	_current["answers"] = int(_current["answers"]) + 1
	if correct:
		_current["correct"] = int(_current["correct"]) + 1
	# 0 ms heißt „nicht gemessen“ (durchgelassenes Monster) und zählt nicht.
	if response_time_ms > 0:
		_current["timed_answers"] = int(_current["timed_answers"]) + 1
		_current["response_time_sum_ms"] = int(_current["response_time_sum_ms"]) + response_time_ms
		if response_time_ms < FAST_ANSWER_MS:
			_current["fast_answers"] = int(_current["fast_answers"]) + 1
	_touch()


## Verbucht eine Kampfzeit (EventBus.battle_timed): eine Welle in die laufende Sitzung,
## alles andere als eigener Eintrag.
func note_battle_time(kind: String, started_at: int, ms: int) -> void:
	if ms <= 0:
		return
	if kind == "wave" and not _current.is_empty():
		_current["battle_ms"] = int(_current.get("battle_ms", 0)) + ms
	else:
		_battles.append({"kind": kind, "started_at": started_at, "battle_ms": ms})
	_save()


## Verbucht eine geräumte Welle und speichert die laufende Sitzung mit, damit sie einen
## Abbruch überlebt (load_sessions).
func note_wave_cleared() -> void:
	if _current.is_empty():
		return
	var cleared := int(_current["waves_cleared"]) + 1
	_current["waves_cleared"] = cleared
	_current["wave_reached"] = maxi(int(_current["wave_reached"]), cleared)
	_touch()
	_save()


## Beendet die Sitzung und schreibt sie fest. `summary`: wave_reached, difficulty_last,
## last_wave_won. Ohne laufende Sitzung ein No-op.
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
	_current["monsters_defeated"] = GameState.monsters_defeated
	_current["monsters_leaked"] = GameState.monsters_leaked
	_current["best_no_leak_streak"] = GameState.best_no_leak_streak
	_current["min_fortress_health"] = GameState.min_fortress_health
	_current["newly_mastered"] = PlayerProgress.mastered_since(int(_current["started_at"])).size()

	# Ohne Antwort und ohne geräumte Welle zählt die Sitzung nicht (auch nicht zur Serie).
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

func sessions() -> Array:
	return _sessions.duplicate(true)


func current() -> Dictionary:
	return _current.duplicate(true)


## Sitzungen mit `started_at` im Zeitraum [from_unix, to_unix], die laufende eingeschlossen.
func sessions_between(from_unix: int, to_unix: int) -> Array:
	var out: Array = []
	for entry in _all_entries():
		var at := int(entry.get("started_at", 0))
		if at >= from_unix and at <= to_unix:
			out.append(entry)
	return out


## Lokale Tagesindizes (Tage seit Epoche) mit Sitzung im Zeitraum, aufsteigend.
func played_days(from_unix: int, to_unix: int) -> Array:
	var seen := {}
	for entry in sessions_between(from_unix, to_unix):
		seen[local_day(int(entry.get("started_at", 0)))] = true
	var days: Array = seen.keys()
	days.sort()
	return days


## Aufeinanderfolgende Tage mit mindestens einer Sitzung, ab heute rückwärts gezählt.
## Ein heute noch nicht gespielter Tag bricht die Serie nicht; sie endet dann gestern.
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


func played_today() -> bool:
	var today := local_day(int(Time.get_unix_time_from_system()))
	for entry in _all_entries():
		if local_day(int(entry.get("started_at", 0))) == today:
			return true
	return false


## Richtige Antworten heute (lokal), die laufende Sitzung eingeschlossen. Eine Sitzung
## über Mitternacht zählt zu ihrem Anfangstag.
func correct_today() -> int:
	var today := local_day(int(Time.get_unix_time_from_system()))
	var n := 0
	for entry in _all_entries():
		if local_day(int(entry.get("started_at", 0))) == today:
			n += int(entry.get("correct", 0))
	return n


## Richtige Antworten je lokalem Tagesindex, die laufende Sitzung eingeschlossen; Zählregel
## wie `correct_today`.
func correct_by_day() -> Dictionary:
	var out := {}
	for entry in _all_entries():
		var day := local_day(int(entry.get("started_at", 0)))
		out[day] = int(out.get(day, 0)) + int(entry.get("correct", 0))
	return out


func played_day_count() -> int:
	var days := {}
	for entry in _all_entries():
		days[local_day(int(entry.get("started_at", 0)))] = true
	return days.size()


## Kampfzeit (ms) je lokalem Tagesindex, laufende Sitzung und Bosskämpfe eingeschlossen.
## Wie bei `correct_by_day` zählt eine Sitzung zu ihrem Anfangstag.
func battle_ms_by_day() -> Dictionary:
	var out := {}
	for entry in _all_entries() + _battles:
		var ms := int(entry.get("battle_ms", 0))
		if ms > 0:
			var day := local_day(int(entry.get("started_at", 0)))
			out[day] = int(out.get(day, 0)) + ms
	return out


func battle_ms_total() -> int:
	var total := 0
	for ms: int in battle_ms_by_day().values():
		total += ms
	return total


## Ab wann die Kampfzeit gemessen statt geschätzt ist (unix); 0 = noch gar nicht.
func battle_measured_since() -> int:
	return _measured_since


## Bestwerte über alle Sitzungen. `min_fortress_health` ist der tiefste HP-Stand je,
## `best_fortress_floor` der höchste der lauf-eigenen Tiefstände; beide -1 = unbekannt.
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


## accuracy_trend() über den echten Verlauf, laufende Sitzung eingeschlossen.
func session_accuracy() -> Dictionary:
	return accuracy_trend(_all_entries())


## Genauigkeit der jüngsten Sitzung mit Antworten und ein Vergleichswert dazu: Summe richtig / Summe Antworten der Sitzungen aus den `window_days` Tagen
## vor Beginn der jüngsten; gibt es dort keine, die Sitzung direkt davor. Unter
## `min_answers` Antworten ist `accuracy` bzw. `baseline` -1 („kein Wert“).
## Felder: answers, correct, accuracy, baseline, baseline_kind ("week" | "previous" | ""),
## live (die jüngste läuft noch).
static func accuracy_trend(entries: Array, min_answers := MIN_ACCURACY_ANSWERS,
		window_days := ACCURACY_WINDOW_DAYS) -> Dictionary:
	var out := {"answers": 0, "correct": 0, "accuracy": -1.0, "baseline": -1.0,
			"baseline_kind": "", "live": false}
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


## Lokaler Tagesindex (Tage seit Epoche) eines Unix-Zeitstempels.
func local_day(unix: int) -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias * 60) / 86400.0)


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
	_battles.clear()
	_current = {}
	load_sessions()


func _save_path() -> String:
	return "%s/%s_sessions.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return "_sessions"


func save_payload() -> Dictionary:
	return {"player_id": player_id, "sessions": _sessions, "current": _current,
			"battles": _battles, "battle_measured_since": _measured_since}


func reload() -> void:
	load_sessions()


func _save() -> void:
	SaveCoordinator.mark_dirty(self)


## Lädt das Log. Eine offen liegende Sitzung (hart beendeter Lauf) wird mit Ende = letzte
## Aktivität geschlossen und als `aborted` markiert. Fehlt die Kampfzeit noch, wird sie
## einmal aus der Spur nachgetragen (BattleBackfill).
func load_sessions() -> void:
	_sessions.clear()
	_battles.clear()
	_current = {}
	_measured_since = 0
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		_measured_since = int(Time.get_unix_time_from_system())
		return
	if int(read["status"]) != SaveStore.Status.OK:
		push_warning("SessionLog: ungültige Sitzungsdatei '%s'" % _save_path())
		return
	var payload: Dictionary = read["data"]
	var loaded: Variant = payload.get("sessions", [])
	if loaded is Array:
		_sessions = loaded
	var battles: Variant = payload.get("battles", [])
	if battles is Array:
		_battles = battles
	_measured_since = int(payload.get("battle_measured_since", 0))
	var open: Variant = payload.get("current", {})
	if open is Dictionary and not (open as Dictionary).is_empty():
		var entry: Dictionary = open
		entry["ended_at"] = int(entry.get("last_activity_at", entry.get("started_at", 0)))
		entry["aborted"] = true
		# Dieselbe Regel wie in end(): eine Sitzung ohne Antwort und ohne Welle fällt weg.
		if int(entry.get("answers", 0)) > 0 or int(entry.get("waves_cleared", 0)) > 0:
			_sessions.append(entry)
		_save()
	if _measured_since == 0:
		backfill_battle_time(BattleBackfill.read_trace(player_id))


## Trägt die Kampfzeit aus der Spur `trace_lines` nach und misst ab jetzt. Gespeichert
## wird mit dem nächsten Speichern; bis dahin wiederholt jedes Laden dasselbe.
func backfill_battle_time(trace_lines: Array) -> void:
	_battles.append_array(BattleBackfill.apply(_sessions, BattleBackfill.segments(trace_lines)))
	_battles.sort_custom(func(a, b): return int(a["started_at"]) < int(b["started_at"]))
	_measured_since = int(Time.get_unix_time_from_system())
