class_name Lightning
extends Node2D
## Zuckende Blitze vom Bildrand zur Mitte, für die Wort-Feier (Issue #23). Die Linien sind
## die Line2D-Kinder aus der Szene (Breite, Farbe, Mischung dort einstellen); hier kommt nur
## der Zickzack dazu, BOLT_RESHAPE_HZ-mal je Sekunde neu — so zuckt ein Blitz. Das kann ein
## Partikelsystem nicht, deshalb der eigene Knoten.
##
## Jeder Blitz besteht aus ZWEI aufeinanderliegenden Line2D (breiter Hof, heller Kern);
## die Kinder stehen paarweise in dieser Reihenfolge.

const BOLT_SEGMENTS := 9
const BOLT_JITTER := 0.05
const BOLT_RESHAPE_HZ := 18.0

var _until_ms: int = 0
var _start_ms: int = 0
var _next_shape_ms: int = 0
var _reach: float = 600.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	visible = false
	set_process(false)


## Blitze für `duration_ms`; `reach` = Abstand der Blitzwurzel von der Mitte in px.
func play(reach: float, duration_ms: int) -> void:
	_reach = reach
	_start_ms = Time.get_ticks_msec()
	_until_ms = _start_ms + duration_ms
	_next_shape_ms = 0
	_rng.randomize()
	visible = true
	set_process(true)


func is_running() -> bool:
	return visible


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _until_ms:
		visible = false
		set_process(false)
		return
	# Zum Ende hin schwächer, dazwischen hartes Flackern statt weichem Ausblenden.
	var t := float(now - _start_ms) / float(maxi(1, _until_ms - _start_ms))
	modulate.a = (1.0 - t) * (1.0 if int(t * 24.0) % 4 != 3 else 0.3)
	if now < _next_shape_ms:
		return
	_next_shape_ms = now + int(1000.0 / BOLT_RESHAPE_HZ)
	var bolts := get_child_count() / 2
	for i in bolts:
		var angle := TAU * (float(i) + _rng.randf_range(-0.2, 0.2)) / bolts - PI / 2.0
		var points := _bolt(angle)
		(get_child(i * 2) as Line2D).points = points
		(get_child(i * 2 + 1) as Line2D).points = points


func _bolt(angle: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var points := PackedVector2Array()
	for i in BOLT_SEGMENTS + 1:
		var along := lerpf(1.0, 0.1, float(i) / BOLT_SEGMENTS)
		var jitter := 0.0 if i == 0 or i == BOLT_SEGMENTS else _rng.randf_range(-BOLT_JITTER, BOLT_JITTER)
		points.append((dir * along + side * jitter) * _reach)
	return points
