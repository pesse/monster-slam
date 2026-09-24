extends Control
## Gestaltete Kopfleiste: Spieler mit Level und Erfahrungsbalken, Festungs-Lebensbalken,
## Wellen-Fortschritt, Kills und die in dieser Sitzung gemeisterten Aufgaben.
## Das Layout liegt in hud.tscn; hier wird nur auf Signale reagiert und der Zustand
## dargestellt (die Werte LIEST das HUD aus GameState und PlayerLevel — die rechnen).
##
## Level und Erfahrung stehen beim NAMEN und nicht in einer eigenen Tafel: sie gehören
## zum Spieler und nicht zur Welle, und die Kopfleiste hat bei 1152 Pixeln keinen Platz
## für eine fünfte Tafel. Anders als HP und Wellenfortschritt hängen sie am Profil, nicht
## am Lauf — deshalb kommt der Wert von PlayerLevel und nicht aus GameState.

## Farbschwellen des Lebensbalkens (Anteil 0..1): darüber grün, darüber amber, sonst rot.
const HP_OK := 0.6
const HP_WARN := 0.3
const COLOR_HP_OK := Color(0.3, 1.0, 0.45)
const COLOR_HP_WARN := Color(1.0, 0.8, 0.25)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.3)

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _armor_bar: ProgressBar = %ArmorBar
@onready var _hp_text: Label = %HpText
@onready var _wave_bar: ProgressBar = %WaveBar
@onready var _wave_text: Label = %WaveText
@onready var _kills_label: Label = %Kills
@onready var _mastered_label: Label = %Mastered
@onready var _player_name: Label = %PlayerName
@onready var _level_text: Label = %LevelText
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_text: Label = %XpText
## Fill-StyleBox des HP-Balkens (in hud.tscn definiert); Farbe wird je Anteil gesetzt.
var _hp_fill: StyleBoxFlat


func _ready() -> void:
	_hp_fill = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	# Profilname ändert sich während des Kampfes nicht -> nur einmal setzen.
	_player_name.text = "👤 %s" % UserSettings.display_name()
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	# Gemeistert wird in PlayerProgress.record(), und das läuft VOR diesem Signal.
	EventBus.item_reviewed.connect(func(_id, _correct, _rt): _refresh())
	# Wellenstart setzt wave_total/wave_resolved zurück -> sofort auffrischen.
	# Die HP rührt er nicht an, der Stand läuft über die Wellen weiter.
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	EventBus.wave_totals.connect(func(_total): _refresh())
	# Erfahrung meldet sich selbst (Profilstand, kein Lauf-Zustand) — der Balken hängt am
	# Signal statt an jedem Refresh, weil er sich nur beim Verbuchen ändert.
	PlayerLevel.changed.connect(func(_total_xp, _level): _refresh_level())
	_refresh_level()
	_refresh()


func _refresh() -> void:
	# Lebensbalken: Wert + Farbe nach Anteil.
	# Das Maximum ist Lauf-Zustand (Talente können es anheben), keine Konstante ->
	# bei jedem Refresh neu lesen, sonst zeigt der Balken einen veralteten Nenner.
	var max_hp: float = float(GameState.fortress_max_health)
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.fortress_health
	# Rüstung ÜBER dem Lebensbalken statt daneben: die Kopfleiste ist in der Breite knapp
	# (tests/hud_header_test.gd), in der Höhe nicht. Ohne Bollwerk-Skill ist der Streifen
	# weg — eine leere Leiste wäre ein Versprechen auf etwas, das es nicht gibt.
	#
	# Sie trägt die Rüstung OHNE Zahl daneben: ein „🛡90" am HP-Text brauchte die letzten
	# freien Pixel der Reihe (1153 von 1152) und wäre bei dreistelliger Rüstung endgültig
	# aus dem Bild gelaufen — und die Beträge der Bäume stehen in JSON und sollen ohne
	# Code-Änderung justierbar bleiben. Der Anteil ist hier die Auskunft, die zählt:
	# „noch etwas Polster" oder „gleich geht es ans Leben".
	var armor_max: int = GameState.fortress_armor_max
	_armor_bar.visible = armor_max > 0
	if armor_max > 0:
		_armor_bar.max_value = float(armor_max)
		_armor_bar.value = GameState.fortress_armor
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

	_kills_label.text = "💀 %d" % GameState.monsters_defeated
	# Keine Punkte: sie sind ein interner Wert (aus ihnen wird das Gold der Kiste), und
	# eine Zahl, mit der der Spieler nichts anfangen kann, lenkt nur ab. Stattdessen, was
	# er in dieser Sitzung gelernt hat — und erst, wenn es etwas gibt: eine „🏅 0" wäre
	# eine Mahnung. Dieselbe Regel wie die Sitzungsbilanz (RunBalance, fresh_rows).
	var session := SessionLog.current()
	var mastered := 0
	if not session.is_empty():
		mastered = PlayerProgress.mastered_since(int(session.get("started_at", 0))).size()
	_mastered_label.visible = mastered > 0
	_mastered_label.text = "🏅 %d" % mastered


## Level und Erfahrungsbalken. Der Balken zeigt den Stand IM Level (0..Kosten des
## nächsten Aufstiegs) und nicht die Gesamt-Erfahrung: gefragt ist „wie weit noch", und
## die Gesamtzahl wächst ohne Obergrenze.
func _refresh_level() -> void:
	var progress := PlayerLevel.progress()
	_level_text.text = "⭐ %d" % int(progress["level"])
	_xp_bar.max_value = maxi(1, int(progress["xp_for_level_up"]))
	_xp_bar.value = int(progress["xp_in_level"])
	_xp_text.text = "%d/%d" % [int(progress["xp_in_level"]), int(progress["xp_for_level_up"])]
