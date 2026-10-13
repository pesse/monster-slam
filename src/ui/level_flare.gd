class_name LevelFlare
extends Control
## Aufleuchten des Level-Badges im Kampf-HUD beim Aufstieg (Material gold_glow.gdshader).
## process_mode ALWAYS, damit es auch während der Meister-Feier leuchtet.

## Nachglühen des Badges (s).
const GLOW_S := 1.3
## Sprung: Größe (Faktor) und Dauer hinauf (s).
const POP_SCALE := 1.45
const POP_S := 0.12
## Dauer zurück auf die Ausgangsgröße (s).
const SETTLE_S := 0.5
## Verzögerung, bevor das Glühen abklingt (s).
const GLOW_DELAY_S := 0.25

## Das Badge, das aufleuchtet: ein Geschwister, kein Kind, sonst träfe sein Sprung auch die
## Partikel. Sein Material trägt den Shader mit `glow`.
@export var badge: Control

var _tween: Tween


## Ein Aufstieg: alle Partikel zünden, das Badge leuchtet. Ein zweiter Aufruf, während der
## erste noch glüht, fängt von vorn an.
func play() -> void:
	for particles in _all_particles():
		_emit(particles)
	_pulse()


## Vorwärmen (FxWarmup): zündet jedes Partikelsystem einmal. Danach cool_down().
func warm_up() -> void:
	for particles in _all_particles():
		_emit(particles)


func cool_down() -> void:
	for particles in _all_particles():
		particles.emitting = false


func _all_particles() -> Array[GPUParticles2D]:
	var found: Array[GPUParticles2D] = []
	for node in find_children("*", "GPUParticles2D", true, false):
		found.append(node as GPUParticles2D)
	return found


func _emit(particles: GPUParticles2D) -> void:
	particles.restart()
	particles.emitting = true


func _pulse() -> void:
	if badge == null:
		return
	if _tween != null:
		_tween.kill()
	badge.pivot_offset = badge.size / 2.0
	badge.scale = Vector2.ONE
	var glow := badge.material as ShaderMaterial
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(badge, "scale", Vector2.ONE * POP_SCALE, POP_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(badge, "scale", Vector2.ONE, SETTLE_S).set_delay(POP_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if glow != null:
		glow.set_shader_parameter(&"glow", 1.0)
		_tween.tween_property(glow, "shader_parameter/glow", 0.0, GLOW_S).set_delay(GLOW_DELAY_S) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
