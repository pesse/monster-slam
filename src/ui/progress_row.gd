class_name ProgressRow
extends VBoxContainer
## Fortschrittszeile der Statistik: Bezeichnung, Balken, „18 von 24". Ein Klick auf die
## Bezeichnung klappt die Wörter der Gruppe mit ihrem Stand auf. Die Wortzeilen entstehen
## erst beim ersten Aufklappen (`words` ist ein Callable), damit nicht der halbe Katalog als
## Knoten im Baum hängt.

const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")

## Breite der Markierungsspalte in der Wortliste (px): „✓" plus ein Sternchen je weiterer
## Aufgabe, höchstens sechs Zeichen.
const MARK_WIDTH := 78

## Liefert beim Aufklappen die Zeilen dieser Gruppe als { label, value, mark }.
var _words := Callable()
var _title := ""
var _filled := false


func _ready() -> void:
	var header := $Row/Header as Button
	header.focus_mode = Control.FOCUS_NONE
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.pressed.connect(toggle)


## `words` ist optional: ohne sie bleibt die Zeile ein reiner Balken (und der Pfeil weg).
## `tasks` zählt Aufgaben statt Wörter — die Zeile eines Bonus (BonusLevel).
func setup(name_text: String, done: int, total: int, words := Callable(), tasks := false) -> void:
	_title = name_text
	_words = words
	var bar := $Row/Bar as ProgressBar
	# Ohne Wörter kein Balken-Maximum von 0 — der Balken wäre sonst voll statt leer.
	bar.max_value = maxi(1, total)
	bar.value = done
	($Row/Count as Label).text = "%d von %d" % [done, total]
	_update_header()
	# Ein Hinweis an der Zeile gilt auch für Knopf und Balken (`Hints` sucht nach oben).
	Hints.attach(self, name_text, "%d von %d %s gemeistert" % [done, total,
			"Aufgaben" if tasks else "Wörtern"],
			("Klick zeigt die %s." % ("Aufgaben" if tasks else "Wörter")) if _words.is_valid() else "")


func is_expanded() -> bool:
	return ($Words as Control).visible


## Klappt die Wortliste auf oder zu.
func toggle() -> void:
	if not _words.is_valid():
		return
	var words := $Words as Control
	words.visible = not words.visible
	if words.visible and not _filled:
		_fill()
	_update_header()


## Baut eine schon gefüllte Liste nach einem Sortierwechsel neu.
func refill() -> void:
	if not _filled:
		return
	var list := $Words/WordList as Node
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_filled = false
	if is_expanded():
		_fill()


func _fill() -> void:
	_filled = true
	var list := $Words/WordList as VBoxContainer
	var rows: Array = _words.call()
	if rows.is_empty():
		var label := Label.new()
		label.text = "Keine Wörter."
		list.add_child(label)
		return
	for row in rows:
		var entry := ROW_SCENE.instantiate() as StatRow
		list.add_child(entry)
		entry.set_mark_width(MARK_WIDTH)
		entry.setup(str(row["label"]), str(row["value"]), str(row.get("mark", "")),
				str(row.get("hint", "")), row.get("hint_list", []))


func _update_header() -> void:
	var header := $Row/Header as Button
	if not _words.is_valid():
		header.text = _title
		return
	header.text = ("▾ " if is_expanded() else "▸ ") + _title
