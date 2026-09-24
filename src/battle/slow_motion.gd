class_name SlowMotion
extends Node
## Nimmt langsam Tippenden den Zeitdruck. Über Engine.time_scale, damit Bewegung,
## Animationen, Spawn-Timer und Tweens gleichmäßig mitgehen. Die Haltedauer läuft
## dagegen in Echtzeit — mit `delta` würde sie sich selbst mitverlangsamen.

## Grundwerte OHNE Skills. Wie in GameState stehen die Konstanten für den Stand ohne
## Bäume; gerechnet wird mit den Feldern darunter, die `apply_skills()` anhebt.
const BASE_FACTOR := 0.15
const BASE_HOLD_MS := 1000  ## Haltedauer je Zeichen (Echtzeit)
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

## Die effektiven Werte des laufenden Laufs: Grundwert plus Boni des Zeitwandler-Baums.
## Alles, was rechnet, liest DIESE beiden — nie die Konstanten.
var factor: float = BASE_FACTOR
var hold_ms: int = BASE_HOLD_MS

var _hold_until_ms: int = 0
var _last_tick_ms: int = 0
var _intensity: float = 0.0
var _fast_forward: bool = false


func _ready() -> void:
	_last_tick_ms = Time.get_ticks_msec()
	EventBus.typing_activity.connect(_on_typing_activity)
	EventBus.typing_stopped.connect(stop)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _last_tick_ms) / 1000.0
	_last_tick_ms = now
	var target := factor if now < _hold_until_ms else 1.0
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


## Legt die Boni der gelernten Skills auf die Grundwerte — der Zeitwandler-Baum verzweigt
## sich genau hier: ein Ast verlängert die Nachwirkung, der andere vertieft den Faktor.
## Gehört zum Laufbeginn (siehe WaveRunner._ready) und nimmt dasselbe Dictionary wie
## GameState.apply_skills, damit es EINE Quelle der Boni gibt.
##
## Der Faktor wird nach unten geklemmt (SkillTree.MIN_SLOW_FACTOR): time_scale 0 wäre ein
## eingefrorenes Spiel, in dem die Haltedauer trotzdem weiterliefe.
func apply_skills(bonuses: Dictionary) -> void:
	factor = clampf(BASE_FACTOR + float(bonuses.get("slow_factor", 0.0)),
			SkillTree.MIN_SLOW_FACTOR, 1.0)
	hold_ms = maxi(0, BASE_HOLD_MS + int(bonuses.get("slow_hold_ms", 0)))


## Spult bis zum nächsten stop() vor — den ruft _finish_wave ohnehin, danach laufen
## Auflösung und Statistik wieder in Normaltempo. Die Rampe bleibt: ein Sprung auf 16×
## sähe aus wie ein Ruckler. Die Vignette bleibt aus, weil _publish_intensity auf 0..1 klemmt.
func fast_forward() -> void:
	_hold_until_ms = 0
	_fast_forward = true


func is_fast_forwarding() -> bool:
	return _fast_forward


func _on_typing_activity() -> void:
	if _fast_forward:
		return
	_hold_until_ms = Time.get_ticks_msec() + hold_ms


## Sofortiges Ende ohne Rampe.
func stop() -> void:
	_hold_until_ms = 0
	_fast_forward = false
	Engine.time_scale = 1.0
	_publish_intensity(0.0)


## time_scale ist global und darf nicht in Folgeszenen weiterwirken.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_publish_intensity(0.0)
