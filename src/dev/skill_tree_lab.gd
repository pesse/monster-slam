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
##     … -- --medallion                  misst den Ring von medallions/available.webp
##
## Unten liegt eine Leiste zum Setzen der Plätze: „Knoten verschieben" schaltet das Ziehen
## ein (linke Taste zieht einen Knoten oder Baumnamen, die mittlere schiebt das Netz),
## „Speichern" schreibt SkillLayout.PATH, „Alle berechnen" nimmt jede Setzung zurück (erst
## mit Speichern dauerhaft). Nur im Editor-Lauf, im Export ist res:// read-only.
##
## Der Screen bekommt ein eigenes Buch mit dem Lernstand des Entwurfs (Späher ausgebaut bis
## auf die Stiefel). Es liest die echten Bäume aus der Registry, lädt und speichert aber
## nichts — das Entwicklungsprofil bleibt unberührt.

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


## Ein Buch ohne Ablage: `_ready` lädt kein Profil, `_save` schreibt nichts.
class LabBook extends "res://src/progression/skill_book.gd":
	var points := -1

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
	_setup_arrange(screen.get_node("%Graph") as SkillGraph)
	if _has_arg("shoot"):
		%Bar.visible = false
		_shoot.call_deferred(screen)


# --- Plätze setzen --------------------------------------------------------------


func _setup_arrange(graph: SkillGraph) -> void:
	_graph = graph
	%ArrangeButton.toggled.connect(func(on: bool) -> void:
		_graph.arranging = on
		_show_status())
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
	_show_status("gespeichert: %s" % SkillLayout.PATH)


func _show_status(extra := "") -> void:
	var text := "%d gesetzt" % _graph.overrides().size()
	if _dirty:
		text += " · ungespeichert"
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
