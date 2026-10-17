class_name Introductions
extends RefCounted
## Neue Aufgaben im Lauf (ADR 0027): welche schon mit Lösung auf dem Schild standen, wie
## viele davon in dieser Welle, und welche nach dem Abtippen ohne Lösung wiederkommen.
## Lebt nur im Lauf; gespeichert wird nichts.

## Eingeführt im Lauf: WaveGenerator.help_key -> true.
var keys := {}
## Spawns mit Lösung in der laufenden Welle.
var in_wave := 0
## Abgetippte Aufgaben: learnable_id -> Spawn-Zähler, ab dem sie wieder dran ist.
var _retests := {}
## Spawns im ganzen Lauf; eine Wiederholung über die Wellengrenze zählt weiter.
var _spawns := 0


func new_wave() -> void:
	in_wave = 0


## Nach jedem Spawn mit dem Plan seiner Aufgabe.
func note_spawn(task: Dictionary) -> void:
	_spawns += 1
	_retests.erase(str(task.get("learnable_id", "")))
	if bool(task.get("help", false)):
		keys[str(task.get("help_key", ""))] = true
		in_wave += 1


## Die Lösung wurde abgetippt: nach WaveGenerator.RETEST_AFTER weiteren Spawns kommt die
## Aufgabe ohne Lösung.
func note_copied(task: Dictionary) -> void:
	_retests[str(task.get("learnable_id", ""))] = _spawns + WaveGenerator.RETEST_AFTER


## Die learnable_ids, deren Wiederholung jetzt fällig ist.
func due() -> Array:
	var out: Array = []
	for id in _retests:
		if _spawns >= int(_retests[id]):
			out.append(id)
	return out
