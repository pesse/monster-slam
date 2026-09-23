extends Control
## Einstellungs-Screen (Profil, Standard-Schwierigkeit, Grund-Geschwindigkeit, Reset,
## Melden).
##
## Statistik und Wortliste sind hier ausgezogen und liegen im eigenen Statistik-Screen
## (stats_screen, Issue #5) — sie hingen zwischen Profilauswahl, Reset und Melde-Token.
##
## Der Reiter „Protokoll" ist der Zugang zum Ereignis-Protokoll (TraceLog): an, aus, Pfad,
## Ordner öffnen, leeren — und darunter die letzten Einträge zum Lesen, neueste oben (was
## darin steht, rechnet TraceView). Der Screen SCHREIBT nichts davon — er stellt den Schalter in
## UserSettings und liest den Stand beim Autoload, so wie der Wellenabschluss den Gold-Stand
## bei Wallet liest.
##
## Der Reiter „Melden" ist die einzige Stelle, an der ein Melde-Token eingetragen wird
## (siehe ReportService, docs/adr/0002-melde-rueckkanal.md). Er bleibt deshalb immer
## sichtbar; die Liste der Meldungen darunter erscheint erst mit hinterlegtem Token —
## ohne Rückkanal gibt es auch nichts zu melden.
##
## Ausgelagert aus dem Start-Screen (profile_menu). Das Layout liegt in settings_menu.tscn
## (im Editor sichtbar); hier wird nur bedient und angezeigt. Einstellungen liegen in
## UserSettings, der Fortschritt (Reset) in PlayerProgress.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const TRACE_ROW_SCENE := preload("res://scenes/ui/trace_row.tscn")
## So viele Ereignisse zeigt der Reiter. Mehr liest niemand am Bildschirm; wer mehr will,
## öffnet die Datei.
const TRACE_SHOWN := 200

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _rename_input: LineEdit = %RenameInput
@onready var _diff_buttons: Array = %DiffRow.get_children()
@onready var _speed_slider: HSlider = %SpeedSlider
@onready var _speed_label: Label = %SpeedLabel
@onready var _reset_confirm: ConfirmationDialog = %ResetDialog
@onready var _flag_list: VBoxContainer = %FlagList
@onready var _flag_scroll: ScrollContainer = %FlagScroll
@onready var _token_input: LineEdit = %TokenInput
@onready var _token_button: Button = %TokenButton
@onready var _token_forget: Button = %TokenForget
@onready var _token_status: Label = %TokenStatus
@onready var _trace_toggle: CheckBox = %TraceToggle
@onready var _trace_path: Label = %TracePath
@onready var _trace_status: Label = %TraceStatus
@onready var _trace_open: Button = %TraceOpen
@onready var _trace_clear: Button = %TraceClear
@onready var _trace_list: VBoxContainer = %TraceList


func _ready() -> void:
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	_profile_select.item_selected.connect(_on_profile_selected)
	_rename_input.text_submitted.connect(func(_t): _on_rename_profile())
	(%RenameButton as Button).pressed.connect(_on_rename_profile)
	# Standard-Schwierigkeits-Buttons 1..5 (Reihenfolge in DiffRow = Stufe i+1).
	for i in _diff_buttons.size():
		(_diff_buttons[i] as Button).pressed.connect(_on_difficulty_pressed.bind(i + 1))
	_speed_slider.value_changed.connect(_on_speed_changed)
	(%ResetButton as Button).pressed.connect(func(): _reset_confirm.popup_centered())
	_reset_confirm.confirmed.connect(_on_reset_confirmed)
	_token_button.pressed.connect(_on_token_submit)
	_token_input.text_submitted.connect(func(_t): _on_token_submit())
	_token_forget.pressed.connect(_on_token_forget)
	# Der Dienst meldet jeden Zustandswechsel; die Anzeige hängt daran statt zu pollen.
	ReportService.changed.connect(_refresh_report)
	_trace_toggle.toggled.connect(_on_trace_toggled)
	_trace_open.pressed.connect(_on_trace_open)
	_trace_clear.pressed.connect(_on_trace_clear)
	Hints.attach(_trace_toggle, "Ereignis-Protokoll",
			"Schreibt jede erschienene Aufgabe und jede Eingabe mit — die Grundlage, "
			+ "auf der sich hinterher sagen lässt, was passiert ist.",
			"bleibt auf diesem Rechner")
	Hints.attach(_trace_open, "Ordner öffnen", "zeigt die Protokolldatei im Dateimanager")
	Hints.attach(_trace_clear, "Protokoll leeren", "löscht beide Dateien; das laufende Spiel schreibt danach neu")
	_refresh()


## Baut Profil-Auswahl, Schwierigkeits-Hervorhebung, Tempo und Melde-Reiter neu auf.
func _refresh() -> void:
	_refresh_profiles()
	_refresh_difficulty()
	_refresh_speed()
	_refresh_report()
	_refresh_trace()


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


## Slider auf die Grund-Geschwindigkeit des aktiven Profils setzen (ohne value_changed
## auszulösen, sonst würde _refresh beim Profilwechsel ein überflüssiges Speichern triggern).
func _refresh_speed() -> void:
	var value := UserSettings.base_speed()
	_speed_slider.set_value_no_signal(value)
	_update_speed_label(value)


func _update_speed_label(value: float) -> void:
	_speed_label.text = "Grund-Geschwindigkeit: %d %%" % int(round(value * 100.0))


## Reiter „Melden": Zustand des Rückkanals oben, die eigenen Meldungen darunter.
func _refresh_report() -> void:
	_refresh_token()
	_refresh_flags()


func _refresh_token() -> void:
	var available := ReportService.configured()
	_token_input.editable = available
	_token_button.disabled = not available
	_token_forget.visible = ReportService.can_report()
	if not available:
		_token_status.text = "Diese Fassung hat keinen Rückkanal — Melden ist aus."
		return
	if ReportService.state == ReportService.State.ERROR:
		_token_status.text = "⚠ %s" % ReportService.error
		return
	if not ReportService.can_report():
		_token_status.text = "Kein Token hinterlegt. Ohne Token gibt es kein Melden."
		return
	var open := ReportService.pending_count()
	_token_status.text = "✔ Token gilt für „%s“." % ReportService.label()
	if open > 0:
		_token_status.text += "   %d Meldung(en) warten auf den Versand." % open


func _on_token_submit() -> void:
	var raw := _token_input.text.strip_edges()
	if raw.is_empty():
		return
	_token_button.disabled = true
	_token_status.text = "Token wird geprüft …"
	var ok := await ReportService.verify(raw)
	_token_button.disabled = false
	if ok:
		_token_input.text = ""
		# Was schon lokal gemeldet wurde, geht jetzt mit.
		await ReportService.send_pending(true)
	_refresh_report()


func _on_token_forget() -> void:
	ReportService.forget()
	_refresh_report()


## Zeigt die im Reveal gemeldeten Lexeme mit Kommentar und Versandstand. Ohne Token
## bleibt die Liste aus: dann gibt es keinen Weg, auf dem eine Meldung ankäme.
func _refresh_flags() -> void:
	for child in _flag_list.get_children():
		child.queue_free()
	_flag_scroll.visible = ReportService.can_report()
	if not _flag_scroll.visible:
		return
	var flagged := ContentRegistry.flagged_lexemes()
	if flagged.is_empty():
		var empty := Label.new()
		empty.text = "Keine Meldungen."
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
		# Der Haken sagt, was beim Content-Autor angekommen ist — offen heißt: geht noch raus.
		var mark := "✔" if bool(flag.get("sent", false)) else "⚑"
		comment.text = "%s %s" % [mark, str(flag.get("comment", ""))]
		comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(comment)


func _on_profile_selected(index: int) -> void:
	var id := str(_profile_select.get_item_metadata(index))
	UserSettings.set_active_profile(id)
	PlayerProgress.switch_to(id)
	_refresh()


func _on_rename_profile() -> void:
	UserSettings.set_display_name(_rename_input.text)
	_refresh()


func _on_difficulty_pressed(level: int) -> void:
	UserSettings.set_default_difficulty(level)
	_refresh_difficulty()


func _on_speed_changed(value: float) -> void:
	UserSettings.set_base_speed(value)
	_update_speed_label(value)


func _on_reset_confirmed() -> void:
	PlayerProgress.reset()
	PlayerProgress.save_progress()
	_refresh()


# --- Reiter „Protokoll" -------------------------------------------------------

func _refresh_trace() -> void:
	# Ohne Signal: _refresh_trace() läuft auch AUS dem toggled-Handler heraus, und ein
	# Setzer, der dort erneut feuert, schriebe die Einstellung ein zweites Mal.
	_trace_toggle.set_pressed_no_signal(UserSettings.trace_enabled())
	_trace_path.text = ProjectSettings.globalize_path(TraceLog.path())
	var bytes := TraceLog.size_bytes()
	_trace_clear.disabled = bytes == 0
	_refresh_trace_list()
	if bytes == 0:
		# Kein „0 KB": leer heißt entweder „noch nichts gespielt" oder „gerade geleert",
		# und beides ist dieselbe Auskunft — es ist nichts da.
		_trace_status.text = "noch nichts aufgezeichnet"
		return
	_trace_status.text = "aufgezeichnet: %s" % String.humanize_size(bytes)


## Die letzten Einträge, neueste oben. Neu gelesen bei jedem _refresh_trace(): im
## Einstellungs-Screen läuft kein Spiel, die Datei ändert sich also nur durch „leeren".
func _refresh_trace_list() -> void:
	for child in _trace_list.get_children():
		child.queue_free()
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	for entry in TraceView.rows(TraceLog.recent(TRACE_SHOWN), bias):
		var row: TraceRow = TRACE_ROW_SCENE.instantiate()
		_trace_list.add_child(row)
		row.setup(entry)


func _on_trace_toggled(pressed: bool) -> void:
	UserSettings.set_trace_enabled(pressed)
	TraceLog.set_enabled(pressed)
	_refresh_trace()


func _on_trace_open() -> void:
	# Der Ordner und nicht die Datei: eine .jsonl öffnet je nach Rechner irgendetwas oder
	# nichts, der Ordner immer den Dateimanager.
	OS.shell_open(ProjectSettings.globalize_path(TraceLog.LOG_DIR))


func _on_trace_clear() -> void:
	TraceLog.clear()
	_refresh_trace()
