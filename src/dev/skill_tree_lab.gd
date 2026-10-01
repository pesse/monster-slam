extends Node
## Werkbank: der Fähigkeiten-Screen als Bild, zum Abgleich mit dem Entwurf
## (assets/ui/skill_tree/concept/skill-tree-v5.webp).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/skill_tree_lab.tscn -- --shoot
##         speichert reports/skill_tree/skill_tree_<breite>x<höhe>.png und beendet sich.
##     … -- --shoot --size=1920x1080     anderes Fenster (Bezugsgröße bleibt 1152×648)
##     … -- --shoot --points=3           echte Punkte statt der unbegrenzten des Debug-Builds
##     … -- --shoot --hint=skill.scout.bow   zeigt die Hinweiskarte, als stünde die Maus
##                                         auf dem Knoten (Bildname bekommt die Id dazu)
##     … -- --shoot --hint=skill.scout.bow --dy=-400   Maus darüber/darunter versetzt, um
##                                         das Umklappen am Rand zu sehen
##     … -- --shoot --hint=… --card=4   nur die Hinweiskarte, vierfach vergrößert (Pixel
##                                         einzeln sichtbar — für Kanten und Pfeil)
##     … -- --shoot --rewire=skill.armor.builder:skill.armor.portcullis   hängt vor dem Bild
##                                         um wie „Umhängen an …" (ohne Speichern)
##     … -- --medallion                  misst den Ring von medallions/available.webp
##
## Unten liegt eine Leiste zum Setzen der Plätze: „Knoten verschieben" schaltet das Ziehen
## ein (linke Taste zieht einen Knoten oder Baumnamen, die mittlere schiebt das Netz),
## „Alle berechnen" nimmt jede Setzung zurück (erst mit Speichern dauerhaft).
## „Bearbeiten": ein Klick wählt einen Knoten, darunter stehen Stufe, Vorstufe und seine
## Kosten (änderbar). „Umhängen an …" macht den NÄCHSTEN Klick zur neuen Vorstufe — er und
## alles, was über ihm hängt, rückt dorthin, auch in einen anderen Baum (Regeln in
## SkillRewire); beim Überfahren sagt die Statuszeile vorher, was geschähe. Ein Klick
## daneben oder die rechte Taste bricht ab, ohne gewählten Knoten wählt die rechte Taste
## ab. „Daten verwerfen" lädt die Dateien neu. „Speichern" schreibt die Plätze
## (SkillLayout.PATH) und jede geänderte Datei unter data/skills/. Nur im Editor-Lauf, im
## Export ist res:// read-only.
##
## Der Screen bekommt ein eigenes Buch mit dem Lernstand des Entwurfs (Späher ausgebaut bis
## auf die Stiefel). Es liest die Bäume aus data/skills/ (nicht aus der Registry: geschrieben
## wird ins Repo), lädt und speichert aber kein Profil — das Entwicklungsprofil bleibt
## unberührt.

const REWIRE := preload("res://src/dev/skill_rewire.gd")

const SCREEN_SCENE := "res://scenes/ui/skill_tree.tscn"
const SHOT_DIR := "res://reports/skill_tree"
const MEDALLION := "res://assets/ui/skill_tree/medallions/available.webp"
## So lange steht das Bild, bevor es gespeichert wird.
const SETTLE := 1.0

## Der Lernstand des Entwurfs.
const LEARNED := ["skill.scout.root", "skill.scout.light", "skill.scout.bow",
		"skill.scout.charge"]

## Das Netz des Screens, und ob seit dem letzten Speichern etwas verschoben wurde.
var _graph: SkillGraph
var _dirty := false
var _screen: Node

## Die Skill-Dateien (Pfad -> Einträge), auf denen das Bearbeiten arbeitet; der gewählte
## Knoten; ob seit dem letzten Speichern Daten geändert wurden; ob die Taste, die gerade
## losgelassen wird, schon dem Bearbeiten gehörte; der Knoten unter dem Zeiger, für den
## die Vorschau gerade gilt.
var _files: Dictionary = {}
var _chosen := ""
var _data_dirty := false
var _eat_release := false
var _previewed := ""


## Ein Buch ohne Ablage: `_ready` lädt kein Profil, `_save` schreibt nichts.
class LabBook extends "res://src/progression/skill_book.gd":
	var points := -1
	var lab_entries: Array = []

	func entries() -> Array:
		return lab_entries

	func _ready() -> void:
		pass

	func available() -> int:
		return points if points >= 0 else UNLIMITED_POINTS

	func _save() -> void:
		pass


func _ready() -> void:
	if _has_arg("medallion"):
		_measure_medallion()
		get_tree().quit()
		return
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var book := LabBook.new()
	_files = REWIRE.load_files()
	book.lab_entries = REWIRE.all_entries(_files)
	book.unlocked = PackedStringArray(LEARNED)
	if not _arg("points").is_empty():
		book.points = int(_arg("points"))
		book.unlimited_points = false
	else:
		book.unlimited_points = true
	add_child(book)
	var screen := (load(SCREEN_SCENE) as PackedScene).instantiate()
	screen.set("book", book)
	add_child(screen)
	_screen = screen
	_setup_arrange(screen.get_node("%Graph") as SkillGraph)
	var rewire := _arg("rewire")
	if not rewire.is_empty():
		_rewire(rewire.get_slice(":", 0), rewire.get_slice(":", 1))
		_choose("")
		print("skill_tree_lab: ", %Status.text)
	if _has_arg("shoot"):
		%Bar.visible = false
		_shoot.call_deferred(screen)


# --- Plätze setzen --------------------------------------------------------------


func _setup_arrange(graph: SkillGraph) -> void:
	_graph = graph
	%ArrangeButton.toggled.connect(func(on: bool) -> void:
		_graph.arranging = on
		if on:
			%EditButton.button_pressed = false
		_show_status())
	%EditButton.toggled.connect(func(on: bool) -> void:
		if on:
			%ArrangeButton.button_pressed = false
		_choose("")
		_show_status("Knoten anklicken" if on else ""))
	%RewireButton.toggled.connect(func(on: bool) -> void:
		_previewed = ""
		_show_status("neue Vorstufe für %s anklicken" % _name_of(_chosen) if on else ""))
	%DeselectButton.pressed.connect(func() -> void:
		_choose("")
		_show_status())
	%CostSpin.value_changed.connect(_set_cost)
	# Das Theme zeigt „eingedrückt" kaum: ein Punkt vor dem Text sagt, welcher Modus läuft.
	for toggle: Button in [%ArrangeButton, %EditButton, %RewireButton]:
		var label := toggle.text
		toggle.toggled.connect(func(on: bool) -> void:
			toggle.text = ("● " if on else "") + label)
	%DiscardButton.pressed.connect(_discard_rewire)
	%SaveButton.pressed.connect(_save_layout)
	%ResetButton.pressed.connect(func() -> void:
		_graph.set_overrides({})
		_dirty = true
		_show_status())
	_graph.arranged.connect(func(id: String) -> void:
		_dirty = true
		var at: Vector2 = _graph.overrides().get(id, Vector2.ZERO)
		_show_status("%s → (%d, %d)" % [id, roundi(at.x), roundi(at.y)]))
	_show_status()


func _save_layout() -> void:
	var error := SkillLayout.save(_graph.overrides())
	if error != OK:
		_show_status("Speichern fehlgeschlagen: %s" % error_string(error))
		return
	_dirty = false
	var saved := REWIRE.save_files(_files)
	if saved.has("error"):
		_show_status("Daten nicht gespeichert: %s" % saved["error"])
		return
	_data_dirty = false
	var names: Array = (saved["written"] as Array).map(func(p: String) -> String: return p.get_file())
	_show_status("gespeichert: %s" % ", ".join([SkillLayout.PATH.get_file()] + names))


# --- Bearbeiten ---------------------------------------------------------------------


## Im Bearbeiten gehören linke und rechte Taste über dem Netz der Werkbank: der Screen
## würde sonst nach dem Lernen fragen. Rad und mittlere Taste gehen weiter ans Netz.
func _input(event: InputEvent) -> void:
	if not %EditButton.button_pressed:
		return
	if event is InputEventMouseMotion and %RewireButton.button_pressed:
		_preview(_skill_under(event))
		return
	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	if not button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not button.pressed:
		if _eat_release:
			_eat_release = false
			get_viewport().set_input_as_handled()
		return
	if %Bar.get_global_rect().has_point(button.position):
		return
	var local := _graph.make_input_local(button) as InputEventMouseButton
	if not Rect2(Vector2.ZERO, _graph.size).has_point(local.position):
		return
	get_viewport().set_input_as_handled()
	_eat_release = true
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if %RewireButton.button_pressed:
			%RewireButton.button_pressed = false
			_show_status("Umhängen abgebrochen")
		else:
			_choose("")
			_show_status()
		return
	var id := _skill_under(button)
	if %RewireButton.button_pressed:
		%RewireButton.button_pressed = false
		if id.is_empty() or id == _chosen:
			_show_status("Umhängen abgebrochen")
			return
		_rewire(_chosen, id)
		return
	_choose(id)
	_show_status()


## Die Id des Skills unter dem Zeiger; leer daneben und über einem Baumnamen.
func _skill_under(event: InputEvent) -> String:
	var local := _graph.make_input_local(event) as InputEventMouse
	var id := _graph.id_at(local.position)
	if str(SkillTree.node_by_id(_book_entries(), id).get("kind", "")) != "skill":
		return ""
	return id


## Was „Umhängen an `id`" täte — auf einer Kopie gerechnet, in der Statuszeile.
func _preview(id: String) -> void:
	if id == _previewed:
		return
	_previewed = id
	if id.is_empty() or id == _chosen:
		_show_status("neue Vorstufe für %s anklicken" % _name_of(_chosen))
		return
	var copy: Array = _book_entries().map(func(e: Dictionary) -> Dictionary: return e.duplicate(true))
	var result := REWIRE.reparent(copy, _chosen, id)
	if not bool(result["ok"]):
		_show_status("an %s: geht nicht — %s" % [_name_of(id), result["error"]])
		return
	var node := SkillTree.node_by_id(copy, _chosen)
	var others := (result["moved"] as Array).size() - 1
	_show_status("an %s: Stufe %d, Ast %d%s" % [_name_of(id), int(node["tier"]),
			int(node["branch"]), " · %d Knoten ziehen mit" % others if others > 0 else ""])


func _rewire(child: String, id: String) -> void:
	var result := REWIRE.reparent(_book_entries(), child, id)
	if not bool(result["ok"]):
		_show_status(str(result["error"]))
		return
	# Gesetzte Plätze des Asts stimmen an der neuen Stelle nicht mehr: wieder rechnen.
	var places := _graph.overrides()
	for moved: String in result["moved"]:
		if places.erase(moved):
			_dirty = true
	_graph.set_overrides(places)
	_data_dirty = true
	_screen.call("_rebuild")
	_choose(child)
	_show_status("%s hängt an %s" % [_name_of(child), _name_of(id)])


## Wählt `id` (leer: keinen) und füllt die Zeile darunter.
func _choose(id: String) -> void:
	_chosen = id
	_graph.mark(id)
	%RewireButton.button_pressed = false
	%Editor.visible = not id.is_empty()
	if id.is_empty():
		return
	var node := SkillTree.node_by_id(_book_entries(), id)
	var parents: Array = (node.get("requires", []) as Array).map(_name_of)
	%NodeLabel.text = "%s · %s · Stufe %d, Ast %d · %s" % [_name_of(id), id,
			int(node.get("tier", 1)), int(node.get("branch", 0)),
			"an " + ", ".join(parents) if not parents.is_empty() else "Anfang des Baums"]
	%CostSpin.set_value_no_signal(SkillTree.cost(node))


func _set_cost(value: float) -> void:
	if _chosen.is_empty():
		return
	var node := SkillTree.node_by_id(_book_entries(), _chosen)
	if int(node.get("cost", 1)) == int(value):
		return
	node["cost"] = int(value)
	_data_dirty = true
	_screen.call("_rebuild")
	_show_status("%s kostet %d P." % [_name_of(_chosen), int(value)])


func _name_of(id: String) -> String:
	return str(SkillTree.node_by_id(_book_entries(), id).get("name", id))


func _book_entries() -> Array:
	return (_screen.get("book") as Node).call("entries")


func _discard_rewire() -> void:
	_choose("")
	_files = REWIRE.load_files()
	(_screen.get("book") as Node).set("lab_entries", REWIRE.all_entries(_files))
	_data_dirty = false
	_screen.call("_rebuild")
	_show_status("Dateien neu geladen")


func _show_status(extra := "") -> void:
	var text := "%d gesetzt" % _graph.overrides().size()
	if _dirty:
		text += " · ungespeichert"
	if _data_dirty:
		text += " · Daten ungespeichert"
	if not extra.is_empty():
		text += " · " + extra
	%Status.text = text


func _shoot(screen: Node) -> void:
	await get_tree().create_timer(SETTLE).timeout
	var hint := _arg("hint")
	if not hint.is_empty():
		var graph := screen.get_node("%Graph") as SkillGraph
		var at := graph.get_global_transform() * graph.screen_position(hint)
		at.y += float(_arg("dy")) if not _arg("dy").is_empty() else 0.0
		# Sonst fragt Hints im nächsten Frame die echte Maus und blendet die Karte aus.
		Hints.set_process(false)
		Hints.probe(graph, at)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var tag := "" if hint.is_empty() else "_" + hint.get_slice(".", 2)
	if not _arg("card").is_empty() and not hint.is_empty():
		# Auf Fensterpixel umrechnen: das Bild hat die Fenstergröße, die Karte Bezugsmaße.
		var to_px := get_viewport().get_final_transform()
		var rect := (to_px * Hints.card().get_global_rect()).grow(32.0 * to_px.get_scale().x)
		rect = rect.intersection(Rect2(Vector2.ZERO, img.get_size()))
		img = img.get_region(Rect2i(rect))
		var zoom := int(_arg("card"))
		img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
		tag += "_card"
	var file := "%s/skill_tree_%dx%d%s.png" % [dir, img.get_width(), img.get_height(), tag]
	img.save_png(file)
	print("skill_tree_lab: ", file)
	get_tree().quit()


## Wo der silberne Ring auf der waagerechten Mittellinie anfängt und aufhört — in Pixeln
## vom Mittelpunkt, auf der 256er-Leinwand. Die Tönung der Mitte muss innerhalb bleiben.
func _measure_medallion() -> void:
	var img := (load(MEDALLION) as Texture2D).get_image()
	img.decompress()
	var half := img.get_width() / 2
	var inner := -1
	var outer := -1
	for x in range(half, img.get_width()):
		var c := img.get_pixel(x, half)
		if inner < 0 and c.get_luminance() > 0.3:
			inner = x - half
		if c.a > 0.5:
			outer = x - half
	print("skill_tree_lab: Ring innen %d px, außen %d px (Leinwand %d, Mitte %s)" % [
			inner, outer, img.get_width(), img.get_pixel(half, half)])


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
