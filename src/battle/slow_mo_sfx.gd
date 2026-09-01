extends Node
## Swoosh beim Ein- und Ausstieg der Tipp-Slow-Motion. Hört wie die Vignette nur auf
## EventBus.slow_motion_changed und kennt weder Eingabe noch Kampf.
##
## Aus der gemeldeten Intensität werden die beiden FLANKEN herausgefiltert: 0 -> >0 ist
## der Einstieg, >0 -> 0 der Ausstieg. Ohne das liefe der Swoosh im Takt der Rampe statt
## einmal je Ereignis — SlowMotion meldet während des Übergangs jeden Frame einen Wert.
##
## Tippt der Spieler während des Ausrampens weiter, erreicht die Intensität nie 0; dann
## gibt es bewusst KEINEN zweiten Einstiegs-Swoosh, weil die Slow-Motion aus Spielersicht
## durchgehend lief.
##
## Der Node hängt als KIND unter SlowMotion, und das ist kein Zufall: dessen _exit_tree()
## meldet beim Szenenwechsel noch eine 0, was sonst einen Ausstiegs-Swoosh ins Menü hinein
## spielen würde. Godot benachrichtigt Kinder VOR dem Elternteil über das Verlassen des
## Baums — hier ist die Verbindung zu dem Zeitpunkt schon getrennt. Der Test
## `test_leaving_the_tree_stays_silent` hält diese Reihenfolge fest.

var _active := false


# An-/Abmelden paarweise am Baum-Ein-/Austritt statt in _ready(): so bleibt der Node auch
# dann korrekt verdrahtet, wenn er ein zweites Mal in den Baum gehängt wird.
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
