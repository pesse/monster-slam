extends Control
## Start- und Profil-/Statistik-Screen (eigene Szene, run/main_scene).
##
## Das Layout liegt in profile_menu.tscn (im Editor sichtbar); hier wird nur bedient und
## angezeigt. Einstellungen (Profil, Standard-Schwierigkeit, Reset) liegen in UserSettings
## + PlayerProgress. Anders als die Kampf-Overlays gibt es hier KEINE Antwort-LineEdit,
## die den Fokus stiehlt, daher bleiben die Controls normal fokussierbar.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _rename_input: LineEdit = %RenameInput
@onready var _name_input: LineEdit = %NameInput
@onready var _diff_buttons: Array = %DiffRow.get_children()
@onready var _reset_confirm: ConfirmationDialog = %ResetDialog
@onready var _stats_lines: VBoxContainer = %Statistik
@onready var _word_list: VBoxContainer = %WordList
@onready var _flag_list: VBoxContainer = %FlagList


func _ready() -> void:
	(%PlayButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(BATTLE_SCENE))
	_profile_select.item_selected.connect(_on_profile_selected)
	_rename_input.text_submitted.connect(func(_t): _on_rename_profile())
	(%RenameButton as Button).pressed.connect(_on_rename_profile)
	(%AddButton as Button).pressed.connect(_on_create_profile)
	# Standard-Schwierigkeits-Buttons 1..5 (Reihenfolge in DiffRow = Stufe i+1).
	for i in _diff_buttons.size():
		(_diff_buttons[i] as Button).pressed.connect(_on_difficulty_pressed.bind(i + 1))
	(%ResetButton as Button).pressed.connect(func(): _reset_confirm.popup_centered())
	_reset_confirm.confirmed.connect(_on_reset_confirmed)
	_refresh()


## Baut Profil-Auswahl, Schwierigkeits-Hervorhebung, Statistik-Zeilen und Wortliste neu auf.
func _refresh() -> void:
	_refresh_profiles()
	_refresh_difficulty()
	_refresh_stats()
	_refresh_words()
	_refresh_flags()


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
		(_diff_buttons[i] as Button).disabled = (i + 1 == current)


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


## Zeigt die im Reveal geflaggten Lexeme mit Kommentar (aus der Quell-JSON).
func _refresh_flags() -> void:
	for child in _flag_list.get_children():
		child.queue_free()
	var flagged := ContentRegistry.flagged_lexemes()
	if flagged.is_empty():
		var empty := Label.new()
		empty.text = "Keine markierten Einträge."
		_flag_list.add_child(empty)
		return
	for entry in flagged:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		_flag_list.add_child(box)
		var type_key := String(entry.get("type", ""))
		var type_label := String(WordTypePalette.LABELS.get(type_key, type_key))
		var header := Label.new()
		header.text = "%s → %s  ·  %s" % [
			str(entry.get("lemma_de", "")), str(entry.get("lemma_en", "")), type_label]
		box.add_child(header)
		var flag: Dictionary = entry.get("flag", {})
		var comment := Label.new()
		comment.text = "⚑ %s" % str(flag.get("comment", ""))
		comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(comment)


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
