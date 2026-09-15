class_name SkillTooltip
extends PanelContainer
## Die Karte, die beim Überfahren eines Knotens erscheint: Name, Wirkung, Zustand.
##
## Sie ersetzt die feste Tafel am Rand. Der Grund ist nicht Platz, sondern Blickrichtung:
## wer einen Knoten prüft, sieht ihn an — die Auskunft soll dort stehen, wo der Zeiger ist,
## und nicht am anderen Bildrand.
##
## Godot baut sie über `Control._make_custom_tooltip()`; der Knoten hängt dabei noch NICHT
## im Baum. Deshalb merkt `fill()` die Texte nur und `_ready()` trägt sie ein: `@onready`
## und `%Name` stehen erst bereit, wenn Godot die Karte eingehängt hat.

var _title: String = ""
var _body: String = ""
var _status: String = ""


func _ready() -> void:
	_apply()


## Füllt die Karte aus einem Knoten und seiner Zustandszeile („Lernen · 2 P.",
## „🔒 braucht Verband"). Die Zeile kommt von außen, weil sie eine REGEL ist
## (`SkillTree.state_label`) und nicht eine Frage der Darstellung.
func fill(node: Dictionary, status: String) -> void:
	_title = "%s %s" % [SkillTree.icon_of(node), str(node.get("name", ""))]
	_body = str(node.get("description", ""))
	_status = status
	if is_node_ready():
		_apply()


func _apply() -> void:
	(%Name as Label).text = _title
	(%Description as Label).text = _body
	(%Status as Label).text = _status
