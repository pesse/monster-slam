class_name SkillNode
extends PanelContainer
## Eine Karte im Fähigkeitsbaum: Name, Wirkung und ein Knopf, der den Zustand trägt.
##
## Vorlage nach dem Muster von content_pack_row/stat_row: das Layout liegt in
## skill_node.tscn, das Skript verdrahtet nur den eigenen Knopf und meldet nach OBEN
## (`learn_requested`). Was ein Klick bedeutet, entscheidet der Screen — die Karte kennt
## weder SkillBook noch Punktestand.
##
## Die vier Zustände unterscheiden sich NUR in Beschriftung und `disabled`, nie in der
## Sichtbarkeit: der Baum soll beim Lernen nicht springen, und eine verschwundene Karte
## wäre ein Ast, der nicht mehr da ist. Dasselbe Prinzip wie bei der zugesperrten
## Schatzkiste (siehe CLAUDE.md).
##
## Die feste Breite steht an der Karte UND an den umbrechenden Labels: ein `Label` mit
## `autowrap_mode` meldet sonst 1 Pixel Mindestbreite und dazu die Höhe, die der Text bei
## einem Pixel bräuchte — der Baum wäre meterhoch.

## Was der Spieler mit dieser Karte tun kann.
enum State {
	LEARNED,        ## schon gelernt
	AVAILABLE,      ## Vorstufe erfüllt, Punkte reichen
	TOO_EXPENSIVE,  ## Vorstufe erfüllt, Punkte reichen nicht
	LOCKED,         ## Vorstufe fehlt
}

## Der Spieler will diesen Knoten lernen. Der Screen bucht, nicht die Karte.
signal learn_requested(id: String)

## Id des dargestellten Knotens (auch für Tests: sie sagt, welche Karte wo steht).
var id: String = ""

@onready var _name: Label = %Name
@onready var _description: Label = %Description
@onready var _action: Button = %Action


func _ready() -> void:
	_action.pressed.connect(func() -> void: learn_requested.emit(id))


## Füllt die Karte. `missing` ist der NAME der fehlenden Vorstufe und nur bei `LOCKED`
## gefüllt: mit zwei Ästen nebeneinander ist ein bloßes „gesperrt" nicht zu deuten —
## welcher Knoten fehlt, muss dastehen.
func setup(node: Dictionary, state: State, missing := "") -> void:
	id = str(node.get("id", ""))
	_name.text = str(node.get("name", id))
	_description.text = str(node.get("description", ""))
	var cost := SkillTree.cost(node)
	match state:
		State.LEARNED:
			_action.text = "✓ Gelernt"
		State.AVAILABLE:
			_action.text = "Lernen · %d P." % cost
		State.TOO_EXPENSIVE:
			_action.text = "%d P. nötig" % cost
		State.LOCKED:
			_action.text = "🔒 braucht %s" % missing
	_action.disabled = state != State.AVAILABLE
