extends Control
## Kopfleiste im Kampf. Liest nur GameState, PlayerLevel und Wallet und reagiert auf Signale.

## Farbschwellen des Lebensbalkens (Anteil 0..1) für HudHp, HudHpWarn, sonst HudHpLow.
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
@onready var _gold_label: Label = %Gold
@onready var _fortress_panel: Control = %FortressPanel
@onready var _name_panel: PanelContainer = %NamePanel
@onready var _player_name: Label = %PlayerName
@onready var _level_text: Label = %LevelText
@onready var _xp_ring: XpRing = %XpRing
## Das Aufleuchten des Level-Badges beim Aufstieg; öffentlich für FxWarmup und Debug-Panel.
@onready var level_flare: LevelFlare = %LevelFlare


func _ready() -> void:
	set_player_name(UserSettings.display_name())
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	EventBus.monster_catapulted.connect(func(_task): _refresh())
	EventBus.monster_struck.connect(func(_task): _refresh())
	# Aufgeschoben: das Signal kommt vor der Wirkung auf HP und Rüstung.
	EventBus.spell_activated.connect(func(_id): _refresh(), CONNECT_DEFERRED)
	# Gemeistert wird in PlayerProgress.record(), vor diesem Signal.
	EventBus.item_reviewed.connect(func(_id, _correct, _rt): _refresh())
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	EventBus.wave_totals.connect(func(_total): _refresh())
	# Gold kommt mit der Kiste nach der Welle, nicht über den EventBus.
	Wallet.changed.connect(func(_gold): _refresh())
	PlayerLevel.changed.connect(func(_total_xp, _level): _refresh_level())
	# `changed` kommt vorher, das Badge zeigt beim Aufleuchten schon die neue Zahl.
	PlayerLevel.leveled_up.connect(func(_level, _points): level_flare.play())
	_refresh_level()
	_refresh()


## Die Namensplakette ist so breit wie der Name, höchstens wie die Festungstafel darüber.
func set_player_name(player_name: String) -> void:
	_player_name.text = player_name
	var font := _player_name.get_theme_font("font")
	var font_size := _player_name.get_theme_font_size("font_size")
	var wanted := font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var frame := _name_panel.get_theme_stylebox("panel").get_minimum_size().x
	var widest := _fortress_panel.custom_minimum_size.x - frame
	_player_name.custom_minimum_size.x = ceilf(minf(wanted, widest))


func _refresh() -> void:
	# Das Maximum kann im Lauf steigen, deshalb jedes Mal neu lesen.
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
	# Ohne Rüstung keine Rüstungszeile; die Tafel behält ihre Höhe.
	var armor_max: int = GameState.fortress_armor_max
	_armor_row.visible = armor_max > 0
	if armor_max > 0:
		_armor_bar.max_value = float(armor_max)
		_armor_bar.value = GameState.fortress_armor
		_armor_text.text = "%d / %d" % [GameState.fortress_armor, armor_max]

	var total: int = GameState.wave_total
	_wave_title.text = "Welle %d" % GameState.wave_number
	_wave_bar.max_value = maxi(1, total)
	_wave_bar.value = GameState.wave_resolved
	_wave_text.text = "%d / %d" % [GameState.wave_resolved, total]

	_kills_label.text = str(GameState.monsters_defeated)
	var session := SessionLog.current()
	var mastered := 0
	if not session.is_empty():
		mastered = PlayerProgress.mastered_since(int(session.get("started_at", 0))).size()
	_book.visible = mastered > 0
	_mastered_label.visible = mastered > 0
	_mastered_label.text = str(mastered)
	_gold_label.text = Wallet.digits()


## Level und Erfahrungsring; der Ring zeigt den Stand im Level, nicht die Gesamt-Erfahrung.
func _refresh_level() -> void:
	var progress := PlayerLevel.progress()
	_level_text.text = str(int(progress["level"]))
	_xp_ring.ratio = float(progress["xp_in_level"]) / maxf(1.0, float(progress["xp_for_level_up"]))
