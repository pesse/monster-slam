extends Node
## Swoosh beim Ein- und Ausstieg der Tipp-Slow-Motion. Hört nur auf
## EventBus.slow_motion_changed und spielt nur an den Flanken (0 -> >0, >0 -> 0), nicht
## bei jedem Wert der Rampe.
##
## Hängt als Kind unter SlowMotion: Godot meldet Kindern das Verlassen des Baums vor dem
## Elternteil, so ist die Verbindung schon getrennt, wenn SlowMotion._exit_tree() die
## letzte 0 meldet (`test_leaving_the_tree_stays_silent`).

var _active := false


# Paarweise am Baum-Ein-/Austritt, damit ein zweites Einhängen wieder verbindet.
func _enter_tree() -> void:
	EventBus.slow_motion_changed.connect(_on_slow_motion_changed)


func _exit_tree() -> void:
	EventBus.slow_motion_changed.disconnect(_on_slow_motion_changed)
	_active = false


## `intensity`: 0.0 = Normaltempo, 1.0 = volle Slow-Mo (siehe SlowMotion).
func _on_slow_motion_changed(intensity: float) -> void:
	var active := intensity > 0.0
	if active == _active:
		return
	_active = active
	Sfx.play(&"slow_mo_in" if active else &"slow_mo_out")
