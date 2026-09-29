extends SceneTree

func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/skill_tree/manifest.json"))
	assert(manifest.assets.size() == 30)
	assert(manifest.skill_icons.size() == 21)
	for entry in manifest.assets.values():
		var texture = load(entry.path) as Texture2D
		assert(texture != null, entry.path)
		assert(texture.get_width() == entry.width)
		assert(texture.get_height() == entry.height)
	print("PASS: 30 textures, 21 skill mappings")
	quit()
