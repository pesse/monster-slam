extends Control
## Werkbank für die Schatzkiste: Güte, Inhalt, Münzzahl und Haltezeit einstellbar, rechts
## die Belohnung einer erfundenen Welle (ChestReward). Kein Gold wird verbucht: `opened`
## geht nur in die Statuszeile.
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/chest_lab.tscn   (oder F6 im Editor)

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

@onready var _chest: TreasureChest = %Chest
@onready var _chest_title: Label = %ChestTitle
@onready var _status: Label = %Status
@onready var _tier_select: OptionButton = %TierSelect
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _coin_spin: SpinBox = %CoinSpin
@onready var _model_toggle: CheckButton = %ModelToggle
@onready var _hold_slider: HSlider = %HoldSlider
@onready var _hold_label: Label = %HoldLabel
@onready var _score_spin: SpinBox = %ScoreSpin
@onready var _correct_spin: SpinBox = %CorrectSpin
@onready var _leaked_spin: SpinBox = %LeakedSpin
@onready var _wave_result: Label = %WaveResult

## Das Fenster, dessen Größe die Werkbank geliehen hat.
var _room: Window


func _ready() -> void:
	# Mehr Platz als das Spiel (LabRoom).
	_room = get_window()
	LabRoom.enlarge(_room)
	for i in ChestReward.TIER_NAMES.size():
		_tier_select.add_item(str(ChestReward.TIER_NAMES[i]), i)
	_tier_select.select(ChestReward.Tier.SILVER)

	_chest.opened.connect(_on_opened)
	_chest.hold_started.connect(func(): _status.text = "Wird gedrückt …")
	_chest.hold_cancelled.connect(func(): _status.text = "Losgelassen — Fortschritt zurück auf null.")
	(%PresentButton as Button).pressed.connect(_present)
	(%OpenButton as Button).pressed.connect(_open_now)
	(%WaveButton as Button).pressed.connect(_from_wave)
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_tier_select.item_selected.connect(func(_i: int): _present())
	_hold_slider.value_changed.connect(func(_v: float): _apply_hold_time())
	# Modell oder Zeichnung.
	_model_toggle.toggled.connect(_on_look_toggled)

	_apply_hold_time()
	_present()



## Gibt das geliehene Fenster zurück, bei jedem Ausgang.
func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	# Escape führt zurück ins Menü.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)


## Umschalten wirkt erst bei der nächsten Kiste (TreasureChest.use_model), also gleich eine
## hinstellen.
func _on_look_toggled(on: bool) -> void:
	_chest.use_model = on
	_present()


func _apply_hold_time() -> void:
	_chest.hold_time = _hold_slider.value
	_hold_label.text = "Haltezeit: %.1f s" % _chest.hold_time


## Stellt eine neue Kiste nach den Einstellungen hin. Münzzahl 0 heißt „aus dem Gold
## rechnen“ wie im Spiel (TreasureChest.coin_count).
func _present() -> void:
	var tier := _tier_select.get_selected_id()
	var gold := int(_gold_spin.value)
	var coins := int(_coin_spin.value)
	_chest.present(tier, gold, coins if coins > 0 else -1)
	_chest_title.text = str(ChestReward.TIER_NAMES[tier])
	_status.text = "Zu — %d Gold drin, %d Münzen erwartet (%s)." % [
		gold, coins if coins > 0 else TreasureChest.coin_count(gold),
		"Modell" if _chest.use_model else "gezeichnet"]


## Springt ohne Drücken auf: für den Blick auf Deckel, Licht und Münzflug allein.
func _open_now() -> void:
	if _chest.is_open():
		_present()
	_chest.begin_hold()
	_chest.hold(_chest.hold_time)


func _on_opened(gold: int) -> void:
	_status.text = "Aufgesprungen: +%s, %d Münzen unterwegs. (Nicht verbucht.)" % [
		Wallet.label(gold), _chest.coins_in_flight()]


## Belohnung einer erfundenen Welle mit der Rechnung des Kampfs.
func _from_wave() -> void:
	var reward := ChestReward.for_wave(
			int(_score_spin.value), int(_correct_spin.value), int(_leaked_spin.value))
	_wave_result.text = "%s mit %s" % [str(reward["name"]), Wallet.label(int(reward["gold"]))]
	_tier_select.select(int(reward["tier"]))
	_gold_spin.value = float(int(reward["gold"]))
	_coin_spin.value = 0.0
	_present()
