extends Node
## Werkbank: der Reiter „Fortschritt" der Statistik als Bild für den Pitch, mit einem
## erfundenen Latein-Lernstand, als reports/stats/pitch_stats.png.
##
##     GODOT_WINDOW=1 tools/godot.sh --resolution 1920x1080 res://scenes/dev/pitch_stats.tscn
##
## Das Entwicklungsprofil wird weder umgeschaltet noch gespeichert: PlayerProgress bekommt
## nur im Speicher die Id eines zz-Profils und einen leeren Stand, auf den die Werkbank
## Antworten bucht. Geschrieben wird nichts.

const SCREEN_SCENE := "res://scenes/ui/stats_screen.tscn"
const SHOT_DIR := "res://reports/stats"
const BOOKS := ["access4", "latein"]
## Anteil gemeisterter Wörter je Unit; was fehlt, ist angefangen oder neu.
const SHARE := {"access4/1": 0.97, "access4/2": 0.81, "access4/3": 0.55, "access4/4": 0.21,
		"latein/1": 0.92, "latein/2": 0.58}


func _ready() -> void:
	TraceLog.enabled = false
	# Nur das Buch des Pitches, nur im Speicher: ohne _save() bleibt settings.cfg, wie es ist.
	UserSettings._config.set_value("scope", UserSettings.active_profile(), PackedStringArray(BOOKS))
	PlayerProgress.player_id = "zz-pitch"
	PlayerProgress.reset()
	var generator := WaveGenerator.new()
	var by_unit := {}
	for lexeme: Dictionary in ContentRegistry.lexemes.values():
		if str(lexeme.get("book", "")) not in BOOKS:
			continue
		var unit := "%s/%d" % [lexeme.get("book", ""), int(lexeme.get("unit", 0))]
		if not by_unit.has(unit):
			by_unit[unit] = []
		by_unit[unit].append(lexeme)
	for unit: String in by_unit:
		var lexemes: Array = by_unit[unit]
		lexemes.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
		var mastered := int(round(lexemes.size() * float(SHARE.get(unit, 0.0))))
		for i in lexemes.size():
			var times := 10 if i < mastered else (2 if i < mastered + lexemes.size() / 6 else 0)
			for id in generator.learnables_of(lexemes[i]):
				for n in times:
					PlayerProgress.record(str(id), true, 2500)
	var screen := (load(SCREEN_SCENE) as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	(screen.get_node("%Tabs").get_children()[1] as Button).button_pressed = true
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/pitch_stats.png" % dir
	get_viewport().get_texture().get_image().save_png(path)
	print("pitch_stats: ", path)
	get_tree().quit()
