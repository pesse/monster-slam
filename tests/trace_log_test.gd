extends GdUnitTestSuite
## Ereignis-Protokoll: Zeilenformat, die Falscheingabe, Vorher/Nachher, Rollen, Schalter.
##
## Geprüft wird auf einer EIGENEN TraceLog-Instanz mit eigenem Profil, nicht am Autoload:
## dessen Datei ist die echte Spur des Spielers, und user:// ist projektübergreifend
## dasselbe Verzeichnis. Die Instanz liegt nicht im Szenenbaum, also läuft kein _ready()
## und nichts hängt am EventBus — die öffentlichen note_* sind genau deshalb öffentlich.
##
## GameState ist Autoload und geteilter Zustand (die Wellen-Zeilen lesen HP und Rüstung
## dort) -> vorher und nachher reset().

const TRACE_LOG := preload("res://src/learning/trace_log.gd")
const TEST_PROFILE := "zz-trace-test"
const OTHER_PROFILE := "zz-trace-test-other"

## Eine aufgelöste Aufgabe, wie sie der TaskResolver liefert — erfunden, damit der Test
## nicht am Submodule hängt.
const TASK := {
	"learnable_id": "translate:de_to_en:zz.lex.coral",
	"source_id": "zz.lex.coral",
	"task_type": "translate",
	"direction": "de_to_en",
	"prompt": "Koralle",
	"accepted_answers": ["coral"],
	"difficulty": 2,
	"initial_confidence": 0.3,
}

var _log: Node


func before_test() -> void:
	GameState.reset()
	_log = auto_free(TRACE_LOG.new())
	_log.player_id = TEST_PROFILE
	_remove_files()


func after_test() -> void:
	_log._close()
	GameState.reset()
	_remove_files()


func _remove_files() -> void:
	for profile in [TEST_PROFILE, OTHER_PROFILE]:
		DirAccess.remove_absolute("user://logs/%s_trace.jsonl" % profile)
		DirAccess.remove_absolute("user://logs/%s_trace.1.jsonl" % profile)


## Die geschriebenen Zeilen als Dictionaries. Scheitert das Parsen, ist die Datei keine
## JSON-Lines-Datei mehr — und genau das soll auffallen.
func _lines(path := "") -> Array:
	var p: String = path if not path.is_empty() else _log.path()
	if not FileAccess.file_exists(p):
		return []
	var out: Array = []
	for raw in FileAccess.get_file_as_string(p).split("\n", false):
		var parsed: Variant = JSON.parse_string(raw)
		assert_that(parsed).append_failure_message("keine gültige JSON-Zeile: %s" % raw).is_not_null()
		out.append(parsed)
	return out


func _verdict(matched: bool, id: String, candidates: Array) -> Dictionary:
	return {
		"matched": matched, "complete": matched, "learnable_id": id, "source_id": "",
		"response_time_ms": 1200 if matched else 0, "canonical": "", "candidates": candidates,
	}


# --- Zeilenformat -------------------------------------------------------------

func test_every_event_becomes_one_line() -> void:
	_log.note_run_start()
	_log.note_wave_start("procedural_1")
	_log.note_spawn(TASK)
	_log.note_answer("coral", _verdict(true, TASK["learnable_id"], [TASK["learnable_id"]]))
	_log.note_wave_clear("procedural_1")
	_log.note_run_end({"wave_reached": 2, "difficulty_last": 3, "last_wave_won": true})
	var kinds: Array = []
	for line in _lines():
		kinds.append(line["e"])
	assert_array(kinds).is_equal(
			["run_start", "wave_start", "spawn", "answer", "wave_clear", "run_end"])


## Die dokumentierten Schlüssel der spawn-Zeile — ohne sie ist die Spur nicht auswertbar.
func test_the_spawn_line_carries_the_lexeme() -> void:
	_log.note_spawn(TASK)
	var line: Dictionary = _lines()[0]
	for key in ["at", "ms", "e", "id", "lex", "type", "dir", "prompt", "answers", "conf", "diff"]:
		assert_bool(line.has(key)).append_failure_message("spawn-Zeile ohne '%s'" % key).is_true()
	assert_str(line["id"]).is_equal(TASK["learnable_id"])
	assert_str(line["lex"]).is_equal("zz.lex.coral")
	assert_str(line["prompt"]).is_equal("Koralle")
	assert_array(line["answers"]).is_equal(["coral"])


## Der Grund, aus dem es das Protokoll gibt: eine Eingabe, die auf kein Monster passte,
## wurde vorher restlos verworfen. Sie steht jetzt da — mit leerer id und dem, was auf dem
## Feld stand, als sie abgewiesen wurde.
func test_a_rejected_answer_is_logged_with_the_field() -> void:
	_log.note_answer("korall", _verdict(false, "", [TASK["learnable_id"]]))
	var line: Dictionary = _lines()[0]
	assert_str(line["e"]).is_equal("answer")
	assert_str(line["text"]).is_equal("korall")
	assert_bool(line["hit"]).is_false()
	assert_str(line["id"]).is_equal("")
	assert_array(line["field"]).is_equal([TASK["learnable_id"]])


func test_a_leaked_monster_names_its_word() -> void:
	_log.note_leak(TASK, 10)
	var line: Dictionary = _lines()[0]
	assert_str(line["e"]).is_equal("leak")
	assert_str(line["id"]).is_equal(TASK["learnable_id"])
	assert_str(line["prompt"]).is_equal("Koralle")
	# JSON kennt nur Zahlen: was als 10 in der Datei steht, kommt als 10.0 zurück.
	assert_int(int(line["dmg"])).is_equal(10)


## Vorher/Nachher steht in ZWEI Zeilen und nicht in einem mitgeführten Feld: die
## spawn-Zeile trägt die Confidence vor der Antwort, die answer-Zeile die danach.
func test_the_confidence_comes_from_the_progress_and_changes_between_the_lines() -> void:
	var progress: Node = auto_free(preload("res://src/learning/player_progress.gd").new())
	progress.player_id = TEST_PROFILE
	_log.progress = progress
	_log.note_spawn(TASK)
	progress.record(TASK["learnable_id"], true, 900, 0.3)
	_log.note_answer("coral", _verdict(true, TASK["learnable_id"], []))
	var lines: Array = _lines()
	assert_float(lines[0]["conf"]).is_less(float(lines[1]["conf"]))


## Ohne PlayerProgress (Test, Werkbank) fällt die Confidence auf den mitgelieferten Prior
## zurück, statt die Zeile scheitern zu lassen.
func test_without_a_progress_the_prior_stands_in() -> void:
	_log.note_spawn(TASK)
	assert_float(_lines()[0]["conf"]).is_equal_approx(0.3, 0.001)


# --- Rollen, Schalter, Profil -------------------------------------------------

func test_the_file_rolls_into_a_second_generation() -> void:
	_log.max_bytes = 400
	for i in 20:
		_log.note_leak(TASK, i)
	assert_bool(FileAccess.file_exists(_log.previous_path())) \
			.append_failure_message("keine vorige Generation angelegt").is_true()
	assert_bool(FileAccess.file_exists(_log.path())).is_true()
	# Die vorige Generation ist voll, die neue fängt wieder klein an.
	assert_int(_lines(_log.path()).size()).is_less(_lines(_log.previous_path()).size())


## Genau zwei Generationen: die dritte Runde überschreibt die vorige, sie legt keine an.
func test_only_two_generations_survive() -> void:
	_log.max_bytes = 200
	for i in 60:
		_log.note_leak(TASK, i)
	assert_bool(FileAccess.file_exists("user://logs/%s_trace.2.jsonl" % TEST_PROFILE)).is_false()


func test_a_switched_off_log_writes_nothing() -> void:
	_log.set_enabled(false)
	_log.note_run_start()
	_log.note_spawn(TASK)
	assert_bool(FileAccess.file_exists(_log.path())) \
			.append_failure_message("abgeschaltet und trotzdem geschrieben").is_false()


func test_switching_the_profile_starts_a_new_file() -> void:
	_log.note_run_start()
	_log.switch_to(OTHER_PROFILE)
	_log.note_run_start()
	assert_str(_log.path()).contains(OTHER_PROFILE)
	assert_int(_lines("user://logs/%s_trace.jsonl" % TEST_PROFILE).size()).is_equal(1)
	assert_int(_lines("user://logs/%s_trace.jsonl" % OTHER_PROFILE).size()).is_equal(1)


func test_clear_removes_both_generations() -> void:
	_log.max_bytes = 300
	for i in 20:
		_log.note_leak(TASK, i)
	_log.clear()
	assert_bool(FileAccess.file_exists(_log.path())).is_false()
	assert_bool(FileAccess.file_exists(_log.previous_path())).is_false()
	assert_int(_log.size_bytes()).is_equal(0)


## Nach dem Leeren schreibt der nächste Eintrag wieder — eine geleerte Spur ist kein
## abgeschaltetes Protokoll.
func test_writing_continues_after_clear() -> void:
	_log.note_run_start()
	_log.clear()
	_log.note_run_start()
	assert_int(_lines().size()).is_equal(1)


# --- Die Nahtstellen am EventBus ----------------------------------------------

## Das Protokoll hängt nur am EventBus. Ändert jemand dort eine Signatur, hört es still
## auf zu schreiben — der Handler wird nie gerufen, und nichts wird rot. Deshalb steht die
## Signatur hier als Behauptung.
func test_the_event_bus_carries_the_arguments_the_log_needs() -> void:
	var expected := {
		"monster_spawned": ["monster", "task"],
		"monster_reached_fortress": ["monster", "task", "damage"],
		"answer_judged": ["text", "verdict"],
	}
	var found := {}
	for entry in EventBus.get_signal_list():
		var sig_name := str(entry["name"])
		if not expected.has(sig_name):
			continue
		var names: Array = []
		for arg in entry["args"]:
			names.append(str(arg["name"]))
		found[sig_name] = names
	assert_dict(found).is_equal(expected)
