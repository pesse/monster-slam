extends Node
## Werkbank: der Bosskampf als Bild für den Pitch — ein eigener Satz, ein erfundenes Modell
## mit Urteil und Erklärung, als reports/boss/pitch_boss.png.
##
##     GODOT_WINDOW=1 tools/godot.sh --resolution 1920x1080 res://scenes/dev/pitch_boss.tscn
##
## Es startet kein llama-server, und die Spur ist für diesen Lauf aus: nichts landet im
## Entwicklungsprofil.

const FIGHT_SCENE := "res://scenes/battle/boss_fight.tscn"
const SHOT_DIR := "res://reports/boss"

const SENTENCE := {
	"id": "sen.zz.pitch",
	"source_text": "Gestern haben wir das Riff gesehen.",
	"reference_translation": "Yesterday we saw the reef.",
	"accepted": ["We saw the reef yesterday."],
	"grammar_tags": ["past_simple"],
}
const ANSWER := "Yesterday we have seen the reef."
const EXPLANATION := "Mit „yesterday“ steht die Handlung abgeschlossen in der Vergangenheit — dafür nimmt das Englische das simple past: „we saw“, nicht „we have seen“."

var _fight: Control


func _ready() -> void:
	TraceLog.enabled = false
	_fight = (load(FIGHT_SCENE) as PackedScene).instantiate() as Control
	_fight.start_service = false
	_fight.record_wins = false
	_fight.fake_backend = func(_s: Dictionary, _a: String, on_done: Callable) -> void:
		on_done.call_deferred({"quality": 0.0, "feedback": ""})
	_fight.fake_explainer = func(_s: Dictionary, _a: String, on_done: Callable) -> void:
		on_done.call_deferred({"mistake": true, "explanation": EXPLANATION})
	add_child(_fight)
	# Fünf Sätze wie im echten Kampf; gezeigt wird nur der erste.
	_fight.begin(ContentRegistry.get_entry("bosses", "boss.grammar_golem"),
			[SENTENCE, SENTENCE, SENTENCE, SENTENCE, SENTENCE])
	await get_tree().create_timer(4.0).timeout
	(_fight.get_node("%AnswerEdit") as LineEdit).text = ANSWER
	(_fight.get_node("%SubmitButton") as Button).pressed.emit()
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for ms: int in [400, 2500]:
		await get_tree().create_timer(ms / 1000.0).timeout
		await RenderingServer.frame_post_draw
		var path := "%s/pitch_boss_%04d.png" % [dir, ms]
		get_viewport().get_texture().get_image().save_png(path)
		print("pitch_boss: ", path)
	get_tree().quit()
