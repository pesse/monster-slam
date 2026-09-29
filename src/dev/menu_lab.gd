extends Node
## Werkbank: das Hauptmenü samt Kulisse als Bild, zum Abgleich mit dem Entwurf
## (assets/ui/main_menu/sources/approved-concept.png).
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/menu_lab.tscn -- --shoot
##         speichert reports/menu/menu_<breite>x<höhe>.png und beendet sich.
##     … -- --shoot --size=1920x1080     anderes Fenster (Bezugsgröße bleibt 1152×648)
##     … -- --shoot --backdrop           nur die Kulisse, ohne Menü
##     … -- --shoot --intro              „Wer spielt?" statt des Menüs
##     … -- --shoot --intro --slide=0.5  mitten im Schieben (0 = „Wer spielt?", 1 = Menü)
##     … -- --shoot --intro --to-menu    schiebt wie „Weiter" ins Menü (ohne Profilwechsel)
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
		screen.get_node("%MenuPage").visible = true
		(screen as ProfileMenu).call("_show_page", float(slide))
	if screen is ProfileMenu and _has_arg("to-menu"):
		get_tree().create_timer(0.5).timeout.connect(
				func(): (screen as ProfileMenu).call("_slide_to", ProfileMenu.MENU))
	if _has_arg("shoot"):
		_shoot.call_deferred()


func _shoot() -> void:
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var what := "backdrop" if _has_arg("backdrop") else ("intro" if _has_arg("intro") else "menu")
	if _has_arg("to-menu"):
		what += "_to_menu"
	if not _arg("slide").is_empty():
		what += "_slide" + _arg("slide")
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
