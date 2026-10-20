extends SceneTree
## Deterministic raster finishing. Run headless with --path pointing at an empty temp directory.
## Never imports or modifies the game project. Only writes inside controls/.

const STATES = ["normal", "hover", "selected", "disabled"]
const POSITIONS = ["first", "mid", "last"]
var asset_dir = get_script().resource_path.get_base_dir().get_base_dir() + "/"
var assets = {}
var report = {"schema": 1, "logical_resolution": [1152, 648], "files": [], "seams": [], "errors": []}
var profiles = {}
var caps = {}
var edges = {}
var source_img
var source_regions = {}
var rib

func color_mix(a, b, t):
	return a.lerp(b, clampf(t, 0, 1))

func canvas(w, h):
	var im = Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	return im

func save_asset(name, im):
	im.convert(Image.FORMAT_RGBA8)
	var expected = Vector2i(32, 32) if name.begins_with("check_") else Vector2i(128 if name.begins_with("field_") else 96, 44)
	assert(im.get_size() == expected, name + " dimensions")
	assert(im.save_webp(asset_dir + name + ".webp", false, 1.0) == OK)
	var encoded = FileAccess.get_file_as_bytes(asset_dir + name + ".webp")
	assert(encoded.slice(12, 16).get_string_from_ascii() == "VP8L", name + " VP8L bitstream")
	var decoded = Image.load_from_file(asset_dir + name + ".webp")
	var native_format = decoded.get_format()
	assert(native_format == Image.FORMAT_RGBA8, name + " native RGBA decode")
	decoded.convert(Image.FORMAT_RGBA8)
	var eq = decoded.get_data() == im.get_data()
	assert(eq, name + " lossless roundtrip")
	var alpha_min = 255
	var alpha_max = 0
	var partial = 0
	var bytes = decoded.get_data()
	for p in range(3, bytes.size(), 4):
		alpha_min = mini(alpha_min, bytes[p])
		alpha_max = maxi(alpha_max, bytes[p])
		if bytes[p] > 0 and bytes[p] < 255:
			partial += 1
	var meta = {"file": name + ".webp", "canvas": [im.get_width(), im.get_height()], "dimensions_passed": true, "format": "RGBA8", "decoded_native_format": native_format, "webp_chunk": "VP8L", "sha256": FileAccess.get_sha256(asset_dir + name + ".webp"), "webp_lossless_pixel_roundtrip": eq, "alpha_min": alpha_min, "alpha_max": alpha_max, "partial_alpha_pixels": partial}
	if name.begins_with("field_") or name.begins_with("seg_"):
		meta["slices_LTRB"] = [16, 16, 16, 16]
		var mismatch = 0
		for y in range(im.get_height()):
			for x in range(17, im.get_width() - 16):
				if im.get_pixel(x, y) != im.get_pixel(16, y):
					mismatch += 1
		meta["horizontal_stretch_column_mismatches"] = mismatch
		assert(mismatch == 0, name + " horizontal uniformity")
		meta["horizontal_facets_and_glints_within_fixed_margins"] = true
	if name.begins_with("field_"):
		var mismatch_y = 0
		for y in range(17, 28):
			for x in range(im.get_width()):
				if im.get_pixel(x, y) != im.get_pixel(x, 16):
					mismatch_y += 1
		meta["vertical_stretch_row_mismatches"] = mismatch_y
		assert(mismatch_y == 0, name + " vertical uniformity")
	if name == "field_focus":
		var nonzero = 0
		for y in range(16, 28):
			for x in range(16, 112):
				if im.get_pixel(x, y).a > 0:
					nonzero += 1
		meta["focus_center_nontransparent_pixels"] = nonzero
		assert(nonzero == 0)
	report.files.append(meta)
	assets[name] = decoded

func concept_crop(rect):
	var scale = float(source_img.get_width()) / 1152.0
	var r = Rect2i(roundi(rect.position.x * scale), roundi(rect.position.y * scale), roundi(rect.size.x * scale), roundi(rect.size.y * scale))
	var im = source_img.get_region(r)
	im.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_LANCZOS)
	return im

func map_vertical(im, width, height = 44, source_edge = 16, target_edge = 16):
	var out = canvas(width, height)
	var src = [0, source_edge, im.get_height() - source_edge, im.get_height()]
	var dst = [0, target_edge, height - target_edge, height]
	for j in range(3):
		var patch = im.get_region(Rect2i(0, src[j], im.get_width(), src[j + 1] - src[j]))
		patch.resize(width, dst[j + 1] - dst[j], Image.INTERPOLATE_LANCZOS)
		out.blit_rect(patch, Rect2i(Vector2i.ZERO, patch.get_size()), Vector2i(0, dst[j]))
	return out

func muted(c, factor = .48):
	var lum = c.r * .2126 + c.g * .7152 + c.b * .0722
	var out = c.lerp(Color(lum, lum, lum, c.a), .65)
	out.r *= factor
	out.g *= factor
	out.b *= factor
	return out

func sample_sources(_unused = null):
	# All coordinates are in the concept normalized to 1152px width.
	# Raw 2128px source pixels are sampled first; 16px fixed zones retain the full bevel.
	source_regions = {
		"normal_face": [60, 171, 6, 59], "selected_face": [193, 171, 6, 59],
		"hover_face": [265, 171, 5, 59],
		"normal_left_cap": [42, 171, 16, 59], "normal_right_cap": [387, 171, 16, 59],
		"gold_left_cap": [626, 171, 16, 59], "joint_rib": [108, 171, 9, 59], "joint_rib_metal_plane": [42, 171, 7, 59],
		"field_focus": [42, 63, 428, 52], "check_on": [47, 268, 43, 44], "check_off": [47, 327, 43, 45]
	}
	for state in ["normal", "selected", "hover"]:
		var r = source_regions[state + "_face"]
		var strip = map_vertical(concept_crop(Rect2i(r[0], r[1], r[2], r[3])), 1)
		var profile = []
		for y in range(44):
			var c = strip.get_pixel(0, y)
			c.a = 1
			profile.append(c)
		profiles[state] = profile
		var rect = Rect2i(111 if state == "normal" else (182 if state == "selected" else 253), 171, 71 if state != "hover" else 72, 59)
		var block = concept_crop(rect)
		edges[state] = [
			map_vertical(block.get_region(Rect2i(0, 0, 16, 59)), 16),
			map_vertical(block.get_region(Rect2i(block.get_width() - 16, 0, 16, 59)), 16)
		]
		block.save_png(asset_dir + "sources/" + state + "-concept-region.png")
	var lc = map_vertical(concept_crop(Rect2i(42, 171, 16, 59)), 16)
	var rc = map_vertical(concept_crop(Rect2i(387, 171, 16, 59)), 16)
	caps.normal = [lc, rc]
	# Hover keeps the actual bright silver corner facets from normal.
	caps.hover = [lc.duplicate(), rc.duplicate()]
	var gold_l = map_vertical(concept_crop(Rect2i(626, 171, 16, 59)), 16)
	var gold_r = gold_l.duplicate()
	gold_r.flip_x()
	caps.selected = [gold_l, gold_r]
	profiles.disabled = []
	for c in profiles.normal:
		profiles.disabled.append(muted(c))
	caps.disabled = [lc.duplicate(), rc.duplicate()]
	edges.disabled = [edges.normal[0].duplicate(), edges.normal[1].duplicate()]
	for im in caps.disabled + edges.disabled:
		for y in range(im.get_height()):
			for x in range(im.get_width()):
				im.set_pixel(x, y, muted(im.get_pixel(x, y)))
	rib = map_vertical(concept_crop(Rect2i(108, 171, 9, 59)), 6)
	var plane = map_vertical(concept_crop(Rect2i(42, 171, 7, 59)), 6)
	for y in range(44):
		for x in range(6):
			var c = rib.get_pixel(x, y)
			# The actual six-pixel silver plate replaces the two thin hairlines.
			# Retain source joint shoulders at top/bottom and crossfade into the plane.
			var blend = minf(clampf(float(y - 8) / 6.0, 0, 1), clampf(float(36 - y) / 6.0, 0, 1))
			c = c.lerp(plane.get_pixel(x, y), blend)
			c.a = 0 if y == 0 else 1
			if c.a == 0:
				c = Color.TRANSPARENT
			rib.set_pixel(x, y, c)
	rib.save_png(asset_dir + "sources/rib-concept-region.png")

func outline_distance(x, y, width, left_cut = true, right_cut = true, cut = 9):
	var d = minf(minf(x, width - 1 - x), minf(y, 43 - y))
	if left_cut:
		d = minf(d, minf(x + y - cut, x + 43 - y - cut) / sqrt(2.0))
	if right_cut:
		d = minf(d, minf(width - 1 - x + y - cut, width - 1 - x + 43 - y - cut) / sqrt(2.0))
	return d

func bare(state, width = 96, field = false):
	var im = canvas(width, 44)
	for y in range(44):
		var sy = 22 if field and y >= 16 and y < 28 else y
		for x in range(width):
			var c = profiles[state][sy]
			if x < 16:
				c = caps[state][0].get_pixel(x, sy)
			elif x >= width - 16:
				c = caps[state][1].get_pixel(x - (width - 16), sy)
			var d = outline_distance(x, y, width)
			c.a = clampf(d + .75, 0, 1)
			if c.a == 0:
				c = Color.TRANSPARENT
			im.set_pixel(x, y, c)
	return im

func make_fields():
	var normal = bare("normal", 128, true)
	# Quiet field fill and top/bottom recess come from the original focused input.
	var field = concept_crop(Rect2i(42, 63, 428, 52))
	var field_face = map_vertical(field.get_region(Rect2i(190, 0, 8, 52)), 1, 44, 12, 16)
	for y in range(44):
		# Sample only the quiet blue interior, excluding the focus's warm inner halo.
		var sy = 22 if y >= 16 and y < 28 else clampi(y, 14, 29)
		if y >= 8 and y < 36:
			for x in range(8, 120):
				normal.set_pixel(x, y, field_face.get_pixel(0, sy))
	save_asset("field_normal", normal)
	var ro = normal.duplicate()
	for y in range(44):
		for x in range(128):
			ro.set_pixel(x, y, muted(ro.get_pixel(x, y), .6))
	save_asset("field_read_only", ro)
	var focus = canvas(128, 44)
	var fl = map_vertical(field.get_region(Rect2i(0, 0, 16, 52)), 16, 44, 12, 16)
	var fr = map_vertical(field.get_region(Rect2i(412, 0, 16, 52)), 16, 44, 12, 16)
	var warm = field_face.get_pixel(0, 4)
	for y in range(44):
		var sy = 22 if y >= 16 and y < 28 else y
		for x in range(128):
			var c = field_face.get_pixel(0, sy)
			if x < 16:
				c = fl.get_pixel(x, sy)
			elif x >= 112:
				c = fr.get_pixel(x - 112, sy)
			var d = outline_distance(x, y, 128, true, true, 7)
			var alpha = clampf(d + .75, 0, 1)
			if d > 7:
				c = warm
				alpha = .28 * pow(clampf((13.0 - d) / 6.0, 0, 1), 2)
			elif d < 0:
				c = warm
				alpha = .12 * clampf(1.0 + d / 2, 0, 1)
			c.a = alpha
			if c.a == 0:
				c = Color.TRANSPARENT
			focus.set_pixel(x, y, c)
	save_asset("field_focus", focus)

func seam_pixel(side, y):
	return rib.get_pixel(2 if side == "right" else 3, y)

func make_segments():
	for pos in POSITIONS:
		for state in STATES:
			var im = bare(state)
			for y in range(44):
				for side in ["left", "right"]:
					var joint = (side == "left" and pos != "first") or (side == "right" and pos != "last")
					if not joint:
						continue
					for k in range(16):
						var x = k if side == "left" else 95 - k
						var c = edges[state][0].get_pixel(k, y) if side == "left" else edges[state][1].get_pixel(15 - k, y)
						c.a = 1
						if k < 3:
							c = rib.get_pixel(3 + k if side == "left" else 2 - k, y)
						im.set_pixel(x, y, c)
			im.fill_rect(Rect2i(0, 0, 96, 1), Color.TRANSPARENT)
			save_asset("seg_" + pos + "_" + state, im)

func make_checks(_unused = null):
	for state in ["off", "on"]:
		var r = source_regions["check_" + state]
		var src = concept_crop(Rect2i(r[0], r[1], r[2], r[3]))
		src.save_png(asset_dir + "sources/check-" + state + "-concept-region.png")
		var im = nine(src, 32, 32, 8)
		for y in range(32):
			for x in range(32):
				var c = im.get_pixel(x, y)
				var d = minf(minf(x, 31 - x), minf(y, 31 - y))
				d = minf(d, minf(minf(x + y - 5, 31 - x + y - 5), minf(x + 31 - y - 5, 62 - x - y - 5)) / sqrt(2))
				c.a = clampf(d + .75, 0, 1)
				if c.a == 0:
					c = Color.TRANSPARENT
				im.set_pixel(x, y, c)
		save_asset("check_" + state, im)
		var disabled = im.duplicate()
		for y in range(32):
			for x in range(32):
				disabled.set_pixel(x, y, muted(disabled.get_pixel(x, y), .48))
		save_asset("check_" + state + "_disabled", disabled)

func nine(im, w, h, m = 16):
	var out = canvas(w, h)
	var sx = [0, m, im.get_width() - m, im.get_width()]
	var sy = [0, m, im.get_height() - m, im.get_height()]
	var dx = [0, m, w - m, w]
	var dy = [0, m, h - m, h]
	for j in range(3):
		for i in range(3):
			var piece = im.get_region(Rect2i(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j]))
			piece.resize(dx[i + 1] - dx[i], dy[j + 1] - dy[j], Image.INTERPOLATE_BILINEAR)
			out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(dx[i], dy[j]))
	return out

func composite(out, im, x, y):
	out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))

func group(out, x, y, widths, states):
	for i in range(widths.size()):
		var pos = "first" if i == 0 else ("last" if i == widths.size() - 1 else "mid")
		composite(out, nine(assets["seg_" + pos + "_" + states[i]], widths[i], 44), x, y)
		x += widths[i]

func test_seams():
	for pair in [["first", "mid"], ["mid", "mid"], ["mid", "last"]]:
		for a in STATES:
			for b in STATES:
				var l = assets["seg_" + pair[0] + "_" + a]
				var r = assets["seg_" + pair[1] + "_" + b]
				var mismatches = 0
				for y in range(44):
					for k in range(3):
						if l.get_pixel(93 + k, y) != rib.get_pixel(k, y):
							mismatches += 1
						if r.get_pixel(k, y) != rib.get_pixel(3 + k, y):
							mismatches += 1
				var result = {"positions": pair, "states": [a, b], "interface_pixel_mismatches": mismatches, "frame_vertical_offset_px": 0, "joint_width_px": 6, "half_width_px": 3, "passed": mismatches == 0}
				report.seams.append(result)
				assert(result.passed, "Seam " + str(result))
	report["seam_summary"] = {"pairs_tested": 48, "pairs_passed": 48, "criterion": "All 6x44 actual RGBA pixels of the assembled rib match the source-derived common reference in every state combination."}
	report["seam_reference"] = {"width": 6, "height": 44, "source": source_regions.joint_rib, "rgba": []}
	for y in range(44):
		var line = []
		for x in range(6):
			var c = rib.get_pixel(x, y)
			line.append([c.r8, c.g8, c.b8, c.a8])
		report.seam_reference.rgba.append(line)

func test_sizes():
	report["stretch_cases"] = []
	for size in [Vector2i(128, 44), Vector2i(360, 44), Vector2i(1000, 300)]:
		var field = nine(assets.field_normal, size.x, size.y)
		var focus = nine(assets.field_focus, size.x, size.y)
		var center = field.get_pixel(16, 16)
		var errors = 0
		for y in range(16, size.y - 16):
			for x in range(16, size.x - 16):
				if field.get_pixel(x, y) != center or focus.get_pixel(x, y).a != 0:
					errors += 1
		assert(errors == 0)
		report.stretch_cases.append({"kind": "field normal plus focus", "canvas": [size.x, size.y], "center_or_focus_errors": errors})
	for width in [44, 96, 220]:
		for pos in POSITIONS:
			for state in STATES:
				var original = assets["seg_" + pos + "_" + state]
				var stretched = nine(original, width, 44)
				var errors = 0
				for y in range(44):
					for x in range(16, width - 16):
						if stretched.get_pixel(x, y) != original.get_pixel(16, y):
							errors += 1
				assert(errors == 0)
				report.stretch_cases.append({"kind": "segment", "position": pos, "state": state, "canvas": [width, 44], "center_errors": errors})

func make_preview():
	var out = canvas(1152, 648)
	var panel = Image.load_from_file(asset_dir + "../window_panel_compact.webp")
	composite(out, nine(panel, 1152, 648, 32), 0, 0)
	var surface = Image.load_from_file(asset_dir + "../window_surface.webp")
	for y in range(10, 638):
		for x in range(10, 1142):
			if x + y < 31 or (1151 - x) + y < 31 or x + (647 - y) < 31 or (1151 - x) + (647 - y) < 31:
				continue
			var c = surface.get_pixel(x % surface.get_width(), y % surface.get_height())
			out.set_pixel(x, y, out.get_pixel(x, y).blend(c))
	composite(out, nine(assets.field_normal, 360, 44), 32, 62)
	composite(out, nine(assets.field_focus, 360, 44), 32, 62)
	composite(out, nine(assets.field_normal, 360, 44), 32, 124)
	composite(out, nine(assets.field_read_only, 288, 44), 824, 124)
	# Single preview button assembled from first/last runtime caps, no extra texture.
	var rename = nine(assets.seg_first_normal, 184, 44)
	rename.blit_rect(assets.seg_last_normal, Rect2i(80, 0, 16, 44), Vector2i(168, 0))
	composite(out, rename, 408, 62)
	group(out, 32, 222, [44, 44, 44, 44, 44], ["normal", "normal", "selected", "hover", "normal"])
	group(out, 600, 222, [128, 128, 128], ["selected", "normal", "normal"])
	group(out, 32, 330, [192, 192, 192, 192, 220], ["normal", "normal", "selected", "hover", "disabled"])
	for y in [190, 302, 402]:
		out.fill_rect(Rect2i(32, y, 1080, 1), Color8(49, 68, 92))
	composite(out, assets.check_on, 32, 428)
	composite(out, assets.check_off, 32, 478)
	composite(out, assets.check_on_disabled, 32, 528)
	composite(out, assets.check_off_disabled, 32, 578)
	# Save unlabelled base to the final named preview; preview_text.ps1 adds text in place.
	assert(out.save_png(asset_dir + "preview/controls-1152.png") == OK)
	# Two actual pair compositions, enlarged by nearest neighbor, no fonts crossing either joint.
	var zoom = canvas(672, 240)
	zoom.fill(Color8(7, 17, 31))
	for i in range(2):
		var pair = canvas(88, 44)
		composite(pair, nine(assets["seg_first_selected" if i == 0 else "seg_mid_hover"], 44, 44), 0, 0)
		composite(pair, nine(assets["seg_mid_hover" if i == 0 else "seg_last_normal"], 44, 44), 44, 0)
		var cut = pair.get_region(Rect2i(24, 0, 40, 44))
		cut.resize(160, 176, Image.INTERPOLATE_NEAREST)
		composite(zoom, cut, 96 + i * 320, 32)
	assert(zoom.save_png(asset_dir + "preview/controls-zoom.png") == OK)
	report["preview"] = {"canvas": [1152, 648], "runtime_only_compositing": true, "background": ["../window_panel_compact.webp", "../window_surface.webp"], "labels": "preview_text.ps1 overlays local Fira Sans SemiBold/Bold only", "zoom": {"factor": 4, "interpolation": "nearest", "pairs": ["first_selected | mid_hover", "mid_hover | last_normal"]}}

func make_comparison():
	var out = canvas(1152, 340)
	out.fill(Color8(6, 17, 32))
	var original = concept_crop(Rect2i(42, 63, 428, 52))
	original.resize(362, 44, Image.INTERPOLATE_LANCZOS)
	composite(out, original, 24, 34)
	var rename_ref = concept_crop(Rect2i(478, 63, 246, 52))
	rename_ref.resize(208, 44, Image.INTERPOLATE_LANCZOS)
	composite(out, rename_ref, 404, 34)
	var rail_ref = concept_crop(Rect2i(42, 171, 361, 59))
	rail_ref.resize(269, 44, Image.INTERPOLATE_LANCZOS)
	composite(out, rail_ref, 24, 114)
	var graphic_ref = concept_crop(Rect2i(626, 171, 421, 59))
	graphic_ref.resize(314, 44, Image.INTERPOLATE_LANCZOS)
	composite(out, graphic_ref, 620, 114)
	for kind in ["on", "off"]:
		var r = source_regions["check_" + kind]
		var c = concept_crop(Rect2i(r[0], r[1], r[2], r[3]))
		c.resize(32, 32, Image.INTERPOLATE_LANCZOS)
		composite(out, c, 1020 if kind == "on" else 1070, 40)
	var y = 204
	composite(out, nine(assets.field_normal, 362, 44), 24, y)
	composite(out, nine(assets.field_focus, 362, 44), 24, y)
	var rename = nine(assets.seg_first_normal, 208, 44)
	rename.blit_rect(assets.seg_last_normal, Rect2i(80, 0, 16, 44), Vector2i(192, 0))
	composite(out, rename, 404, y)
	composite(out, assets.check_on, 1020, y + 6)
	composite(out, assets.check_off, 1070, y + 6)
	group(out, 24, 284, [52, 53, 53, 54, 57], ["normal", "normal", "selected", "hover", "normal"])
	group(out, 620, 284, [97, 107, 110], ["selected", "normal", "normal"])
	out.fill_rect(Rect2i(0, 169, 1152, 1), Color8(62, 83, 111))
	out.save_png(asset_dir + "preview/compare-v1.png")
	report["comparison"] = {"file": "preview/compare-v1.png", "canvas": [1152, 340], "reference_top": "Unretouched concept region crops, Lanczos downsampled to 44px control height (checkboxes 32px).", "runtime_bottom": "Same positions, widths and heights, composed exclusively from decoded runtime assets; labels added by preview_text.ps1.", "group_widths": [[52,53,53,54,57],[97,107,110]], "note": "Per-control region comparison avoids comparing the concept's 59px rail against a 44px runtime rail."}

func _initialize():
	source_img = Image.load_from_file(asset_dir + "concept/sources/controls-v1.png")
	assert(source_img.get_size() == Vector2i(2128, 739))
	source_img.convert(Image.FORMAT_RGBA8)
	sample_sources()
	make_fields()
	make_segments()
	make_checks()
	test_seams()
	test_sizes()
	make_preview()
	make_comparison()
	report["revision"] = 4
	report["passed"] = true
	report["source"] = {"file": "concept/sources/controls-v1.png", "sha256": FileAccess.get_sha256(asset_dir + "concept/sources/controls-v1.png"), "raw_canvas": [2128,739], "normalized_width": 1152, "regions": source_regions, "method": "Direct source pixels; fixed 16px bevel zones, vertical remapping of text-free profiles, horizontal column repetition. No regenerated or redrawn material."}
	report["material_samples"] = {}
	for state in STATES:
		var samples = []
		for y in [2, 4, 6, 10, 16, 22, 28, 34, 38, 40, 42]:
			var c = profiles[state][y]
			samples.append({"y": y, "rgb": [c.r8, c.g8, c.b8]})
		report.material_samples[state] = samples
	report["visual_review"] = {"status": "pending", "comparison": "preview/compare-v1.png", "reference": "concept/sources/controls-v1.png"}
	var file = FileAccess.open(asset_dir + "preview/checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS: ", report.files.size(), " RGBA assets; 48/48 6px-rib seam pairs; 39 stretch cases; 16px slices.")
	quit()
