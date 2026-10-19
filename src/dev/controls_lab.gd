extends Control
## Werkbank: Eingabefelder, Segmentleisten und Kästchen in allen Zuständen nebeneinander, zum
## Abgleich mit dem Entwurf (assets/ui/windows/controls/concept/controls-v1.webp).
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/controls_lab.tscn [-- <Argumente>]
## --shoot: Bild nach reports/controls/controls_<breite>x<höhe>.png, dazu --size=1920x1080.
## Fokus und Hover setzt die Werkbank selbst; der Hover kommt als Mausereignis ins Fenster,
## der Zeiger des Rechners bleibt, wo er ist.

const SHOT_DIR := "res://reports/controls"
## Wartezeit vor dem Bild, in s.
const SETTLE := 1.0


func _ready() -> void:
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	%Hover.pressed.connect(_hover)
	_hover.call_deferred()
	if _has_arg("shoot"):
		_shoot.call_deferred()


## Fokus aufs Feld, Zeiger auf das Hover-Segment. Der Fokus geht bei einem Klick verloren,
## deshalb gibt es dafür einen Knopf.
func _hover() -> void:
	(%FocusField as LineEdit).grab_focus()
	var target := %HoverSegment as Control
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_screen_transform() \
			* target.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)


func _shoot() -> void:
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var file := "%s/controls_%dx%d.png" % [dir, img.get_width(), img.get_height()]
	img.save_png(file)
	print("controls_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
