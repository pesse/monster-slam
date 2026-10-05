class_name SlowMotion
extends Node
## Nimmt langsam Tippenden den Zeitdruck: solange die Eingabe offen ist (EventBus.typing_started
## bis typing_stopped), läuft die Zeit langsamer. Über Engine.time_scale, damit Bewegung,
## Animationen, Spawn-Timer und Tweens gleichmäßig mitgehen. Die Rampe rechnet in Echtzeit —
## mit `delta` würde sie sich selbst mitverlangsamen.

## Grundwerte OHNE Skills. Wie in GameState stehen die Konstanten für den Stand ohne
## Bäume; gerechnet wird mit den Feldern darunter, die `apply_skills()` anhebt.
const BASE_FACTOR := 0.15
const RAMP_PER_SEC := 6.0   ## Faktoränderung pro Echtzeit-Sekunde
## Tempo beim „Schnell auflösen" (WaveRunner). Lebt HIER, weil time_scale diesem Knoten
## gehört: jede fremde Änderung zöge _process wieder auf 1 zurück. Höher als 8 ruckelt —
## die Physik holt höchstens 8 Schritte je Frame nach, darüber wird nur jeder Schritt länger.
## Das Ziel wird trotzdem angesteuert (Monster.gd prüft das Ziel mit >=, kein Schritt springt
## darüber), nur eben mit gröberen Schritten.
const FAST_FORWARD_FACTOR := 16.0
## Eigene, flachere Rampe: das Feld soll sichtbar Fahrt aufnehmen (gut 3 s bis 16×), statt
## schlagartig loszurasen — beim Tippen dagegen muss die Zeitlupe sofort greifen.
const FAST_FORWARD_RAMP_PER_SEC := 5.0

## Der effektive Wert des laufenden Laufs: Grundwert plus Boni des Zeitwandler-Baums.
## Alles, was rechnet, liest DIESEN — nie die Konstante.
var factor: float = BASE_FACTOR

var _last_tick_ms: int = 0
var _intensity: float = 0.0
var _fast_forward: bool = false
## Die Eingabe ist offen: Zeitlupe bis stop().
var _held_open: bool = false


func _ready() -> void:
	_last_tick_ms = Time.get_ticks_msec()
	EventBus.typing_stopped.connect(stop)
	EventBus.typing_started.connect(hold_open)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _last_tick_ms) / 1000.0
	_last_tick_ms = now
	var target := factor if _held_open else 1.0
	var ramp := RAMP_PER_SEC
	if _fast_forward:
		target = FAST_FORWARD_FACTOR
		ramp = FAST_FORWARD_RAMP_PER_SEC
	if Engine.time_scale != target:
		Engine.time_scale = move_toward(Engine.time_scale, target, ramp * real_delta)
		_publish_intensity(inverse_lerp(1.0, factor, Engine.time_scale))


## Nur bei echter Änderung, damit im Normaltempo kein Signal pro Frame läuft.
func _publish_intensity(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _intensity):
		return
	_intensity = clamped
	EventBus.slow_motion_changed.emit(clamped)


## Legt die Boni der gelernten Skills auf den Grundwert: der Zeitwandler vertieft den
## Faktor. Gehört zum Laufbeginn (siehe WaveRunner._ready) und nimmt dasselbe Dictionary wie
## GameState.apply_skills, damit es EINE Quelle der Boni gibt.
##
## Der Faktor wird nach unten geklemmt (SkillTree.MIN_SLOW_FACTOR): time_scale 0 wäre ein
## eingefrorenes Spiel.
func apply_skills(bonuses: Dictionary) -> void:
	factor = clampf(BASE_FACTOR + float(bonuses.get("slow_factor", 0.0)),
			SkillTree.MIN_SLOW_FACTOR, 1.0)


## Spult bis zum nächsten stop() vor — den ruft _finish_wave ohnehin, danach laufen
## Auflösung und Statistik wieder in Normaltempo. Die Rampe bleibt: ein Sprung auf 16×
## sähe aus wie ein Ruckler. Die Vignette bleibt aus, weil _publish_intensity auf 0..1 klemmt.
func fast_forward() -> void:
	_held_open = false
	_fast_forward = true


func is_fast_forwarding() -> bool:
	return _fast_forward


## Zeitlupe ab sofort und ohne Ende, bis stop() — die Eingabe ist offen.
func hold_open() -> void:
	if _fast_forward:
		return
	_held_open = true


## Sofortiges Ende ohne Rampe.
func stop() -> void:
	_held_open = false
	_fast_forward = false
	Engine.time_scale = 1.0
	_publish_intensity(0.0)


## time_scale ist global und darf nicht in Folgeszenen weiterwirken.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_publish_intensity(0.0)
