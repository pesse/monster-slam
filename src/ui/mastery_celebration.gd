class_name MasteryCelebration
extends Control
## Kurze Feier im Kampf, wenn eine Aufgabe oder ein Wort zum ersten Mal gemeistert ist
## (Issue #23). Hängt nur an EventBus.task_mastered / lexeme_mastered und meldet über
## `started`, wie lange sie steht — das Anhalten selbst macht der WaveRunner über die
## Baum-Pause (get_tree().paused). Engine.time_scale bleibt unberührt, es gehört SlowMotion.
##
## Regeln:
## - Schließt eine Antwort Aufgabe UND Wort ab, läuft nur die Wort-Feier. Beide Signale
##   kommen im selben Frame; gesammelt wird bis zum Frame-Ende (call_deferred), dann
##   gewinnt die größere.
## - Jede Meisterung wird gefeiert. Kommt eine während einer Feier, stellt sie sich an und
##   läuft direkt danach; `started` kommt je Feier, `finished` erst, wenn keine mehr wartet.
##
## Die Szene steht auf process_mode ALWAYS: sie läuft, während der Kampf pausiert. Die
## Effekte sind GPUParticles2D-Knoten in mastery_celebration.tscn (dort im Editor
## einstellen); Knoten mit `Task` im Namen gehören zur Aufgaben-, `Word` zur Wort-Feier.
## Nur die Blitze sind ein eigener Knoten (Lightning), das kann ein Partikelsystem nicht.
##
## Plaketten (Badges, Issue #63) laufen durch dieselbe Warteschlange: auch sie halten den
## Kampf kurz an, aber kleiner — eine Medaille, ein Ring und ein paar Funken in ihrer Farbe,
## kein Blitz, kein Bildflash. Sie kommen nach der Meister-Feier derselben Antwort und
## verdrängen keine: jede gemeldete Plakette läuft.

signal started(duration_ms: int)
signal finished()

enum Kind { NONE, TASK, WORD, BADGE }

const TASK_MS := 1200
const WORD_MS := 2000
const BADGE_MS := 1300
## Die zweite Funkenwelle der Wort-Feier kommt so viel später, die Glut steigt so lange,
## die Blitze zucken so lange (alles ms).
const WORD_GLITTER_DELAY_MS := 350
const WORD_EMBERS_MS := 1300
const WORD_LIGHTNING_MS := 900

var _pending: Kind = Kind.NONE
var _pending_id: String = ""
var _flush_queued: bool = false
## Im selben Frame gemeldete Plaketten; sie stellen sich hinter die Meister-Feier.
var _pending_badges: Array = []
var _playing: bool = false
## Wartende Feiern als [Kind, id], älteste zuerst.
var _queue_list: Array = []
## Angehalten (hold): Feiern stellen sich an, starten aber erst mit release(). So kommt das
## Standbild der Schreibweise (SpellingFreeze) vor der Feier derselben Antwort.
var _held: bool = false

@onready var _flash: ColorRect = $Flash
@onready var _origin: Control = $Origin
@onready var _embers: GPUParticles2D = $Bottom/WordEmbers
@onready var _glitter: GPUParticles2D = $Origin/WordGlitter
@onready var _lightning: Lightning = $Origin/Lightning
@onready var _content: Control = $Content
@onready var _headline: Label = %Headline
@onready var _detail: Label = %Detail
@onready var _badge_content: Control = $BadgeContent
@onready var _badge_fx: Node2D = $Origin/BadgeFx
@onready var _plate: BadgePlate = %Plate
@onready var _badge_title: Label = %BadgeTitle
@onready var _badge_detail: Label = %BadgeDetail


func _ready() -> void:
	visible = false
	EventBus.task_mastered.connect(_on_task_mastered)
	EventBus.lexeme_mastered.connect(_on_lexeme_mastered)


func _on_task_mastered(task_id: String) -> void:
	celebrate(Kind.TASK, task_id)


func _on_lexeme_mastered(lexeme_id: String) -> void:
	celebrate(Kind.WORD, lexeme_id)


## Meldet eine Feier an — der Weg der EventBus-Signale, und der des Debug-Panels, das
## feiern will, ohne eine Meisterung in die Spur zu schreiben.
func celebrate(kind: Kind, id: String) -> void:
	if kind > _pending:
		_pending = kind
		_pending_id = id
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## Meldet eine Plakette an (Badges.make). Wie eine Meisterung erst zum Frame-Ende, damit
## die Meister-Feier derselben Antwort vorgeht.
func announce(badge: Dictionary) -> void:
	_pending_badges.append(badge)
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	var kind := _pending
	var id := _pending_id
	_pending = Kind.NONE
	_pending_id = ""
	if kind != Kind.NONE:
		_queue_list.append([kind, id])
	for badge in _pending_badges:
		_queue_list.append([Kind.BADGE, badge])
	_pending_badges.clear()
	if _queue_list.is_empty():
		return
	if not _playing and not _held:
		_run()


## Hält neue Feiern zurück, bis release() kommt.
func hold() -> void:
	_held = true


## Lässt zurückgehaltene Feiern laufen. Startet eine, kommt `started` noch in diesem Aufruf.
func release() -> void:
	_held = false
	if not _playing and not _flush_queued and not _queue_list.is_empty():
		_run()


## Vorwärmen beim Kampfstart (FxWarmup): zündet jedes Partikelsystem und zeigt die Schrift
## der Wort-Feier, damit ihre Shader und Zeichen nicht erst bei der ersten Meisterung
## entstehen. Ohne Klang, ohne `started`, an der Warteschlange vorbei. Danach cool_down().
func warm_up() -> void:
	if is_busy():
		return
	_headline.theme_type_variation = &"CelebrateWord"
	_headline.text = FxWarmup.GLYPHS
	_detail.text = FxWarmup.GLYPHS
	_content.modulate = Color.WHITE
	_content.visible = true
	_badge_title.text = FxWarmup.GLYPHS
	_badge_detail.text = FxWarmup.GLYPHS
	_plate.setup(&"gold", "0123456789")
	_badge_content.modulate = Color.WHITE
	_badge_content.visible = true
	_flash.modulate.a = 0.6
	visible = true
	for particles in _all_particles():
		_emit(particles)
	_lightning.play(size.length() / 2.0, 50)


func cool_down() -> void:
	if is_busy():
		return
	for particles in _all_particles():
		particles.emitting = false
	_flash.modulate.a = 0.0
	visible = false


func _all_particles() -> Array[GPUParticles2D]:
	var found: Array[GPUParticles2D] = []
	for node in find_children("*", "GPUParticles2D", true, false):
		found.append(node as GPUParticles2D)
	return found


## Steht eine Feier an, läuft eine, oder wartet eine? Der WaveRunner hält damit das
## Wellenende zurück: auch das letzte Monster bekommt seine Feier.
func is_busy() -> bool:
	return _playing or _flush_queued or not _queue_list.is_empty()


func is_playing() -> bool:
	return _playing


func _run() -> void:
	_playing = true
	while not _queue_list.is_empty():
		var next: Array = _queue_list.pop_front()
		if next[0] == Kind.BADGE:
			await _play_badge(next[1])
		else:
			await _play(next[0], next[1])
	visible = false
	_playing = false
	finished.emit()


func _play(kind: Kind, id: String) -> void:
	var big := kind == Kind.WORD
	var duration := WORD_MS if big else TASK_MS
	# Inhalt VOR dem Einblenden festlegen: ein sichtbares Overlay in der Bildmitte ändert
	# seine Größe nicht mehr.
	_headline.theme_type_variation = &"CelebrateWord" if big else &"CelebrateTask"
	_headline.text = "Wort gemeistert!" if big else "Aufgabe gemeistert!"
	_detail.text = _word_label(id) if big else TaskResolver.new().describe_learnable(id)
	_content.visible = true
	_badge_content.visible = false
	visible = true
	_fire(big)
	Sfx.play(&"word_mastered" if big else &"task_mastered")
	_pop_in(_content, duration)
	started.emit(duration)
	await _wait(duration)


## Eine Plakette: Medaille, Titel und Detail springen auf, ein Ring und Funken in der Farbe
## der Plakette gehen von der Medaille aus.
func _play_badge(badge: Dictionary) -> void:
	var palette := StringName(badge.get("palette", &"gold"))
	_plate.setup(palette, str(badge.get("mark", "")))
	_badge_title.text = str(badge.get("title", ""))
	_badge_detail.text = str(badge.get("detail", ""))
	_badge_detail.visible = not _badge_detail.text.is_empty()
	_content.visible = false
	_badge_content.visible = true
	visible = true
	Sfx.play(badge.get("sound", &"badge_earned"))
	_pop_in(_badge_content, BADGE_MS)
	started.emit(BADGE_MS)
	# Erst nach dem Layout steht die Medaille dort, wo die Funken herkommen sollen. Gemessen
	# am Stand OHNE das Aufspringen: der Inhalt ist gerade noch klein (_pop_in).
	await get_tree().process_frame
	var medal := _plate.get_global_transform() * (_plate.size * BadgePlate.DISC_CENTER)
	var unscaled := _badge_content.get_global_transform().affine_inverse() * medal
	_badge_fx.global_position = get_global_transform() * (_badge_content.position + unscaled)
	_badge_fx.modulate = BadgePlate.glow(palette)
	for particles in _badge_fx.get_children():
		_emit(particles as GPUParticles2D)
	await _wait(BADGE_MS)


## Echtzeit-Wartezeit, die auch in der Baum-Pause läuft (process_always).
func _wait(ms: int) -> void:
	await get_tree().create_timer(ms / 1000.0, true).timeout


## Zündet die Partikel der Feier. Die zweite Funkenwelle und das Ende der Glut hängen an
## eigenen Timern, damit _play nicht auf sie warten muss.
func _fire(big: bool) -> void:
	var prefix := "Word" if big else "Task"
	for child in _origin.get_children():
		if child is GPUParticles2D and child.name.begins_with(prefix) and child != _glitter:
			_emit(child)
	if not big:
		return
	_flash.modulate.a = 0.6
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	_lightning.play(size.length() / 2.0, WORD_LIGHTNING_MS)
	_embers.emitting = true
	_stop_embers_later()
	_glitter_later()


func _emit(particles: GPUParticles2D) -> void:
	particles.restart()
	particles.emitting = true


func _stop_embers_later() -> void:
	await _wait(WORD_EMBERS_MS)
	_embers.emitting = false


func _glitter_later() -> void:
	await _wait(WORD_GLITTER_DELAY_MS)
	_emit(_glitter)


## „fremdsprachig ↔ deutsch", oder leer, wenn das Lexem nicht geladen ist.
func _word_label(lexeme_id: String) -> String:
	var lex := ContentRegistry.get_entry("lexemes", lexeme_id)
	if lex.is_empty():
		return ""
	return "%s ↔ %s" % [Lexeme.foreign(lex), lex.get("lemma_de", "")]


func _pop_in(content: Control, duration_ms: int) -> void:
	content.pivot_offset = content.size / 2.0
	content.scale = Vector2.ONE * 0.4
	content.modulate = Color(1, 1, 1, 0)
	var seconds := duration_ms / 1000.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(content, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "modulate:a", 1.0, 0.15)
	tw.chain().tween_property(content, "modulate:a", 0.0, 0.3).set_delay(seconds - 0.3 - 0.3)
