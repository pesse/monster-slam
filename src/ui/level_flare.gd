class_name LevelFlare
extends Control
## Goldenes Aufleuchten des Level-Badges im Kampf-HUD beim Aufstieg — die kleine Schwester
## der Meister-Feier (MasteryCelebration): dieselben weichen Partikel, aber am Badge statt
## in der Bildmitte, ohne Schrift und ohne Pause. Der Kampf läuft weiter.
##
## Die Effekte sind GPUParticles2D-Knoten in level_flare.tscn (dort im Editor einstellen).
## Die Szene liegt im HUD VOR dem Badge: Schein, Ring und Strahlen stehen dahinter, Funken
## und Glitzer (z_index 1) davor. Das Badge selbst leuchtet golden (gold_glow.gdshader, sein
## Material in hud.tscn) und springt kurz an.
## process_mode ALWAYS: ein Aufstieg während der Meister-Feier (Baum-Pause) leuchtet trotzdem.

## So lange (s) glüht das Badge nach, bis es wieder seine eigene Farbe hat.
const GLOW_S := 1.3
const POP_SCALE := 1.45
const POP_S := 0.12

## Das Badge, das aufleuchtet (Geschwister im HUD, kein Kind: sein Pop träfe sonst auch die
## Partikel). Sein Material trägt den Shader mit `glow`.
@export var badge: Control

var _tween: Tween


## Ein Aufstieg: alle Partikel zünden, das Badge leuchtet. Ein zweiter Aufruf, während der
## erste noch glüht, fängt von vorn an.
func play() -> void:
	for particles in _all_particles():
		_emit(particles)
	_pulse()


## Vorwärmen beim Kampfstart (FxWarmup): zündet jedes Partikelsystem einmal, damit seine
## Shader nicht erst beim ersten Aufstieg entstehen. Danach cool_down().
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
	_tween.tween_property(badge, "scale", Vector2.ONE, 0.5).set_delay(POP_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if glow != null:
		glow.set_shader_parameter(&"glow", 1.0)
		_tween.tween_property(glow, "shader_parameter/glow", 0.0, GLOW_S).set_delay(0.25) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
