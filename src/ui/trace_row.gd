class_name TraceRow
extends HBoxContainer
## Eine Zeile der Protokoll-Ansicht (Einstellungen, Reiter „Protokoll"): Uhrzeit links, das
## Ereignis rechts. Was darin steht, rechnet `TraceView.rows()`; hier wird nur eingesetzt.
##
## Die Karte am Zeiger hängt an der ZEILE (siehe StatRow): dort stehen Lösung, Sicherheit
## und Antwortzeit, die in der Zeile keinen Platz haben.

## `entry` wie von `TraceView.rows()`.
func setup(entry: Dictionary) -> void:
	($Time as Label).text = str(entry.get("time", ""))
	var text := $Text as Label
	text.text = str(entry.get("text", ""))
	text.theme_type_variation = StringName(str(entry.get("style", "")))
	var hint: Dictionary = entry.get("hint", {})
	Hints.attach(self, str(hint.get("title", "")), str(hint.get("body", "")),
			str(hint.get("note", "")), hint.get("list", []))
