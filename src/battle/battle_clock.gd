class_name BattleClock
extends Node
## Misst die Kampfzeit einer Welle oder eines Bosskampfs: Echtzeit zwischen `start` und
## `stop`, ohne angehaltenen Baum (Pause, Feier) und ohne `hold`. Zeitlupe zählt voll.
## `stop` meldet sie über `EventBus.battle_timed`; das Verlassen der Szene stoppt auch.

## "wave" oder die Id des Bosses.
var kind := "wave"
## Ob `stop` meldet; aus für Tests.
var emit_events := true

var _running := false
var _held := false
var _started_at := 0
## Beginn des laufenden Abschnitts (Ticks, ms); -1 = gerade keiner.
var _since := -1
var _ms := 0


func _init() -> void:
	# Nur so kommen NOTIFICATION_PAUSED und _UNPAUSED an, auch unter einem ALWAYS-Elternteil.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_close()
		NOTIFICATION_UNPAUSED:
			_open()
		NOTIFICATION_EXIT_TREE:
			stop()


## Beginnt eine neue Messung; eine laufende wird vorher gemeldet.
func start() -> void:
	stop()
	_running = true
	_ms = 0
	_started_at = int(Time.get_unix_time_from_system())
	_open()


## Beendet die Messung und meldet sie; ohne laufende ein No-op.
func stop() -> void:
	if not _running:
		return
	_close()
	_running = false
	if emit_events:
		EventBus.battle_timed.emit(kind, _started_at, _ms)


## Hält die Uhr an (Vorwärmen hinter dem Schleier), ohne die Messung zu beenden.
func hold(on: bool) -> void:
	_held = on
	if on:
		_close()
	else:
		_open()


func is_running() -> bool:
	return _running


## Bisher gemessene Zeit (ms), der laufende Abschnitt eingeschlossen.
func elapsed_ms() -> int:
	return _ms + (Time.get_ticks_msec() - _since if _since >= 0 else 0)


func _open() -> void:
	if not _running or _held or _since >= 0:
		return
	if is_inside_tree() and not can_process():
		return
	_since = Time.get_ticks_msec()


func _close() -> void:
	if _since < 0:
		return
	_ms += Time.get_ticks_msec() - _since
	_since = -1
