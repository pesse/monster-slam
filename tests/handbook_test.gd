extends GdUnitTestSuite
## Das Handbuch im Spiel (ADR 0019): jedes Kapitel lässt sich lesen, ohne dass Markdown
## stehen bleibt, jeder Link darin führt irgendwohin, und jedes „?“ im Spiel zeigt auf eine
## Überschrift, die es gibt. Ein umbenannter Abschnitt im Handbuch fällt hier auf, nicht erst
## beim Kind, das auf „?“ drückt und am Kapitelanfang landet.

const SCENES := "res://scenes"
## Wo Code einem „?“ seinen Abschnitt setzt (Reiter): Zeilen `%…Tab: "<Überschrift>",`.
const SECTION_SOURCES := {
	"res://src/ui/stats_screen.gd": "12-statistik.md",
	"res://src/ui/settings_menu.gd": "13-einstellungen.md",
}


func _anchors_of(file: String) -> Array:
	var out: Array = []
	for block in Handbook.blocks(Handbook.read(file)):
		if block.kind == "heading":
			out.append(block.anchor)
	return out


func _files() -> Array:
	return Handbook.chapters().map(func(c): return c.file)


func test_chapters_come_from_the_index_in_order() -> void:
	var chapters := Handbook.chapters()
	assert_str(chapters[0].file).is_equal(Handbook.INDEX)
	assert_int(chapters.size()).is_greater(10)
	assert_str(chapters[1].file).is_equal("01-start-screen.md")
	for chapter in chapters:
		assert_bool(FileAccess.file_exists(Handbook.DIR + chapter.file)) \
				.override_failure_message("Kapitel fehlt: " + chapter.file).is_true()
		assert_str(chapter.title).is_not_empty()


## Jede Datei im Ordner steht im Inhalt — sonst ist sie im Spiel unerreichbar.
func test_every_file_is_in_the_index() -> void:
	var listed := _files()
	for file in DirAccess.get_files_at(Handbook.DIR):
		if file.ends_with(".md"):
			assert_bool(listed.has(file)) \
					.override_failure_message("nicht im Inhalt: " + file).is_true()


func test_anchor_matches_github() -> void:
	assert_str(Handbook.anchor("Reiter „Fortschritt“: gezählt werden Wörter")) \
			.is_equal("reiter-fortschritt-gezählt-werden-wörter")
	assert_str(Handbook.anchor("Stufe 1: Ergebnis und Schatzkiste")) \
			.is_equal("stufe-1-ergebnis-und-schatzkiste")
	assert_str(Handbook.anchor("Gold, Erfahrung und Level")).is_equal("gold-erfahrung-und-level")
	# Ein Anker bleibt sein eigener Anker: `section` darf beides sein.
	assert_str(Handbook.anchor("wann-eine-aufgabe-wiederkommt")) \
			.is_equal("wann-eine-aufgabe-wiederkommt")


func test_blocks_split_lists_and_tables() -> void:
	var md := "# Titel\n\nEin **Absatz**\nüber zwei Zeilen.\n\n" \
			+ "1. **Eins.** erster Punkt\n   geht weiter.\n   - Unterpunkt\n\n" \
			+ "   Folgeabsatz im selben Punkt.\n2. Zwei.\n\nDanach.\n\n" \
			+ "| A | B |\n|---|---:|\n| 1 | `x` |\n\n---\nNavigation"
	var blocks := Handbook.blocks(md)
	var kinds := blocks.map(func(b): return b.kind)
	assert_array(kinds).is_equal(
			["heading", "text", "item", "item", "item", "item", "text", "table"])
	assert_str(blocks[1].bbcode).is_equal("Ein [b]Absatz[/b] über zwei Zeilen.")
	assert_str(blocks[2].marker).is_equal("1.")
	assert_str(blocks[2].bbcode).is_equal("[b]Eins.[/b] erster Punkt geht weiter.")
	assert_str(blocks[3].marker).is_equal("•")
	assert_int(blocks[3].depth).is_equal(1)
	assert_str(blocks[4].marker).is_equal("")
	assert_str(blocks[5].marker).is_equal("2.")
	assert_int(blocks[7].columns).is_equal(2)
	assert_str(blocks[7].bbcode).starts_with("[table=2][cell][b]A[/b][/cell]")
	assert_str(blocks[7].bbcode).not_contains("---")


## Kein Kapitel lässt Markdown-Zeichen stehen, die der Leser dann sähe.
func test_no_markdown_left_in_any_chapter() -> void:
	var leftovers := []
	for file in _files():
		for block in Handbook.blocks(Handbook.read(file)):
			if block.kind == "heading":
				continue
			var text: String = block.bbcode
			for needle in ["**", "`", "](", "\n#", "|---"]:
				if text.contains(needle):
					leftovers.append("%s: %s … %s" % [file, needle, text.left(60)])
			if block.kind == "text" and RegEx.create_from_string("^([-*+]|\\d+\\.) ") \
					.search(text):
				leftovers.append("%s: Liste als Absatz … %s" % [file, text.left(60)])
	assert_array(leftovers).is_empty()


## Jeder Link im Handbuch führt auf ein Kapitel (und dort auf eine Überschrift) oder ins Netz.
func test_every_link_resolves() -> void:
	var broken := []
	var url := RegEx.create_from_string("\\[url=([^\\]]+)\\]")
	var files := _files()
	for file in files:
		for block in Handbook.blocks(Handbook.read(file)):
			if not block.has("bbcode"):
				continue
			for m in url.search_all(block.bbcode):
				var link := m.get_string(1)
				var target := Handbook.resolve(link, file)
				if target.is_empty():
					if not link.begins_with("https://"):
						broken.append("%s: %s" % [file, link])
				elif not files.has(target.file) or (target.section != ""
						and not _anchors_of(target.file).has(target.section)):
					broken.append("%s: %s" % [file, link])
	assert_array(broken).is_empty()


static func _collect(root: String, suffix: String, out: Array) -> void:
	for dir in DirAccess.get_directories_at(root):
		_collect(root.path_join(dir), suffix, out)
	for file in DirAccess.get_files_at(root):
		if file.ends_with(suffix):
			out.append(root.path_join(file))


## Jedes „?“ in einer Szene zeigt auf ein Kapitel und eine Überschrift, die es gibt.
func test_every_link_in_a_scene_resolves() -> void:
	var scenes: Array = []
	_collect(SCENES, ".tscn", scenes)
	var found := 0
	var broken := []
	for path in scenes:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("handbook_link.tscn"):
			continue
		for chunk in text.split("\n[node "):
			if not chunk.contains("instance=ExtResource(\"handbook_link\")") \
					and not chunk.contains("instance=ExtResource(\"16_handbook\")"):
				continue
			found += 1
			var chapter := Handbook.INDEX
			var section := ""
			for line in chunk.split("\n"):
				if line.begins_with("chapter = "):
					chapter = line.get_slice("\"", 1)
				elif line.begins_with("section = "):
					section = line.get_slice("\"", 1)
			if not _files().has(chapter):
				broken.append("%s: Kapitel %s" % [path, chapter])
			elif section != "" and not _anchors_of(chapter).has(Handbook.anchor(section)):
				broken.append("%s: %s#%s" % [path, chapter, section])
	assert_int(found).is_greater(8)
	assert_array(broken).is_empty()


## Die Reiter-Abschnitte, die Statistik und Einstellungen zur Laufzeit setzen.
func test_every_tab_section_resolves() -> void:
	var line := RegEx.create_from_string("%\\w+Tab: \"([^\"]+)\"")
	for path in SECTION_SOURCES:
		var chapter: String = SECTION_SOURCES[path]
		var hits := line.search_all(FileAccess.get_file_as_string(path))
		assert_int(hits.size()).is_equal(3)
		for m in hits:
			assert_array(_anchors_of(chapter)).override_failure_message(
					"%s: %s fehlt in %s" % [path, m.get_string(1), chapter]) \
					.contains([Handbook.anchor(m.get_string(1))])


func test_internal_link_resolution() -> void:
	assert_dict(Handbook.resolve("18-wie-das-spiel-lernt.md#weiteres", "README.md")) \
			.is_equal({"file": "18-wie-das-spiel-lernt.md", "section": "weiteres"})
	assert_dict(Handbook.resolve("#zauber", "05-kampf.md")) \
			.is_equal({"file": "05-kampf.md", "section": "zauber"})
	assert_dict(Handbook.resolve("https://github.com/pesse/monster-slam", "README.md")).is_empty()
	assert_dict(Handbook.resolve("../ARCHITECTURE.md", "README.md")).is_empty()


## Das Fenster öffnet auf dem Kapitel, fährt an die Überschrift und passt in 1152×648.
func test_window_opens_at_a_section() -> void:
	Handbook.open("18-wie-das-spiel-lernt.md", "Wann eine Aufgabe wiederkommt")
	assert_bool(Handbook.is_open()).is_true()
	var layer := get_tree().root.get_node("Handbook") as CanvasLayer
	var window := layer.get_child(0) as Control
	for i in 4:
		await get_tree().process_frame
	var page := window.get_node("%Page") as VBoxContainer
	assert_int(page.get_child_count()).is_greater(10)
	var scroll := window.get_node("%PageScroll") as ScrollContainer
	assert_int(scroll.scroll_vertical).is_greater(0)
	var frame := (window.get_node("%Window") as Control).get_global_rect()
	var screen := window.get_viewport_rect()
	assert_float(frame.end.x).is_less_equal(screen.end.x)
	assert_float(frame.end.y).is_less_equal(screen.end.y)
	# Ein zweites Öffnen blättert im selben Fenster.
	Handbook.open("05-kampf.md", "Zauber")
	await get_tree().process_frame
	assert_int(layer.get_child_count()).is_equal(1)
	Handbook.close()
	await get_tree().process_frame
	assert_bool(Handbook.is_open()).is_false()
