extends Node
## Werkbank: das Hauptmenü samt Kulisse als Bild, zum Abgleich mit dem Entwurf
## (assets/ui/main_menu/sources/approved-concept.png).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/menu_lab.tscn -- --shoot
##         speichert reports/menu/menu_<breite>x<höhe>.png und beendet sich.
##     … -- --shoot --size=1920x1080     anderes Fenster (Bezugsgröße bleibt 1152×648)
##     … -- --shoot --backdrop           nur die Kulisse, ohne Menü
##     … -- --shoot --intro              „Wer spielt?" statt des Menüs
##     … -- --shoot --intro --slide=0.5  mitten im Schieben (0 = „Wer spielt?", 1 = Menü,
##                                       2 = Bibliothek)
##     … -- --shoot --library            die Bibliothek (kein Buch herausgenommen)
##     … -- --shoot --library --book=<id> … mit diesem Buch herausgenommen
##     … -- --shoot --to-library         schiebt wie „Spielen" in die Bibliothek
##     … -- --shoot --intro --to-menu    schiebt wie „Weiter" ins Menü (ohne Profilwechsel)
##     … -- --shoot --stats              drückt „Statistik": das Fenster über der Kulisse
##     … -- --shoot --stats=close        … und schließt es wieder; druckt, wer den Fokus hat
##
## Das Menü liest das aktive Profil nur (Name, Gold, Level); geschrieben wird nichts.
## Headless gibt es keinen Renderer — deshalb GODOT_WINDOW=1.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const BACKDROP_SCENE := "res://scenes/ui/menu_backdrop.tscn"
const SHOT_DIR := "res://reports/menu"
## So lange steht das Bild, bevor es gespeichert wird: Einblenden und ein Stück Idle.
const SETTLE := 2.0


func _ready() -> void:
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var path := BACKDROP_SCENE if _has_arg("backdrop") else MENU_SCENE
	ProfileMenu.intro_done = not _has_arg("intro")
	var screen := (load(path) as PackedScene).instantiate()
	add_child(screen)
	var slide := _arg("slide")
	if screen is ProfileMenu and not slide.is_empty():
		for page in ["%Intro", "%MenuPage", "%Library"]:
			screen.get_node(page).visible = true
		if float(slide) > ProfileMenu.MENU:
			(screen.get_node("%Library") as BookSelect).enter()
		(screen as ProfileMenu).call("_show_page", float(slide))
	if not _arg("book").is_empty():
		MapSelection.book = _arg("book")
	if screen is ProfileMenu and _has_arg("library"):
		(screen as ProfileMenu).call("_open_library")
		var library := screen.get_node("%Library") as BookSelect
		var book := library.call("_book_of", MapSelection.book) as Book3D
		if book != null:
			library.call("_select", book.get_index())
	if screen is ProfileMenu and _has_arg("to-library"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen as ProfileMenu).call("_open_library"))
	if screen is ProfileMenu and _has_arg("to-menu"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen as ProfileMenu).call("_slide_to", ProfileMenu.MENU))
	if screen is ProfileMenu and (_has_arg("stats") or not _arg("stats").is_empty()):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen.get_node("%StatsButton") as Button).pressed.emit())
		if _arg("stats") == "close":
			get_tree().create_timer(1.2).timeout.connect(func():
				var window := screen.get_node_or_null("StatsScreen")
				print("menu_lab: Fenster offen: ", window != null)
				if window != null:
					window.call("close")
				await get_tree().process_frame
				print("menu_lab: Fokus bei ", get_viewport().gui_get_focus_owner(),
						", Fenster noch da: ", is_instance_valid(window) and window.is_inside_tree()))
	if _has_arg("shoot"):
		_shoot.call_deferred()


func _shoot() -> void:
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var what := "backdrop" if _has_arg("backdrop") else ("intro" if _has_arg("intro") else "menu")
	if _has_arg("library"):
		what = "library"
	if _has_arg("to-library"):
		what += "_to_library"
	if _has_arg("to-menu"):
		what += "_to_menu"
	if not _arg("slide").is_empty():
		what += "_slide" + _arg("slide")
	if _has_arg("stats") or not _arg("stats").is_empty():
		what += "_stats" + ("_closed" if _arg("stats") == "close" else "")
	var file := "%s/%s_%dx%d.png" % [dir, what,
			img.get_width(), img.get_height()]
	img.save_png(file)
	print("menu_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
