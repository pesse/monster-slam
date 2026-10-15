class_name WritingMarkRow
extends VBoxContainer
## Eine markierte Stelle beim Überarbeiten (scenes/battle/writing/mark_row.tscn): oben die
## Stelle selbst als Knopf, darunter der Hinweis — die Regel, nie die Lösung (ADR 0023,
## Abschnitt 5). Ein Klick auf die Stelle wählt sie im Schreibfeld aus (`picked`).

signal picked(quote: String)

@onready var _quote: Button = %Quote
@onready var _hint: Label = %Hint

var quote := ""


func _ready() -> void:
	_quote.pressed.connect(func() -> void: picked.emit(quote))


func show_mark(the_quote: String, hint: String) -> void:
	quote = the_quote
	_quote.text = "„%s“" % the_quote
	_hint.text = hint
	_hint.visible = not hint.is_empty()


func hint() -> String:
	return _hint.text
