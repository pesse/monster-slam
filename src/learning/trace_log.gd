extends Node
## Ereignis-Protokoll für die Fehlersuche (Autoload `TraceLog`).
##
## Die vierte Ebene unter den drei vorhandenen: `PlayerProgress` hält den Lernstand JE
## AUFGABE, `GameState` den Zustand DES LAUFENDEN LAUFS, `SessionLog` eine Zeile JE LAUF —
## alles Summen. Hier stehen die Rohdaten: welches Lexem wann erschienen ist, was getippt
## wurde und wie es beurteilt wurde. Daraus lässt sich jede Frage nachträglich beantworten,
## ohne dass ein System dafür mitzählt.
##
## Drei Regeln, die beim nächsten Umbau zählen:
##
## 1. **Das Protokoll hängt NUR am EventBus und wirkt nie zurück.** Es liest, es schreibt,
##    es entscheidet nichts. Ein Fehler hier darf kein Spiel kosten — deshalb auch kein
##    push_error, sondern eine Warnung und Stille.
## 2. **Felder kommen dazu, sie werden nicht umbenannt.** Eine Zeile von gestern muss
##    lesbar bleiben; dieselbe Regel wie bei den Content-Packs und aus demselben Grund.
## 3. **Das Protokoll bleibt auf diesem Rechner.** Es enthält getippte Kindertexte und
##    Lemmata aus geschütztem Material. Der Melde-Rückkanal kennt Ids, dieses Protokoll
##    kennt Wörter — die Grenze ist der Punkt, nicht ein Versehen.
##
## Persistenz: JSON Lines unter user://logs/<player_id>_trace.jsonl, eine Zeile je
## Ereignis, zwei Generationen (siehe max_bytes). Geschrieben wird sofort und mit flush():
## ein Protokoll, das den Absturz nicht überlebt, erklärt den Absturz nicht.

const LOG_DIR := "user://logs"

## Ab dieser Größe rückt die Datei auf <profil>_trace.1.jsonl und wird neu begonnen. Als
## `var` und nicht als Konstante, damit ein Test das Rollen prüfen kann, ohne 2 MB zu
## schreiben.
var max_bytes: int = 2 * 1024 * 1024

var player_id: String = "default"
## Aus, solange UserSettings es sagt. Ohne Autoload (Test, Werkbank) ist es an.
var enabled: bool = true

## Quelle der Confidence-Werte; im Autoload PlayerProgress, im Test nichts (siehe
## _confidence). Wird vor dem Einhängen gesetzt.
var progress: Node = null

var _file: FileAccess = null


func _ready() -> void:
	player_id = UserSettings.active_profile()
	enabled = UserSettings.trace_enabled() and not _under_test()
	progress = PlayerProgress
	UserSettings.active_profile_changed.connect(switch_to)
	EventBus.run_started.connect(note_run_start)
	EventBus.run_ended.connect(note_run_end)
	EventBus.wave_started.connect(func(wave_id): note_wave_start(wave_id))
	EventBus.wave_cleared.connect(func(wave_id): note_wave_clear(wave_id))
	EventBus.wave_fast_resolved.connect(note_fast_resolve)
	EventBus.monster_spawned.connect(func(_monster, task): note_spawn(task))
	EventBus.answer_judged.connect(note_answer)
	EventBus.monster_reached_fortress.connect(func(_monster, task, damage): note_leak(task, damage))
	EventBus.task_mastered.connect(note_task_mastered)
	EventBus.lexeme_mastered.connect(note_lexeme_mastered)
	EventBus.boss_started.connect(note_boss_start)
	EventBus.boss_answer_judged.connect(note_boss_answer)
	EventBus.boss_answer_explained.connect(note_boss_explained)
	EventBus.boss_ended.connect(note_boss_end)


func _exit_tree() -> void:
	_close()


# --- Erfassung ----------------------------------------------------------------
#
# Öffentliche Methoden, die die Signal-Handler oben nur weiterreichen: so ist das Protokoll
# ohne EventBus und ohne Szene prüfbar (dasselbe Muster wie SessionLog).

func note_run_start() -> void:
	_write({"e": "run_start", "profile": player_id})


func note_run_end(summary: Dictionary = {}) -> void:
	_write({
		"e": "run_end",
		"wave_reached": int(summary.get("wave_reached", 0)),
		"difficulty": int(summary.get("difficulty_last", 0)),
		"won": bool(summary.get("last_wave_won", false)),
	})


func note_boss_start(boss_id: String) -> void:
	_write({"e": "boss_start", "boss": boss_id})


## Eine Antwort im Bosskampf. `stage` sagt, wer geurteilt hat (card oder model) — genau
## das, was man beim Nachsehen eines Modellurteils wissen will.
func note_boss_answer(sentence_id: String, text: String, result: Dictionary) -> void:
	_write({
		"e": "boss_answer", "id": sentence_id, "text": text,
		"hit": bool(result.get("hit", false)),
		"q": snappedf(float(result.get("quality", 0.0)), 0.01),
		"stage": str(result.get("stage", "")),
		"sure": bool(result.get("sure", false)),
	})


func note_boss_explained(sentence_id: String, explanation: String) -> void:
	_write({"e": "boss_explained", "id": sentence_id, "why": explanation})


func note_boss_end(boss_id: String, won: bool) -> void:
	_write({"e": "boss_end", "boss": boss_id, "won": won})


func note_wave_start(wave_id: String) -> void:
	_write({
		"e": "wave_start", "wave": wave_id,
		"hp": GameState.fortress_health, "armor": GameState.fortress_armor,
	})


func note_wave_clear(wave_id: String) -> void:
	_write({"e": "wave_clear", "wave": wave_id, "hp": GameState.fortress_health})


## Der Rest der Welle wird vorgespult. Die leak-Zeilen danach bleiben, wie sie sind —
## vorgespult sind sie daran zu erkennen, dass sie hinter dieser Zeile stehen.
func note_fast_resolve(unspawned: int, on_field: int) -> void:
	_write({
		"e": "fast_resolve", "wave": GameState.current_wave,
		"unspawned": unspawned, "on_field": on_field,
	})


## Ein Lexem erscheint. Die Confidence wird hier GELESEN und nicht durchgereicht: zum
## Spawn-Zeitpunkt steht sie noch auf dem Wert vor der Antwort, in der answer-Zeile auf dem
## danach. Zwei Zeilen ergeben das Vorher/Nachher — keine zweite Buchführung.
func note_spawn(task: Dictionary) -> void:
	var id := str(task.get("learnable_id", ""))
	_write({
		"e": "spawn", "id": id,
		"lex": str(task.get("source_id", "")),
		"type": str(task.get("task_type", "")),
		"dir": str(task.get("direction", "")),
		"prompt": str(task.get("prompt", "")),
		"answers": task.get("accepted_answers", []),
		"conf": _confidence(id, float(task.get("initial_confidence", -1.0))),
		"diff": int(task.get("difficulty", 0)),
	})


## Eine abgeschickte Antwort samt Urteil — auch die, die auf kein Monster passte. Genau
## dafür gibt es das Protokoll: `id` ist dann leer und `field` nennt, was auf dem Feld
## stand, als die Antwort abgewiesen wurde.
func note_answer(text: String, verdict: Dictionary) -> void:
	var id := str(verdict.get("learnable_id", ""))
	var line := {
		"e": "answer", "text": text,
		"hit": bool(verdict.get("matched", false)),
		"full": bool(verdict.get("complete", false)),
		"id": id,
		"rt": int(verdict.get("response_time_ms", 0)),
		"field": verdict.get("candidates", []),
	}
	if not id.is_empty():
		line["conf"] = _confidence(id, -1.0)
	var canonical := str(verdict.get("canonical", ""))
	if not canonical.is_empty():
		line["canonical"] = canonical
	_write(line)


## Ein Monster ist durchgekommen. Prompt und Lösungen stehen schon in der spawn-Zeile;
## sie stehen hier trotzdem, weil diese Zeile allein gelesen wird, wenn jemand nach einem
## Wort greppt.
func note_leak(task: Dictionary, damage: int) -> void:
	_write({
		"e": "leak",
		"id": str(task.get("learnable_id", "")),
		"lex": str(task.get("source_id", "")),
		"prompt": str(task.get("prompt", "")),
		"answers": task.get("accepted_answers", []),
		"dmg": damage,
	})


## Eine Aufgabe ist zum ersten Mal gemeistert (Issue #23). Steht direkt hinter der
## answer-Zeile, die es geschafft hat — auch wenn die Feier dazu ausfiel.
func note_task_mastered(task_id: String) -> void:
	_write({"e": "mastered", "id": task_id})


## Ein Wort sitzt zum ersten Mal in allen Richtungen.
func note_lexeme_mastered(lexeme_id: String) -> void:
	_write({"e": "word_mastered", "lex": lexeme_id})


# --- Schalter und Profil ------------------------------------------------------

## Läuft gerade die Testsuite? Dann schweigt das Autoload. Andere Suiten feuern
## EventBus-Signale (Wellenstart, durchgelassenes Monster) und schrieben damit erfundene
## Zeilen in die ECHTE Spur des Spielers — user:// ist projektübergreifend dasselbe
## Verzeichnis, und die Datei des aktiven Profils gehört ihm. Dieselbe Regel wie das
## zz-Profil bei Wallet und PlayerLevel, nur dass hier das Autoload schreibt und nicht der
## Test. Geprüft wird das Protokoll auf einer eigenen Instanz (tests/trace_log_test.gd).
func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("GdUnitCmdTool"):
			return true
	return false


## Schaltet das Protokoll um. Aus heißt: keine offene Datei und keine neue Zeile — eine
## abgeschaltete Aufzeichnung, die die Datei weiter offen hält, ist keine.
func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value
	if not enabled:
		_close()


## Wechselt das Profil: die alte Datei zu, die neue beim nächsten Schreiben auf.
func switch_to(id: String) -> void:
	_close()
	player_id = id


func path() -> String:
	return "%s/%s_trace.jsonl" % [LOG_DIR, player_id]


## Die vorige Generation. Mehr als diese beiden gibt es nicht: ein Protokoll, das den
## Rechner vollschreibt, schaltet man ab, und dann hilft es niemandem.
func previous_path() -> String:
	return "%s/%s_trace.1.jsonl" % [LOG_DIR, player_id]


## Bytes, die das Protokoll dieses Profils belegt (beide Generationen).
func size_bytes() -> int:
	if _file != null:
		_file.flush()
	var total := 0
	for p in [path(), previous_path()]:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				total += int(f.get_length())
				f.close()
	return total


## Die letzten `limit` Zeilen dieses Profils, älteste zuerst — für die Ansicht im Reiter
## „Protokoll". Gelesen wird nur das ENDE jeder Datei (`tail_bytes`), nicht die ganzen
## 2 MB: wer nachsieht, will wissen, was eben passiert ist. Reicht die laufende Generation
## nicht, kommt das Ende der vorigen davor. Eine Zeile, die sich nicht lesen lässt, fällt
## still heraus — die Ansicht ist ein Leser, und ein Leser bricht an einer Zeile nicht ab.
func recent(limit: int = 200, tail_bytes: int = 96 * 1024) -> Array:
	if _file != null:
		_file.flush()
	var lines := _tail_lines(path(), tail_bytes)
	if lines.size() < limit:
		lines = _tail_lines(previous_path(), tail_bytes) + lines
	if lines.size() > limit:
		lines = lines.slice(lines.size() - limit)
	return lines


func _tail_lines(p: String, tail_bytes: int) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(p):
		return out
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return out
	var length := int(f.get_length())
	var start := maxi(0, length - tail_bytes)
	f.seek(start)
	var bytes := f.get_buffer(length - start)
	f.close()
	# Mitten in der Datei begonnen: die erste Zeile ist abgeschnitten und fällt weg — schon
	# als BYTES, denn der Schnitt kann in einem Umlaut liegen, und ein halbes UTF-8-Zeichen
	# meldet der Decoder als Fehler.
	if start > 0:
		var newline := bytes.find(10)
		bytes = PackedByteArray() if newline < 0 else bytes.slice(newline + 1)
	for part in bytes.get_string_from_utf8().split("\n", false):
		var parsed: Variant = JSON.parse_string(part)
		if parsed is Dictionary:
			out.append(parsed)
	return out


## Löscht beide Generationen. Die offene Datei wird vorher geschlossen, sonst schriebe der
## nächste Eintrag in eine Datei, die es nicht mehr gibt.
func clear() -> void:
	_close()
	DirAccess.remove_absolute(path())
	DirAccess.remove_absolute(previous_path())


# --- Persistenz ---------------------------------------------------------------

## Confidence einer Aufgabe. `progress` ist nur gesetzt, wenn das Protokoll als Autoload
## läuft — ein Test hängt hier nichts ein und bekommt den mitgelieferten Prior. Auf drei
## Stellen gerundet: eine Spur soll lesbar sein, und 0.4375000000000001 ist sie nicht.
func _confidence(id: String, fallback: float) -> float:
	if progress == null or id.is_empty():
		return snappedf(fallback, 0.001)
	return snappedf(float(progress.confidence(id)), 0.001)


func _write(line: Dictionary) -> void:
	if not enabled:
		return
	if not _open():
		return
	# Zeit und Art voran, dann der Rest in der Reihenfolge, in der die note_*-Methode ihn
	# aufgeschrieben hat: `sort_keys` steht bei JSON.stringify auf true und machte aus
	# jeder Zeile ein Alphabet, in dem "answers" vor "e" steht. Eine Spur wird gelesen.
	var out := {
		"at": int(Time.get_unix_time_from_system()),
		"ms": Time.get_ticks_msec(),
	}
	out.merge(line)
	_file.store_line(JSON.stringify(out, "", false))
	# Sofort auf die Platte: der Absturz, den das Protokoll erklären soll, kommt ohne
	# Vorwarnung. Ein paar Zeilen je Sekunde kosten das nicht.
	_file.flush()
	if _file.get_length() >= max_bytes:
		_roll()


func _open() -> bool:
	if _file != null and _file.is_open():
		return true
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var p := path()
	# READ_WRITE hängt an, WRITE legt an — FileAccess kennt kein "append or create".
	_file = FileAccess.open(p, FileAccess.READ_WRITE) if FileAccess.file_exists(p) \
			else FileAccess.open(p, FileAccess.WRITE)
	if _file == null:
		push_warning("TraceLog: konnte '%s' nicht schreiben" % p)
		return false
	_file.seek_end()
	return true


func _roll() -> void:
	_close()
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return
	if dir.file_exists(previous_path().get_file()):
		dir.remove(previous_path().get_file())
	dir.rename(path().get_file(), previous_path().get_file())


func _close() -> void:
	if _file != null:
		if _file.is_open():
			_file.close()
		_file = null
