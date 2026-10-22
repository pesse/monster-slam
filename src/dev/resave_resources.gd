extends SceneTree
## Speichert .tscn/.tres so, wie der Editor sie schreibt (uid, unique_id der Knoten,
## Reihenfolge, keine Standardwerte) — sonst schreibt der Editor sie beim nächsten Öffnen
## um. Braucht `--editor` (nur dann schreibt Godot Uids) und einen geschlossenen Editor.
## Wiederholen, bis `git diff` leer bleibt: ein Verweis bekommt die Uid erst, wenn sein
## Ziel eine hat, und eine Instanz verliert Werte erst, wenn ihre Szene sie selbst trägt.
##     tools/godot.sh --editor -s res://src/dev/resave_resources.gd -- $(git ls-files '*.tscn' '*.tres' | grep -v '^addons/')


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty() or not Engine.is_editor_hint():
		push_error("resave_resources: --editor -s … -- <pfad> …")
		quit(1)
		return
	var failed := 0
	for path in paths:
		var res_path: String = path if path.begins_with("res://") else "res://" + path
		var err := _resave(res_path)
		if err != OK:
			push_error("resave_resources: %s: %s" % [res_path, error_string(err)])
			failed += 1
	print("resave_resources: %d Dateien, %d Fehler" % [paths.size(), failed])
	quit(0 if failed == 0 else 1)


func _resave(path: String) -> Error:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return ERR_CANT_OPEN
	if not res is PackedScene:
		return ResourceSaver.save(res, path)
	# Die unique_id der Knoten entstehen erst beim Packen, wie im Editor.
	var root := (res as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if root == null:
		return ERR_CANT_CREATE
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		return err
	return ResourceSaver.save(packed, path)
