extends Node
## Persistenter Spielerfortschritt je learnable_id (Autoload `PlayerProgress`); Schema der
## Schlüssel: TaskResolver.learnable_id(). Die Fälligkeit wird gerechnet (SpacedRepetition,
## ADR 0018). Persistenz: user://progress/<player_id>.json über den SaveCoordinator
## (ADR 0024); Antworten einer abgebrochenen Welle verfallen.

const SAVE_DIR := "user://progress"

## Ab dieser Confidence (0..1) gilt eine Aufgabe als „gemeistert".
const MASTERY_CONFIDENCE := 0.8
## Start-Confidence einer ungesehenen Aufgabe ohne Prior aus CEFR/Frequenz.
const DEFAULT_CONFIDENCE := 0.3
## Wochen der Lernkurve (mastery_curve).
const CURVE_WEEKS := 12

## learnable_id -> {
##   confidence: float (0..1), attempts: int, correct_total: int,
##   current_streak: int, best_streak: int, last_correct: bool,
##   last_response_time_ms: int, last_seen_at: int (unix),
##   first_seen_at: int (unix), mastered_at: int (unix, 0 = nie/unbekannt)
## }
## Fehlende Zeitstempel heißen 0 = „unbekannt“ und werden nie erfunden.
var _records: Dictionary = {}
var player_id: String = "default"


func _ready() -> void:
	player_id = UserSettings.active_profile()
	load_progress()
	SaveCoordinator.register(self)
	UserSettings.active_profile_changed.connect(switch_to)


## Abstand der lokalen Zeit zu UTC in Sekunden.
var utc_offset := int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _now() -> int:
	return int(Time.get_unix_time_from_system())


## `initial_confidence` >= 0 setzt die Start-Confidence eines neu angelegten Records
## (Prior aus CEFR/Frequenz), < 0 heißt DEFAULT_CONFIDENCE. Bestehende bleiben unberührt.
func _ensure(task_id: String, initial_confidence: float = -1.0) -> void:
	if not _records.has(task_id):
		var start_conf := initial_confidence if initial_confidence >= 0.0 else DEFAULT_CONFIDENCE
		_records[task_id] = {
			"confidence": start_conf, "attempts": 0, "correct_total": 0,
			"current_streak": 0, "best_streak": 0, "last_correct": false,
			"last_response_time_ms": 0, "last_seen_at": 0,
			"first_seen_at": int(Time.get_unix_time_from_system()), "mastered_at": 0,
		}


## Verbucht ein Antwort-Ergebnis für eine Aufgabe. Rückgabe: true genau dann, wenn diese Antwort die Aufgabe zum ersten Mal gemeistert hat
## (`mastered_at` springt von 0 auf einen Zeitstempel, die Confidence lag vorher unter der
## Schwelle). Ob damit auch das Wort sitzt, sagt mastered_lexeme_of().
## `now`: unix, < 0 = Systemzeit.
func record(task_id: String, correct: bool, response_time_ms: int = 0, initial_confidence: float = -1.0,
		now := -1) -> bool:
	_ensure(task_id, initial_confidence)
	var rec: Dictionary = _records[task_id]
	var was_below := float(rec["confidence"]) < MASTERY_CONFIDENCE
	# Abstand zur letzten Antwort und das bis dahin geplante Intervall — vor dem
	# Überschreiben von last_seen_at; -1: noch nie beantwortet.
	var last := int(rec["last_seen_at"])
	if now < 0:
		now = _now()
	var elapsed := now - last if last > 0 else -1
	var interval := due_at(task_id) - last if last > 0 else 0
	rec["attempts"] += 1
	rec["last_correct"] = correct
	rec["last_response_time_ms"] = response_time_ms
	rec["last_seen_at"] = now

	if correct:
		rec["correct_total"] += 1
		rec["current_streak"] += 1
		rec["best_streak"] = max(rec["best_streak"], rec["current_streak"])
		# Nähert sich 1.0, schneller mit mehr Abstand zur letzten Antwort (ADR 0018).
		var gain := SpacedRepetition.spacing_gain(elapsed, interval)
		rec["confidence"] = minf(1.0, rec["confidence"] + gain * (1.0 - rec["confidence"]))
	else:
		rec["current_streak"] = 0
		rec["confidence"] = maxf(0.0, rec["confidence"] * 0.5)

	# Datum der ersten Meisterung, einmalig und ohne Rücknahme. Ein Altbestand-Record, der
	# schon über der Schwelle stand, bekommt sein Datum, gilt aber nicht als neu gemeistert.
	var newly_mastered := false
	if int(rec.get("mastered_at", 0)) == 0 and float(rec["confidence"]) >= MASTERY_CONFIDENCE:
		rec["mastered_at"] = rec["last_seen_at"]
		newly_mastered = was_below
	return newly_mastered


## Fälligkeit (unix) einer Aufgabe, gerechnet aus ihrem Record (SpacedRepetition.due_at);
## 0, wenn sie nie beantwortet wurde.
func due_at(task_id: String) -> int:
	var rec: Dictionary = _records.get(task_id, {})
	if rec.is_empty():
		return 0
	return SpacedRepetition.due_at(float(rec.get("confidence", 0.0)),
			bool(rec.get("last_correct", false)), int(rec.get("last_seen_at", 0)), utc_offset)


## {} für eine ungesehene Aufgabe, sonst { confidence, last_seen, due_at }.
func state_of(task_id: String) -> Dictionary:
	if not _records.has(task_id):
		return {}
	return {
		"confidence": confidence(task_id),
		"last_seen": last_seen_at(task_id),
		"due_at": due_at(task_id),
	}


## Gesehene learnable_ids, die zu `now` (unix, < 0 = jetzt) fällig sind, überfälligste zuerst.
func due_task_ids(now := -1) -> Array:
	var at := now if now >= 0 else _now()
	var due: Array = []
	var due_ats := {}
	for id in _records:
		var d := due_at(id)
		if d <= at:
			due.append(id)
			due_ats[id] = d
	due.sort_custom(func(a, b): return due_ats[a] < due_ats[b])
	return due


func record_of(task_id: String) -> Dictionary:
	return (_records.get(task_id, {}) as Dictionary).duplicate()


## Wie viele Wörter der Sprache `lang` schon einmal richtig übersetzt wurden, in irgendeiner
## Richtung. Gezählt wird nur `translate`.
func lexemes_answered(lang: String) -> int:
	return lexemes_answered_in(_records, lang)


static func lexemes_answered_in(records: Dictionary, lang: String) -> int:
	var hit := {}
	for id in records:
		if int(records[id].get("correct_total", 0)) <= 0:
			continue
		var parts := str(id).split(":")
		if parts.size() == 3 and parts[0] == "translate" \
				and Lexeme.language_of_direction(parts[1]) == lang:
			hit[parts[2]] = true
	return hit.size()


## Confidence 0..1 für eine Aufgabe; `default_value` für ungesehene.
func confidence(task_id: String, default_value: float = DEFAULT_CONFIDENCE) -> float:
	return float(_records.get(task_id, {}).get("confidence", default_value))


func has_seen(task_id: String) -> bool:
	return _records.has(task_id)


## Wann die Aufgabe zuletzt beantwortet wurde (unix); 0, wenn nie.
func last_seen_at(task_id: String) -> int:
	return int(_records.get(task_id, {}).get("last_seen_at", 0))


## Die letzte Antwort (unix) je Buch über alle Aufgaben seiner Lexeme; ungespielte Bücher
## fehlen. `book_of`: Lexem-Id -> Buch.
func last_seen_by_book(book_of: Dictionary) -> Dictionary:
	return last_seen_by_book_in(_records, book_of)


static func last_seen_by_book_in(records: Dictionary, book_of: Dictionary) -> Dictionary:
	var out := {}
	for id in records:
		var seen := int(records[id].get("last_seen_at", 0))
		if seen <= 0:
			continue
		# Die Lexem-Id steht je nach Aufgabentyp an Stelle 1 oder 2 (TaskResolver.learnable_id).
		var parts := str(id).split(":")
		for i in range(1, mini(parts.size(), 3)):
			var book := str(book_of.get(parts[i], ""))
			if not book.is_empty():
				out[book] = maxi(int(out.get(book, 0)), seen)
				break
	return out


func last_correct(task_id: String) -> bool:
	return bool(_records.get(task_id, {}).get("last_correct", false))


## Die Aufgabe sitzt: gesehen und über der Schwelle. Der Prior einer ungesehenen zählt nicht.
func is_mastered(task_id: String, threshold := MASTERY_CONFIDENCE) -> bool:
	return has_seen(task_id) and confidence(task_id) >= threshold


func mastered_count(threshold := MASTERY_CONFIDENCE, languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		if float(rec.get("confidence", 0.0)) >= threshold:
			n += 1
	return n


## Die Records der Sprachen in `languages`, alle bei leerer Liste. Die Sprache wird
## gerechnet (Lexeme.language_of_learnable); unbestimmbare zählen nur ohne Filter.
func _records_in(languages: Array) -> Dictionary:
	if languages.is_empty():
		return _records
	var language_of := _language_filter()
	var out := {}
	for id in _records:
		if language_of.call(id) in languages:
			out[id] = _records[id]
	return out


func _language_filter() -> Callable:
	var books := {}
	var book_language := func(book: String) -> String:
		if not books.has(book):
			books[book] = ContentRegistry.book_language(book)
		return books[book]
	return func(id) -> String:
		return Lexeme.language_of_learnable(str(id), ContentRegistry.lexemes, book_language)


func reset() -> void:
	_records.clear()


## Wechselt zum Profil `id` und lädt dessen Fortschritt; ohne Datei leer.
func switch_to(id: String) -> void:
	player_id = id
	reload()


func reload() -> void:
	reset()
	load_progress()


# --- Aggregierte Statistik ----------------------------------------------------
#
# Jeder Zähler nimmt optional Sprachen (["fr", "la"]); leer heißt alle (_records_in).

func total_attempts(languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		n += int(rec.get("attempts", 0))
	return n


func total_correct(languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		n += int(rec.get("correct_total", 0))
	return n


## Gesamt-Genauigkeit 0..1 (korrekt / Versuche); 0.0 wenn noch keine Versuche.
func overall_accuracy(languages: Array = []) -> float:
	return float(total_correct(languages)) / float(max(1, total_attempts(languages)))


func best_streak_overall(languages: Array = []) -> int:
	var best := 0
	for rec in _records_in(languages).values():
		best = max(best, int(rec.get("best_streak", 0)))
	return best


func seen_count(languages: Array = []) -> int:
	return _records_in(languages).size()


## Anzahl heute (oder früher) fälliger Wiederholungen.
func due_count(languages: Array = []) -> int:
	var due := due_task_ids()
	if languages.is_empty():
		return due.size()
	var in_language := _records_in(languages)
	return due.filter(func(id): return in_language.has(id)).size()


## learnable_ids, die seit `since` (unix) erstmals gemeistert wurden, jüngste zuerst.
## Records ohne Zeitstempel bleiben außen vor.
func mastered_since(since: int) -> Array:
	var ids: Array = []
	for id in _records:
		var at := int(_records[id].get("mastered_at", 0))
		if at > 0 and at >= since:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(_records[a]["mastered_at"]) > int(_records[b]["mastered_at"]))
	return ids


## Anzahl der Aufgaben, die vor `before` (unix) gemeistert wurden. Altbestand ohne
## Zeitstempel zählt mit, sofern er jetzt gemeistert ist.
func mastered_count_before(before: int, threshold := MASTERY_CONFIDENCE, languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		var at := int(rec.get("mastered_at", 0))
		if at == 0:
			if float(rec.get("confidence", 0.0)) >= threshold:
				n += 1
		elif at < before:
			n += 1
	return n


## Kumulierte Lernkurve „gemeisterte Aufgaben" über die letzten `weeks` Wochen.
## Rückgabe: Array von { "end": int (unix, Ende der Woche, exklusiv), "count": int },
## älteste Woche zuerst, `weeks` Einträge; `count` ist kumuliert (mastered_count_before).
## Die letzte Woche endet am Ende des heutigen lokalen Tages. `now`: unix, < 0 = Systemzeit.
func mastery_curve(weeks := CURVE_WEEKS, now := -1, languages: Array = []) -> Array:
	var now_unix := now if now >= 0 else int(Time.get_unix_time_from_system())
	var last_end := _local_day_end(now_unix)
	var out: Array = []
	for i in range(maxi(1, weeks) - 1, -1, -1):
		var week_end := last_end - i * 7 * 86400
		out.append({"end": week_end, "count": mastered_count_before(week_end, MASTERY_CONFIDENCE, languages)})
	return out


## Ende des lokalen Tages, in dem `unix` liegt (exklusiv, also die Mitternacht danach).
func _local_day_end(unix: int) -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return (floori(float(unix + bias) / 86400.0) + 1) * 86400 - bias


## Lexem-Ids, die als gemeistert gelten, als Menge (id -> true). Ein Wort braucht beide
## Übersetzungsrichtungen, ein unregelmäßiges Verb dazu seine Formaufgaben (ADR 0009;
## ARCHITECTURE „Meisterung: ein Wort braucht beide Richtungen“).
func mastered_lexemes(threshold := MASTERY_CONFIDENCE) -> Dictionary:
	return mastered_lexemes_in(_records, threshold, ContentRegistry.form_requirements())


## Wie mastered_lexemes(), statisch über übergebene Records. `requirements` ist
## ContentRegistry.form_requirements(): Lexem-Id -> learnable_ids, die zusätzlich zu den
## beiden Übersetzungsrichtungen sitzen müssen.
static func mastered_lexemes_in(records: Dictionary, threshold := MASTERY_CONFIDENCE,
		requirements: Dictionary = {}) -> Dictionary:
	# "<lexeme_id>|<sprache>" -> Menge der gemeisterten Richtungen dieser Sprache.
	var hits := {}
	for id in records:
		if float(records[id].get("confidence", 0.0)) < threshold:
			continue
		var parts := str(id).split(":")
		if parts.size() != 3 or parts[0] != "translate":
			continue
		var lang := Lexeme.language_of_direction(parts[1])
		if lang.is_empty():
			continue
		var key := "%s|%s" % [parts[2], lang]
		if not hits.has(key):
			hits[key] = {}
		hits[key][parts[1]] = true
	var out := {}
	for key in hits:
		if hits[key].size() == 2:
			var lexeme_id := str(key).get_slice("|", 0)
			if _all_mastered(records, requirements.get(lexeme_id, []), threshold):
				out[lexeme_id] = true
	return out


## Das Lexem, dessen Meisterung die Aufgabe `task_id` gerade abschließt, oder "".
## Gedacht direkt nach einem record(), das true geliefert hat; Regel wie mastered_lexemes().
func mastered_lexeme_of(task_id: String, threshold := MASTERY_CONFIDENCE) -> String:
	return mastered_lexeme_in(_records, task_id, threshold, ContentRegistry.form_requirements())


static func mastered_lexeme_in(records: Dictionary, task_id: String, threshold := MASTERY_CONFIDENCE,
		requirements: Dictionary = {}) -> String:
	var parts := task_id.split(":")
	if parts.size() != 3:
		return ""
	if parts[0] != "translate":
		# Eine Formaufgabe (conjugation:<lexem>:<form>) schließt nur ein Wort ab, das sie braucht.
		var needed: Array = requirements.get(parts[1], [])
		return parts[1] if task_id in needed and _all_mastered(records, needed, threshold) else ""
	var lang := Lexeme.language_of_direction(parts[1])
	if lang.is_empty():
		return ""
	for direction in Lexeme.mastery_directions(lang):
		var id := "translate:%s:%s" % [direction, parts[2]]
		if float(records.get(id, {}).get("confidence", 0.0)) < threshold:
			return ""
	return parts[2] if _all_mastered(records, requirements.get(parts[2], []), threshold) else ""


static func _all_mastered(records: Dictionary, ids: Array, threshold: float) -> bool:
	for id in ids:
		if float(records.get(id, {}).get("confidence", 0.0)) < threshold:
			return false
	return true


## Kann dieses Lexem gemeistert werden, gibt es zu ihm Übersetzungsaufgaben? Wer nicht,
## gehört in keinen Wert des Fortschrittsbalkens.
static func masterable(lexeme: Dictionary) -> bool:
	return not ("translate" in lexeme.get("excluded_task_types", []))


## Sortierte Liste für die Wort-Tabelle im Menü (schwächste Confidence zuerst).
## Rückgabe: Array von { id, label, confidence, mastered, attempts, correct, mastered_at }.
func records_for_display(languages: Array = []) -> Array:
	var resolver := TaskResolver.new()
	var rows: Array = []
	var records := _records_in(languages)
	for id in records:
		var rec: Dictionary = records[id]
		var conf := float(rec.get("confidence", 0.0))
		rows.append({
			"id": id,
			"label": resolver.describe_learnable(id),
			"confidence": conf,
			"mastered": conf >= MASTERY_CONFIDENCE,
			"attempts": int(rec.get("attempts", 0)),
			"correct": int(rec.get("correct_total", 0)),
			"mastered_at": int(rec.get("mastered_at", 0)),
		})
	rows.sort_custom(func(a, b): return a["confidence"] < b["confidence"])
	return rows


# --- Persistenz ---------------------------------------------------------------

func _save_path() -> String:
	return "%s/%s.json" % [SAVE_DIR, player_id]


func save_path() -> String:
	return _save_path()


func save_suffix() -> String:
	return ""


func save_payload() -> Dictionary:
	return {"player_id": player_id, "records": _records}


## Speichert über den SaveCoordinator (ADR 0024); eine nicht registrierte Instanz sofort.
func save_progress() -> void:
	SaveCoordinator.mark_dirty(self)


func load_progress() -> void:
	var read := SaveStore.read(_save_path())
	if int(read["status"]) == SaveStore.Status.MISSING:
		return
	var parsed: Variant = read["data"]
	if int(read["status"]) != SaveStore.Status.OK:
		push_warning("PlayerProgress: ungültige Fortschrittsdatei '%s'" % _save_path())
		return
	# Die player_id in der Datei gilt nicht; maßgeblich ist der Pfad.
	_records = parsed.get("records", {})
	# Altes Feld aus der Zeit vor ADR 0018, fällt beim nächsten Speichern weg.
	for rec in _records.values():
		rec.erase("next_review_at")
