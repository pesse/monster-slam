class_name SlowMotion
extends Node
## Nimmt langsam Tippenden den Zeitdruck. Über Engine.time_scale, damit Bewegung,
## Animationen, Spawn-Timer und Tweens gleichmäßig mitgehen. Die Haltedauer läuft
## dagegen in Echtzeit — mit `delta` würde sie sich selbst mitverlangsamen.

const FACTOR := 0.15
const HOLD_MS := 1000       ## Haltedauer je Zeichen (Echtzeit)
const RAMP_PER_SEC := 6.0   ## Faktoränderung pro Echtzeit-Sekunde

var _hold_until_ms: int = 0
var _last_tick_ms: int = 0
var _intensity: float = 0.0


func _ready() -> void:
	_last_tick_ms = Time.get_ticks_msec()
	EventBus.typing_activity.connect(_on_typing_activity)
	EventBus.typing_stopped.connect(stop)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _last_tick_ms) / 1000.0
	_last_tick_ms = now
	var target := FACTOR if now < _hold_until_ms else 1.0
	if Engine.time_scale != target:
		Engine.time_scale = move_toward(Engine.time_scale, target, RAMP_PER_SEC * real_delta)
		_publish_intensity(inverse_lerp(1.0, FACTOR, Engine.time_scale))


## Nur bei echter Änderung, damit im Normaltempo kein Signal pro Frame läuft.
func _publish_intensity(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _intensity):
		return
	_intensity = clamped
	EventBus.slow_motion_changed.emit(clamped)


func _on_typing_activity() -> void:
	_hold_until_ms = Time.get_ticks_msec() + HOLD_MS


## Sofortiges Ende ohne Rampe.
func stop() -> void:
	_hold_until_ms = 0
	Engine.time_scale = 1.0
	_publish_intensity(0.0)


## time_scale ist global und darf nicht in Folgeszenen weiterwirken.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_publish_intensity(0.0)
