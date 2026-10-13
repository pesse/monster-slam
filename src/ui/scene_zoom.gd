class_name SceneZoom
extends CanvasLayer
## Zoom zwischen Karte und Kampf (ADR 0006) für Szenen, die keine MapCanvas sind. Ein
## Schleier blendet aus (`reveal`) oder ein (`cover`); die Bewegung darunter macht die Szene
## selbst über `apply(k)`, k von 0 bis 1. Gerechnet nach der Wanduhr mit gedeckeltem Schritt,
## unabhängig von `Engine.time_scale` und langen ersten Frames.

signal finished

## Maßstab der Welt am Anfang von `reveal` und am Ende von `cover`.
const FROM := 0.8

@onready var _veil: ColorRect = $Veil
var _apply := Callable()
var _t := -1.0
var _ease_in := false
var _last_usec := 0


func _ready() -> void:
	set_process(false)


## Kommt aus dem Dunkel: der Schleier geht, `apply` bekommt k = 0 → 1 (langsamer werdend).
func reveal(apply: Callable = Callable()) -> void:
	_start(apply, false)


## Hält den Schleier geschlossen, bis `reveal` kommt (z. B. für FxWarmup).
func hold() -> void:
	_veil.modulate.a = 1.0


## Geht ins Dunkel: der Schleier kommt, `apply` bekommt k = 0 → 1 (schneller werdend).
## Danach kommt `finished` — dann wechselt die Szene.
func cover(apply: Callable = Callable()) -> void:
	_start(apply, true)


func is_running() -> bool:
	return _t >= 0.0


func _start(apply: Callable, ease_in: bool) -> void:
	_apply = apply
	_ease_in = ease_in
	_t = 0.0
	_last_usec = Time.get_ticks_usec()
	_show(0.0)
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var step := (now - _last_usec) / 1000000.0
	_last_usec = now
	advance(step)


## Einen Schritt weiter, `step` in Sekunden, höchstens MapCanvas.MAX_ZOOM_STEP.
func advance(step: float) -> void:
	if _t < 0.0:
		return
	_t = minf(1.0, _t + minf(step, MapCanvas.MAX_ZOOM_STEP) / MapCanvas.ZOOM_FROM_TIME)
	_show(_t)
	if _t >= 1.0:
		_t = -1.0
		set_process(false)
		finished.emit()


func _show(t: float) -> void:
	var k := t * t * t if _ease_in else 1.0 - pow(1.0 - t, 3.0)
	_veil.modulate.a = k if _ease_in else 1.0 - k
	if _apply.is_valid():
		_apply.call(k)
