extends Node
## Persistenter Spielerfortschritt pro Aufgabe (Autoload `PlayerProgress`).
##
## Hält player_progress-Records (ERM) und kapselt den SM-2-Scheduler
## (src/learning/spaced_repetition.gd, unverändert wiederverwendet). Der Lernstand
## hängt nur an Spieler + learnable_id (Task-Typ + Richtung + Lexeme/Form/Relation),
## nicht am Monster. Siehe TaskResolver.learnable_id() für das Schlüssel-Schema.
##
## Persistenz: JSON unter user://progress/<player_id>.json. Content (lexemes, tasks…)
## bleibt versioniertes JSON unter res://data/ — hier landet NUR der Fortschritt.

const SAVE_DIR := "user://progress"

## Ab dieser Confidence (0..1) gilt eine Aufgabe als „gemeistert".
const MASTERY_CONFIDENCE := 0.8
## Start-Confidence einer noch ungesehenen Aufgabe ohne weitere Information. Ein aus
## CEFR/Frequenz des Lexems abgeleiteter Prior (WaveGenerator) kann diesen Wert beim
## ersten Kontakt ersetzen — schwerere/seltenere Wörter starten dann unsicherer.
const DEFAULT_CONFIDENCE := 0.3
## Festungsstufen-Schwellen: ab so vielen gemeisterten Aufgaben steigt die Stufe
## um 1 (0 → 1 → 2 → 3 → 4). Bewusst als Konstante, damit leicht justierbar.
const FORTRESS_TIER_THRESHOLDS := [1, 3, 6, 10]

## learnable_id -> {
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


## `initial_confidence` >= 0 setzt die Start-Confidence eines NEU angelegten Records
## (der Prior aus CEFR/Frequenz); < 0 fällt auf DEFAULT_CONFIDENCE zurück. Bestehende
## Records bleiben unberührt.
func _ensure(task_id: String, initial_confidence: float = -1.0) -> void:
	if not _records.has(task_id):
		var start_conf := initial_confidence if initial_confidence >= 0.0 else DEFAULT_CONFIDENCE
		_records[task_id] = {
			"confidence": start_conf, "attempts": 0, "correct_total": 0,
			"current_streak": 0, "best_streak": 0, "last_correct": false,
			"last_response_time_ms": 0, "last_seen_at": 0, "next_review_at": 0,
		}
	_sr.register(task_id)


## Verbucht ein Antwort-Ergebnis für eine Aufgabe und aktualisiert Fortschritt + Scheduler.
func record(task_id: String, correct: bool, response_time_ms: int = 0, initial_confidence: float = -1.0) -> void:
	_ensure(task_id, initial_confidence)
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


## learnable_ids, die heute oder früher fällig sind (überfälligste zuerst).
## Nur bereits gesehene Aufgaben; neue (ohne Record) wählt der WaveGenerator separat.
func due_task_ids() -> Array:
	return _sr.due_items(_today())


## Confidence 0..1 für eine Aufgabe. Für noch ungesehene Aufgaben liefert `default_value`
## den Wert — der WaveGenerator übergibt hier den CEFR/Frequenz-Prior des Lexems.
func confidence(task_id: String, default_value: float = DEFAULT_CONFIDENCE) -> float:
	return float(_records.get(task_id, {}).get("confidence", default_value))


func has_seen(task_id: String) -> bool:
	return _records.has(task_id)


## Anzahl Aufgaben, deren Confidence die Meisterungs-Schwelle erreicht — Grundlage
## der Festungsstufe (mehr gemeistert = größere Festung).
func mastered_count(threshold := MASTERY_CONFIDENCE) -> int:
	var n := 0
	for rec in _records.values():
		if float(rec.get("confidence", 0.0)) >= threshold:
			n += 1
	return n


## Festungsstufe 0..4 aus der Zahl gemeisterter Aufgaben (siehe FORTRESS_TIER_THRESHOLDS).
func fortress_tier() -> int:
	var m := mastered_count()
	var tier := 0
	for t in FORTRESS_TIER_THRESHOLDS:
		if m >= int(t):
			tier += 1
	return tier


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
