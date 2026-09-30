extends SceneTree
## Rendert die Festung jeder Stufe (FortressModel, dieselbe wie im Kampf) als Bild für die
## Festungsanzeige der Karte: freigestellt, von der Feindseite, auf die Größe gebracht, in
## der das Medaillon sie zeigt. Einmal vorab statt 3D in der Karte.
##
##     GODOT_WINDOW=1 tools/godot.sh -s res://src/dev/fortress_icons.gd [-- --size=72]
##
## Kopflos gibt es kein Bild. Ausgabe: assets/ui/fortress/tiers/tier_<n>.webp (verlustfrei);
## danach `tools/godot.sh --import`.

const OUT_DIR := "res://assets/ui/fortress/tiers"
## Vielfaches der Zielgröße, in dem gerendert wird — Lanczos beim Verkleinern ersetzt MSAA.
const OVERSAMPLE := 8
## Blick schräg von vorn (Feindseite, -z) und oben, damit Tor und Burg zu sehen sind.
const VIEW := Vector3(-28.0, 200.0, 0.0)


func _initialize() -> void:
	var size := 72
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			size = int(arg.get_slice("=", 1))
	_render_all.call_deferred(size)


func _render_all(size: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for tier in 5:
		var img := await _render(tier, size * OVERSAMPLE)
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var path := "%s/tier_%d.webp" % [OUT_DIR, tier]
		var err := img.save_webp(ProjectSettings.globalize_path(path), false)
		print("fortress_icons: %s (%d×%d) %s" % [path, size, size, error_string(err)])
	quit(0)


func _render(tier: int, px: int) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(px, px)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, VIEW.y - 35.0, 0.0)
	sun.light_energy = 1.1
	view.add_child(sun)

	var fort := Node3D.new()
	view.add_child(fort)
	FortressModel.build(fort, tier, 0.0, func(_x: float, _z: float) -> float: return 0.0)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	camera.rotation_degrees = VIEW
	_frame(camera, fort)

	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	view.queue_free()
	return img


## Richtet die Kamera so aus, dass die Festung das Bild mit etwas Rand füllt.
func _frame(camera: Camera3D, fort: Node3D) -> void:
	var inv := camera.global_transform.basis.inverse()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for mesh: MeshInstance3D in fort.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		for i in 8:
			var p := inv * box.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
	var centre := camera.global_transform.basis * ((lo + hi) * 0.5)
	var extent := hi - lo
	camera.size = maxf(extent.x, extent.y) * 1.08
	camera.global_position = centre + camera.global_transform.basis.z * (extent.z + 20.0)
	camera.far = extent.z + 60.0
