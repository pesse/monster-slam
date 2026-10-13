class_name LanguageBar
extends HBoxContainer
## Die Sprachwahl der Statistik (Issue #45): je Sprache eine Flagge zum An- und Abschalten.
## Meldet nur die gewählten Sprachen. Die letzte gewählte Flagge lässt sich nicht abschalten.

signal changed(languages: Array)

const CHOICE_SCENE := preload("res://scenes/ui/language_choice.tscn")
const FLAG_PATH := "res://assets/ui/flags/%s.svg"

## Sprachcode -> Knopf, in Anzeigereihenfolge.
var _buttons := {}


## Legt je Sprachcode aus `languages` eine Flagge an, ohne Bild mit dem Namen. `hint_body`
## steht im Hinweis jeder Flagge.
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


func selected() -> Array:
	return _buttons.keys().filter(func(code): return (_buttons[code] as Button).button_pressed)


func _on_toggled(button: Button, on: bool) -> void:
	if not on and selected().is_empty():
		button.set_pressed_no_signal(true)
		return
	changed.emit(selected())
