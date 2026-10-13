class_name TraceSanitizer
extends RefCounted
## Macht aus der Rohspur (TraceLog) die Fassung, die den Rechner verlassen darf (ADR 0021).
## Allowlist je Ereignistyp (`KEEP`): ein neues Ereignis oder Feld bleibt draußen, bis es
## hier eingetragen ist (tests/trace_sanitizer_test.gd). Getipptes wird zu Zahlen (Länge,
## Wortzahl, Editierabstand zur nächsten Lösung); die Lösungen stehen in früheren
## spawn-Zeilen, deshalb wird die Spur immer von vorn gelesen.

## Felder, die je Ereignistyp hinausgehen dürfen. `at`, `ms` und `e` gehen immer mit.
const KEEP := {
	"run_start": [],
	"run_end": ["wave_reached", "difficulty", "won"],
	"run_suspend": ["next_wave", "hp", "remaining"],
	"run_resume": ["next_wave", "since", "hp", "added"],
	"boss_start": ["boss"],
	"boss_answer": ["id", "hit", "q", "stage", "sure"],
	"boss_explained": ["id"],
	"boss_end": ["boss", "won"],
	"boss_won": ["boss", "unit"],
	"wave_start": ["wave", "hp", "armor"],
	"wave_clear": ["wave", "hp"],
	"fast_resolve": ["wave", "unspawned", "on_field"],
	"spawn": ["id", "lex", "type", "dir", "conf", "diff"],
	"answer": ["hit", "full", "id", "rt", "field", "conf", "exact", "unseen"],
	"leak": ["id", "lex", "dmg"],
	"catapult": ["id", "lex", "conf"],
	"struck": ["id", "lex"],
	"spell": ["spell", "wave"],
	"mastered": ["id"],
	"word_mastered": ["lex"],
	"badge": ["id", "tier"],
	# Spielstand (ADR 0024): nur Endungen, Zeitpunkte und Werte, kein Profilname.
	"save_refused": ["part", "reason"],
	"save_restored": ["parts", "backup_at"],
	"save_damaged": ["parts"],
}

## Höchstlänge einer Eingabe für den Editierabstand (Zeichen), gegen quadratische Rechnung.
const MAX_COMPARE := 64

var _evaluator := AnswerEvaluator.new()
## Akzeptierte Antworten je learnable_id, aus den spawn-Zeilen.
var _answers := {}


## Bereinigt `lines` (älteste zuerst) und gibt nur die Zeilen nach `after` ([at, ms]) zurück.
## Die davor werden für die Lösungen trotzdem gelesen.
func sanitize(lines: Array, after: Array = [0, 0]) -> Array:
	var out: Array = []
	for raw in lines:
		if not (raw is Dictionary):
			continue
		var line: Dictionary = raw
		var event := str(line.get("e", ""))
		if event == "spawn":
			_answers[str(line.get("id", ""))] = line.get("answers", [])
		if not is_after(mark_of(line), after):
			continue
		var clean := sanitize_line(line)
		if not clean.is_empty():
			out.append(clean)
	return out


## Eine Zeile durch die Allowlist; {} für ein Ereignis, das nicht hinausgeht.
func sanitize_line(line: Dictionary) -> Dictionary:
	var event := str(line.get("e", ""))
	if not KEEP.has(event):
		return {}
	var out := {"at": int(line.get("at", 0)), "ms": int(line.get("ms", 0)), "e": event}
	for field in KEEP[event]:
		if line.has(field):
			out[field] = line[field]
	match event:
		"spawn":
			# In der Rohspur heißt der Auswahlgrund `why` — wie die Boss-Erklärung. Draußen
			# heißt er `pick`, damit der Endpunkt `why` überall abweisen kann.
			if line.get("why") is Dictionary:
				out["pick"] = line["why"]
		"answer":
			out.merge(_typed_features(str(line.get("text", "")), line))
		"boss_answer":
			var words := _evaluator.tokens(str(line.get("text", "")))
			out["words"] = words.size()
	return out


## Was sich über eine getippte Antwort sagen lässt, ohne sie zu zeigen.
func _typed_features(text: String, line: Dictionary) -> Dictionary:
	var typed := _compare_form(text)
	var features := {"len": typed.length(), "words": _evaluator.tokens(text).size()}
	# Mit Treffer zählt die eigene Aufgabe; ohne die Monster, die auf dem Feld standen.
	var ids: Array = [line["id"]] if not str(line.get("id", "")).is_empty() else line.get("field", [])
	var best := -1
	var near := ""
	for id in ids:
		for answer in _answers.get(str(id), []):
			var d := distance(typed, _compare_form(str(answer)))
			if best < 0 or d < best:
				best = d
				near = str(id)
	if best >= 0:
		features["dist"] = best
		if str(line.get("id", "")).is_empty():
			features["near"] = near
	return features


func _compare_form(s: String) -> String:
	return " ".join(_evaluator.tokens(s)).substr(0, MAX_COMPARE)


## Levenshtein-Abstand (Einfügen, Löschen, Ersetzen je 1).
static func distance(a: String, b: String) -> int:
	if a == b:
		return 0
	if a.is_empty():
		return b.length()
	if b.is_empty():
		return a.length()
	var previous := PackedInt32Array()
	previous.resize(b.length() + 1)
	for j in b.length() + 1:
		previous[j] = j
	for i in a.length():
		var row := PackedInt32Array()
		row.resize(b.length() + 1)
		row[0] = i + 1
		for j in b.length():
			var cost := 0 if a[i] == b[j] else 1
			row[j + 1] = mini(mini(row[j] + 1, previous[j + 1] + 1), previous[j] + cost)
		previous = row
	return previous[b.length()]


## [at, ms] einer Zeile — die Marke, an der der Cursor steht.
static func mark_of(line: Dictionary) -> Array:
	return [int(line.get("at", 0)), int(line.get("ms", 0))]


## Liegt `mark` nach `after`? `ms` zählt ab Programmstart und springt bei einem Neustart
## zurück, deshalb entscheidet zuerst die Sekunde.
static func is_after(mark: Array, after: Array) -> bool:
	if int(mark[0]) != int(after[0]):
		return int(mark[0]) > int(after[0])
	return int(mark[1]) > int(after[1])


## Alle Zeilen einer Spurdatei; unlesbare fallen still heraus.
static func read_lines(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var text := FileAccess.get_file_as_string(path)
	for part in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(part)
		if parsed is Dictionary:
			out.append(parsed)
	return out
