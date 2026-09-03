extends PanelContainer
## Statistik-Overlay nach einer Welle. Zeigt die Leistung der Welle + Lernfortschritt
## und lässt den Spieler die Schwierigkeit (1..5) der nächsten Welle wählen und starten.
## Nach einer Niederlage ist der Lauf zu Ende: Schwierigkeitswahl und Startknopf sind
## dann ausgeblendet, es bleibt der Weg ins Menü (siehe show_stats).
##
## Das Layout liegt in wave_stats.tscn; hier nur die Befüllung (show_stats) und die
## Auswahl-Logik. Interaktive Controls haben focus_mode=FOCUS_NONE (in der Szene gesetzt),
## sonst reißt die Antwort-LineEdit (die sich per _process den Fokus zurückholt) den Klick weg.

## Der Spieler hat die nächste Welle gestartet; übergeben wird die Änderung der
## Schwierigkeit RELATIV zur aktuellen (-2..+2), nicht ein absoluter Wert.
signal next_wave_requested(difficulty_delta: int)

## Der Spieler will zurück zum Profil-/Statistik-Menü (verlässt die laufende Partie).
signal back_to_menu_requested

## Deltas der Schwierigkeitswahl, in Reihenfolge der Buttons in ChoiceRow (wave_stats.tscn).
const CHOICE_DELTAS := [-2, -1, 0, 1, 2]
## Index der Standardauswahl ("Gleich").
const DEFAULT_CHOICE := 2

@onready var _title: Label = %Title
@onready var _lines: VBoxContainer = %Lines
@onready var _diff_label: Label = %DiffLabel
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _start_button: Button = %StartButton
@onready var _choice_buttons: Array = %ChoiceRow.get_children()
var _selected_choice: int = DEFAULT_CHOICE


func _ready() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).pressed.connect(_on_choice_pressed.bind(i))
	_start_button.pressed.connect(_on_start_pressed)
	(%MenuButton as Button).pressed.connect(func(): back_to_menu_requested.emit())
	_update_choice_highlight()


## Befüllt den Screen mit den Statistiken einer Welle und zeigt ihn an.
## Erwartete Felder in `data`: won, wave_number, difficulty, correct, leaked, total,
## accuracy, score_gained, score_total, fortress_health, mastered, fortress_tier.
func show_stats(data: Dictionary) -> void:
	var won := bool(data.get("won", true))
	_title.text = "Welle %d geräumt!" % int(data.get("wave_number", 0)) if won \
			else "Festung gefallen (Welle %d)" % int(data.get("wave_number", 0))
	# Ergebnis-Titel einfärben (passt zu den grün/rot-Feedbackfarben des Spiels).
	_title.add_theme_color_override("font_color",
			Color(0.3, 1.0, 0.45) if won else Color(1.0, 0.35, 0.35))

	for child in _lines.get_children():
		child.queue_free()
	_add_line("Richtig besiegt: %d von %d" % [int(data.get("correct", 0)), int(data.get("total", 0))])
	_add_line("Durchgelassen: %d" % int(data.get("leaked", 0)))
	_add_line("Genauigkeit: %d %%" % int(round(float(data.get("accuracy", 0.0)))))
	_add_line("Punkte: %d  (+%d)" % [int(data.get("score_total", 0)), int(data.get("score_gained", 0))])
	_add_line("Festung: %d HP" % int(data.get("fortress_health", 0)))
	_add_line("Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		int(data.get("mastered", 0)), int(data.get("fortress_tier", 0))])
	_add_line("Schwierigkeit: %d / 5" % int(data.get("difficulty", 3)))

	# Gefallene Festung = Ende des Laufs. Es gibt keine nächste Welle, also auch keine
	# Schwierigkeitswahl und keinen Startknopf — nur den Weg ins Menü. Damit muss der
	# Wellenstart die HP auch nie „retten": ein neuer Lauf beginnt über GameState.reset().
	_diff_label.visible = won
	_choice_row.visible = won
	_start_button.visible = won

	# Auswahl startet jedesmal bei "Gleich" – die Wahl ist relativ zur eben gespielten Welle.
	_selected_choice = DEFAULT_CHOICE
	_update_choice_highlight()
	visible = true


func hide_stats() -> void:
	visible = false


func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	_lines.add_child(label)


func _on_choice_pressed(index: int) -> void:
	_selected_choice = index
	_update_choice_highlight()


## Markiert die gewählte Option (deaktivierter Button = optisch hervorgehoben).
func _update_choice_highlight() -> void:
	for i in _choice_buttons.size():
		(_choice_buttons[i] as Button).disabled = (i == _selected_choice)


func _on_start_pressed() -> void:
	next_wave_requested.emit(CHOICE_DELTAS[_selected_choice])
