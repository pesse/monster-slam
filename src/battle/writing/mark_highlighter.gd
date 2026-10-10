class_name WritingMarkHighlighter
extends SyntaxHighlighter
## Färbt im Schreibfeld die Stellen, an denen The Rambler etwas gefunden hat
## (docs/adr/0023-schreib-boss.md, „Überarbeiten").
##
## Gesucht wird nach dem **Wortlaut** der Stelle, nicht nach ihrer Position: das Kind
## schreibt um, und jede Zeichenposition aus der Bewertung wäre nach dem ersten Tastendruck
## falsch. So verschwindet eine Markierung von selbst, sobald die Stelle umgeschrieben ist —
## und taucht dieselbe Formulierung woanders noch einmal auf, ist sie dort auch gemeint.
## Groß/Klein egal, wie bei der Suche im WritingJudge. Eine Stelle über einen Zeilenumbruch
## hinweg findet die Zeilensuche nicht; eine Summary schreibt man in Absätzen, nicht so.
##
## Die Farbe ist Code, nicht Theme: SyntaxHighlighter kennt keine Theme-Rolle.

const MARK_COLOR := Color(1.0, 0.62, 0.32)

var quotes: Array = []


func set_quotes(list: Array) -> void:
	quotes = []
	for quote in list:
		var q := str(quote).strip_edges().to_lower()
		if not q.is_empty() and not quotes.has(q):
			quotes.append(q)
	clear_highlighting_cache()


## Die markierten Bereiche einer Zeile als [[von, bis], …], sortiert und ohne Überlappung.
static func ranges_in(line: String, list: Array) -> Array:
	var low := line.to_lower()
	var found: Array = []
	for q in list:
		var at := low.find(q)
		while at != -1:
			found.append([at, at + q.length()])
			at = low.find(q, at + q.length())
	found.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	for r in found:
		if not merged.is_empty() and r[0] <= merged[-1][1]:
			merged[-1][1] = maxi(merged[-1][1], r[1])
		else:
			merged.append(r)
	return merged


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var edit := get_text_edit()
	if edit == null or quotes.is_empty():
		return {}
	var plain := edit.get_theme_color("font_color")
	var out := {}
	for r in ranges_in(edit.get_line(line), quotes):
		out[r[0]] = {"color": MARK_COLOR}
		out[r[1]] = {"color": plain}
	return out
