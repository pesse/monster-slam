extends CanvasLayer
## Die Einblendung eines Erfolgs unten rechts wie bei Steam (Autoload `AchievementToast`,
## ADR 0029): kommt auf `EventBus.achievement_unlocked`, überall im Spiel, und hält nichts an.
## Mehrere stellen sich an; ist die Schlange einmal lang (nachgetragene Erfolge), steht bis zu
## ihrem Ende jede kürzer.

## Standzeit einer Einblendung (s), bei mindestens FAST_FROM wartenden die kürzere.
const SHOW_S := 4.0
const FAST_S := 1.5
const FAST_FROM := 3
## Von unten Hereingleiten und Ausblenden (s), Weg des Gleitens (px).
const SLIDE_S := 0.25
const FADE_S := 0.3
const SLIDE_PX := 48.0
## Ebene beim Vorwärmen: unter dem Schleier (SceneZoom, Ebene 100). Bei gleicher Ebene
## entscheidet der Index unter dem jeweiligen Elternknoten, und der Autoload hängt woanders.
const WARM_LAYER := 99

## Eine Einblendung beginnt (für Tests und Werkbänke).
signal shown(id: String)

var _queue: Array[String] = []
var _playing := false
var _start_queued := false

@onready var _top_layer := layer
@onready var _card: Control = %Card
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _body: Label = %Body


func _ready() -> void:
	_card.visible = false
	EventBus.achievement_unlocked.connect(announce)


## Startet am Frame-Ende, damit alles aus demselben Frame schon in der Schlange steht.
func announce(id: String) -> void:
	_queue.append(id)
	if not _playing and not _start_queued:
		_start_queued = true
		_start.call_deferred()


func _start() -> void:
	_start_queued = false
	if not _playing:
		_run()


func is_busy() -> bool:
	return _playing or not _queue.is_empty()


## Vorwärmen (FxWarmup): Schriften der Einblendung einmal zeigen, ohne Klang. Danach cool_down().
func warm_up() -> void:
	if is_busy():
		return
	_icon.texture = Achievements.icon(Achievements.HIDDEN_ICON)
	_title.text = FxWarmup.GLYPHS
	_body.text = FxWarmup.GLYPHS
	layer = WARM_LAYER
	_card.modulate.a = 1.0
	_card.visible = true


func cool_down() -> void:
	layer = _top_layer
	if not is_busy():
		_card.visible = false


func _run() -> void:
	_playing = true
	var languages := Achievements.languages()
	var fast := false
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		var entry := Achievements.find(languages, id)
		if entry.is_empty():
			continue
		_icon.texture = Achievements.icon(entry)
		_title.text = str(entry["title"])
		_body.text = str(entry["body"])
		fast = fast or _queue.size() + 1 >= FAST_FROM
		await _play(FAST_S if fast else SHOW_S)
		shown.emit(id)
	_playing = false


func _play(hold_s: float) -> void:
	Sfx.play(&"badge_earned")
	_card.visible = true
	# Erst messen, dann von unten hereingleiten.
	await get_tree().process_frame
	var rest := _card.position
	_card.position.y = rest.y + SLIDE_PX
	_card.modulate.a = 0.0
	var tween := create_tween().set_ignore_time_scale().set_parallel()
	tween.tween_property(_card, "position:y", rest.y, SLIDE_S) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, SLIDE_S)
	await tween.finished
	await get_tree().create_timer(hold_s, true, false, true).timeout
	tween = create_tween().set_ignore_time_scale()
	tween.tween_property(_card, "modulate:a", 0.0, FADE_S)
	await tween.finished
	_card.visible = false
	_card.position = rest
