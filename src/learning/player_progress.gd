extends Node
## Persistenter Spielerfortschritt pro Aufgabe (Autoload `PlayerProgress`).
##
## Hält player_progress-Records (ERM). Die Fälligkeit wird aus ihnen gerechnet
## (SpacedRepetition, ADR 0018), es gibt keinen Plan daneben. Der Lernstand
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
## So viele Wochen umfasst die Lernkurve (siehe mastery_curve). Fest und nicht
## umschaltbar: ein Vierteljahr ist lang genug für einen Verlauf und kurz genug, dass
## die letzte Woche noch zu erkennen ist.
const CURVE_WEEKS := 12

## learnable_id -> {
##   confidence: float (0..1), attempts: int, correct_total: int,
##   current_streak: int, best_streak: int, last_correct: bool,
##   last_response_time_ms: int, last_seen_at: int (unix),
##   first_seen_at: int (unix), mastered_at: int (unix, 0 = nie/unbekannt)
## }
##
## `first_seen_at` und `mastered_at` sind die Zeitachse des Lernstands (Issue #4): ohne sie
## lässt sich nicht sagen, WANN etwas gemeistert wurde, und Lernkurve wie „frisch gemeistert"
## sind nicht darstellbar. Fortschrittsdateien von vor dieser Änderung haben die Felder nicht;
## fehlend heißt 0 = „unbekannt" und wird NICHT mit einem erfundenen Datum aufgefüllt.
var _records: Dictionary = {}
var player_id: String = "default"


func _ready() -> void:
	# Aktives Profil aus den Einstellungen übernehmen (UserSettings lädt vorher, siehe [autoload]).
	player_id = UserSettings.active_profile()
	load_progress()
	# Nach geräumter Welle sichern; günstiger Zeitpunkt ohne eigenes Autosave.
	EventBus.wave_cleared.connect(func(_wave_id): save_progress())


## Abstand der lokalen Zeit zu UTC in Sekunden: die Fälligkeit rechnet Tage ab lokaler
## Mitternacht (siehe SpacedRepetition).
var utc_offset := int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _now() -> int:
	return int(Time.get_unix_time_from_system())


## `initial_confidence` >= 0 setzt die Start-Confidence eines NEU angelegten Records
## (der Prior aus CEFR/Frequenz); < 0 fällt auf DEFAULT_CONFIDENCE zurück. Bestehende
## Records bleiben unberührt.
func _ensure(task_id: String, initial_confidence: float = -1.0) -> void:
	if not _records.has(task_id):
		var start_conf := initial_confidence if initial_confidence >= 0.0 else DEFAULT_CONFIDENCE
		_records[task_id] = {
			"confidence": start_conf, "attempts": 0, "correct_total": 0,
			"current_streak": 0, "best_streak": 0, "last_correct": false,
			"last_response_time_ms": 0, "last_seen_at": 0,
			# Erstkontakt: der Zeitpunkt gehört zum Anlegen des Records, nicht zur ersten
			# Antwort — `record()` legt ihn über _ensure() unmittelbar davor an.
			"first_seen_at": int(Time.get_unix_time_from_system()), "mastered_at": 0,
		}


## Verbucht ein Antwort-Ergebnis für eine Aufgabe und aktualisiert Fortschritt + Scheduler.
##
## Rückgabe: true genau dann, wenn diese Antwort die Aufgabe ZUM ERSTEN MAL gemeistert hat
## (`mastered_at` springt von 0 auf einen Zeitstempel und die Confidence lag vorher unter
## der Schwelle). Das ist der Anlass der Feier im
## Kampf (Issue #23); ob damit auch das Wort sitzt, sagt mastered_lexeme_of().
## `now` (unix, < 0 = Systemzeit) setzen nur Tests, die Tage zwischen Antworten brauchen.
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
		# Confidence nähert sich 1.0 — um so schneller, je mehr Zeit seit der letzten Antwort
		# lag (ADR 0018): drei Tage hintereinander meistern, dreimal in einer Stunde nicht.
		var gain := SpacedRepetition.spacing_gain(elapsed, interval)
		rec["confidence"] = minf(1.0, rec["confidence"] + gain * (1.0 - rec["confidence"]))
	else:
		rec["current_streak"] = 0
		rec["confidence"] = maxf(0.0, rec["confidence"] * 0.5)

	# Zeitpunkt der ERSTEN Meisterung festhalten. Bewusst einmalig und ohne Rücknahme:
	# fällt die Confidence später unter die Schwelle und steigt wieder, bleibt das Datum
	# der ersten Meisterung stehen — sonst taucht dasselbe Wort immer wieder unter
	# „frisch gemeistert" auf und die Lernkurve bekäme Sprünge in die Vergangenheit.
	# Gemeldet wird nur ein echter Übergang: ein Altbestand-Record ohne Zeitstempel, der
	# schon über der Schwelle stand, bekommt hier sein Datum, ist aber nicht NEU gemeistert.
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


## Was die Auswahl über eine Aufgabe wissen muss (WaveGenerator.ordered): {} für eine
## ungesehene, sonst { confidence, last_seen, due_at }.
func state_of(task_id: String) -> Dictionary:
	if not _records.has(task_id):
		return {}
	return {
		"confidence": confidence(task_id),
		"last_seen": last_seen_at(task_id),
		"due_at": due_at(task_id),
	}


## learnable_ids, die zu `now` (unix, < 0 = jetzt) fällig sind, überfälligste zuerst.
## Nur bereits gesehene Aufgaben; neue (ohne Record) zählen nicht.
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


## Confidence 0..1 für eine Aufgabe. Für noch ungesehene Aufgaben liefert `default_value`
## den Wert — der WaveGenerator übergibt hier den CEFR/Frequenz-Prior des Lexems.
func confidence(task_id: String, default_value: float = DEFAULT_CONFIDENCE) -> float:
	return float(_records.get(task_id, {}).get("confidence", default_value))


func has_seen(task_id: String) -> bool:
	return _records.has(task_id)


## Wann die Aufgabe zuletzt beantwortet wurde (unix); 0, wenn nie.
func last_seen_at(task_id: String) -> int:
	return int(_records.get(task_id, {}).get("last_seen_at", 0))


## War die letzte Antwort auf die Aufgabe richtig? false, wenn nie beantwortet.
func last_correct(task_id: String) -> bool:
	return bool(_records.get(task_id, {}).get("last_correct", false))


## Die Aufgabe sitzt: gesehen und über der Meisterungs-Schwelle — dieselbe Regel wie
## mastered_count(). Der Prior einer ungesehenen Aufgabe zählt nicht, gemeistert wird im
## Kampf. Das Wachkatapult (Bollwerk) räumt solche Monster ab.
func is_mastered(task_id: String, threshold := MASTERY_CONFIDENCE) -> bool:
	return has_seen(task_id) and confidence(task_id) >= threshold


## Anzahl Aufgaben, deren Confidence die Meisterungs-Schwelle erreicht. Die Festungsstufe
## hängt NICHT mehr daran, sondern an den Wörtern je Unit (FortressTier).
func mastered_count(threshold := MASTERY_CONFIDENCE, languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		if float(rec.get("confidence", 0.0)) >= threshold:
			n += 1
	return n


## Die Records der Sprachen in `languages` (Issue #45), alle bei leerer Liste. Die Statistik
## filtert so ihre Zähler. Die Sprache wird gerechnet (Lexeme.language_of_learnable: Richtung,
## sonst das Buch des Lexems), die Records tragen kein Sprachfeld; eine Aufgabe, deren Sprache
## sich nicht bestimmen lässt, zählt nur ohne Filter.
func _records_in(languages: Array) -> Dictionary:
	if languages.is_empty():
		return _records
	var language_of := _language_filter()
	var out := {}
	for id in _records:
		if language_of.call(id) in languages:
			out[id] = _records[id]
	return out


## Sprache je learnable_id, mit der Sprache je Buch zwischengespeichert —
## ContentRegistry.book_language läuft einmal über den Katalog.
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


## Speichert den aktuellen Stand und wechselt zum Profil `id` (lädt dessen Fortschritt).
## load_progress() kehrt früh zurück, wenn das Profil noch keine Datei hat -> leerer Start.
func switch_to(id: String) -> void:
	save_progress()
	reset()
	player_id = id
	load_progress()


# --- Aggregierte Statistik ----------------------------------------------------
#
# Jeder Zähler nimmt optional Sprachen (["fr", "la"]); leer heißt alle Sprachen. Gefiltert wird
# über _records_in, die Sprache wird dabei gerechnet und nicht gespeichert (Issue #45).

## Summe aller Antwortversuche über alle Aufgaben.
func total_attempts(languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		n += int(rec.get("attempts", 0))
	return n


## Summe aller korrekten Antworten über alle Aufgaben.
func total_correct(languages: Array = []) -> int:
	var n := 0
	for rec in _records_in(languages).values():
		n += int(rec.get("correct_total", 0))
	return n


## Gesamt-Genauigkeit 0..1 (korrekt / Versuche); 0.0 wenn noch keine Versuche.
func overall_accuracy(languages: Array = []) -> float:
	return float(total_correct(languages)) / float(max(1, total_attempts(languages)))


## Höchste je erreichte Serie über alle Aufgaben.
func best_streak_overall(languages: Array = []) -> int:
	var best := 0
	for rec in _records_in(languages).values():
		best = max(best, int(rec.get("best_streak", 0)))
	return best


## Anzahl bisher gesehener (mindestens einmal geübter) Aufgaben.
func seen_count(languages: Array = []) -> int:
	return _records_in(languages).size()


## Anzahl heute (oder früher) fälliger Wiederholungen.
func due_count(languages: Array = []) -> int:
	var due := due_task_ids()
	if languages.is_empty():
		return due.size()
	var in_language := _records_in(languages)
	return due.filter(func(id): return in_language.has(id)).size()


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
## < 0 heißt Systemzeit. `languages` beschränkt sie auf diese Sprachen (_records_in).
func mastery_curve(weeks := CURVE_WEEKS, now := -1, languages: Array = []) -> Array:
	var now_unix := now if now >= 0 else int(Time.get_unix_time_from_system())
	var last_end := _local_day_end(now_unix)
	var out: Array = []
	for i in range(maxi(1, weeks) - 1, -1, -1):
		var week_end := last_end - i * 7 * 86400
		out.append({"end": week_end, "count": mastered_count_before(week_end, MASTERY_CONFIDENCE, languages)})
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
## Ausnahme unregelmäßige Verben (`irregular: true` am Lexem, ADR 0009): bei ihnen gehören
## auch die Formaufgaben zur Meisterung (ContentRegistry.form_requirements). Ihre Formen
## lassen sich nicht aus einer Regel ableiten — wer „go" übersetzen kann, aber „went" nicht,
## kann das Wort nicht. Bei allen anderen bleiben Formen und Relationen außen vor: sie
## hängen an Zusatzdaten, die nur ein Teil der Lexeme hat, und wären als Bedingung eine
## Hürde, die vom Wort selbst nicht abhängt.
func mastered_lexemes(threshold := MASTERY_CONFIDENCE) -> Dictionary:
	return mastered_lexemes_in(_records, threshold, ContentRegistry.form_requirements())


## Wie mastered_lexemes(), aber über übergebene Records — statisch und ohne Autoload,
## damit die Regel für sich prüfbar bleibt (siehe tests/mastered_lexemes_test.gd).
## `requirements` ist ContentRegistry.form_requirements(): Lexem-Id -> alle learnable_ids,
## die für dieses Wort sitzen müssen; Wörter, die nicht drinstehen, brauchen nur die
## beiden Übersetzungsrichtungen.
static func mastered_lexemes_in(records: Dictionary, threshold := MASTERY_CONFIDENCE,
		requirements: Dictionary = {}) -> Dictionary:
	# lexeme_id -> Menge der gemeisterten Richtungen. Die Sprache steht in der Richtung
	# („de_to_la"); ein Wort ist gemeistert, wenn beide Richtungen EINER Sprache sitzen.
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


## Das Lexem, dessen Meisterung die Aufgabe `task_id` gerade abschließt — oder "".
##
## Gedacht für den Moment direkt nach einem record(), das true geliefert hat: gehört die
## Aufgabe zu dem, was das Wort braucht (eine der Übersetzungsrichtungen, bei einem
## unregelmäßigen Verb auch eine seiner Formen) und sitzt jetzt alles, ist das WORT zum
## ersten Mal gemeistert. Zum ersten Mal, weil diese Aufgabe eben erst ihre erste
## Meisterung bekam — vorher kann nie alles zugleich gesessen haben.
## Dieselbe Regel wie mastered_lexemes(), nur für ein einzelnes Wort.
func mastered_lexeme_of(task_id: String, threshold := MASTERY_CONFIDENCE) -> String:
	return mastered_lexeme_in(_records, task_id, threshold, ContentRegistry.form_requirements())


## Wie mastered_lexeme_of(), statisch über übergebene Records (prüfbar ohne Autoload).
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


## Kann dieses Lexem überhaupt gemeistert werden — gibt es zu ihm Übersetzungsaufgaben?
##
## Der Nenner des Fortschrittsbalkens ist die Zahl der Wörter einer Unit, der Zähler die
## der gemeisterten; ein Wort ohne `translate`-Aufgabe (`excluded_task_types` am Lexem,
## siehe WaveGenerator._instances) erreicht die Meisterung nie und hielte den Balken
## dauerhaft bei „N-1 von N" — genau der stehende Balken, gegen den es die Regel gibt.
## Es gehört deshalb in keinen der beiden Werte.
##
## Statisch und ohne Autoload, aus demselben Grund wie mastered_lexemes_in().
static func masterable(lexeme: Dictionary) -> bool:
	return not ("translate" in lexeme.get("excluded_task_types", []))


## Sortierte Liste für die Wort-Tabelle im Menü (schwächste Confidence zuerst).
## Rückgabe: Array von { id, label, confidence, mastered, attempts, correct, mastered_at }.
##
## `mastered_at` (0 = nie/unbekannt) fährt mit, damit die Listen „frisch gemeistert" und
## „Comeback" aus DIESER einen Abfrage entstehen und nicht aus einer zweiten daneben —
## das Auflösen der Labels über den TaskResolver ist der teure Teil. `languages` beschränkt
## die Liste auf diese Sprachen (_records_in).
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


func save_progress() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"player_id": player_id,
		"records": _records,
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
	# Bis 0.26 lag daneben ein SM-2-Plan (`sr`) und je Record sein Ergebnis
	# (`next_review_at`). Die Fälligkeit wird jetzt gerechnet (ADR 0018); beides fällt
	# beim nächsten Speichern weg.
	for rec in _records.values():
		rec.erase("next_review_at")
