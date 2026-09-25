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

signal started(duration_ms: int)
signal finished()

enum Kind { NONE, TASK, WORD }

const TASK_MS := 1200
const WORD_MS := 2000
## Die zweite Funkenwelle der Wort-Feier kommt so viel später, die Glut steigt so lange,
## die Blitze zucken so lange (alles ms).
const WORD_GLITTER_DELAY_MS := 350
const WORD_EMBERS_MS := 1300
const WORD_LIGHTNING_MS := 900

var _pending: Kind = Kind.NONE
var _pending_id: String = ""
var _flush_queued: bool = false
var _playing: bool = false
## Wartende Feiern als [Kind, id], älteste zuerst.
var _queue_list: Array = []

@onready var _flash: ColorRect = $Flash
@onready var _origin: Control = $Origin
@onready var _embers: GPUParticles2D = $Bottom/WordEmbers
@onready var _glitter: GPUParticles2D = $Origin/WordGlitter
@onready var _lightning: Lightning = $Origin/Lightning
@onready var _content: Control = $Content
@onready var _headline: Label = %Headline
@onready var _detail: Label = %Detail


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


func _flush() -> void:
	_flush_queued = false
	var kind := _pending
	var id := _pending_id
	_pending = Kind.NONE
	_pending_id = ""
	if kind == Kind.NONE:
		return
	_queue_list.append([kind, id])
	if not _playing:
		_run()


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
	visible = true
	_fire(big)
	Sfx.play(&"word_mastered" if big else &"task_mastered")
	_pop_in(duration)
	started.emit(duration)
	await _wait(duration)


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


## „englisch ↔ deutsch", oder leer, wenn das Lexem nicht geladen ist.
func _word_label(lexeme_id: String) -> String:
	var lex := ContentRegistry.get_entry("lexemes", lexeme_id)
	if lex.is_empty():
		return ""
	return "%s ↔ %s" % [lex.get("lemma_en", ""), lex.get("lemma_de", "")]


func _pop_in(duration_ms: int) -> void:
	_content.pivot_offset = _content.size / 2.0
	_content.scale = Vector2.ONE * 0.4
	_content.modulate = Color(1, 1, 1, 0)
	var seconds := duration_ms / 1000.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_content, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_content, "modulate:a", 1.0, 0.15)
	tw.chain().tween_property(_content, "modulate:a", 0.0, 0.3).set_delay(seconds - 0.3 - 0.3)
