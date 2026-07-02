extends Control
## Zeigt Festungs-HP und Punkte. Reagiert nur auf EventBus-Signale und LIEST
## die Werte aus GameState (GameState rechnet, das HUD stellt dar).


@onready var _hp: Label = $HP
@onready var _score: Label = $Score


func _ready() -> void:
	EventBus.fortress_damaged.connect(func(_amount): _refresh())
	EventBus.monster_defeated.connect(func(_monster, _correct): _refresh())
	# Zu Wellenbeginn wird die Festungs-HP zurückgesetzt -> Anzeige sofort auffrischen.
	EventBus.wave_started.connect(func(_wave_id): _refresh())
	_refresh()


func _refresh() -> void:
	_hp.text = "Festung: %d" % GameState.fortress_health
	_score.text = "Punkte: %d" % GameState.score
