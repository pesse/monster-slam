extends Node
## Persistenter Spielerfortschritt pro Aufgabe (Autoload `PlayerProgress`).
##
## Hält player_task_progress-Records (ERM) und kapselt den SM-2-Scheduler
## (src/learning/spaced_repetition.gd, unverändert wiederverwendet). Der Lernstand
## hängt nur an Spieler + task_template_id — nicht am Monster.
##
## Persistenz: JSON unter user://progress/<player_id>.json. Content (lexemes, tasks…)
## bleibt versioniertes JSON unter res://data/ — hier landet NUR der Fortschritt.

const SAVE_DIR := "user://progress"

## task_template_id -> {
##   confidence: float (0..1), attempts: int, correct_total: int,
##   current_streak: int, best_streak: int, last_correct: bool,
##   last_response_time_ms: int, last_seen_at: int (unix), next_review_at: int (unix)
## }
var _records: Dictionary = {}
var _sr := SpacedRepetition.new()
var player_id: String = "default"


func _ready() -> void:
	load_progress()
	# Nach geräumter Welle sichern; günstiger Zeitpunkt ohne eigenes Autosave.
	EventBus.wave_cleared.connect(func(_wave_id): save_progress())


## Ganzzahliger Tageszähler als monotone Zeitbasis für den SM-2-Scheduler.
func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func _ensure(task_id: String) -> void:
	if not _records.has(task_id):
		_records[task_id] = {
			"confidence": 0.3, "attempts": 0, "correct_total": 0,
			"current_streak": 0, "best_streak": 0, "last_correct": false,
			"last_response_time_ms": 0, "last_seen_at": 0, "next_review_at": 0,
		}
	_sr.register(task_id)


## Verbucht ein Antwort-Ergebnis für eine Aufgabe und aktualisiert Fortschritt + Scheduler.
func record(task_id: String, correct: bool, response_time_ms: int = 0) -> void:
	_ensure(task_id)
	var rec: Dictionary = _records[task_id]
	rec["attempts"] += 1
	rec["last_correct"] = correct
	rec["last_response_time_ms"] = response_time_ms
	rec["last_seen_at"] = int(Time.get_unix_time_from_system())

	if correct:
		rec["correct_total"] += 1
		rec["current_streak"] += 1
		rec["best_streak"] = max(rec["best_streak"], rec["current_streak"])
		# Confidence nähert sich exponentiell 1.0.
		rec["confidence"] = minf(1.0, rec["confidence"] + 0.25 * (1.0 - rec["confidence"]))
	else:
		rec["current_streak"] = 0
		rec["confidence"] = maxf(0.0, rec["confidence"] * 0.5)

	# SM-2-Qualität (0..5): schnell+richtig hoch, falsch < 3 (Reset im Scheduler).
	var quality := 2
	if correct:
		quality = 5 if (response_time_ms > 0 and response_time_ms < 4000) else 4
	_sr.review(task_id, quality, _today())
	rec["next_review_at"] = _due_day(task_id) * 86400


## Nächster Fälligkeitstag (Tageszähler) des Items laut Scheduler.
func _due_day(task_id: String) -> int:
	return int(_sr.to_dict().get(task_id, {}).get("due", _today()))


## task_template_ids, die heute oder früher fällig sind (überfälligste zuerst).
## Nur bereits gesehene Aufgaben; neue (ohne Record) wählt der WaveGenerator separat.
func due_task_ids() -> Array:
	return _sr.due_items(_today())


## Confidence 0..1 für eine Aufgabe; Default für ungesehene Aufgaben.
func confidence(task_id: String) -> float:
	return float(_records.get(task_id, {}).get("confidence", 0.3))


func has_seen(task_id: String) -> bool:
	return _records.has(task_id)


func reset() -> void:
	_records.clear()
	_sr = SpacedRepetition.new()


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s.json" % [SAVE_DIR, player_id]


func save_progress() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"player_id": player_id,
		"records": _records,
		"sr": _sr.to_dict(),
	}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("PlayerProgress: konnte '%s' nicht schreiben" % _save_path())
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_progress() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var text := FileAccess.get_file_as_string(_save_path())
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("PlayerProgress: ungültige Fortschrittsdatei '%s'" % _save_path())
		return
	player_id = str(parsed.get("player_id", player_id))
	_records = parsed.get("records", {})
	_sr.from_dict(parsed.get("sr", {}))
