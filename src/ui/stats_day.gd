class_name StatsDay
extends VBoxContainer
## Ein Tag der Monatsreihe in der Statistik: ein dunkles Medaillon, auf einem geübten Tag
## die Münze darüber, darunter die Tageszahl (Entwurf `assets/ui/statistics/concept/`).
##
## Nicht dieselbe Zeichnung wie `DayCoin`: die fliegt weiter aus der Schatzkiste und
## braucht kein Medaillon. Die Zustände sind aber dieselben (`DayCoin.State`), gerechnet
## wird in `CoinStrip.states` — eine Regel für „heute ist keine Lücke", nicht zwei.
##
## Maus und Tastatur zeigen denselben goldenen Ring und dieselbe Karte: Datum als
## Überschrift, der Stand darunter.

## Heute ohne Zeiger: der Ring halb, damit man den Tag findet, ohne ihn mit dem Zeiger
## zu verwechseln.
const TODAY_RING := 0.45
## Ein Tag, der erst kommt: leiser als ein verpasster — ein leerer Platz, keine Lücke.
const FUTURE_ALPHA := 0.4

var state: DayCoin.State = DayCoin.State.MISSED
var is_today := false
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


## `day` ist die Zahl unter dem Medaillon, `title`/`note` die Karte am Zeiger.
func setup(new_state: DayCoin.State, today: bool, day: int, title: String, note: String) -> void:
	state = new_state
	is_today = today
	var earned := new_state == DayCoin.State.EARNED
	(%Coin as CanvasItem).visible = earned
	(%Medal as CanvasItem).modulate.a = FUTURE_ALPHA if new_state == DayCoin.State.FUTURE else 1.0
	var label := %Day as Label
	label.text = str(day)
	label.theme_type_variation = &"DayGold" if earned or today else &"DayNumber"
	Hints.attach(self, title, note)
	_update_ring()


func _set_hot(hot: bool) -> void:
	_hot = hot
	_update_ring()


func _update_ring() -> void:
	var ring := %Ring as CanvasItem
	ring.visible = _hot or is_today
	ring.modulate.a = 1.0 if _hot else TODAY_RING
