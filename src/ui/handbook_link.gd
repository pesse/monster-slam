class_name HandbookLink
extends Button
## Der Absprung ins Handbuch: ein kleines „?“ neben dem, was es erklärt (ADR 0019).
##
## Zeigt auf ein Kapitel und, wenn gesetzt, auf eine Überschrift darin — deren Text, wie er
## im Kapitel steht. Ein Screen mit Reitern setzt `section` beim Umschalten neu, dann führt
## das „?“ zum Reiter, der gerade offen ist. `handbook_test.gd` prüft, dass jedes Ziel in
## einer Szene existiert.
##
## F1 öffnet das Handbuch am obersten sichtbaren Absprung: Fenster hängen später im Baum
## als das Menü darunter und bekommen die Taste zuerst. Ein Absprung mitten im Inhalt (neben
## einer einzelnen Zahl) hört nicht auf F1 — sonst gewönne er gegen den des Fensters, der
## im Baum vor ihm steht.

const GROUP := &"handbook_link"

@export var chapter := Handbook.INDEX:
	set(value):
		chapter = value
		_describe()
@export var section := "":
	set(value):
		section = value
		_describe()
@export var answers_f1 := true


func _ready() -> void:
	add_to_group(GROUP)
	pressed.connect(open)
	_describe()


func open() -> void:
	Handbook.open(chapter, section)


func _describe() -> void:
	if not is_inside_tree():
		return
	if chapter == Handbook.INDEX and section == "":
		Hints.attach(self, "Handbuch", "Alles über das Spiel zum Nachlesen", "F1")
		return
	var where := Handbook.title_of(chapter)
	if section != "":
		where += " – " + section
	Hints.attach(self, "Im Handbuch nachlesen", where, "F1")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if (key and key.pressed and not key.echo and key.keycode == KEY_F1 and answers_f1
			and is_visible_in_tree()):
		get_viewport().set_input_as_handled()
		open()
