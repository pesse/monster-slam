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
	grab_focus()


func _process(_delta: float) -> void:
	if not has_focus():
		grab_focus()


func _on_text_submitted(new_text: String) -> void:
	var answer := new_text.strip_edges()
	if not answer.is_empty():
		EventBus.answer_submitted.emit(answer)
	clear()
