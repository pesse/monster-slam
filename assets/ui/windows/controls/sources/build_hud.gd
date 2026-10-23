extends SceneTree
## Independent additive HUD exporter. Never runs or rewrites the earlier controls exporter.
## Use an empty temporary --path, not the game project.

var asset_dir = get_script().resource_path.get_base_dir().get_base_dir() + "/"
var assets = {}
var hud = {"revision": 1, "files": [], "stretch_cases": [], "sources": [], "errors": []}
var old_report = {}
const SPECS = {
	"hud_plate": [[96, 64], [16, 16, 16, 16], "both"],
	"bar_track": [[64, 16], [8, 6, 8, 6], "horizontal"],
	"bar_fill": [[64, 16], [8, 6, 8, 6], "horizontal"],
	"scroll_track": [[12, 48], [0, 6, 0, 6], "vertical"],
	"scroll_grabber": [[12, 48], [0, 6, 0, 6], "vertical"],
	"scroll_grabber_hover": [[12, 48], [0, 6, 0, 6], "vertical"],
	"scroll_grabber_pressed": [[12, 48], [0, 6, 0, 6], "vertical"]
}

func require(ok, message):
	if not ok:
		push_error(message)
		quit(1)
		assert(false, message)

func canvas(w, h):
	var im = Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	return im

func input(name):
	var path = asset_dir + name + ".webp"
	var im = Image.load_from_file(path)
	require(not im.is_empty(), "Missing input " + name)
	im.convert(Image.FORMAT_RGBA8)
	var found = false
	for s in hud.sources:
		if s.file == name + ".webp":
			found = true
	if not found:
		hud.sources.append({"file": name + ".webp", "sha256": FileAccess.get_sha256(path)})
	return im

func closed(state):
	var first = input("seg_first_" + state)
	var last = input("seg_last_" + state)
	first.blit_rect(last, Rect2i(80, 0, 16, 44), Vector2i(80, 0))
	return first

func nine(src, w, h, margins, dst_margins = [], interpolation = Image.INTERPOLATE_BILINEAR):
	var dm = margins if dst_margins.is_empty() else dst_margins
	var sx = [0, margins[0], src.get_width() - margins[2], src.get_width()]
	var sy = [0, margins[1], src.get_height() - margins[3], src.get_height()]
	var dx = [0, dm[0], w - dm[2], w]
	var dy = [0, dm[1], h - dm[3], h]
	var out = canvas(w, h)
	for j in range(3):
		for i in range(3):
			if dx[i + 1] == dx[i] or dy[j + 1] == dy[j]:
				continue
			if sx[i + 1] == sx[i] or sy[j + 1] == sy[j]:
				continue
			var piece = src.get_region(Rect2i(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j]))
			piece.resize(dx[i + 1] - dx[i], dy[j + 1] - dy[j], interpolation)
			out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(dx[i], dy[j]))
	return out

func canonicalize(im):
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			if im.get_pixel(x, y).a8 == 0:
				im.set_pixel(x, y, Color.TRANSPARENT)
	return im

func neutral_metal(im):
	var out = im.duplicate()
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c = out.get_pixel(x, y)
			if c.a == 0:
				continue
			var lum = .2126 * c.r + .7152 * c.g + .0722 * c.b
			# Tonal remap only: original facet/grain energy and highlight placement remain.
			var g = clampf(.64 + .36 * sqrt(lum), 0, 1)
			out.set_pixel(x, y, Color(g, g, g, c.a))
	return canonicalize(out)

func tone(im, color, boost = 1.0):
	var out = im.duplicate()
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c = out.get_pixel(x, y)
			c.r = clampf(c.r * color.r * boost, 0, 1)
			c.g = clampf(c.g * color.g * boost, 0, 1)
			c.b = clampf(c.b * color.b * boost, 0, 1)
			out.set_pixel(x, y, c)
	return canonicalize(out)

func export_asset(name, im):
	var spec = SPECS[name]
	require(im.get_size() == Vector2i(spec[0][0], spec[0][1]), name + " size")
	im = canonicalize(im)
	var png_path = asset_dir + "sources/" + name + "-raw.png"
	var path = asset_dir + name + ".webp"
	require(im.save_png(png_path) == OK, name + " raw PNG")
	require(im.save_webp(path, false, 1.0) == OK, name + " WebP")
	var decoded = Image.load_from_file(path)
	require(decoded.get_size() == Vector2i(spec[0][0], spec[0][1]), name + " decoded canvas")
	require(decoded.get_format() == Image.FORMAT_RGBA8, name + " native RGBA")
	require(decoded.get_data() == im.get_data(), name + " exact RGBA lossless roundtrip")
	var encoded = FileAccess.get_file_as_bytes(path)
	require(encoded.slice(12, 16).get_string_from_ascii() == "VP8L", name + " VP8L")
	var raw_png = Image.load_from_file(png_path)
	require(raw_png.get_data() == decoded.get_data(), name + " PNG equals WebP")
	var amin = 255
	var amax = 0
	var partial = 0
	var bytes = decoded.get_data()
	for p in range(3, bytes.size(), 4):
		amin = mini(amin, bytes[p])
		amax = maxi(amax, bytes[p])
		if bytes[p] > 0 and bytes[p] < 255:
			partial += 1
	var meta = {"file": name + ".webp", "canvas": spec[0], "slices_LTRB": spec[1], "format": "RGBA8", "webp_chunk": "VP8L", "lossless_RGBA_roundtrip": true, "raw_png_equal": true, "alpha_range": [amin, amax], "partial_alpha_pixels": partial, "sha256": FileAccess.get_sha256(path)}
	var errors = 0
	if spec[2] in ["horizontal", "both"]:
		for y in range(im.get_height()):
			for x in range(spec[1][0] + 1, im.get_width() - spec[1][2]):
				if im.get_pixel(x, y) != im.get_pixel(spec[1][0], y):
					errors += 1
		meta["horizontal_stretch_pixel_errors"] = errors
		require(errors == 0, name + " horizontal uniformity")
	if spec[2] in ["vertical", "both"]:
		errors = 0
		for y in range(spec[1][1] + 1, im.get_height() - spec[1][3]):
			for x in range(im.get_width()):
				if im.get_pixel(x, y) != im.get_pixel(x, spec[1][1]):
					errors += 1
		meta["vertical_stretch_pixel_errors"] = errors
		require(errors == 0, name + " vertical uniformity")
	if name == "bar_fill":
		var nonneutral = 0
		for y in range(im.get_height()):
			for x in range(im.get_width()):
				var c = im.get_pixel(x, y)
				if c.a > 0 and (c.r8 != c.g8 or c.g8 != c.b8):
					nonneutral += 1
		require(nonneutral == 0, "Fill must be neutral grayscale")
		meta["non_neutral_pixels"] = nonneutral
	if name == "hud_plate":
		meta["center_alpha"] = im.get_pixel(48, 32).a8
		require(meta.center_alpha == 235, "HUD face alpha 235")
	hud.files.append(meta)
	assets[name] = decoded

func make_plate():
	var src = closed("normal")
	var im = canvas(96, 64)
	for y in range(64):
		var sy = y if y < 16 else (y - 20 if y >= 48 else 22)
		for x in range(96):
			var sx = x if x < 16 or x >= 80 else 48
			var c = src.get_pixel(sx, sy)
			if x >= 8 and x < 88 and y >= 8 and y < 56:
				c.a = 235.0 / 255.0
			im.set_pixel(x, y, c)
	export_asset("hud_plate", im)

func make_bars():
	var src = input("field_normal")
	var track = nine(src, 64, 16, [16, 16, 16, 16], [8, 6, 8, 6], Image.INTERPOLATE_LANCZOS)
	export_asset("bar_track", track)
	var visible = nine(closed("hover"), 60, 12, [16, 16, 16, 16], [6, 4, 6, 4], Image.INTERPOLATE_LANCZOS)
	visible = neutral_metal(visible)
	# A lower diffuse shadow gives the tiny fill a convex section; source glints remain.
	for y in range(7, 12):
		var factor = 1.0 - .35 * pow(float(y - 6) / 5.0, 1.3)
		for x in range(60):
			var c = visible.get_pixel(x, y)
			c.r *= factor
			c.g *= factor
			c.b *= factor
			visible.set_pixel(x, y, c)
	var fill = canvas(64, 16)
	fill.blit_rect(visible, Rect2i(Vector2i.ZERO, visible.get_size()), Vector2i(2, 2))
	export_asset("bar_fill", fill)

func make_scroll():
	var src = input("field_normal")
	var track = nine(src, 48, 12, [16, 16, 16, 16], [6, 4, 6, 4], Image.INTERPOLATE_LANCZOS)
	track.rotate_90(CLOCKWISE)
	track.flip_x() # Transpose: original upper/left light becomes upper/left light again.
	export_asset("scroll_track", track)
	for state in ["normal", "hover", "pressed"]:
		var im = nine(closed("selected" if state == "pressed" else "hover"), 48, 12, [16, 16, 16, 16], [6, 4, 6, 4], Image.INTERPOLATE_LANCZOS)
		# Auf der dunklen Rinne braucht der Griff Abstand: normal heller als das Segment.
		if state == "normal":
			im = tone(im, Color(1, 1, 1), 1.2)
		elif state == "hover":
			im = tone(im, Color(1, 1, 1), 1.45)
		im.rotate_90(CLOCKWISE)
		im.flip_x()
		export_asset("scroll_grabber" + ("" if state == "normal" else "_" + state), im)

func test_stretch(name, sizes):
	var spec = SPECS[name]
	for size in sizes:
		var im = nine(assets[name], size.x, size.y, spec[1])
		var errors = 0
		if spec[2] in ["horizontal", "both"]:
			for y in range(im.get_height()):
				for x in range(spec[1][0] + 1, size.x - spec[1][2]):
					if im.get_pixel(x, y) != im.get_pixel(spec[1][0], y):
						errors += 1
		if spec[2] in ["vertical", "both"]:
			for y in range(spec[1][1] + 1, size.y - spec[1][3]):
				for x in range(size.x):
					if im.get_pixel(x, y) != im.get_pixel(x, spec[1][1]):
						errors += 1
		var border_errors = 0
		if name == "bar_fill":
			for y in range(size.y):
				for x in range(size.x):
					if (x < 2 or y < 2 or x >= size.x - 2 or y >= size.y - 2) and im.get_pixel(x, y).a8 != 0:
						border_errors += 1
			require(border_errors == 0, "Two-pixel fill padding at " + str(size))
		require(errors == 0, name + " stretch at " + str(size))
		hud.stretch_cases.append({"file": name + ".webp", "canvas": [size.x, size.y], "stretch_errors": errors, "fill_2px_padding_errors": border_errors, "passed": true})

func blend(out, im, x, y):
	out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))

func state_checks():
	hud["state_checks"] = []
	for pair in [["scroll_grabber", "scroll_grabber_hover"]]:
		var normal = assets[pair[0]].get_data()
		var hover = assets[pair[1]].get_data()
		var alpha_errors = 0
		var normal_light = 0.0
		var hover_light = 0.0
		for p in range(0, normal.size(), 4):
			if normal[p + 3] != hover[p + 3]:
				alpha_errors += 1
			normal_light += (.2126 * normal[p] + .7152 * normal[p + 1] + .0722 * normal[p + 2]) * normal[p + 3] / 255.0
			hover_light += (.2126 * hover[p] + .7152 * hover[p + 1] + .0722 * hover[p + 2]) * hover[p + 3] / 255.0
		require(alpha_errors == 0 and hover_light > normal_light, "Hover brightness/alignment " + pair[0])
		hud.state_checks.append({"pair": pair, "alpha_mask_errors": alpha_errors, "hover_brighter": true, "luminance_ratio": hover_light / normal_light})

func draw_asset(out, name, x, y, w, h, color = Color.WHITE):
	var im = nine(assets[name], w, h, SPECS[name][1])
	if color != Color.WHITE:
		im = tone(im, color)
	blend(out, im, x, y)

func draw_bar(out, x, y, width, fraction, color):
	draw_asset(out, "bar_track", x, y, width, 16)
	if fraction <= 0:
		return
	# Fraction is measured over the actual inner width, excluding the baked 2px rim.
	var fw = mini(width, 4 + roundi((width - 4) * fraction))
	if fw >= 16:
		draw_asset(out, "bar_fill", x, y, fw, 16, color)
	elif fw > 0:
		var minimum = tone(nine(assets.bar_fill, 16, 16, [8, 6, 8, 6]), color)
		out.blend_rect(minimum, Rect2i(0, 0, fw, 16), Vector2i(x, y))

func make_preview():
	var out = canvas(1152, 648)
	out.fill(Color8(40, 36, 70))
	draw_asset(out, "hud_plate", 48, 36, 1056, 124)
	draw_bar(out, 144, 108, 912, .7, Color(1, .20, .23))
	draw_asset(out, "hud_plate", 48, 184, 184, 44)
	draw_bar(out, 48, 292, 720, .5, Color(1, .76, .19))
	draw_bar(out, 48, 396, 720, .3, Color(1, .76, .19))
	draw_asset(out, "hud_plate", 848, 228, 256, 372)
	for i in range(3):
		var x = 890 + i * 80
		draw_asset(out, "scroll_track", x, 306, 12, 252)
		var name = ["scroll_grabber", "scroll_grabber_hover", "scroll_grabber_pressed"][i]
		draw_asset(out, name, x, 354, 12, 96)
	# Additional small source-faithful controls expose neutral tinting and 16px minimum fill.
	draw_bar(out, 48, 526, 160, .75, Color(.28, 1, .39))
	draw_bar(out, 248, 526, 160, .75, Color(1, .82, .17))
	draw_bar(out, 448, 526, 160, .75, Color(.25, .58, 1))
	draw_bar(out, 696, 526, 16, 1, Color(.25, .58, 1))
	require(out.save_png(asset_dir + "preview/hud-1152.png") == OK, "HUD preview")
	hud["preview"] = {"file": "preview/hud-1152.png", "canvas": [1152, 648], "background_rgb": [40, 36, 70], "boss_fraction": .7, "experience_fraction": .3, "slider_fraction": .5, "scroll_states": ["normal", "hover", "pressed"], "composition": "Decoded new runtime assets; only local Fira Sans labels and a heart placeholder are added by hud_preview_text.ps1."}

func _initialize():
	var report_path = asset_dir + "preview/checks.json"
	old_report = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	require(old_report is Dictionary, "Existing checks JSON")
	make_plate()
	make_bars()
	make_scroll()
	test_stretch("hud_plate", [Vector2i(120, 44), Vector2i(400, 64), Vector2i(1100, 400)])
	for name in ["bar_track", "bar_fill"]:
		test_stretch(name, [Vector2i(16, 16), Vector2i(200, 16), Vector2i(600, 16)])
	for name in ["scroll_track", "scroll_grabber", "scroll_grabber_hover", "scroll_grabber_pressed"]:
		test_stretch(name, [Vector2i(12, 48), Vector2i(12, 600)])
	state_checks()
	require(hud.files.size() == 9 and hud.stretch_cases.size() == 17, "HUD test counts")
	make_preview()
	hud["passed"] = true
	hud["visual_review"] = {"status": "pending", "reference": "concept/controls-v1.webp and preview/compare-v1.png"}
	hud["material_method"] = "Derived from the approved source-based runtime textures: original corner facets and bevels, repeated horizontal/vertical stretch samples; fill luminance remapped to neutral grayscale; gold tint of the same metal for slider core. No new generated atlas."
	old_report["hud"] = hud
	old_report["total_runtime_files"] = old_report.files.size() + hud.files.size()
	var file = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_report, "  ") + "\n")
	print("PASS HUD: 9 native lossless RGBA textures; 17 stretch cases; zero stretch/padding mismatches.")
	quit()
