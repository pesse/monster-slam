class_name MarkdownToBbcode
extends RefCounted
## Release-Notes (Markdown) für RichTextLabel: Überschriften, Listen, fett/kursiv, Code,
## Links; der Rest bleibt Klartext. Der Text kommt aus dem Netz und wird zuerst
## BBCode-entschärft.

const CODE_COLOR := "#c8b88a"


static func convert(markdown: String) -> String:
	var out: PackedStringArray = []
	for raw_line in markdown.replace("\r\n", "\n").split("\n"):
		out.append(_line(str(raw_line)))
	return "\n".join(out)


static func _line(line: String) -> String:
	var text := line.strip_edges(true, false)

	var heading := 0
	while heading < 3 and text.begins_with("#"):
		text = text.substr(1)
		heading += 1
	if heading > 0:
		return "[b]%s[/b]" % inline(text.strip_edges())

	for bullet in ["- ", "* ", "+ "]:
		if text.begins_with(bullet):
			return "  • %s" % inline(text.substr(2))

	return inline(line)


## Zeichenauszeichnung innerhalb einer Zeile. `**` vor `*`, sonst frisst die Kursiv-Regel
## die Hälfte einer Fett-Auszeichnung.
static func inline(text: String) -> String:
	var safe := text.replace("[", "[lb]")
	safe = _wrap(safe, "**", "[b]", "[/b]")
	safe = _wrap(safe, "__", "[b]", "[/b]")
	safe = _wrap(safe, "*", "[i]", "[/i]")
	safe = _wrap(safe, "`", "[color=%s]" % CODE_COLOR, "[/color]")
	return _links(safe)


## Ersetzt paarweise Begrenzer; ein unpaariger Rest bleibt als Zeichen stehen.
static func _wrap(text: String, marker: String, open_tag: String, close_tag: String) -> String:
	var parts := text.split(marker)
	if parts.size() < 3:
		return text
	var out := str(parts[0])
	var i := 1
	while i < parts.size():
		if i + 1 < parts.size():
			out += open_tag + str(parts[i]) + close_tag + str(parts[i + 1])
			i += 2
		else:
			out += marker + str(parts[i])
			i += 1
	return out


## [lb]text](url) -> [url=url]text[/url]. Die öffnende Klammer ist zu diesem Zeitpunkt
## schon entschärft, deshalb steht hier [lb] und nicht [.
static func _links(text: String) -> String:
	var regex := RegEx.create_from_string("\\[lb\\]([^\\]]+)\\]\\(([^) ]+)\\)")
	return regex.sub(text, "[url=$2]$1[/url]", true)
