class_name ProgressRow
extends VBoxContainer
## Eine Fortschrittszeile der Statistik: Bezeichnung links, Balken in der Mitte, Zählung
## rechts — „Access 2, Unit 6 | ████████░░ | 18 von 24" (Issue #8). Ein Klick auf die
## Bezeichnung klappt die Wörter der Gruppe darunter auf, jedes mit seinem Prozentstand.
##
## Das Layout liegt in progress_row.tscn (im Editor gestaltbar), die Listen befüllen es
## über setup() — dieselbe Aufteilung wie bei StatRow. Der Balken macht aus der Summe ein
## Ziel: „18 von 24" liest man anders als „18 gemeistert"; die aufgeklappte Liste sagt
## dann, WELCHE 6 noch fehlen — die Zahl allein beantwortet das nicht.
##
## Die Wortzeilen kommen erst beim ersten Aufklappen (`words` ist ein Callable, kein
## Array): der Fortschritts-Reiter hat eine Zeile je Unit UND je Thema, und alle Listen
## im Voraus zu bauen hieße, den halben Katalog als Knoten in den Baum zu hängen.

const ROW_SCENE := preload("res://scenes/ui/stat_row.tscn")

## Breite der Markierungsspalte in der Wortliste: „✓" plus ein Sternchen je weiterer
## Aufgabe zum Wort. Sechs Zeichen sind das Maximum, das der Katalog hergibt (ein
## Adjektiv mit Gegenteil, zwei Synonymen und einer Verwechslung).
const MARK_WIDTH := 78

## Liefert beim Aufklappen die Zeilen dieser Gruppe als { label, value, mark }.
var _words := Callable()
var _title := ""
var _filled := false


func _ready() -> void:
	var header := $Row/Header as Button
	# Kein Fokusrahmen: die Zeile ist ein Aufklapper in einer langen Liste, kein Knopf,
	# den man ertasten soll.
	header.focus_mode = Control.FOCUS_NONE
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.pressed.connect(toggle)


## `words` ist optional: ohne sie bleibt die Zeile ein reiner Balken (und der Pfeil weg).
func setup(name_text: String, done: int, total: int, words := Callable()) -> void:
	_title = name_text
	_words = words
	var bar := $Row/Bar as ProgressBar
	# Ohne Wörter kein Balken-Maximum von 0 — der Balken wäre sonst voll statt leer.
	bar.max_value = maxi(1, total)
	bar.value = done
	($Row/Count as Label).text = "%d von %d" % [done, total]
	_update_header()
	var hint := "%s — %d von %d Wörtern gemeistert" % [name_text, done, total]
	if _words.is_valid():
		hint += "\nKlick zeigt die Wörter."
	tooltip_text = hint
	($Row/Header as Button).tooltip_text = hint


func is_expanded() -> bool:
	return ($Words as Control).visible


## Klappt die Wortliste auf oder zu. Öffentlich, damit der Test nicht den Knopf drücken
## muss, um die Liste zu sehen.
func toggle() -> void:
	if not _words.is_valid():
		return
	var words := $Words as Control
	words.visible = not words.visible
	if words.visible and not _filled:
		_fill()
	_update_header()


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
		# Haken plus bis zu vier Sternchen passen nicht in die Markierungsspalte einer
		# gewöhnlichen Zeile (siehe MARK_WIDTH).
		entry.set_mark_width(MARK_WIDTH)
		entry.setup(str(row["label"]), str(row["value"]), str(row.get("mark", "")),
				str(row.get("hint", "")))


func _update_header() -> void:
	var header := $Row/Header as Button
	if not _words.is_valid():
		header.text = _title
		return
	header.text = ("▾ " if is_expanded() else "▸ ") + _title
