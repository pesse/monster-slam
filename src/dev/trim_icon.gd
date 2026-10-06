extends SceneTree
## Bringt ein einzeln erzeugtes Menü-Icon auf das Maß der übrigen: auf den Inhalt
## beschneiden, auf 224 px einpassen, 16 px Rand — 256 × 256, wie `export-assets.cjs` die
## Icons aus dem Atlas schneidet (`assets/ui/main_menu/`).
##
##     tools/godot.sh -s res://src/dev/trim_icon.gd -- <quelle> <ziel>
##         z. B. res://assets/ui/main_menu/sources/handbook.webp res://assets/ui/main_menu/icons/handbook.webp
##
## Warum hier und nicht im Skript: `export-assets.cjs` braucht `sharp` aus einer
## Windows-Node-Laufzeit; diese Werkbank läuft überall, wo `tools/godot.sh` läuft. Die
## Regel ist dieselbe: Alpha über 8 zählt als Inhalt, 3 px Luft drumherum. Ohne den Schnitt
## steht ein Icon, dessen Bild viel leeren Rand hat, kleiner da als seine Nachbarn.
##
## Gespeichert wird verlustfrei als WebP. Das Ziel bekommt beim nächsten `--import` seine
## `.import`-Datei; Mipmaps einschalten wie bei den anderen Icons.

const ALPHA_MIN := 8
const SLACK := 3
const FIT := 224
const PAD := 16


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("trim_icon: <quelle> <ziel>")
		quit(1)
		return
	var src := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if src == null or src.is_empty():
		push_error("trim_icon: '%s' nicht lesbar" % args[0])
		quit(1)
		return
	src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var lo := Vector2i(src.get_width(), src.get_height())
	var hi := Vector2i(-1, -1)
	for y in src.get_height():
		for x in src.get_width():
			if src.get_pixel(x, y).a8 > ALPHA_MIN:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		push_error("trim_icon: '%s' ist leer" % args[0])
		quit(1)
		return
	lo = Vector2i(maxi(0, lo.x - SLACK), maxi(0, lo.y - SLACK))
	hi = Vector2i(mini(src.get_width() - 1, hi.x + SLACK), mini(src.get_height() - 1, hi.y + SLACK))
	var crop := src.get_region(Rect2i(lo, hi - lo + Vector2i.ONE))
	var scale := float(FIT) / maxf(crop.get_width(), crop.get_height())
	var size := Vector2i(roundi(crop.get_width() * scale), roundi(crop.get_height() * scale))
	crop.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(FIT + 2 * PAD, FIT + 2 * PAD, false, Image.FORMAT_RGBA8)
	out.blit_rect(crop, Rect2i(Vector2i.ZERO, size), Vector2i(PAD, PAD) + (Vector2i(FIT, FIT) - size) / 2)
	var err := out.save_webp(ProjectSettings.globalize_path(args[1]), false)
	print("trim_icon: %s → %s (Inhalt %s, %d×%d)" % [args[0], args[1], hi - lo + Vector2i.ONE, size.x, size.y])
	quit(err)
