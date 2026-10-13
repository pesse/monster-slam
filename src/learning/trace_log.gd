extends Node
## Ereignis-Protokoll für die Fehlersuche (Autoload `TraceLog`): Rohdaten je Ereignis
## (Lexem erschienen, Antwort getippt und beurteilt). Hängt nur am EventBus, wirkt nie
## zurück; Felder kommen dazu, werden nie umbenannt; hinaus geht nur `TraceSanitizer`
## (CONVENTIONS, ADR 0021). Ein Fehler hier warnt nur.
## Persistenz: JSON Lines unter user://logs/<player_id>_trace.jsonl, sofort mit flush().

const LOG_DIR := "user://logs"

## Ab dieser Größe (Bytes) rückt die Datei auf <profil>_trace.1.jsonl und wird neu
## begonnen. Eine `var`, damit ein Test sie senken kann.
var max_bytes: int = 2 * 1024 * 1024

var player_id: String = "default"
## Aus, solange UserSettings es sagt. Ohne Autoload (Test, Werkbank) ist es an.
var enabled: bool = true

## Quelle der Confidence-Werte; im Autoload PlayerProgress, im Test null.
var progress: Node = null

var _file: FileAccess = null


func _ready() -> void:
	player_id = UserSettings.active_profile()
	enabled = UserSettings.trace_enabled() and not _under_test()
	progress = PlayerProgress
	UserSettings.active_profile_changed.connect(switch_to)
	EventBus.run_started.connect(note_run_start)
	EventBus.run_ended.connect(note_run_end)
	EventBus.run_suspended.connect(note_run_suspended)
	EventBus.run_resumed.connect(note_run_resumed)
	EventBus.wave_started.connect(func(wave_id): note_wave_start(wave_id))
	EventBus.wave_cleared.connect(func(wave_id): note_wave_clear(wave_id))
	EventBus.wave_fast_resolved.connect(note_fast_resolve)
	EventBus.monster_spawned.connect(func(_monster, task): note_spawn(task))
	EventBus.answer_judged.connect(note_answer)
	EventBus.monster_reached_fortress.connect(func(_monster, task, damage): note_leak(task, damage))
	EventBus.monster_catapulted.connect(note_catapult)
	EventBus.monster_struck.connect(note_struck)
	EventBus.spell_activated.connect(note_spell)
	EventBus.task_mastered.connect(note_task_mastered)
	EventBus.lexeme_mastered.connect(note_lexeme_mastered)
	EventBus.badge_earned.connect(note_badge)
	EventBus.boss_started.connect(note_boss_start)
	EventBus.boss_answer_judged.connect(note_boss_answer)
	EventBus.boss_answer_explained.connect(note_boss_explained)
	EventBus.boss_ended.connect(note_boss_end)
	EventBus.boss_won.connect(note_boss_won)
	EventBus.save_refused.connect(note_save_refused)
	EventBus.save_restored.connect(note_save_restored)
	EventBus.save_damaged.connect(note_save_damaged)


func _exit_tree() -> void:
	_close()


# --- Erfassung ----------------------------------------------------------------
#
# Öffentlich, damit das Protokoll ohne EventBus prüfbar ist.

func note_run_start() -> void:
	_write({"e": "run_start", "profile": player_id})


func note_run_end(summary: Dictionary = {}) -> void:
	_write({
		"e": "run_end",
		"wave_reached": int(summary.get("wave_reached", 0)),
		"difficulty": int(summary.get("difficulty_last", 0)),
		"won": bool(summary.get("last_wave_won", false)),
	})


## Gerastet (ADR 0020): mit dieser Welle kann der Lauf auf der Karte weitergehen.
## `remaining` (nur mitten in der Welle) sind die Monster, die von ihr noch kommen.
func note_run_suspended(next_wave: int, remaining := 0) -> void:
	var line := {"e": "run_suspend", "next_wave": next_wave, "hp": GameState.fortress_health}
	if remaining > 0:
		line["remaining"] = remaining
	_write(line)


## Ein begonnener Lauf geht weiter; `since` ist der Beginn des ursprünglichen Laufs,
## `added` (nur wenn erweitert) die Orte, die dazukamen.
func note_run_resumed(next_wave: int, run_started_at: int, added: Array = []) -> void:
	var line := {"e": "run_resume", "next_wave": next_wave, "since": run_started_at,
			"hp": GameState.fortress_health}
	if not added.is_empty():
		line["added"] = added
	_write(line)


func note_boss_start(boss_id: String) -> void:
	_write({"e": "boss_start", "boss": boss_id})


## Eine Antwort im Bosskampf. `stage` sagt, wer geurteilt hat (card oder model).
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


func note_boss_won(boss_id: String, unit_key: String) -> void:
	_write({"e": "boss_won", "boss": boss_id, "unit": unit_key})


func note_wave_start(wave_id: String) -> void:
	_write({
		"e": "wave_start", "wave": wave_id,
		"hp": GameState.fortress_health, "armor": GameState.fortress_armor,
	})


func note_wave_clear(wave_id: String) -> void:
	_write({"e": "wave_clear", "wave": wave_id, "hp": GameState.fortress_health})


## Der Rest der Welle wird vorgespult; die leak-Zeilen danach gehören dazu.
func note_fast_resolve(unspawned: int, on_field: int) -> void:
	_write({
		"e": "fast_resolve", "wave": GameState.current_wave,
		"unspawned": unspawned, "on_field": on_field,
	})


## Ein Lexem erscheint. `conf` ist der Wert vor der Antwort, die answer-Zeile trägt den danach.
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
		# Warum dieses Wort (WaveGenerator.pick_reason): Gruppe, Stelle, Größe des Pools.
		"why": task.get("pick", {}),
	})


## Eine abgeschickte Antwort samt Urteil. Passte sie auf kein Monster, ist `id` leer und
## `field` nennt, was auf dem Feld stand.
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
	# Nur nachsichtig getroffen (ADR 0008); das Feld steht nur dann.
	if not bool(verdict.get("exact", true)):
		line["exact"] = false
	var canonical := str(verdict.get("canonical", ""))
	if not canonical.is_empty():
		line["canonical"] = canonical
	# Ich-Sicht: was auf dem Feld stand, aber nicht im Bild war.
	var unseen: Array = verdict.get("unseen", [])
	if not unseen.is_empty():
		line["unseen"] = unseen
	_write(line)


## Ein Monster ist durchgekommen. Prompt und Lösungen wiederholt, damit die Zeile allein lesbar ist.
func note_leak(task: Dictionary, damage: int) -> void:
	_write({
		"e": "leak",
		"id": str(task.get("learnable_id", "")),
		"lex": str(task.get("source_id", "")),
		"prompt": str(task.get("prompt", "")),
		"answers": task.get("accepted_answers", []),
		"dmg": damage,
	})


## Das Wachkatapult hat ein Monster abgeschossen, dessen Aufgabe gemeistert war.
func note_catapult(task: Dictionary) -> void:
	var id := str(task.get("learnable_id", ""))
	_write({
		"e": "catapult", "id": id,
		"lex": str(task.get("source_id", "")),
		"prompt": str(task.get("prompt", "")),
		"conf": _confidence(id, float(task.get("initial_confidence", -1.0))),
	})


## Der Donnerschlag (ADR 0014) hat ein Monster vom Feld genommen.
func note_struck(task: Dictionary) -> void:
	_write({
		"e": "struck", "id": str(task.get("learnable_id", "")),
		"lex": str(task.get("source_id", "")),
		"prompt": str(task.get("prompt", "")),
	})


## Ein Zauber aus dem Vorrat hat gewirkt (ADR 0014). Steht vor seinen Folgen (struck-Zeilen).
func note_spell(spell_id: String) -> void:
	_write({"e": "spell", "spell": spell_id, "wave": GameState.current_wave})


## Eine Aufgabe ist zum ersten Mal gemeistert; steht hinter der auslösenden answer-Zeile.
func note_task_mastered(task_id: String) -> void:
	_write({"e": "mastered", "id": task_id})


func note_lexeme_mastered(lexeme_id: String) -> void:
	_write({"e": "word_mastered", "lex": lexeme_id})


## Eine Plakette ist verdient. Steht hinter der auslösenden answer-Zeile.
func note_badge(id: String, tier: int) -> void:
	_write({"e": "badge", "id": id, "tier": tier})


## Spielstand (ADR 0024). `part` ist die Endung der Datei („_level“), ohne den Profilnamen
## davor; `reason` nennt Feld und Werte („total_xp würde von 32500 auf 10 sinken“).
func note_save_refused(file: String, reason: String) -> void:
	_write({"e": "save_refused", "part": file.get_basename().trim_prefix(player_id), "reason": reason})


func note_save_restored(parts: Array, backup_at: int) -> void:
	_write({"e": "save_restored", "parts": parts, "backup_at": backup_at})


func note_save_damaged(parts: Array) -> void:
	_write({"e": "save_damaged", "parts": parts})


# --- Schalter und Profil ------------------------------------------------------

## Läuft gerade die Testsuite? Dann schweigt das Autoload, sonst schrieben Signale aus
## anderen Tests in die Spur des aktiven Entwicklungsprofils.
func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("GdUnitCmdTool"):
			return true
	return false


## Schaltet das Protokoll um. Aus heißt: keine offene Datei und keine neue Zeile.
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


## Die vorige Generation; mehr als zwei gibt es nicht.
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


## Die letzten `limit` Zeilen dieses Profils, älteste zuerst. Gelesen werden nur die
## letzten `tail_bytes` jeder Generation; unlesbare Zeilen fallen still heraus.
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
	# Die erste, abgeschnittene Zeile schon als Bytes verwerfen (bis "\n" = 10): der Schnitt
	# kann mitten in einem UTF-8-Zeichen liegen.
	if start > 0:
		var newline := bytes.find(10)
		bytes = PackedByteArray() if newline < 0 else bytes.slice(newline + 1)
	for part in bytes.get_string_from_utf8().split("\n", false):
		var parsed: Variant = JSON.parse_string(part)
		if parsed is Dictionary:
			out.append(parsed)
	return out


## Löscht beide Generationen; schließt vorher die offene Datei.
func clear() -> void:
	_close()
	DirAccess.remove_absolute(path())
	DirAccess.remove_absolute(previous_path())


# --- Persistenz ---------------------------------------------------------------

## Confidence einer Aufgabe, auf drei Stellen gerundet; ohne `progress` der `fallback`.
func _confidence(id: String, fallback: float) -> float:
	if progress == null or id.is_empty():
		return snappedf(fallback, 0.001)
	return snappedf(float(progress.confidence(id)), 0.001)


func _write(line: Dictionary) -> void:
	if not enabled:
		return
	if not _open():
		return
	# Zeit voran, dann die Felder in der Reihenfolge der note_*-Methode (sort_keys aus).
	var out := {
		"at": int(Time.get_unix_time_from_system()),
		"ms": Time.get_ticks_msec(),
	}
	out.merge(line)
	_file.store_line(JSON.stringify(out, "", false))
	# Sofort auf die Platte, damit die Spur einen Absturz überlebt.
	_file.flush()
	if _file.get_length() >= max_bytes:
		_roll()


func _open() -> bool:
	if _file != null and _file.is_open():
		return true
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var p := path()
	# FileAccess kennt kein „append or create“: READ_WRITE hängt an, WRITE legt an.
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
