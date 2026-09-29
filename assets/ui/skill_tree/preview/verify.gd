extends SceneTree

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/skill_tree/manifest.json"))
	assert(manifest.assets.size() == 35)
	assert(manifest.skill_icons.size() == 21)
	for entry in manifest.assets.values():
		var texture = load(entry.path) as Texture2D
		assert(texture != null, entry.path)
		assert(texture.get_width() == entry.width)
		assert(texture.get_height() == entry.height)
	for file in ["frame_only.tres", "textured_panel.tres"]:
		assert(load("res://assets/ui/skill_tree/tooltip/" + file) is StyleBoxTexture)
	var shell = load("res://assets/ui/skill_tree/tooltip/tooltip_shell.tscn").instantiate()
	root.add_child(shell)
	assert(shell.get_node("Body/Content") is VBoxContainer)
	shell.size = Vector2(400, 220)
	print("PASS: 35 textures, 21 skill mappings, 2 styles, tooltip scene")
	quit()
