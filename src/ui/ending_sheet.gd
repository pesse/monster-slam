class_name EndingSheet
extends Control
## Overlay der Buchkarte: der Stand der lateinischen Endungen eines Buchs als Tabellen
## (EndingTable, ADR 0032). Esc oder das Kreuz schließen.

const SCENE := preload("res://scenes/ui/ending_sheet.tscn")


## Öffnet das Overlay über `parent` für die Endungen in `present` (Endings.present_units).
static func open(parent: Node, present: Dictionary) -> EndingSheet:
	var sheet := SCENE.instantiate() as EndingSheet
	parent.add_child(sheet)
	sheet.fill(present)
	return sheet


func _ready() -> void:
	(%CloseButton as BaseButton).pressed.connect(queue_free)
	Hints.attach(%CloseButton as Control, "Schließen", "", "Esc")


func fill(present: Dictionary) -> void:
	var count := EndingTable.summary(present, PlayerProgress.is_mastered)
	(%Summary as Label).text = "%d von %d Endungen gemeistert" % [count["done"], count["total"]]
	for table: EndingTable in [%DeclTable, %ConjTable]:
		var sheet := EndingTable.sheet("decl" if table == %DeclTable else "conj", present,
				PlayerProgress.confidence.bind(-1.0), PlayerProgress.is_mastered)
		table.visible = EndingTable.has_present(sheet)
		table.show_sheet(sheet)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
