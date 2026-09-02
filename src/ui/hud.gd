extends Control
## Gestaltete Kopfleiste: Festungs-Lebensbalken, Wellen-Fortschritt und Punkte/Kills.
## Das Layout liegt in hud.tscn; hier wird nur auf EventBus-Signale reagiert und der
## Zustand dargestellt (die Werte LIEST das HUD aus GameState — GameState rechnet).

## Farbschwellen des Lebensbalkens (Anteil 0..1): darüber grün, darüber amber, sonst rot.
const HP_OK := 0.6
const HP_WARN := 0.3
const COLOR_HP_OK := Color(0.3, 1.0, 0.45)
const COLOR_HP_WARN := Color(1.0, 0.8, 0.25)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.3)

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_text: Label = %HpText
@onready var _wave_bar: ProgressBar = %WaveBar
@onready var _wave_text: Label = %WaveText
@onready var _kills_label: Label = %Kills
@onready var _score_label: Label = %Score
@onready var _player_name: Label = %PlayerName
## Fill-StyleBox des HP-Balkens (in hud.tscn definiert); Farbe wird je Anteil gesetzt.
var _hp_fill: StyleBoxFlat


func _ready() -> void:
	_hp_fill = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	# Profilname ändert sich während des Kampfes nicht -> nur einmal setzen.
	_player_name.text = "👤 %s" % UserSettings.display_name()
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	# Wellenstart setzt wave_total/wave_resolved zurück -> sofort auffrischen.
	# Die HP rührt er nicht an, der Stand läuft über die Wellen weiter.
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	EventBus.wave_totals.connect(func(_total): _refresh())
	_refresh()


func _refresh() -> void:
	# Lebensbalken: Wert + Farbe nach Anteil.
	# Das Maximum ist Lauf-Zustand (Talente können es anheben), keine Konstante ->
	# bei jedem Refresh neu lesen, sonst zeigt der Balken einen veralteten Nenner.
	var max_hp: float = float(GameState.fortress_max_health)
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.fortress_health
	_hp_text.text = "%d/%d" % [GameState.fortress_health, GameState.fortress_max_health]
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
