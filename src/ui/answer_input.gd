extends LineEdit
## Texteingabe für Übersetzungen. Bei Enter wird die Antwort entkoppelt über den
## EventBus verschickt; die Kampf-Logik entscheidet, ob sie passt.
##
## Wichtig: In Godot 4 sind "Fokus" und "Editier-Zustand" getrennt. Eine LineEdit
## beendet bei Enter standardmäßig das Editieren (Cursor verschwindet, obwohl
## has_focus() weiter true ist). keep_editing_on_text_submit=true hält das
## Editieren aktiv, sodass man direkt weitertippen kann.
## Zusätzlich: mouse_filter=IGNORE auf den Welt-ColorRects verhindert Fokusklau,
## und der _process-Guard holt den Fokus im Zweifel zurück.


func _ready() -> void:
	placeholder_text = "Übersetzung eingeben und Enter…"
	keep_editing_on_text_submit = true
	text_submitted.connect(_on_text_submitted)
	text_changed.connect(_on_text_changed)
	grab_focus()


func _process(_delta: float) -> void:
	# Nur zurückholen, wenn sichtbar — sonst würde die (unsichtbare) Kampfeingabe
	# den Fokus anderer Controls klauen, z.B. dem Kommentarfeld im Leak-Reveal.
	if visible and not has_focus():
		grab_focus()


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
