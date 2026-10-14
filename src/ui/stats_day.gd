class_name StatsDay
extends VBoxContainer
## Ein Tag der Monatsreihe in der Statistik: Medaillon, auf einem geübten Tag die Münze
## darüber, darunter die Tageszahl. Die Zustände rechnet `CoinStrip.states` (`DayCoin.State`).
## Maus und Tastatur zeigen denselben Ring und dieselbe Karte; Klick oder Enter wählt den
## Tag, eine kleine Plakette am Medaillon heißt, an dem Tag gab es welche.

## Der Tag wurde gewählt (Klick oder ui_accept).
signal chosen()

## Deckkraft des Rings am heutigen Tag ohne Zeiger.
const TODAY_RING := 0.45
## Deckkraft des Medaillons an einem Tag, der erst kommt.
const FUTURE_ALPHA := 0.4

var state: DayCoin.State = DayCoin.State.MISSED
var is_today := false
var selected := false:
	set(value):
		selected = value
		if is_node_ready():
			_update_ring()
var _hot := false


func _ready() -> void:
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))
	focus_entered.connect(func() -> void:
		_set_hot(true)
		Hints.show_for(self))
	focus_exited.connect(func() -> void:
		_set_hot(false)
		Hints.refresh())


func _gui_input(event: InputEvent) -> void:
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept"):
		accept_event()
		chosen.emit()


## `day` ist die Zahl unter dem Medaillon, `title`/`note` die Karte am Zeiger, `badges`
## zeigt die kleine Plakette.
func setup(new_state: DayCoin.State, today: bool, day: int, title: String, note: String,
		badges := false) -> void:
	state = new_state
	is_today = today
	var earned := new_state == DayCoin.State.EARNED
	(%Coin as CanvasItem).visible = earned
	(%Medal as CanvasItem).modulate.a = FUTURE_ALPHA if new_state == DayCoin.State.FUTURE else 1.0
	var label := %Day as Label
	label.text = str(day)
	label.theme_type_variation = &"DayGold" if earned or today else &"DayNumber"
	(%Badge as CanvasItem).visible = badges
	Hints.attach(self, title, note)
	_update_ring()


func _set_hot(hot: bool) -> void:
	_hot = hot
	_update_ring()


func _update_ring() -> void:
	var ring := %Ring as CanvasItem
	ring.visible = _hot or selected or is_today
	ring.modulate.a = 1.0 if _hot or selected else TODAY_RING
