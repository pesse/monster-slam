extends PanelContainer
## Löst nach dem Wellenende die durchgelassenen Vokabeln auf: zeigt sie als Karten-
## Karussell (immer EINE Karte sichtbar) mit "Wort -> korrekte Übersetzung", inkl.
## aller alternativen Antworten. Beim ersten Durchlauf läuft eine automatische
## Animation (Karte einwischen -> Lösung aufdecken -> 3 s halten -> zur nächsten
## wischen); danach kann der Spieler mit Pfeilen frei blättern und mit "Weiter" zum
## Statistik-Screen gehen.
##
## Baut sein Layout — wie wave_stats/DebugPanel — komplett im Code auf. Alle inter-
## aktiven Controls setzen focus_mode=FOCUS_NONE, sonst reißt die Antwort-LineEdit
## (die sich per _process den Fokus zurückholt) den Klick weg.

const CORRECT_COLOR := Color(0.3, 1.0, 0.45)   # grün, wie FLASH_CORRECT im WaveRunner
const ALT_COLOR := Color(0.6, 0.85, 0.65)      # gedämpftes Grün für Alternativen
const HOLD_TIME := 3.0                          # Standzeit pro Karte im Auto-Durchlauf
const READ_QUESTION_TIME := 0.5                 # kurze Pause auf der Frage vor dem Aufdecken
const SWIPE_TIME := 0.35
const REVEAL_TIME := 0.3
const STAGE_MIN := Vector2(600, 200)

var _items: Array = []
var _index: int = 0

var _title: Label
var _stage: Control
var _progress: Label
var _prev_btn: Button
var _next_btn: Button
var _continue_btn: Button
var _current_card: Control = null


func _ready() -> void:
	# Bildschirm-zentriert, wächst zur Inhaltsgröße.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.text = "Durchgelassen — die richtigen Antworten"
	root.add_child(_title)

	# Karten-Bühne: schneidet den Ein-/Auswisch am Rand ab, nimmt genau eine Karte auf.
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE_MIN
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_progress)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	root.add_child(nav)

	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.pressed.connect(func(): _goto(_index - 1))
	nav.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "▶"
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.pressed.connect(func(): _goto(_index + 1))
	nav.add_child(_next_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "✔ Weiter"
	_continue_btn.focus_mode = Control.FOCUS_NONE
	root.add_child(_continue_btn)


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
	var card := _build_card(_items[index], revealed)
	card.size = Vector2(w, _stage.size.y)
	card.position = Vector2(w if offscreen else 0.0, 0.0)
	_stage.add_child(card)
	_current_card = card


func _build_card(item: Dictionary, revealed: bool) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	# Wortart-Kennzeichnung in der Palettenfarbe (wie Monster-Outline & Legende).
	var type_key := String(item.get("lexeme_type", ""))
	if not type_key.is_empty():
		var type_label := Label.new()
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 18)
		type_label.add_theme_color_override("font_color", WordTypePalette.color_for(type_key))
		type_label.text = String(WordTypePalette.LABELS.get(type_key, type_key))
		box.add_child(type_label)

	var prompt := Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 30)
	prompt.text = String(item.get("prompt", ""))
	box.add_child(prompt)

	# Lösungsteil (primäre Antwort + Alternativen). Startet je nach `revealed` sichtbar
	# oder verdeckt; _reveal_solution() blendet ihn ein.
	var sol := VBoxContainer.new()
	sol.alignment = BoxContainer.ALIGNMENT_CENTER
	sol.add_theme_constant_override("separation", 4)
	sol.modulate.a = 1.0 if revealed else 0.0
	box.add_child(sol)

	var answers: Array = item.get("answers", [])
	var arrow := Label.new()
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 22)
	arrow.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	arrow.text = "↓"
	sol.add_child(arrow)

	var primary := Label.new()
	primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary.add_theme_font_size_override("font_size", 30)
	primary.add_theme_color_override("font_color", CORRECT_COLOR)
	primary.text = String(answers[0]) if not answers.is_empty() else "—"
	sol.add_child(primary)

	if answers.size() > 1:
		var alt := Label.new()
		alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alt.add_theme_font_size_override("font_size", 20)
		alt.add_theme_color_override("font_color", ALT_COLOR)
		alt.text = "auch: %s" % ", ".join(_rest_as_strings(answers))
		sol.add_child(alt)

	card.set_meta("sol", sol)
	return card


## answers[1..] als String-Array (join braucht String-Elemente).
func _rest_as_strings(answers: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, answers.size()):
		out.append(String(answers[i]))
	return out


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
	var sol := _current_card.get_meta("sol") as CanvasItem
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
