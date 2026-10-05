class_name SpellTile
extends Button
## Ein Zauber im Laden als Kachel (scenes/ui/spell_tile.tscn): groß das Zeichen, unten
## rechts, wie viele im Vorrat liegen. Name, Wirkung und Preis stehen im Hinweis. Ein Klick kauft einen; die Kachel meldet ihn nur, gekauft wird im SpellShop.

signal buy_pressed(spell: Dictionary)

## So lange leuchtet die Kachel nach einem Kauf auf (s).
const PULSE := 0.25

var spell: Dictionary = {}
var _note := ""

@onready var _icon: Label = %Icon
@onready var _count: Label = %Count


func _ready() -> void:
	pressed.connect(func() -> void: buy_pressed.emit(spell))


func setup(entry: Dictionary) -> void:
	spell = entry
	_icon.text = str(entry.get("icon", "?"))
	refresh()


## Vorrat und Sperre nach dem aktuellen Stand. Gesperrt statt ausgeblendet; warum, sagt
## der Hinweis.
func refresh() -> void:
	var id := str(spell.get("id", ""))
	var owned := Inventory.count_of(id)
	_count.text = "×%d" % owned if owned > 0 else ""
	var room := Inventory.slot_for(id) >= 0
	var gold := Wallet.can_afford(_price())
	disabled = not (room and gold)
	_note = "Klick: kaufen"
	if not room:
		_note = "Kein Platz frei — alle %d Plätze sind belegt" % Inventory.slot_count()
	elif not gold:
		_note = "Zu wenig Gold"
	Hints.attach_live(self, hint)


## Der Hinweis: Name, Wirkung, ob es geht, und der Preis als Münze mit Zahl (`prices`, wie
## im Fähigkeitsbaum).
func hint(_at := Vector2.ZERO) -> Dictionary:
	return {
		"title": str(spell.get("name", spell.get("id", ""))),
		"body": str(spell.get("description", "")),
		"note": _note,
		"prices": [[SkillIcons.gold(), Wallet.digits(_price())]],
	}


func _price() -> int:
	return maxi(0, int(spell.get("price", 0)))


## Kurzes Aufleuchten nach einem Kauf.
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 1.3, 1.0), PULSE * 0.4)
	tween.tween_property(self, "modulate", Color.WHITE, PULSE * 0.6)
