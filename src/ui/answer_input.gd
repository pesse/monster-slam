extends LineEdit
## Texteingabe für Übersetzungen. Bei Enter wird die Antwort entkoppelt über den
## EventBus verschickt; die Kampf-Logik entscheidet, ob sie passt.


func _ready() -> void:
	placeholder_text = "Übersetzung eingeben und Enter…"
	text_submitted.connect(_on_text_submitted)
	focus_exited.connect(_on_focus_exited)
	grab_focus()


func _on_focus_exited() -> void:
	# Fokus soll immer im Eingabefeld bleiben (auch nach Klick woanders hin).
	if is_inside_tree():
		grab_focus.call_deferred()


func _on_text_submitted(new_text: String) -> void:
	var answer := new_text.strip_edges()
	if answer.is_empty():
		return
	EventBus.answer_submitted.emit(answer)
	clear()
	grab_focus()
