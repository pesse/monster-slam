extends LineEdit
## Texteingabe für Übersetzungen; schickt die Antwort über den EventBus.
## Zwischen zwei Antworten zu: Enter öffnet, das zweite Enter schickt ab, Escape schließt
## (ADR 0016). Offen gehört jede Taste dem Wort, und die Zeitlupe hält. In Godot 4 sind
## Fokus und Editier-Zustand getrennt; `_process` holt den Fokus der offenen Eingabe zurück.

const PLACEHOLDER_OPEN := "Übersetzung eingeben…"
const PLACEHOLDER_CLOSED := "Enter: antworten"
const PLACEHOLDER_CLOSED_WALK := "Enter: antworten · WASD: laufen · Alt: Maus"
const PLACEHOLDER_CLOSED_TAB := "Enter: antworten · Tab: Waffe · Alt: Maus"

## Ich-Sicht: die geschlossene Eingabe nennt auch Laufen und Maus.
var first_person := false:
	set(value):
		first_person = value
		if not _open:
			placeholder_text = _closed_text()

## Ich-Sicht mit zwei gelernten Waffen: die geschlossene Eingabe nennt Tab statt WASD.
var weapon_switch := false:
	set(value):
		weapon_switch = value
		if not _open:
			placeholder_text = _closed_text()

var _open := false


func _ready() -> void:
	keep_editing_on_text_submit = false
	text_submitted.connect(_on_text_submitted)
	text_changed.connect(_on_text_changed)
	# Nach dem Ausblenden fängt die Eingabe zu an; war sie offen, endet auch ihre Zeitlupe.
	visibility_changed.connect(func() -> void:
		if _open:
			EventBus.typing_stopped.emit()
		_set_open(false))
	_set_open(false)


## Tippt der Spieler gerade? Nur dann ist eine Ziffer ein Zeichen und P ein Buchstabe.
func is_typing() -> bool:
	return _open and visible


func _process(_delta: float) -> void:
	# Nur sichtbar zurückholen, sonst klaut die Eingabe anderen Controls den Fokus.
	if visible and _open and not has_focus():
		grab_focus()


## `_input`, weil die geschlossene Eingabe keinen Fokus hat. Das öffnende Enter wird
## verschluckt, sonst schickte die LineEdit ein leeres Feld ab.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not _open and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_set_open(true)
		# Die Zeitlupe beginnt mit dem Öffnen, nicht erst mit dem ersten Buchstaben.
		EventBus.typing_started.emit()
	elif _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		clear()
		EventBus.typing_stopped.emit()
		_set_open(false)


func _set_open(on: bool) -> void:
	_open = on
	editable = on
	placeholder_text = PLACEHOLDER_OPEN if on else _closed_text()
	if not is_inside_tree():
		return
	if on:
		grab_focus()
		edit()
	else:
		release_focus()


func _closed_text() -> String:
	if not first_person:
		return PLACEHOLDER_CLOSED
	return PLACEHOLDER_CLOSED_TAB if weapon_switch else PLACEHOLDER_CLOSED_WALK


## Nur bei nicht-leerem Feld: das clear() nach dem Absenden löst selbst text_changed aus.
func _on_text_changed(new_text: String) -> void:
	if not new_text.is_empty():
		EventBus.typing_activity.emit()


func _on_text_submitted(new_text: String) -> void:
	var answer := new_text.strip_edges()
	# Vor der Auswertung, damit die schon in Normaltempo läuft.
	EventBus.typing_stopped.emit()
	if not answer.is_empty():
		EventBus.answer_submitted.emit(answer)
	clear()
	_set_open(false)
