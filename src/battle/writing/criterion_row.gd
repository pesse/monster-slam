class_name WritingCriterionRow
extends HBoxContainer
## Eine Zeile im Schreib-Boss (scenes/battle/writing/criterion_row.tscn): ein Zeichen, ein
## Name, darunter eine Zeile Erklärung. Dieselbe Vorlage trägt die Offline-Prüfungen in der
## Randleiste, die Kriterien beim Angriff und die Kriterien beim Überarbeiten — was eine
## Zeile sagt, entscheidet WritingBoss, die Zeile weiß nichts davon.
##
## Erst einhängen, dann `show_row` — die Labels stehen ab `_ready`.

@onready var _icon: Label = %Icon
@onready var _title: Label = %Title
@onready var _detail: Label = %Detail


## `detail` leer blendet die zweite Zeile aus; die Zeile darf dabei ihre Höhe ändern, sie
## steht in einer Spalte fester Größe.
func show_row(icon: String, title: String, detail := "") -> void:
	_icon.text = icon
	_title.text = title
	_detail.text = detail
	_detail.visible = not detail.is_empty()


func icon() -> String:
	return _icon.text


func title() -> String:
	return _title.text


func detail() -> String:
	return _detail.text
