extends Node
## Autoload `FreezeWatch`: schreibt ins Log, wenn der Hauptthread länger als `limit_ms` keinen
## Frame schafft, und wann er wieder läuft. Ein eigener Thread prüft den Herzschlag aus
## `_process`; die Meldung nennt die letzten Kampfereignisse. `printerr` leert das Log sofort,
## damit die Zeilen auch ein danach abgeschossenes Spiel überstehen.

## Ab dieser Stillstandsdauer wird gemeldet (Millisekunden).
const LIMIT_MS := 5000
## Prüfabstand des Wächter-Threads (Millisekunden); begrenzt auch die Wartezeit beim Beenden.
const POLL_MS := 250
## So viele der letzten Ereignisse nennt eine Meldung.
const CRUMBS := 8

var limit_ms := LIMIT_MS
## Empfängt jede Meldezeile; wird auf dem Wächter-Thread aufgerufen.
var sink: Callable = func(line: String) -> void: printerr(line)

var _mutex := Mutex.new()
var _thread: Thread = null
var _running := false
var _beat_ms := 0
var _beat_frame := 0
var _crumbs := PackedStringArray()
var _scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # auch in der Pause schlägt das Herz
	# Kopflos (Tests, Werkzeuge) und am Haltepunkt des Debuggers steht der Thread gewollt.
	if DisplayServer.get_name() == "headless" or EngineDebugger.is_active():
		set_process(false)
		return
	_listen()
	start()


func _process(_delta: float) -> void:
	beat()
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		note("Szene %s" % (scene.scene_file_path.get_file() if scene != null else "-"))


func _exit_tree() -> void:
	stop()


func start() -> void:
	if _thread != null:
		return
	beat()
	_running = true
	_thread = Thread.new()
	_thread.start(_watch)


func stop() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_running = false
	_mutex.unlock()
	_thread.wait_to_finish()
	_thread = null


## Herzschlag des Hauptthreads.
func beat() -> void:
	_mutex.lock()
	_beat_ms = Time.get_ticks_msec()
	_beat_frame = Engine.get_process_frames()
	_mutex.unlock()


## Merkt sich ein Ereignis für die nächste Meldung. Keine getippten Texte, keine Lemmata.
func note(text: String) -> void:
	_mutex.lock()
	_crumbs.append("%s %s" % [Time.get_time_string_from_system(), text])
	if _crumbs.size() > CRUMBS:
		_crumbs.remove_at(0)
	_mutex.unlock()


## Die Meldezeile für einen Stillstand von `stalled_ms`, "" ohne Meldung. `reported`: ob der
## laufende Stillstand schon gemeldet ist.
static func report(stalled_ms: int, reported: bool, limit: int, frame: int,
		crumbs: PackedStringArray) -> String:
	if not reported and stalled_ms >= limit:
		return "[FREEZE] Hauptthread steht seit %.1f s (Frame %d). Zuletzt: %s" % [
				stalled_ms / 1000.0, frame, " | ".join(crumbs) if not crumbs.is_empty() else "-"]
	if reported and stalled_ms < limit:
		return "[FREEZE] Hauptthread läuft wieder"
	return ""


func _watch() -> void:
	var reported := false
	var stalled_since := 0
	while true:
		OS.delay_msec(POLL_MS)
		_mutex.lock()
		var running := _running
		var beat_ms := _beat_ms
		var frame := _beat_frame
		var crumbs := _crumbs.duplicate()
		_mutex.unlock()
		if not running:
			return
		var stalled := Time.get_ticks_msec() - beat_ms
		var line := report(stalled, reported, limit_ms, frame, crumbs)
		if line.is_empty():
			continue
		if not reported:
			stalled_since = beat_ms
		else:
			line += " nach %.1f s." % ((beat_ms - stalled_since) / 1000.0)
		reported = not reported
		sink.call(line)


func _listen() -> void:
	EventBus.run_started.connect(func() -> void: note("Lauf beginnt"))
	EventBus.run_ended.connect(func(_s: Dictionary) -> void: note("Lauf endet"))
	EventBus.run_suspended.connect(func(_w: int, _r: int) -> void: note("Rast"))
	EventBus.wave_started.connect(func(id: String) -> void: note("Welle %s" % id))
	EventBus.wave_cleared.connect(func(_id: String) -> void: note("Welle geschafft"))
	EventBus.monster_spawned.connect(func(_m: Dictionary, task: Dictionary) -> void:
			note("Monster %s" % str(task.get("type", "?"))))
	EventBus.answer_submitted.connect(func(_t: String) -> void: note("Antwort"))
	EventBus.monster_defeated.connect(func(_m: Dictionary, _c: bool) -> void: note("Treffer"))
	EventBus.monster_reached_fortress.connect(func(_m: Dictionary, _t: Dictionary, _d: int) -> void:
			note("Monster an der Festung"))
	EventBus.spell_activated.connect(func(id: String) -> void: note("Zauber %s" % id))
	EventBus.boss_started.connect(func(id: String) -> void: note("Boss %s" % id))
	EventBus.boss_ended.connect(func(_id: String, _w: bool) -> void: note("Boss endet"))
