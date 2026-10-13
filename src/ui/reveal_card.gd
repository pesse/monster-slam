class_name RevealCard
extends PanelContainer
## Auflösungs-Karte im Leak-Reveal-Karussell: Wortart, Aufgabe mit Alternativen, Lösung.
## Der Hintergrund zeigt je Karte den Ausgang: rötlich durchgelassen, grünlich richtig.

# Panelfarben des Themes, dezent ins Rote bzw. Grüne verschoben.
const LEAKED_BG := Color(0.28, 0.11, 0.13, 0.92)
const LEAKED_BORDER := Color(0.85, 0.38, 0.38)
const CORRECT_BG := Color(0.10, 0.24, 0.15, 0.92)
const CORRECT_BORDER := Color(0.38, 0.8, 0.48)

@onready var _type: Label = %Type
@onready var _prompt: Label = %Prompt
@onready var _prompt_alt: Label = %PromptAlt
@onready var _solution: CanvasItem = %Solution
@onready var _primary: Label = %Primary
@onready var _alt: Label = %Alt
@onready var _meaning: Label = %Meaning


## Stellt die Karte vor dem Setzen der Größe auf ihre Breite (px) ein. Umbrechende Labels
## brauchen die Breite vor dem Messen (docs/CONVENTIONS.md „Fallen").
func set_width(width: float) -> void:
	var inner := width - get_theme_stylebox("panel").get_minimum_size().x
	for label in [_prompt, _prompt_alt, _primary, _alt, _meaning]:
		label.custom_minimum_size.x = inner
		label.size.x = inner          # löst das Umbrechen jetzt aus, nicht erst im Layout
	custom_minimum_size.x = width


## Der einblendbare Lösungsteil (für die Aufdeck-Animation).
func solution() -> CanvasItem:
	return _solution


## Füllt die Karte aus { prompt, prompt_alt, answers, lexeme_type, meaning, leaked }.
## `revealed` = false hält den Lösungsteil unsichtbar.
func setup(item: Dictionary, revealed: bool) -> void:
	var type_key := String(item.get("lexeme_type", ""))
	_type.visible = not type_key.is_empty()
	if _type.visible:
		_type.text = String(WordTypePalette.LABELS.get(type_key, type_key))
		_type.add_theme_color_override("font_color", WordTypePalette.color_for(type_key))

	_apply_outcome(bool(item.get("leaked", false)))

	_prompt.text = String(item.get("prompt", ""))
	# Die Alternativen der Aufgabe verraten die Antwort nicht, also außerhalb des Lösungsteils.
	var prompt_alt := _as_strings(item.get("prompt_alt", []))
	_prompt_alt.visible = not prompt_alt.is_empty()
	if _prompt_alt.visible:
		_prompt_alt.text = "auch: %s" % ", ".join(prompt_alt)

	var answers := _as_strings(item.get("answers", []))
	_primary.text = answers[0] if not answers.is_empty() else "—"
	_alt.visible = answers.size() > 1
	if _alt.visible:
		_alt.text = "auch: %s" % ", ".join(answers.slice(1))

	# Im Lösungsteil: bei Gegenteil/Synonym verriete die Bedeutung die Antwort.
	var meaning := String(item.get("meaning", ""))
	_meaning.visible = not meaning.is_empty()
	_meaning.text = meaning

	_solution.modulate.a = 1.0 if revealed else 0.0


## Färbt die Karte nach dem Ausgang, auf einer Kopie der geteilten Theme-Stylebox.
func _apply_outcome(leaked: bool) -> void:
	var panel := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if panel == null:
		return
	panel.bg_color = LEAKED_BG if leaked else CORRECT_BG
	panel.border_color = LEAKED_BORDER if leaked else CORRECT_BORDER
	add_theme_stylebox_override("panel", panel)


## Ein Array als String-Array (join braucht String-Elemente).
func _as_strings(values: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for value in values:
		out.append(String(value))
	return out
