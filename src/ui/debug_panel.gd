extends PanelContainer
## Einklappbares Debug-Panel (nur im Debug-Build sichtbar). Das Layout liegt in
## debug_panel.tscn; hier nur der Debug-Check und die Signal-Verdrahtung. Weitere
## Debug-Funktionen: in der Szene ergänzen und hier verbinden.

## Der Nutzer hat eine Festungsstufe (0..4) gewählt.
signal fortress_tier_selected(tier: int)


func _ready() -> void:
	# Im veröffentlichten Build gibt es kein Debug-Panel.
	if not OS.is_debug_build():
		queue_free()
		return
	var body: VBoxContainer = $Root/Body
	($Root/Toggle as CheckButton).toggled.connect(func(on: bool) -> void: body.visible = on)
	# Jeder Festung-Stufen-Button (0..4) setzt direkt seine Ausbaustufe.
	var row := $Root/Body/TierRow
	for tier in row.get_child_count():
		(row.get_child(tier) as Button).pressed.connect(_on_tier_pressed.bind(tier))


func _on_tier_pressed(tier: int) -> void:
	fortress_tier_selected.emit(tier)
