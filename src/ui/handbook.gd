class_name Handbook
extends RefCounted
## Das Handbuch im Spiel: liest `docs/handbuch/` und öffnet das Fenster dazu (ADR 0019).
##
## Die Kapitel sind dieselben Markdown-Dateien wie auf GitHub, sie kommen über den
## `include_filter` der Export-Presets in die EXE. Es gibt keine zweite Fassung für das
## Spiel: was im Repo steht, steht im Fenster.
##
## Hier steht nur das Lesen. Gegliedert wird in Blöcke (Überschrift, Absatz, Listenpunkt,
## Tabelle), weil Überschriften eigene Labels mit eigener Typografie sind und ein
## Listenpunkt einen hängenden Einzug braucht, den BBCode für nummerierte Listen mit
## Folgeabsätzen nicht kann. Die Zeichen innerhalb eines Blocks (fett, kursiv, Code, Links)
## macht `MarkdownToBbcode.inline`. Unterstützt ist, was das Handbuch benutzt; der Test
## `handbook_test.gd` prüft, dass in keinem Kapitel Markdown übrig bleibt.

const DIR := "res://docs/handbuch/"
## Die Startseite, zugleich das Inhaltsverzeichnis: Reihenfolge und Titel der Kapitel stehen
## in ihrer Liste unter „## Inhalt“.
const INDEX := "README.md"
const INDEX_TITLE := "Überblick"
const WINDOW_SCENE := "res://scenes/ui/handbook.tscn"
## Über jedem Fenster und dem Kampf-UI, unter der Auskunft am Zeiger (Hints.LAYER 128): auch
## im Handbuch erklären die Knöpfe sich selbst.
const LAYER := 110

static var _layer: CanvasLayer = null


## Die Kapitel in Lesereihenfolge: [{file, title}], die Startseite zuerst.
static func chapters() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"file": INDEX, "title": INDEX_TITLE}]
	var in_index := false
	var link := RegEx.create_from_string("^\\d+\\.\\s+\\[(.+)\\]\\(([^)#]+\\.md)\\)")
	for line in read(INDEX).split("\n"):
		if line.begins_with("## "):
			in_index = line.strip_edges() == "## Inhalt"
			continue
		var m := link.search(line) if in_index else null
		if m:
			out.append({"file": m.get_string(2), "title": m.get_string(1)})
	return out


static func read(file: String) -> String:
	return FileAccess.get_file_as_string(DIR + file).replace("\r\n", "\n")


## Der Titel eines Kapitels, wie er im Inhaltsverzeichnis steht.
static func title_of(file: String) -> String:
	for chapter in chapters():
		if chapter.file == file:
			return chapter.title
	return ""


## Der Anker einer Überschrift wie auf GitHub: klein, Leerzeichen zu „-“, alles außer
## Buchstaben, Ziffern, „-“ und „_“ fällt weg. Damit gelten Links wie
## `18-wie-das-spiel-lernt.md#wann-eine-aufgabe-wiederkommt` hier wie dort.
static func anchor(heading: String) -> String:
	var out := ""
	for c in heading.strip_edges().to_lower():
		if c == " ":
			out += "-"
		elif c == "-" or c == "_" or c.is_valid_int() or c.to_upper() != c.to_lower():
			out += c
	return out


## Gliedert ein Kapitel in Blöcke:
## - `{kind: "heading", level, text, anchor}`
## - `{kind: "text", bbcode}` — ein Absatz
## - `{kind: "item", marker, depth, bbcode}` — ein Listenpunkt; ein Folgeabsatz im selben
##   Punkt hat den Marker "".
## - `{kind: "table", columns, bbcode}`
## Ab der ersten Linie (`---`) ist Schluss: darunter steht die Blätterzeile für GitHub, im
## Fenster blättert die Kapitelliste.
static func blocks(markdown: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lines := markdown.split("\n")
	var para: PackedStringArray = []
	var i := 0
	while i < lines.size():
		var line := lines[i]
		var bare := line.strip_edges()
		if bare == "---":
			break
		var item := _list_marker(line)
		if bare == "" or bare.begins_with("#") or bare.begins_with("|") or not item.is_empty():
			_flush_paragraph(para, out)
		if bare == "":
			i += 1
		elif bare.begins_with("#"):
			var level := bare.length() - bare.lstrip("#").length()
			var text := bare.lstrip("#").strip_edges()
			out.append({"kind": "heading", "level": level, "text": text, "anchor": anchor(text)})
			i += 1
		elif bare.begins_with("|"):
			i = _table(lines, i, out)
		elif not item.is_empty():
			i = _list(lines, i, out)
		else:
			para.append(bare)
			i += 1
	_flush_paragraph(para, out)
	return out


static func _flush_paragraph(para: PackedStringArray, out: Array[Dictionary]) -> void:
	if para.is_empty():
		return
	out.append({"kind": "text", "bbcode": MarkdownToBbcode.inline(" ".join(para))})
	para.clear()


## `{indent, marker, rest}` für eine Listenzeile („- …“, „1. …“), sonst {}.
static func _list_marker(line: String) -> Dictionary:
	var m := RegEx.create_from_string("^( *)([-*+]|\\d+\\.) (.*)$").search(line)
	if m == null:
		return {}
	var marker := m.get_string(2)
	return {
		"indent": m.get_string(1).length(),
		"marker": "•" if marker in ["-", "*", "+"] else marker,
		"rest": m.get_string(3),
	}


## Liest eine Liste ab Zeile `start`. Ein Punkt geht weiter, solange die Zeilen eingerückt
## sind oder ohne Leerzeile folgen; eine eingerückte Zeile nach einer Leerzeile beginnt einen
## Folgeabsatz im selben Punkt, eine tiefer eingerückte Listenzeile einen Unterpunkt. Die
## Liste endet an der ersten Zeile ohne Einzug nach einer Leerzeile.
static func _list(lines: PackedStringArray, start: int, out: Array[Dictionary]) -> int:
	var base := int(_list_marker(lines[start]).indent)
	var marker := ""
	var depth := 0
	var text: PackedStringArray = []
	var blank := false
	var i := start
	while i < lines.size():
		var line := lines[i]
		var bare := line.strip_edges()
		var indent := line.length() - line.lstrip(" ").length()
		var item := _list_marker(line)
		if bare == "":
			blank = true
			i += 1
			continue
		if bare == "---" or bare.begins_with("#") or bare.begins_with("|"):
			break
		if not item.is_empty() and int(item.indent) >= base:
			_flush_item(marker, depth, text, out)
			marker = item.marker
			depth = 1 if int(item.indent) > base else 0
			text.append(str(item.rest).strip_edges())
		elif indent > base:
			if blank:
				_flush_item(marker, depth, text, out)
				marker = ""
				depth = 0
			text.append(bare)
		elif blank:
			break
		else:
			text.append(bare)
		blank = false
		i += 1
	_flush_item(marker, depth, text, out)
	return i


static func _flush_item(marker: String, depth: int, text: PackedStringArray, out: Array[Dictionary]) -> void:
	if text.is_empty():
		return
	out.append({
		"kind": "item", "marker": marker, "depth": depth,
		"bbcode": MarkdownToBbcode.inline(" ".join(text)),
	})
	text.clear()


## Eine Tabelle als `[table]` für ein RichTextLabel; die Kopfzeile fett, die Trennzeile
## (`|---|`) fällt weg.
static func _table(lines: PackedStringArray, start: int, out: Array[Dictionary]) -> int:
	var rows: Array[PackedStringArray] = []
	var i := start
	while i < lines.size() and lines[i].strip_edges().begins_with("|"):
		var cells := _cells(lines[i])
		var rule := true
		for cell in cells:
			if cell.replace("-", "").replace(":", "").strip_edges() != "":
				rule = false
		if not rule:
			rows.append(cells)
		i += 1
	var columns := 0
	for row in rows:
		columns = maxi(columns, row.size())
	var bb := "[table=%d]" % columns
	for r in rows.size():
		for c in columns:
			var cell := MarkdownToBbcode.inline(rows[r][c]) if c < rows[r].size() else ""
			bb += "[cell]%s[/cell]" % ("[b]%s[/b]" % cell if r == 0 else cell)
	out.append({"kind": "table", "columns": columns, "bbcode": bb + "[/table]"})
	return i


static func _cells(line: String) -> PackedStringArray:
	var bare := line.strip_edges().trim_prefix("|").trim_suffix("|")
	var out: PackedStringArray = []
	for cell in bare.split("|"):
		out.append(cell.strip_edges())
	return out


## Wohin ein Link im Handbuch zeigt: `{file, section}` für ein Kapitel (auch `#anker` im
## selben Kapitel), {} für alles andere (Webseiten).
static func resolve(url: String, current_file: String) -> Dictionary:
	if url.contains("://") or url.begins_with("mailto:"):
		return {}
	var parts := url.split("#", true, 1)
	var file := parts[0] if parts[0] != "" else current_file
	if not file.ends_with(".md") or file.contains("/"):
		return {}
	return {"file": file, "section": parts[1] if parts.size() > 1 else ""}


## Öffnet das Handbuch über allem, was gerade läuft — auf einem Kapitel und, wenn
## angegeben, an einer Überschrift (ihr Text oder ihr Anker). Ist es schon offen, blättert
## es dorthin.
static func open(file := INDEX, section := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.name = "Handbook"
		_layer.layer = LAYER
		_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_layer)
		var window: Node = load(WINDOW_SCENE).instantiate()
		_layer.add_child(window)
		window.closed.connect(close)
	_layer.get_child(0).show_chapter(file, section)


static func close() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null


static func is_open() -> bool:
	return is_instance_valid(_layer) and not _layer.is_queued_for_deletion()
