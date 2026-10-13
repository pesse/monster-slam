extends SceneTree
## Verkleinert ein Bild vorab mit Lanczos auf die Größe, in der das Spiel es zeigt, als
## verlustfreies WebP. Nötig, weil ein 9-Slice-Rahmen (`StyleBoxTexture`) seine Ränder in
## Texturpixeln zeichnet.
##     tools/godot.sh -s res://src/dev/shrink_image.gd -- <quelle> <ziel> <faktor>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("shrink_image: <quelle> <ziel> <faktor>")
		quit(1)
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if img == null or img.is_empty():
		push_error("shrink_image: '%s' nicht lesbar" % args[0])
		quit(1)
		return
	img.decompress()
	var factor := float(args[2])
	var w := maxi(1, roundi(img.get_width() * factor))
	var h := maxi(1, roundi(img.get_height() * factor))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := ProjectSettings.globalize_path(args[1])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err := img.save_webp(out, false)
	print("shrink_image: %s -> %s (%d×%d) %s" % [args[0], args[1], w, h, error_string(err)])
	quit(0 if err == OK else 1)
