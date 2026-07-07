extends PanelContainer
## Löst nach dem Wellenende die durchgelassenen Vokabeln auf: zeigt sie als Karten-
## Karussell (immer EINE Karte sichtbar) mit "Wort -> korrekte Übersetzung", inkl.
## aller alternativen Antworten. Beim ersten Durchlauf läuft eine automatische
## Animation (Karte einwischen -> Lösung aufdecken -> 3 s halten -> zur nächsten
## wischen); danach kann der Spieler mit Pfeilen frei blättern und mit "Weiter" zum
## Statistik-Screen gehen.
##
## Die statische Hülle (Titel, Bühne, Fortschritt, Nav-Buttons) liegt in leak_reveal.tscn;
## hier bleibt nur das dynamische Karten-Karussell. Alle interaktiven Controls haben
## focus_mode=FOCUS_NONE (in der Szene gesetzt), sonst reißt die Antwort-LineEdit
## (die sich per _process den Fokus zurückholt) den Klick weg.

const CARD_SCENE := preload("res://scenes/ui/reveal_card.tscn")
const HOLD_TIME := 3.0                          # Standzeit pro Karte im Auto-Durchlauf
const READ_QUESTION_TIME := 0.5                 # kurze Pause auf der Frage vor dem Aufdecken
const SWIPE_TIME := 0.35
const REVEAL_TIME := 0.3

var _items: Array = []
var _index: int = 0

@onready var _stage: Control = %Stage
@onready var _progress: Label = %Progress
@onready var _prev_btn: Button = %PrevBtn
@onready var _next_btn: Button = %NextBtn
@onready var _continue_btn: Button = %ContinueBtn
var _current_card: Control = null


func _ready() -> void:
	_prev_btn.pressed.connect(func(): _goto(_index - 1))
	_next_btn.pressed.connect(func(): _goto(_index + 1))


## Awaitbar: zeigt das Karussell, spielt einmal automatisch durch und kehrt erst
## zurück, wenn der Spieler "Weiter" klickt. Erwartet je Eintrag:
## {"prompt": String, "answers": Array}.
func play(leaked: Array) -> void:
	if leaked.is_empty():
		return
	_items = leaked
	_index = 0
	visible = true
	_prev_btn.disabled = true
	_next_btn.disabled = true
	_continue_btn.disabled = true
	# Ein Frame, damit die Bühne ihre echte Größe hat (für die Wisch-Distanz).
	await get_tree().process_frame

	await _autoplay()

	_continue_btn.disabled = false
	_update_nav()
	await _continue_btn.pressed
	hide_reveal()


func hide_reveal() -> void:
	visible = false
	if is_instance_valid(_current_card):
		_current_card.queue_free()
		_current_card = null


## Spielt alle Karten einmal automatisch durch.
func _autoplay() -> void:
	for i in _items.size():
		_index = i
		_update_progress()
		_place_card(i, false, true)         # Frage sichtbar, Lösung verdeckt, off-screen rechts
		await _swipe_in()
		await get_tree().create_timer(READ_QUESTION_TIME).timeout
		await _reveal_solution()
		await get_tree().create_timer(HOLD_TIME).timeout
		if i < _items.size() - 1:
			await _swipe_out()


## Baut die Karte für `index` und hängt sie in die Bühne. `offscreen` platziert sie
## rechts außerhalb (für den Einwisch), sonst zentriert bei x=0.
func _place_card(index: int, revealed: bool, offscreen: bool) -> void:
	if is_instance_valid(_current_card):
		_current_card.queue_free()
	var w := _stage.size.x
	var card := CARD_SCENE.instantiate() as RevealCard
	_stage.add_child(card)                 # zuerst in den Baum -> onready-Knoten stehen
	card.setup(_items[index], revealed)
	card.size = Vector2(w, _stage.size.y)
	card.position = Vector2(w if offscreen else 0.0, 0.0)
	_current_card = card


func _swipe_in() -> void:
	var tw := create_tween()
	tw.tween_property(_current_card, "position:x", 0.0, SWIPE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _swipe_out() -> void:
	var card := _current_card
	var tw := create_tween()
	tw.tween_property(card, "position:x", -_stage.size.x, SWIPE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func _reveal_solution() -> void:
	if not is_instance_valid(_current_card):
		return
	var sol := (_current_card as RevealCard).solution()
	sol.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(sol, "modulate:a", 1.0, REVEAL_TIME)
	await tw.finished


## Manuelle Navigation per Pfeil: springt zur Karte, vollständig aufgelöst.
func _goto(index: int) -> void:
	_index = clampi(index, 0, _items.size() - 1)
	_place_card(_index, true, false)
	_update_nav()


func _update_nav() -> void:
	_prev_btn.disabled = _index <= 0
	_next_btn.disabled = _index >= _items.size() - 1
	_update_progress()


func _update_progress() -> void:
	_progress.text = "Karte %d / %d" % [_index + 1, _items.size()]
