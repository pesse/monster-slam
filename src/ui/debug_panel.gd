extends PanelContainer
## Einklappbares Debug-Panel (nur im Debug-Build sichtbar). Baut seine Steuer-Elemente
## per Code auf, damit später leicht weitere Debug-Funktionen ergänzt werden können:
## einfach in _build() einen weiteren Abschnitt hinzufügen und ein Signal emittieren.

## Der Nutzer hat eine Festungsstufe (0..4) gewählt.
signal fortress_tier_selected(tier: int)

const FORTRESS_TIERS := 5

var _body: VBoxContainer


func _ready() -> void:
	# Im veröffentlichten Build gibt es kein Debug-Panel.
	if not OS.is_debug_build():
		queue_free()
		return
	_build()


func _build() -> void:
	# Oben rechts verankern und zur Inhaltsgröße wachsen lassen (nach links/unten).
	# Kein PRESET_MODE_MINSIZE: die Mindestgröße steht im _ready noch nicht fest,
	# sonst bliebe der Container 0 breit und damit unsichtbar.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	offset_top = 8.0
	offset_right = -8.0

	var root := VBoxContainer.new()
	add_child(root)

	# Kopfzeile klappt den Inhalt ein/aus -> Panel lässt sich einfach ausblenden.
	var toggle := CheckButton.new()
	toggle.text = "🐞 Debug"
	toggle.button_pressed = true
	# Keinen Tastatur-Fokus nehmen: sonst reißt die Antwort-LineEdit (die sich per
	# _process den Fokus zurückholt) ihn im selben Frame weg und bricht den Klick ab.
	toggle.focus_mode = Control.FOCUS_NONE
	root.add_child(toggle)

	_body = VBoxContainer.new()
	root.add_child(_body)
	toggle.toggled.connect(func(on: bool) -> void: _body.visible = on)

	_add_fortress_section()


## Abschnitt „Festung": eine Button-Reihe 0..4 zum direkten Setzen der Ausbaustufe.
func _add_fortress_section() -> void:
	var label := Label.new()
	label.text = "Festung-Stufe"
	_body.add_child(label)

	var row := HBoxContainer.new()
	_body.add_child(row)
	for tier in FORTRESS_TIERS:
		var button := Button.new()
		button.text = str(tier)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tier_pressed.bind(tier))
		row.add_child(button)


func _on_tier_pressed(tier: int) -> void:
	fortress_tier_selected.emit(tier)
