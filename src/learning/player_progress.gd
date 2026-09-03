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
## Die Richtungen, in denen die Übersetzungsaufgabe eines Lexems sitzen muss, damit das
## WORT als gemeistert gilt (siehe mastered_lexemes).
const LEXEME_MASTERY_DIRECTIONS := ["de_to_en", "en_to_de"]
## So viele Wochen umfasst die Lernkurve (siehe mastery_curve). Fest und nicht
## umschaltbar: ein Vierteljahr ist lang genug für einen Verlauf und kurz genug, dass
## die letzte Woche noch zu erkennen ist.
const CURVE_WEEKS := 12

## learnable_id -> {
##   confidence: float (0..1), attempts: int, correct_total: int,
##   current_streak: int, best_streak: int, last_correct: bool,
##   last_response_time_ms: int, last_seen_at: int (unix), next_review_at: int (unix),
##   first_seen_at: int (unix), mastered_at: int (unix, 0 = nie/unbekannt)
## }
##
## `first_seen_at` und `mastered_at` sind die Zeitachse des Lernstands (Issue #4): ohne sie
## lässt sich nicht sagen, WANN etwas gemeistert wurde, und Lernkurve wie „frisch gemeistert"
## sind nicht darstellbar. Fortschrittsdateien von vor dieser Änderung haben die Felder nicht;
## fehlend heißt 0 = „unbekannt" und wird NICHT mit einem erfundenen Datum aufgefüllt.
var _records: Dictionary = {}
var _sr := SpacedRepetition.new()
var player_id: String = "default"


func _ready() -> void:
	# Aktives Profil aus den Einstellungen übernehmen (UserSettings lädt vorher, siehe [autoload]).
	player_id = UserSettings.active_profile()
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
			# Erstkontakt: der Zeitpunkt gehört zum Anlegen des Records, nicht zur ersten
			# Antwort — `record()` legt ihn über _ensure() unmittelbar davor an.
			"first_seen_at": int(Time.get_unix_time_from_system()), "mastered_at": 0,
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

	# Zeitpunkt der ERSTEN Meisterung festhalten. Bewusst einmalig und ohne Rücknahme:
	# fällt die Confidence später unter die Schwelle und steigt wieder, bleibt das Datum
	# der ersten Meisterung stehen — sonst taucht dasselbe Wort immer wieder unter
	# „frisch gemeistert" auf und die Lernkurve bekäme Sprünge in die Vergangenheit.
	if int(rec.get("mastered_at", 0)) == 0 and float(rec["confidence"]) >= MASTERY_CONFIDENCE:
		rec["mastered_at"] = rec["last_seen_at"]

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


## Speichert den aktuellen Stand und wechselt zum Profil `id` (lädt dessen Fortschritt).
## load_progress() kehrt früh zurück, wenn das Profil noch keine Datei hat -> leerer Start.
func switch_to(id: String) -> void:
	save_progress()
	reset()
	player_id = id
	load_progress()


# --- Aggregierte Statistik ----------------------------------------------------

## Summe aller Antwortversuche über alle Aufgaben.
func total_attempts() -> int:
	var n := 0
	for rec in _records.values():
		n += int(rec.get("attempts", 0))
	return n


## Summe aller korrekten Antworten über alle Aufgaben.
func total_correct() -> int:
	var n := 0
	for rec in _records.values():
		n += int(rec.get("correct_total", 0))
	return n


## Gesamt-Genauigkeit 0..1 (korrekt / Versuche); 0.0 wenn noch keine Versuche.
func overall_accuracy() -> float:
	return float(total_correct()) / float(max(1, total_attempts()))


## Höchste je erreichte Serie über alle Aufgaben.
func best_streak_overall() -> int:
	var best := 0
	for rec in _records.values():
		best = max(best, int(rec.get("best_streak", 0)))
	return best


## Anzahl bisher gesehener (mindestens einmal geübter) Aufgaben.
func seen_count() -> int:
	return _records.size()


## Anzahl heute (oder früher) fälliger Wiederholungen.
func due_count() -> int:
	return due_task_ids().size()


## learnable_ids, die seit `since` (unix) erstmals gemeistert wurden — jüngste zuerst.
## Records ohne Zeitstempel (Altbestand von vor der Zeitmessung) bleiben außen vor: ihre
## Meisterung liegt vor dem Messbeginn und wäre hier ein Eintrag vom 01.01.1970.
func mastered_since(since: int) -> Array:
	var ids: Array = []
	for id in _records:
		var at := int(_records[id].get("mastered_at", 0))
		if at > 0 and at >= since:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(_records[a]["mastered_at"]) > int(_records[b]["mastered_at"]))
	return ids


## Anzahl der Aufgaben, die vor `before` (unix) gemeistert wurden — der Startwert einer
## Lernkurve. Altbestand ohne Zeitstempel zählt mit, sofern er JETZT gemeistert ist: die
## Meisterung liegt irgendwann vor dem Messbeginn, und die Kurve soll bei ihm anfangen
## statt bei null.
func mastered_count_before(before: int, threshold := MASTERY_CONFIDENCE) -> int:
	var n := 0
	for rec in _records.values():
		var at := int(rec.get("mastered_at", 0))
		if at == 0:
			if float(rec.get("confidence", 0.0)) >= threshold:
				n += 1
		elif at < before:
			n += 1
	return n


## Kumulierte Lernkurve „gemeisterte Aufgaben" über die letzten `weeks` Wochen (Issue #7).
##
## Rückgabe: Array von { "end": int (unix, Ende der Woche, exklusiv), "count": int },
## älteste Woche zuerst, `weeks` Einträge. `count` ist der Stand am Ende der Woche, also
## kumuliert — die Kurve steigt und geht nie zurück, anders als die Genauigkeit, die beim
## Üben schwerer Wörter einbricht. Das ist der ganze Punkt der Darstellung.
##
## Der Startwert enthält den Altbestand ohne Zeitstempel (siehe mastered_count_before):
## dessen Meisterung liegt vor dem Messbeginn, und die Kurve fängt bei ihm an statt bei
## null — als Sprung am 01.01.1970 taucht er nirgends auf.
##
## Die Wochen enden am Ende des heutigen (lokalen) Tages, nicht am Kalender-Sonntag: die
## letzte Stütze soll den Stand von jetzt zeigen. `now` (unix) ist für Tests einsetzbar,
## < 0 heißt Systemzeit.
func mastery_curve(weeks := CURVE_WEEKS, now := -1) -> Array:
	var now_unix := now if now >= 0 else int(Time.get_unix_time_from_system())
	var last_end := _local_day_end(now_unix)
	var out: Array = []
	for i in range(maxi(1, weeks) - 1, -1, -1):
		var week_end := last_end - i * 7 * 86400
		out.append({"end": week_end, "count": mastered_count_before(week_end)})
	return out


## Ende des lokalen Tages, in dem `unix` liegt (exklusiv, also die Mitternacht danach).
## Lokal und nicht UTC, aus demselben Grund wie SessionLog.local_day: sonst wechselt der
## Tag abends mitten in der Sitzung.
func _local_day_end(unix: int) -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return (floori(float(unix + bias) / 86400.0) + 1) * 86400 - bias


## Lexem-Ids, die als gemeistert gelten — als Menge (id -> true), für die
## Fortschrittsbalken pro Unit und Thema (Issue #8).
##
## Die Regel: ein WORT ist gemeistert, wenn die Übersetzungsaufgabe in BEIDEN Richtungen
## gemeistert ist (de→en und en→de). mastered_count() zählt learnable_ids, und davon hat
## ein Wort mehrere (Richtungen, Formen, Relationen) — „18 von 24 Wörtern" bräuchte sonst
## keine Regel, sondern eine Ausrede: der Balken zählte Äpfel gegen Birnen und könnte über
## 100 % gehen. Beide Richtungen, weil ein Wort erkennen (en→de) leichter ist als es
## produzieren (de→en); wer nur die eine Richtung kann, kann das Wort noch nicht.
##
## Formen und Relationen (Konjugation, Gegenteil …) bleiben außen vor: sie hängen an
## Zusatzdaten, die nur ein Teil der Lexeme hat, und wären als Bedingung eine Hürde, die
## vom Wort selbst nicht abhängt.
func mastered_lexemes(threshold := MASTERY_CONFIDENCE) -> Dictionary:
	return mastered_lexemes_in(_records, threshold)


## Wie mastered_lexemes(), aber über übergebene Records — statisch und ohne Autoload,
## damit die Regel für sich prüfbar bleibt (siehe tests/mastered_lexemes_test.gd).
static func mastered_lexemes_in(records: Dictionary, threshold := MASTERY_CONFIDENCE) -> Dictionary:
	# lexeme_id -> Menge der gemeisterten Richtungen.
	var hits := {}
	for id in records:
		if float(records[id].get("confidence", 0.0)) < threshold:
			continue
		var parts := str(id).split(":")
		if parts.size() != 3 or parts[0] != "translate":
			continue
		if not (parts[1] in LEXEME_MASTERY_DIRECTIONS):
			continue
		if not hits.has(parts[2]):
			hits[parts[2]] = {}
		hits[parts[2]][parts[1]] = true
	var out := {}
	for lexeme_id in hits:
		if hits[lexeme_id].size() == LEXEME_MASTERY_DIRECTIONS.size():
			out[lexeme_id] = true
	return out


## Sortierte Liste für die Wort-Tabelle im Menü (schwächste Confidence zuerst).
## Rückgabe: Array von { id, label, confidence, mastered, attempts, correct }.
func records_for_display() -> Array:
	var resolver := TaskResolver.new()
	var rows: Array = []
	for id in _records:
		var rec: Dictionary = _records[id]
		var conf := float(rec.get("confidence", 0.0))
		rows.append({
			"id": id,
			"label": resolver.describe_learnable(id),
			"confidence": conf,
			"mastered": conf >= MASTERY_CONFIDENCE,
			"attempts": int(rec.get("attempts", 0)),
			"correct": int(rec.get("correct_total", 0)),
		})
	rows.sort_custom(func(a, b): return a["confidence"] < b["confidence"])
	return rows


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
