class_name BadgeChip
extends VBoxContainer
## Eine Plakette der Statistik: die Medaille aus `BadgePlate`, verkleinert, darunter eine
## kurze Zeile („×3“). Gezeigt wird nur Verdientes. Maus und Tastatur zeigen dieselbe Karte.


func _ready() -> void:
	focus_entered.connect(Hints.show_for.bind(self))
	focus_exited.connect(Hints.refresh)


## `badge` wie aus Badges.make (palette, mark); `caption` steht darunter, `title`/`body`/`note`
## sind die Karte am Zeiger.
func setup(badge: Dictionary, caption: String, title: String, body: String, note := "") -> void:
	(%Plate as BadgePlate).setup(badge["palette"], str(badge["mark"]))
	(%Caption as Label).text = caption
	Hints.attach(self, title, body, note)
