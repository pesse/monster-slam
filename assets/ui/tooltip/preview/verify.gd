extends SceneTree

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/tooltip/manifest.json"))
	assert(manifest.assets.size() == 5)
	for entry in manifest.assets.values():
		var texture = load(entry.path) as Texture2D
		assert(texture != null, entry.path)
		assert(texture.get_width() == entry.width)
		assert(texture.get_height() == entry.height)
	for file in ["frame_only.tres", "textured_panel.tres"]:
		assert(load("res://assets/ui/tooltip/" + file) is StyleBoxTexture)
	var shell = load("res://assets/ui/tooltip/tooltip_shell.tscn").instantiate()
	root.add_child(shell)
	assert(shell.get_node("Body/Content") is VBoxContainer)
	print("PASS: 5 general tooltip textures, 2 styles, example scene")
	quit()
