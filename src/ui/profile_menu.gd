extends Control
## Start- und Profil-/Statistik-Screen (eigene Szene, run/main_scene).
##
## Baut sein Layout — wie WaveStats/DebugPanel — komplett im Code auf. Anders als die
## Kampf-Overlays gibt es hier KEINE Antwort-LineEdit, die den Fokus stiehlt, daher
## bleiben die Controls normal fokussierbar (kein focus_mode = FOCUS_NONE nötig).
##
## Einstellungen (Profil, Standard-Schwierigkeit, Reset) liegen in UserSettings +
## PlayerProgress; hier wird nur bedient und angezeigt.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var _profile_select: OptionButton
var _rename_input: LineEdit
var _name_input: LineEdit
var _diff_buttons: Array[Button] = []
var _reset_confirm: ConfirmationDialog
var _stats_lines: VBoxContainer
var _word_list: VBoxContainer


func _ready() -> void:
	_build()
	_refresh()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Monster Slam"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	root.add_child(title)

	var play := Button.new()
	play.text = "▶ Spielen"
	play.pressed.connect(func(): get_tree().change_scene_to_file(BATTLE_SCENE))
	root.add_child(play)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_build_profile_tab(tabs)
	_build_stats_tab(tabs)
	_build_words_tab(tabs)

	# Bestätigungsdialog fürs Zurücksetzen (als Kind gehalten, per popup_centered gezeigt).
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.dialog_text = "Fortschritt dieses Profils wirklich löschen?"
	_reset_confirm.confirmed.connect(_on_reset_confirmed)
	add_child(_reset_confirm)


func _build_profile_tab(tabs: TabContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "Profil"
	box.add_theme_constant_override("separation", 10)
	tabs.add_child(box)

	var pick_label := Label.new()
	pick_label.text = "Aktives Profil"
	box.add_child(pick_label)

	_profile_select = OptionButton.new()
	_profile_select.item_selected.connect(_on_profile_selected)
	box.add_child(_profile_select)

	# Aktives Profil umbenennen (ändert nur den Anzeigenamen, nicht die player_id).
	var rename_row := HBoxContainer.new()
	box.add_child(rename_row)
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Profilname"
	_rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_input.text_submitted.connect(func(_t): _on_rename_profile())
	rename_row.add_child(_rename_input)
	var rename_button := Button.new()
	rename_button.text = "Umbenennen"
	rename_button.pressed.connect(_on_rename_profile)
	rename_row.add_child(rename_button)

	var new_row := HBoxContainer.new()
	box.add_child(new_row)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Neuer Profilname"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(_name_input)
	var add_button := Button.new()
	add_button.text = "Neues Profil"
	add_button.pressed.connect(_on_create_profile)
	new_row.add_child(add_button)

	var diff_label := Label.new()
	diff_label.text = "Standard-Schwierigkeit"
	box.add_child(diff_label)

	var diff_row := HBoxContainer.new()
	box.add_child(diff_row)
	for level in range(1, 6):
		var button := Button.new()
		button.text = str(level)
		button.pressed.connect(_on_difficulty_pressed.bind(level))
		diff_row.add_child(button)
		_diff_buttons.append(button)

	var reset_button := Button.new()
	reset_button.text = "Fortschritt zurücksetzen"
	reset_button.pressed.connect(func(): _reset_confirm.popup_centered())
	box.add_child(reset_button)


func _build_stats_tab(tabs: TabContainer) -> void:
	_stats_lines = VBoxContainer.new()
	_stats_lines.name = "Statistik"
	_stats_lines.add_theme_constant_override("separation", 6)
	tabs.add_child(_stats_lines)


func _build_words_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Wörter"
	tabs.add_child(scroll)
	_word_list = VBoxContainer.new()
	_word_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_word_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_word_list)


## Baut Profil-Auswahl, Schwierigkeits-Hervorhebung, Statistik-Zeilen und Wortliste neu auf.
func _refresh() -> void:
	_refresh_profiles()
	_refresh_difficulty()
	_refresh_stats()
	_refresh_words()


func _refresh_profiles() -> void:
	_profile_select.clear()
	var active := UserSettings.active_profile()
	var profiles := UserSettings.profiles()
	for i in profiles.size():
		# Anzeigename im Dropdown, player_id als Metadaten (für die Auswahl-Rückabbildung).
		_profile_select.add_item(UserSettings.display_name(profiles[i]))
		_profile_select.set_item_metadata(i, profiles[i])
		if profiles[i] == active:
			_profile_select.select(i)
	# Umbenennen-Feld mit dem aktuellen Anzeigenamen vorbelegen.
	_rename_input.text = UserSettings.display_name()


func _refresh_difficulty() -> void:
	var current := UserSettings.default_difficulty()
	for i in _diff_buttons.size():
		# Gewählte Stufe optisch hervorheben (deaktivierter Button = markiert, wie in WaveStats).
		_diff_buttons[i].disabled = (i + 1 == current)


func _refresh_stats() -> void:
	for child in _stats_lines.get_children():
		child.queue_free()
	_add_stat("Gemeisterte Aufgaben: %d  (Festungsstufe %d)" % [
		PlayerProgress.mastered_count(), PlayerProgress.fortress_tier()])
	_add_stat("Gesamt-Genauigkeit: %d %%" % int(round(PlayerProgress.overall_accuracy() * 100.0)))
	_add_stat("Gesehene Wörter: %d    Versuche: %d" % [
		PlayerProgress.seen_count(), PlayerProgress.total_attempts()])
	_add_stat("Beste Serie: %d" % PlayerProgress.best_streak_overall())
	_add_stat("Heute fällig: %d" % PlayerProgress.due_count())


func _refresh_words() -> void:
	for child in _word_list.get_children():
		child.queue_free()
	var rows := PlayerProgress.records_for_display()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Wörter geübt."
		_word_list.add_child(empty)
		return
	for row in rows:
		var line := HBoxContainer.new()
		_word_list.add_child(line)
		var name_label := Label.new()
		name_label.text = str(row["label"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var conf_label := Label.new()
		conf_label.text = "%d %%" % int(round(float(row["confidence"]) * 100.0))
		line.add_child(conf_label)
		var mastered_label := Label.new()
		mastered_label.text = "  ✓" if bool(row["mastered"]) else "   "
		line.add_child(mastered_label)


func _add_stat(text: String) -> void:
	var label := Label.new()
	label.text = text
	_stats_lines.add_child(label)


func _on_profile_selected(index: int) -> void:
	var id := str(_profile_select.get_item_metadata(index))
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	_refresh()


func _on_rename_profile() -> void:
	UserSettings.set_display_name(_rename_input.text)
	_refresh()


func _on_create_profile() -> void:
	var id := UserSettings.create_profile(_name_input.text)
	if id.is_empty():
		return
	_name_input.clear()
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	_refresh()


func _on_difficulty_pressed(level: int) -> void:
	UserSettings.set_default_difficulty(level)
	_refresh_difficulty()


func _on_reset_confirmed() -> void:
	PlayerProgress.reset()
	PlayerProgress.save_progress()
	_refresh()
