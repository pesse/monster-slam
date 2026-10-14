extends Node
## Werkbank: das Statistik-Fenster als Bild, zum Abgleich mit dem Entwurf
## (assets/ui/statistics/concept/statistics-v3.webp).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/stats_lab.tscn -- --shoot
##         speichert reports/stats/stats_<breite>x<höhe>.png und beendet sich.
##     … -- --shoot --size=1920x1080   anderes Fenster (Bezugsgröße nach Menügröße, UiScale)
##     … -- --shoot --tab=1            zweiter Reiter (0 Überblick, 1 Fortschritt, 2 Aufgaben,
##                                     3 Plaketten)
##     … -- --shoot --day=29           Karte des Tages 29, als hätte er den Tastaturfokus
##     … -- --shoot --pick=5           Tag 5 der Monatsreihe gewählt (Plaketten-Band)
##     … -- --shoot --month=-1         Monatsreihe um so viele Monate geblättert
##     … -- --shoot --scroll=400       gezeigter Reiter um so viele Pixel nach unten geschoben
##     … -- --shoot --language=fr,la   Sprachwahl auf diese Sprachen gestellt (Issue #45)
##     … -- --sizes                    druckt die Mindestgrößen der Überblick-Abschnitte
## Zeigt den echten Stand des Entwicklungsprofils, schreibt nichts. Die Bilder tragen Wörter
## und bleiben unter reports/ (gitignored).

const SCREEN_SCENE := "res://scenes/ui/stats_screen.tscn"
const SHOT_DIR := "res://reports/stats"
## So lange steht das Bild, bevor es gespeichert wird.
const SETTLE := 1.0


func _ready() -> void:
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var screen := (load(SCREEN_SCENE) as PackedScene).instantiate()
	add_child(screen)
	if _has_arg("sizes"):
		_print_sizes.call_deferred(screen.get_node("%OverviewPage"), 0)
		get_tree().quit.call_deferred()
	if _has_arg("shoot"):
		_shoot.call_deferred(screen)


func _print_sizes(node: Node, depth: int) -> void:
	var control := node as Control
	if control == null or depth > 6:
		return
	print("stats_lab: %s%s %s" % ["  ".repeat(depth), node.name, control.get_combined_minimum_size()])
	for child in node.get_children():
		_print_sizes(child, depth + 1)


func _shoot(screen: Node) -> void:
	var tag := ""
	if not _arg("tab").is_empty():
		var tabs := screen.get_node("%Tabs").get_children()
		(tabs[int(_arg("tab"))] as Button).button_pressed = true
		tag += "_tab" + _arg("tab")
	if not _arg("language").is_empty():
		var languages := Array(_arg("language").split(","))
		(screen.get_node("%LanguageBar") as LanguageBar).set_languages(languages)
		screen._on_languages_changed(languages)
		tag += "_" + _arg("language").replace(",", "-")
	await get_tree().create_timer(SETTLE).timeout
	var strip := screen.get_node("%CoinStrip") as CoinStrip
	if not _arg("month").is_empty():
		for i in absi(int(_arg("month"))):
			strip._turn(1 if int(_arg("month")) < 0 else -1)
		tag += "_month" + _arg("month")
	if not _arg("pick").is_empty():
		strip.select(strip._first_shown() + int(_arg("pick")) - 1)
		tag += "_pick" + _arg("pick")
	if not _arg("scroll").is_empty():
		for page: ScrollContainer in [screen.get_node("%OverviewPage"), screen.get_node("%ProgressPage"),
				screen.get_node("%TaskPage"), screen.get_node("%BadgePage")]:
			if page.visible:
				page.scroll_vertical = int(_arg("scroll"))
		tag += "_scroll" + _arg("scroll")
		await get_tree().process_frame
	if not _arg("day").is_empty():
		var day := screen.get_node("%CoinStrip").get_node("%Coins").get_child(int(_arg("day")) - 1) as Control
		# Sonst fragt Hints im nächsten Frame die echte Maus und blendet die Karte aus.
		Hints.set_process(false)
		day.grab_focus()
		await get_tree().process_frame
		tag += "_day" + _arg("day")
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var file := "%s/stats_%dx%d%s.png" % [dir, img.get_width(), img.get_height(), tag]
	img.save_png(file)
	print("stats_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
