class_name HandbookLink
extends Button
## Der Absprung ins Handbuch: ein „?“ neben dem, was es erklärt (ADR 0019). Zeigt auf ein
## Kapitel und optional eine Überschrift (ihr Text); `handbook_test.gd` prüft die Ziele.
## F1 öffnet am obersten sichtbaren Absprung, weil später im Baum hängende Fenster die Taste
## zuerst bekommen.

const GROUP := &"handbook_link"

@export var chapter := Handbook.INDEX:
	set(value):
		chapter = value
		_describe()
@export var section := "":
	set(value):
		section = value
		_describe()
## Aus für Absprünge mitten im Inhalt, die sonst dem Fenster-Absprung F1 wegnähmen.
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
