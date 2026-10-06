extends Node
## Werkbank: die Karten zwischen den Wellen als Bild — Wellenabschluss, Auflösung,
## Rückfrage — über dem Schlachtfeld, mit erfundenen Werten.
##
## Ein echter Kampf spielt im Entwicklungsprofil und schreibt Lernstand und Spur (CLAUDE.md);
## hier wird nichts verbucht. Die Kiste meldet ihr Gold nur per Signal, und daran hängt hier
## niemand. Statt Vokabeln stehen Füllwörter auf den Karten.
##
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/wave_card_lab.tscn -- --snap
##         speichert reports/wave_cards/<karte>_<breite>x<höhe>.png und beendet sich.
##     … -- --snap --card=result       Ergebnis mit Kiste (Voreinstellung)
##     … -- --snap --card=opened       … Kiste geöffnet
##     … -- --snap --card=levelup      … mit Aufstieg und Meisterung in der Sitzung
##     … -- --snap --card=consolation  Trostwort statt Kiste
##     … -- --snap --card=next         Stufe 2 nach einem Sieg, mit Sitzungsbilanz
##     … -- --snap --card=defeat       Stufe 2 nach einer Niederlage
##     … -- --snap --card=reveal       die Auflösung der Vokabeln
##     … -- --snap --card=confirm      die Rückfrage (wie „Welle auflösen")
##     … -- --snap --size=1920x1080    anderes Fenster (Bezugsgröße nach Menügröße, UiScale)
##
## Ohne `--snap` bleibt das Fenster offen: unten links schalten ◀/▶ (oder Bild↑/Bild↓)
## durch alle Karten. Die Karten sind echt — die Kiste lässt sich öffnen, Knöpfe blättern.
##
## Headless gibt es keinen Renderer — deshalb GODOT_WINDOW=1. `--snap` statt `--shoot`:
## das Schlachtfeld kommt aus `battle_theme_lab`, und das reagiert selbst auf `--shoot`.

const FIELD_SCENE := "res://scenes/dev/battle_theme_lab.tscn"
const STATS_SCENE := "res://scenes/ui/wave_stats.tscn"
const REVEAL_SCENE := "res://scenes/ui/leak_reveal.tscn"
const CONFIRM_SCENE := "res://scenes/ui/confirm_dialog.tscn"
const SHOT_DIR := "res://reports/wave_cards"
## So lange steht das Bild, bevor es gespeichert wird: Kiste, Einblenden, Karussell.
const SETTLE := 2.5
## Alle Karten in der Reihenfolge des Umschalters.
const CARDS: Array[String] = ["result", "opened", "levelup", "consolation", "next", "defeat",
		"reveal", "confirm"]

var _index := 0


func _ready() -> void:
	var size := _arg("size")
	if not size.is_empty():
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var field := (load(FIELD_SCENE) as PackedScene).instantiate()
	add_child(field)
	# Die Regler der Themen-Werkbank (oben links) gibt es im Kampf nicht.
	(field.get_node("UI") as CanvasLayer).visible = false
	_index = maxi(CARDS.find(_card_name()), 0)
	%Prev.pressed.connect(_step.bind(-1))
	%Next.pressed.connect(_step.bind(1))
	_show_card()
	if _has_arg("snap"):
		%Switcher.visible = false
		_snap.call_deferred(CARDS[_index])


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_PAGEUP:
		_step(-1)
	elif key.keycode == KEY_PAGEDOWN:
		_step(1)


func _step(delta: int) -> void:
	_index = posmod(_index + delta, CARDS.size())
	_show_card()


## Baut die Karte neu auf: jede Karte bekommt eine frische Szene, wie im Kampf.
func _show_card() -> void:
	var layer := %Cards as CanvasLayer
	for old in layer.get_children():
		layer.remove_child(old)
		old.queue_free()
	var card := CARDS[_index]
	%CardName.text = card
	%Position.text = "%d / %d · Bild↑ Bild↓" % [_index + 1, CARDS.size()]
	match card:
		"reveal":
			var reveal := (load(REVEAL_SCENE) as PackedScene).instantiate() as Control
			layer.add_child(reveal)
			reveal.call("play", _reveal_items())
		"confirm":
			var dialog := (load(CONFIRM_SCENE) as PackedScene).instantiate() as ConfirmDialog
			layer.add_child(dialog)
			dialog.ask("Welle auflösen?", "Alle Monster auf dem Feld verschwinden; die Welle "
					+ "zählt als geräumt, bringt aber keine Punkte.", "Auflösen")
		_:
			var stats := (load(STATS_SCENE) as PackedScene).instantiate() as Control
			layer.add_child(stats)
			stats.call("show_stats", _wave_data(card))
			if card in ["opened", "next"]:
				var chest := stats.get_node("%Chest") as TreasureChest
				chest.begin_hold()
				chest.hold(TreasureChest.HOLD_TIME)
			if card in ["next", "defeat"]:
				(stats.get_node("%ResultContinue") as Button).pressed.emit()


func _card_name() -> String:
	var card := _arg("card")
	return "result" if card.is_empty() else card


func _wave_data(card: String) -> Dictionary:
	var won := card != "defeat"
	var data := {
		"won": won, "wave_number": 3, "difficulty": 3,
		"correct": 7, "leaked": 2, "total": 9, "accuracy": 78.0,
		"score_gained": 60, "score_total": 180, "fortress_health": 75 if won else 0,
		"mastered": 12, "fortress_tier": 1, "xp_gained": 45, "levels_gained": 0,
		"chest": ChestReward.for_wave(60, 7, 2),
		"session": _balance(),
	}
	if card == "levelup":
		data["levels_gained"] = 1
	if card == "consolation":
		data["correct"] = 0
		data["leaked"] = 9
		data["chest"] = ChestReward.for_wave(0, 0, 9)
	return data


## Die Sitzungsbilanz mit Füllwörtern, eine davon zurückerobert und ein Überhang.
func _balance() -> Dictionary:
	var words: Array = []
	for i in 6:
		words.append({"label": "lorem-%d → ipsum-%d" % [i, i], "misses": 4 if i == 0 else 0,
				"comeback": i == 0})
	return {"waves_cleared": 3 if CARDS[_index] != "defeat" else 2, "wave_reached": 3,
			"answers": 41, "correct": 33, "mastered": words.size(), "comeback": 1,
			"words": words}


func _reveal_items() -> Array:
	return [
		{"prompt": "Lorem ipsum", "prompt_alt": [], "answers": ["dolor", "sit amet"],
		"lexeme_type": "noun", "meaning": "", "source_id": "zz-lab-1",
		"learnable_id": "zz-lab-1", "leaked": true},
		{"prompt": "consetetur", "prompt_alt": ["sadipscing"], "answers": ["elitr"],
		"lexeme_type": "verb", "meaning": "", "source_id": "zz-lab-2",
		"learnable_id": "zz-lab-2", "leaked": false},
	]


func _snap(card: String) -> void:
	await get_tree().create_timer(SETTLE).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var file := "%s/%s_%dx%d.png" % [dir, card, img.get_width(), img.get_height()]
	img.save_png(file)
	print("wave_card_lab: ", file)
	get_tree().quit()


func _has_arg(arg_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + arg_name)


func _arg(arg_name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % arg_name):
			return a.get_slice("=", 1)
	return ""
