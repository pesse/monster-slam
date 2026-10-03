class_name LanguageBar
extends HBoxContainer
## Die Sprachwahl der Statistik (Issue #45): je Sprache eine Flagge, die sich an- und
## abschalten lässt — mehrere zugleich, von Haus aus alle. Das Layout liegt in
## language_bar.tscn, eine Flagge in language_choice.tscn, die Bilder unter
## assets/ui/flags/<sprache>.svg.
##
## Wie die SortBar filtert die Leiste nicht selbst, sie meldet nur die gewählten Sprachen.
## Die letzte gewählte Flagge lässt sich nicht abschalten: ohne Sprache gäbe es nichts zu
## zählen, und eine leere Wahl als „alle" zu lesen, hieße das Gegenteil dessen anzuzeigen,
## was gedrückt ist. Die Flaggen entstehen einmal vor dem Anzeigen (`setup`); beim
## Umschalten ändert sich nur, welche gedrückt sind, die Leiste behält ihre Breite.

signal changed(languages: Array)

const CHOICE_SCENE := preload("res://scenes/ui/language_choice.tscn")
const FLAG_PATH := "res://assets/ui/flags/%s.svg"

## Sprachcode -> Knopf, in Anzeigereihenfolge.
var _buttons := {}


## Legt je Sprache aus `languages` (Codes, in Anzeigereihenfolge) eine Flagge an. Eine Sprache
## ohne Flaggenbild steht mit ihrem Namen da. `hint_body` erklärt an jeder Flagge, was der
## Filter trifft und was nicht.
func setup(languages: Array, hint_body: String) -> void:
	for lang in languages:
		var code := str(lang)
		var button := CHOICE_SCENE.instantiate() as Button
		if ResourceLoader.exists(FLAG_PATH % code):
			button.icon = load(FLAG_PATH % code)
		else:
			button.text = Lexeme.language_name(code)
		add_child(button)
		button.toggled.connect(func(on: bool) -> void: _on_toggled(button, on))
		Hints.attach(button, Lexeme.language_name(code), hint_body)
		_buttons[code] = button


## Drückt die Flaggen aus `languages`, ohne `changed` zu melden.
func set_languages(languages: Array) -> void:
	for code in _buttons:
		(_buttons[code] as Button).set_pressed_no_signal(code in languages)


## Die gedrückten Sprachen, in Anzeigereihenfolge.
func selected() -> Array:
	return _buttons.keys().filter(func(code): return (_buttons[code] as Button).button_pressed)


func _on_toggled(button: Button, on: bool) -> void:
	if not on and selected().is_empty():
		button.set_pressed_no_signal(true)
		return
	changed.emit(selected())
