extends Control
## Gestaltete Kopfleiste: Festungs-Lebensbalken, Wellen-Fortschritt und Punkte/Kills.
## Baut sein Layout — wie DebugPanel/WaveStats — komplett im Code auf und reagiert nur
## auf EventBus-Signale; die Werte LIEST es aus GameState (GameState rechnet, HUD stellt dar).

## Farbschwellen des Lebensbalkens (Anteil 0..1): darüber grün, darüber amber, sonst rot.
const HP_OK := 0.6
const HP_WARN := 0.3
const COLOR_HP_OK := Color(0.3, 1.0, 0.45)
const COLOR_HP_WARN := Color(1.0, 0.8, 0.25)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.3)

var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_text: Label
var _wave_bar: ProgressBar
var _wave_text: Label
var _kills_label: Label
var _score_label: Label


func _ready() -> void:
	_build()
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	# Wellenstart setzt HP + wave_total/wave_resolved zurück -> sofort auffrischen.
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	EventBus.wave_totals.connect(func(_total): _refresh())
	_refresh()


## Baut die dreigeteilte Kopfleiste (Leben links, Welle mitte, Punkte rechts) am oberen Rand.
func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# --- Spieler (ganz links) ---
	# Profilname aus den Einstellungen; ändert sich während des Kampfes nicht -> nur hier gesetzt.
	var player := _make_section()
	player.add_child(_make_caption("👤 %s" % UserSettings.display_name()))
	row.add_child(_section_panel(player))

	row.add_child(_spacer())

	# --- Leben (links) ---
	var life := _make_section()
	life.add_child(_make_caption("🏰 Festung"))
	_hp_bar = _make_bar()
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.set_corner_radius_all(5)
	_hp_fill.bg_color = COLOR_HP_OK
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	life.add_child(_hp_bar)
	_hp_text = _make_value("100/100")
	life.add_child(_hp_text)
	row.add_child(_section_panel(life))

	row.add_child(_spacer())

	# --- Welle (mitte) ---
	var wave := _make_section()
	wave.add_child(_make_caption("⚔ Welle"))
	_wave_bar = _make_bar()
	wave.add_child(_wave_bar)
	_wave_text = _make_value("0/0")
	wave.add_child(_wave_text)
	row.add_child(_section_panel(wave))

	row.add_child(_spacer())

	# --- Punkte/Kills (rechts) ---
	var stats := _make_section()
	_kills_label = _make_value("💀 0")
	stats.add_child(_kills_label)
	_score_label = _make_value("💰 0")
	stats.add_child(_score_label)
	row.add_child(_section_panel(stats))


func _refresh() -> void:
	# Lebensbalken: Wert + Farbe nach Anteil.
	var max_hp: float = float(GameState.FORTRESS_MAX_HEALTH)
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.fortress_health
	_hp_text.text = "%d/%d" % [GameState.fortress_health, GameState.FORTRESS_MAX_HEALTH]
	var ratio := GameState.fortress_health / max_hp if max_hp > 0.0 else 0.0
	if ratio > HP_OK:
		_hp_fill.bg_color = COLOR_HP_OK
	elif ratio > HP_WARN:
		_hp_fill.bg_color = COLOR_HP_WARN
	else:
		_hp_fill.bg_color = COLOR_HP_LOW

	# Wellen-Fortschritt: erledigte (besiegt + durchgelassen) von gesamt.
	var total: int = GameState.wave_total
	_wave_bar.max_value = maxi(1, total)
	_wave_bar.value = GameState.wave_resolved
	_wave_text.text = "%d/%d" % [GameState.wave_resolved, total]

	# Punkte + zerstörte Monster.
	_kills_label.text = "💀 %d" % GameState.monsters_defeated
	_score_label.text = "💰 %d" % GameState.score


# --- kleine Bau-Helfer -------------------------------------------------------

## Innen-Container einer Sektion (Label + Balken + Wert nebeneinander).
func _make_section() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return box


## Verpackt eine Sektion in ein gerahmtes PanelContainer (Stein-Look aus dem Theme).
func _section_panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	return panel


func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_value(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
