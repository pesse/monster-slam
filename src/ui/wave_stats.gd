extends PanelContainer
## Statistik-Overlay nach einer Welle. Zeigt die Leistung der Welle + Lernfortschritt
## und lässt den Spieler die Schwierigkeit (1..5) der nächsten Welle wählen und starten.
##
## Baut sein Layout — wie das DebugPanel — komplett im Code auf. Alle interaktiven
## Controls setzen focus_mode=FOCUS_NONE, sonst reißt die Antwort-LineEdit (die sich per
## _process den Fokus zurückholt) den Klick weg.

## Der Spieler hat die nächste Welle mit der gewählten Schwierigkeit gestartet.
signal next_wave_requested(difficulty: int)

const DIFFICULTIES := 5

var _title: Label
var _lines: VBoxContainer
var _difficulty_buttons: Array[Button] = []
var _selected_difficulty: int = 3


func _ready() -> void:
	# Bildschirm-zentriert, wächst zur Inhaltsgröße.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	root.add_child(_title)

	_lines = VBoxContainer.new()
	root.add_child(_lines)

	var diff_label := Label.new()
	diff_label.text = "Schwierigkeit der nächsten Welle"
	root.add_child(diff_label)

	var row := HBoxContainer.new()
	root.add_child(row)
	for i in DIFFICULTIES:
		var level := i + 1
		var button := Button.new()
		button.text = str(level)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_difficulty_pressed.bind(level))
		row.add_child(button)
		_difficulty_buttons.append(button)

	var start := Button.new()
	start.text = "▶ Nächste Welle rufen"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(_on_start_pressed)
	root.add_child(start)

	_update_difficulty_highlight()


## Befüllt den Screen mit den Statistiken einer Welle und zeigt ihn an.
## Erwartete Felder in `data`: won, wave_number, difficulty, correct, leaked, total,
## accuracy, score_gained, score_total, fortress_health, mastered, fortress_tier.
func show_stats(data: Dictionary) -> void:
	var won := bool(data.get("won", true))
	_title.text = "Welle %d geräumt!" % int(data.get("wave_number", 0)) if won \
			else "Festung gefallen (Welle %d)" % int(data.get("wave_number", 0))

	for child in _lines.get_children():
		child.queue_free()
	_add_line("Richtig besiegt: %d von %d" % [int(data.get("correct", 0)), int(data.get("total", 0))])
	_add_line("Durchgelassen: %d" % int(data.get("leaked", 0)))
	_add_line("Genauigkeit: %d %%" % int(round(float(data.get("accuracy", 0.0)))))
	_add_line("Punkte: %d  (+%d)" % [int(data.get("score_total", 0)), int(data.get("score_gained", 0))])
	_add_line("Festung: %d HP" % int(data.get("fortress_health", 0)))
	_add_line("Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		int(data.get("mastered", 0)), int(data.get("fortress_tier", 0))])

	_selected_difficulty = clampi(int(data.get("difficulty", _selected_difficulty)), 1, DIFFICULTIES)
	_update_difficulty_highlight()
	visible = true


func hide_stats() -> void:
	visible = false


func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	_lines.add_child(label)


func _on_difficulty_pressed(level: int) -> void:
	_selected_difficulty = level
	_update_difficulty_highlight()


## Markiert die gewählte Stufe (deaktivierter Button = optisch hervorgehoben).
func _update_difficulty_highlight() -> void:
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].disabled = (i + 1 == _selected_difficulty)


func _on_start_pressed() -> void:
	next_wave_requested.emit(_selected_difficulty)
