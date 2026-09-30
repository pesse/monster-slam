extends Control
## Kopfleiste im Kampf (Grafiken: `assets/ui/gameplay/`). Links das Porträt mit Level und
## Erfahrungsring, daneben die Festungstafel (Rüstung, HP) und darunter die Namensplakette;
## rechts die Welle mit Fortschritt, besiegte Monster und in dieser Sitzung gemeisterte
## Wörter. Das Layout liegt in hud.tscn; hier wird nur auf Signale reagiert und der Zustand
## dargestellt (die Werte LIEST das HUD aus GameState und PlayerLevel — die rechnen).
##
## Level und Erfahrung hängen am Porträt, nicht an der Welle: sie gehören zum Profil, nicht
## zum Lauf — deshalb kommt der Wert von PlayerLevel und nicht aus GameState. Die Erfahrung
## ist nur der Ring, ohne Zahl: gefragt ist „wie weit noch", nicht wie viel.

## Farbschwellen des Lebensbalkens (Anteil 0..1): darüber grün, darüber amber, sonst rot.
## Die Farben stehen im Theme (HudHp, HudHpWarn, HudHpLow).
const HP_OK := 0.6
const HP_WARN := 0.3

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_text: Label = %HpText
@onready var _armor_row: Control = %ArmorRow
@onready var _armor_bar: ProgressBar = %ArmorBar
@onready var _armor_text: Label = %ArmorText
@onready var _wave_title: Label = %WaveTitle
@onready var _wave_bar: ProgressBar = %WaveBar
@onready var _wave_text: Label = %WaveText
@onready var _kills_label: Label = %Kills
@onready var _book: Control = %Book
@onready var _mastered_label: Label = %Mastered
@onready var _fortress_panel: Control = %FortressPanel
@onready var _name_panel: PanelContainer = %NamePanel
@onready var _player_name: Label = %PlayerName
@onready var _level_text: Label = %LevelText
@onready var _xp_ring: XpRing = %XpRing
## Das goldene Aufleuchten des Level-Badges beim Aufstieg. Öffentlich, weil der Kampf es
## beim Start vorwärmt (FxWarmup) und das Debug-Panel es auslöst.
@onready var level_flare: LevelFlare = %LevelFlare


func _ready() -> void:
	# Profilname ändert sich während des Kampfes nicht -> nur einmal setzen.
	set_player_name(UserSettings.display_name())
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	# Gemeistert wird in PlayerProgress.record(), und das läuft VOR diesem Signal.
	EventBus.item_reviewed.connect(func(_id, _correct, _rt): _refresh())
	# Wellenstart setzt wave_total/wave_resolved zurück -> sofort auffrischen.
	# Die HP rührt er nicht an, der Stand läuft über die Wellen weiter.
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	EventBus.wave_totals.connect(func(_total): _refresh())
	# Erfahrung meldet sich selbst (Profilstand, kein Lauf-Zustand) — der Ring hängt am
	# Signal statt an jedem Refresh, weil er sich nur beim Verbuchen ändert.
	PlayerLevel.changed.connect(func(_total_xp, _level): _refresh_level())
	# `changed` kommt vorher: das Badge zeigt schon die neue Zahl, wenn es aufleuchtet.
	PlayerLevel.leveled_up.connect(func(_level, _points): level_flare.play())
	_refresh_level()
	_refresh()


## Die Namensplakette ist so breit wie der Name, höchstens so breit wie die Festungstafel
## darüber; ein längerer Name endet mit einer Ellipse. Die Schrift wird nicht kleiner.
func set_player_name(player_name: String) -> void:
	_player_name.text = player_name
	var font := _player_name.get_theme_font("font")
	var font_size := _player_name.get_theme_font_size("font_size")
	var wanted := font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var frame := _name_panel.get_theme_stylebox("panel").get_minimum_size().x
	var widest := _fortress_panel.custom_minimum_size.x - frame
	_player_name.custom_minimum_size.x = ceilf(minf(wanted, widest))


func _refresh() -> void:
	# Das Maximum ist Lauf-Zustand (Talente können es anheben), keine Konstante ->
	# bei jedem Refresh neu lesen, sonst zeigt der Balken einen veralteten Nenner.
	var max_hp: float = float(GameState.fortress_max_health)
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.fortress_health
	_hp_text.text = "%d / %d" % [GameState.fortress_health, GameState.fortress_max_health]
	var ratio := GameState.fortress_health / max_hp if max_hp > 0.0 else 0.0
	if ratio > HP_OK:
		_hp_bar.theme_type_variation = &"HudHp"
	elif ratio > HP_WARN:
		_hp_bar.theme_type_variation = &"HudHpWarn"
	else:
		_hp_bar.theme_type_variation = &"HudHpLow"
	# Ohne Bollwerk-Skill gibt es keine Rüstungszeile — eine leere Leiste wäre ein
	# Versprechen auf etwas, das es nicht gibt. Die Tafel behält ihre Höhe (die HP-Zeile
	# steht dann mittig), damit die Namensplakette darunter nicht springt.
	var armor_max: int = GameState.fortress_armor_max
	_armor_row.visible = armor_max > 0
	if armor_max > 0:
		_armor_bar.max_value = float(armor_max)
		_armor_bar.value = GameState.fortress_armor
		_armor_text.text = "%d / %d" % [GameState.fortress_armor, armor_max]

	# Wellen-Fortschritt: erledigte (besiegt + durchgelassen) von gesamt.
	var total: int = GameState.wave_total
	_wave_title.text = "Welle %d" % GameState.wave_number
	_wave_bar.max_value = maxi(1, total)
	_wave_bar.value = GameState.wave_resolved
	_wave_text.text = "%d / %d" % [GameState.wave_resolved, total]

	_kills_label.text = "%d besiegt" % GameState.monsters_defeated
	# Keine Punkte: sie sind ein interner Wert (aus ihnen wird das Gold der Kiste), und
	# eine Zahl, mit der der Spieler nichts anfangen kann, lenkt nur ab. Stattdessen, was
	# er in dieser Sitzung gelernt hat — und erst, wenn es etwas gibt: eine „0 gemeistert"
	# wäre eine Mahnung. Dieselbe Regel wie die Sitzungsbilanz (RunBalance, fresh_rows).
	var session := SessionLog.current()
	var mastered := 0
	if not session.is_empty():
		mastered = PlayerProgress.mastered_since(int(session.get("started_at", 0))).size()
	_book.visible = mastered > 0
	_mastered_label.visible = mastered > 0
	_mastered_label.text = "%d gemeistert" % mastered


## Level und Erfahrungsring. Der Ring zeigt den Stand IM Level (0..Kosten des nächsten
## Aufstiegs) und nicht die Gesamt-Erfahrung: die wächst ohne Obergrenze.
func _refresh_level() -> void:
	var progress := PlayerLevel.progress()
	_level_text.text = str(int(progress["level"]))
	_xp_ring.ratio = float(progress["xp_in_level"]) / maxf(1.0, float(progress["xp_for_level_up"]))
