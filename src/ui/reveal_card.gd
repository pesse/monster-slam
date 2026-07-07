class_name RevealCard
extends PanelContainer
## Eine Auflösungs-Karte im Leak-Reveal-Karussell: Wortart + Prompt + Lösung (primäre
## Antwort + Alternativen). Layout & Styling liegen in reveal_card.tscn (im Editor auf
## einen Blick sichtbar); die Inhalte setzt das LeakReveal per setup().

@onready var _type: Label = %Type
@onready var _prompt: Label = %Prompt
@onready var _solution: CanvasItem = %Solution
@onready var _primary: Label = %Primary
@onready var _alt: Label = %Alt


## Der einblendbare Lösungsteil — vom LeakReveal für die Aufdeck-Animation getweent.
func solution() -> CanvasItem:
	return _solution


## Füllt die Karte aus einem Eintrag { prompt, answers, lexeme_type }. `revealed`=false
## hält den Lösungsteil zunächst unsichtbar (wird später eingeblendet).
func setup(item: Dictionary, revealed: bool) -> void:
	var type_key := String(item.get("lexeme_type", ""))
	_type.visible = not type_key.is_empty()
	if _type.visible:
		_type.text = String(WordTypePalette.LABELS.get(type_key, type_key))
		_type.add_theme_color_override("font_color", WordTypePalette.color_for(type_key))

	_prompt.text = String(item.get("prompt", ""))

	var answers: Array = item.get("answers", [])
	_primary.text = String(answers[0]) if not answers.is_empty() else "—"
	_alt.visible = answers.size() > 1
	if _alt.visible:
		_alt.text = "auch: %s" % ", ".join(_rest_as_strings(answers))

	_solution.modulate.a = 1.0 if revealed else 0.0


## answers[1..] als String-Array (join braucht String-Elemente).
func _rest_as_strings(answers: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, answers.size()):
		out.append(String(answers[i]))
	return out
