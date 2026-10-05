extends LineEdit
## Texteingabe für Übersetzungen. Bei Enter wird die Antwort entkoppelt über den
## EventBus verschickt; die Kampf-Logik entscheidet, ob sie passt.
##
## Eine Eingabe für beide Sichten (ADR 0016): zwischen zwei Antworten ist sie zu, Enter
## öffnet sie, das zweite Enter schickt ab und schließt, Escape schließt ohne abzuschicken.
## Solange sie offen ist, gehört jede Taste dem Wort — auch Ziffern und P; zu sind die
## Ziffern Zauber und P die Pause (WaveRunner), in der Ich-Sicht die Buchstaben das Laufen.
## Solange sie offen ist, hält die Zeitlupe (typing_started bis typing_stopped). Gesperrt
## und umbeschriftet statt ausgeblendet — das Feld steht in der Bildmitte und behält seine
## Größe.
##
## Wichtig: In Godot 4 sind "Fokus" und "Editier-Zustand" getrennt. mouse_filter=IGNORE
## auf den Welt-ColorRects verhindert Fokusklau, und der _process-Guard holt den Fokus der
## offenen Eingabe im Zweifel zurück.

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

## Ich-Sicht mit zwei gelernten Waffen: die geschlossene Eingabe nennt auch Tab. Dafür
## fällt WASD weg — mit allen vier passt es nicht in das Feld, und Laufen kennt man, bevor
## man eine zweite Waffe hat.
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
	# Taucht die Eingabe nach einer Pause wieder auf (Rückfrage, Wellenende), fängt sie
	# zu an: sonst stünde der Spieler nach „Abbrechen" mit offenem Feld da. Offen
	# verschwunden heißt: auch die Zeitlupe, die das Öffnen gestartet hat, endet.
	visibility_changed.connect(func() -> void:
		if _open:
			EventBus.typing_stopped.emit()
		_set_open(false))
	_set_open(false)


## Tippt der Spieler gerade? Nur dann ist eine Ziffer ein Zeichen und P ein Buchstabe.
func is_typing() -> bool:
	return _open and visible


func _process(_delta: float) -> void:
	# Nur zurückholen, wenn sichtbar — sonst würde die (unsichtbare) Kampfeingabe
	# den Fokus anderer Controls klauen, z.B. dem Kommentarfeld im Leak-Reveal.
	if visible and _open and not has_focus():
		grab_focus()


## `_input` und nicht `gui_input`: die geschlossene Eingabe hat keinen Fokus und bekäme
## das Enter sonst nie. Das öffnende Enter wird verschluckt, bevor die LineEdit es sieht —
## sonst schickte es sofort ein leeres Feld ab. Escape im offenen Feld schließt nur;
## erst das nächste bricht den Kampf ab (WaveRunner._input läuft nach diesem hier).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not _open and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_set_open(true)
		# Die Zeitlupe beginnt mit dem Öffnen, nicht erst mit dem ersten Buchstaben — und
		# hält, bis abgeschickt oder geschlossen wird (typing_stopped).
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


## Nur bei nicht-leerem Feld: das clear() nach dem Absenden löst selbst ein
## text_changed aus und würde die eben beendete Slow-Mo sonst neu starten.
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
