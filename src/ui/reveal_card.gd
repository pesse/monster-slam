class_name RevealCard
extends PanelContainer
## Eine Auflösungs-Karte im Leak-Reveal-Karussell: Wortart + Prompt + Lösung (primäre
## Antwort + Alternativen). Layout & Styling liegen in reveal_card.tscn (im Editor auf
## einen Blick sichtbar); die Inhalte setzt das LeakReveal per setup().
##
## Die langen Zeilen (Aufgabe, Alternativen, Bedeutung) brechen um — eine Aufgabe mit
## mehreren Alternativantworten passt sonst nicht in die Breite und die Bühne schneidet
## sie ab. Umbrechende Labels wollen dafür VOR dem ersten Layout-Durchgang ihre Breite
## wissen, siehe set_width().
##
## Der Hintergrund sagt je Karte, wie es ausging: rötlich durchgelassen, grünlich
## richtig. Der Titel der Auflösung kann das nicht — nach „Alle anzeigen" stehen beide
## im selben Karussell.

# Aus dem Panel des Themes (bg 0.12/0.14/0.22, Rahmen 0.5/0.56/0.7) heraus verschoben —
# dezent, damit Wortart-Farbe und grüne Antwort lesbar bleiben.
const LEAKED_BG := Color(0.28, 0.11, 0.13, 0.92)
const LEAKED_BORDER := Color(0.85, 0.38, 0.38)
const CORRECT_BG := Color(0.10, 0.24, 0.15, 0.92)
const CORRECT_BORDER := Color(0.38, 0.8, 0.48)

@onready var _type: Label = %Type
@onready var _prompt: Label = %Prompt
@onready var _solution: CanvasItem = %Solution
@onready var _primary: Label = %Primary
@onready var _alt: Label = %Alt
@onready var _meaning: Label = %Meaning


## Stellt die Karte auf die Breite ein, in der sie stehen wird — vom LeakReveal vor dem
## Setzen der Größe gerufen.
##
## Ein Label mit `autowrap_mode` rechnet seine Mindesthöhe aus der Breite, die es GERADE
## hat: ohne zugeteilte Breite also aus null, und das sind für die Bedeutung ein paar
## tausend Pixel. `Control.size` wird an der Mindestgröße geklemmt, die Karte bleibt
## danach also hoch — gemessen 5881 statt 250 Pixel — und trägt ihren Inhalt weit aus der
## Bühne heraus, die ihn abschneidet. Die zugeteilte Breite kommt erst einen
## Layout-Durchgang später; deshalb wird sie hier von Hand gesetzt.
func set_width(width: float) -> void:
	var inner := width - get_theme_stylebox("panel").get_minimum_size().x
	for label in [_prompt, _primary, _alt, _meaning]:
		label.custom_minimum_size.x = inner
		label.size.x = inner          # löst das Umbrechen jetzt aus, nicht erst im Layout
	custom_minimum_size.x = width


## Der einblendbare Lösungsteil — vom LeakReveal für die Aufdeck-Animation getweent.
func solution() -> CanvasItem:
	return _solution


## Füllt die Karte aus einem Eintrag { prompt, answers, lexeme_type, meaning }. `revealed`=false
## hält den Lösungsteil zunächst unsichtbar (wird später eingeblendet).
func setup(item: Dictionary, revealed: bool) -> void:
	var type_key := String(item.get("lexeme_type", ""))
	_type.visible = not type_key.is_empty()
	if _type.visible:
		_type.text = String(WordTypePalette.LABELS.get(type_key, type_key))
		_type.add_theme_color_override("font_color", WordTypePalette.color_for(type_key))

	_apply_outcome(bool(item.get("leaked", false)))

	_prompt.text = String(item.get("prompt", ""))

	var answers: Array = item.get("answers", [])
	_primary.text = String(answers[0]) if not answers.is_empty() else "—"
	_alt.visible = answers.size() > 1
	if _alt.visible:
		_alt.text = "auch: %s" % ", ".join(_rest_as_strings(answers))

	# Bedeutung, wo die Aufgabe sie nicht schon zeigt („bully → Past Participle").
	# Sie steht im Lösungsteil: bei Gegenteil/Synonym ist sie die Bedeutung der Antwort
	# und würde vorab verraten, was gesucht ist.
	var meaning := String(item.get("meaning", ""))
	_meaning.visible = not meaning.is_empty()
	_meaning.text = meaning

	_solution.modulate.a = 1.0 if revealed else 0.0


## Färbt die Karte nach dem Ausgang. Auf einer KOPIE des Theme-Panels: der Stylebox aus
## dem Theme ist geteilt, eine Änderung daran träfe jede Tafel im Spiel. Die Ränder der
## Kopie sind dieselben, set_width() rechnet also unverändert.
func _apply_outcome(leaked: bool) -> void:
	var panel := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if panel == null:
		return
	panel.bg_color = LEAKED_BG if leaked else CORRECT_BG
	panel.border_color = LEAKED_BORDER if leaked else CORRECT_BORDER
	add_theme_stylebox_override("panel", panel)


## answers[1..] als String-Array (join braucht String-Elemente).
func _rest_as_strings(answers: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, answers.size()):
		out.append(String(answers[i]))
	return out
