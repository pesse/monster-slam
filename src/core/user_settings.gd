extends Node
## Einstellungen in user://settings.cfg (Autoload): Profile, ihre Einstellungen und Filter
## je `[<einstellung>] <id>=…`, geräteweite Werte unter [general] (ADR 0028). Lädt vor
## PlayerProgress, das in `_ready()` das aktive Profil liest.

const PATH := "user://settings.cfg"
const PROGRESS_DIR := "user://progress"
const BACKUP_DIR := "user://backups"
const QUARANTINE_DIR := "user://quarantine"
const DEFAULT_PROFILE := "default"
const DEFAULT_DIFFICULTY := 3
const DEFAULT_BASE_SPEED := 1.0
const MIN_BASE_SPEED := 0.5
const MAX_BASE_SPEED := 1.5
const DEFAULT_VOLUME := 1.0
const DEFAULT_TRACE_ENABLED := true

## Das aktive Profil hat gewechselt (`id` = neue player_id).
signal active_profile_changed(id: String)

var _config := ConfigFile.new()


## Pfade; Tests setzen eigene.
var config_path := PATH
var progress_dir := PROGRESS_DIR
var backup_dir := BACKUP_DIR
var quarantine_dir := QUARANTINE_DIR
## Was beim Laden repariert wurde, für das Startmenü (SaveCoordinator.take_notices).
var _recovery_notice := {}


func _ready() -> void:
	load_config()
	# Das Default-Profil braucht einen Anzeigenamen.
	if str(_config.get_value("names", DEFAULT_PROFILE, "")).is_empty():
		_config.set_value("names", DEFAULT_PROFILE, "Spieler")
		_save()
	var root := get_tree().root
	root.size_changed.connect(func() -> void: UiScale.apply(root, ui_size()))
	_apply_window()


## Grafik, Menügröße und Vollbild des aktiven Profils aufs Fenster.
func _apply_window() -> void:
	var root := get_tree().root
	GraphicsQuality.apply_window(root, graphics_quality())
	UiScale.apply(root, ui_size())
	# Vollbild nur in der EXE (ADR 0017).
	if OS.has_feature("template"):
		_apply_fullscreen(fullscreen())


func active_profile() -> String:
	return str(_config.get_value("general", "active_profile", DEFAULT_PROFILE))


## Setzt das aktive Profil (nur wenn es im Roster ist) und meldet den Wechsel.
func set_active_profile(id: String) -> void:
	if id == active_profile():
		return
	if id not in profiles():
		push_warning("UserSettings: unbekanntes Profil '%s'" % id)
		return
	_config.set_value("general", "active_profile", id)
	_save()
	_apply_window()
	active_profile_changed.emit(id)


func profiles() -> PackedStringArray:
	return PackedStringArray(_config.get_value("profiles", "roster", PackedStringArray([DEFAULT_PROFILE])))


## Legt aus einem Anzeigenamen ein Profil an (idempotent); gibt die player_id oder "" zurück.
func create_profile(name: String) -> String:
	var id := _sanitize(name)
	if id.is_empty():
		return ""
	var roster := profiles()
	if id not in roster:
		roster.append(id)
		_config.set_value("profiles", "roster", roster)
	_config.set_value("names", id, name.strip_edges())
	_save()
	return id


## Anzeigename eines Profils, sonst die player_id. Leeres `profile` -> aktives Profil.
func display_name(profile := "") -> String:
	var id := profile if not profile.is_empty() else active_profile()
	var name := str(_config.get_value("names", id, ""))
	return name if not name.is_empty() else id


## Ändert nur den Anzeigenamen, die player_id bleibt. Leere Eingabe wird ignoriert.
func set_display_name(name: String, profile := "") -> void:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("names", id, trimmed)
	_save()


## Standard-Schwierigkeit (1..5) eines Profils. Leeres `profile` -> aktives Profil.
func default_difficulty(profile := "") -> int:
	var id := profile if not profile.is_empty() else active_profile()
	return clampi(int(_config.get_value("difficulty", id, DEFAULT_DIFFICULTY)), 1, 5)


func set_default_difficulty(value: int, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("difficulty", id, clampi(value, 1, 5))
	_save()


## Stehen die Monster still, solange die Eingabe offen ist (statt der Zeitlupe)? Vorgabe aus.
func typing_standstill(profile := "") -> bool:
	return bool(_profile_value("typing_standstill", profile, false))


func set_typing_standstill(on: bool, profile := "") -> void:
	_set_profile_value("typing_standstill", profile, on)


## Grund-Geschwindigkeit eines Profils als Faktor (0.5..1.5) zusätzlich zur Schwierigkeit.
func base_speed(profile := "") -> float:
	var id := profile if not profile.is_empty() else active_profile()
	return clampf(float(_config.get_value("base_speed", id, DEFAULT_BASE_SPEED)), MIN_BASE_SPEED, MAX_BASE_SPEED)


func set_base_speed(value: float, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("base_speed", id, clampf(value, MIN_BASE_SPEED, MAX_BASE_SPEED))
	_save()


## Lautstärke der Effekte (0.0..1.0), geräteweit.
func sfx_volume() -> float:
	return clampf(float(_config.get_value("general", "sfx_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func set_sfx_volume(value: float) -> void:
	_config.set_value("general", "sfx_volume", clampf(value, 0.0, 1.0))
	_save()


## Schreibt das Ereignis-Protokoll eines Profils mit (TraceLog)? Vorgabe an.
func trace_enabled(profile := "") -> bool:
	return bool(_profile_value("trace_log", profile, DEFAULT_TRACE_ENABLED))


func set_trace_enabled(value: bool, profile := "") -> void:
	_set_profile_value("trace_log", profile, value)


## Bewertet die Cloud statt des lokalen Modells die Sätze im Satzmeister (ADR 0025)?
## Geräteweit wie der Schlüssel; gilt nur, solange einer eingetragen ist. Vorgabe aus.
func sentence_cloud() -> bool:
	return bool(_config.get_value("general", "sentence_cloud", false))


func set_sentence_cloud(value: bool) -> void:
	_config.set_value("general", "sentence_cloud", value)
	_save()


## Lautstärke der Musik (0.0..1.0), geräteweit.
func music_volume() -> float:
	return clampf(float(_config.get_value("general", "music_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func set_music_volume(value: float) -> void:
	_config.set_value("general", "music_volume", clampf(value, 0.0, 1.0))
	_save()


## Grafikstufe eines Profils, Vorgabe „Schön“. Ohne gespeicherte Stufe gilt der alte
## Schlüssel `graphics_simple` als „Schnell“.
func graphics_quality(profile := "") -> GraphicsQuality.Level:
	var fallback := GraphicsQuality.Level.FAST \
			if bool(_config.get_value("general", "graphics_simple", false)) else GraphicsQuality.Level.FINE
	return clampi(int(_profile_value("graphics_quality", profile, fallback)),
			GraphicsQuality.Level.FAST, GraphicsQuality.Level.FINE) as GraphicsQuality.Level


func set_graphics_quality(value: GraphicsQuality.Level) -> void:
	_set_profile_value("graphics_quality", "", int(value))
	GraphicsQuality.apply_window(get_tree().root, value)


## Menügröße eines Profils; gespeichert wird nur die Stufe (ADR 0017).
func ui_size(profile := "") -> UiScale.Size:
	return clampi(int(_profile_value("ui_size", profile, UiScale.Size.MEDIUM)),
			UiScale.Size.SMALL, UiScale.Size.LARGE) as UiScale.Size


func set_ui_size(value: UiScale.Size) -> void:
	_set_profile_value("ui_size", "", int(value))
	UiScale.apply(get_tree().root, value)


## Gewünschtes Vollbild eines Profils; den tatsächlichen Zustand sagt `window_is_fullscreen()`.
func fullscreen(profile := "") -> bool:
	return bool(_profile_value("fullscreen", profile, false))


func set_fullscreen(on: bool) -> void:
	_set_profile_value("fullscreen", "", on)
	_apply_fullscreen(on)


static func window_is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Ein im Editor eingebettetes Spiel (F5, Reiter „Game“) kennt nur das freie Fenster.
static func can_fullscreen() -> bool:
	return not Engine.is_embedded_in_editor()


## Ohne Vollbild: die EXE maximiert, alles andere frei (`window/size/mode.template`).
func _apply_fullscreen(on: bool) -> void:
	if not can_fullscreen() or on == window_is_fullscreen():
		return
	var back := DisplayServer.WINDOW_MODE_MAXIMIZED if OS.has_feature("template") \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else back)


## F11 und Alt+Enter schalten überall um; `_input` kommt vor jedem Eingabefeld.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var f11 := key.keycode == KEY_F11 and not (key.alt_pressed or key.ctrl_pressed
			or key.shift_pressed or key.meta_pressed)
	var alt_enter := key.keycode in [KEY_ENTER, KEY_KP_ENTER] and key.alt_pressed \
			and not (key.ctrl_pressed or key.shift_pressed or key.meta_pressed)
	if (f11 or alt_enter) and can_fullscreen():
		get_viewport().set_input_as_handled()
		set_fullscreen(not window_is_fullscreen())


## Ausgewählte Lexem-Tags eines Profils (Session-Filter). Leer -> keine Einschränkung.
func selected_tags(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("tags", id, PackedStringArray([])))


func set_selected_tags(tags: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("tags", id, tags)
	_save()


## Ausgewählter Curriculum-Scope ("access2", "access2/6"). Leer -> keine Einschränkung.
func selected_scope(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("scope", id, PackedStringArray([])))


func set_selected_scope(scope: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("scope", id, scope)
	_save()


## Ausgewählte Aufgabentypen (Session-Filter). Leer -> keine Einschränkung.
func selected_task_types(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("task_types", id, PackedStringArray([])))


func set_selected_task_types(types: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("task_types", id, types)
	_save()


## Ausgewählte Lexem-`type`s (noun, verb, …). Leer -> keine Einschränkung.
func selected_lexeme_types(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("lexeme_types", id, PackedStringArray([])))


func set_selected_lexeme_types(types: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("lexeme_types", id, types)
	_save()


## Zufällige Statistik-Kennung eines Profils (ADR 0021), 32 Hex; nie die player_id (= Name).
func stats_id(profile := "") -> String:
	var id := profile if not profile.is_empty() else active_profile()
	var value := str(_config.get_value("stats_id", id, ""))
	if value.is_empty():
		value = Crypto.new().generate_random_bytes(16).hex_encode()
		_config.set_value("stats_id", id, value)
		_save()
	return value


## Hat dieser Rechner den Hinweis zur Statistik gesehen? Vorher wird nichts gesendet.
func stats_notice_seen() -> bool:
	return bool(_config.get_value("general", "stats_notice_seen", false))


func set_stats_notice_seen(value: bool) -> void:
	_config.set_value("general", "stats_notice_seen", value)
	_save()


## Bis wohin die bereinigte Spur eines Profils beim Server ist: [at, ms] der letzten
## gesendeten Zeile. Den Stand bestätigt der Server (`have`), nicht die App.
func stats_trace_cursor(profile: String) -> Array:
	var value: Variant = _config.get_value("stats_cursor", profile, [0, 0])
	if value is Array and (value as Array).size() == 2:
		return [int(value[0]), int(value[1])]
	return [0, 0]


func set_stats_trace_cursor(profile: String, mark: Array) -> void:
	_config.set_value("stats_cursor", profile, [int(mark[0]), int(mark[1])])
	_save()


## Wann der Snapshot eines Profils zuletzt angenommen wurde (unix, 0 = nie).
func stats_sent_at(profile: String) -> int:
	return int(_config.get_value("stats_sent", profile, 0))


func set_stats_sent_at(profile: String, unix: int) -> void:
	_config.set_value("stats_sent", profile, unix)
	_save()


## Wert eines Profils aus `[key]`; ohne eigenen Eintrag der alte geräteweite aus
## `[general] key` (ADR 0028), sonst `default`. Leeres `profile` -> aktives Profil.
func _profile_value(key: String, profile: String, default: Variant) -> Variant:
	var id := profile if not profile.is_empty() else active_profile()
	if _config.has_section_key(key, id):
		return _config.get_value(key, id)
	return _config.get_value("general", key, default)


func _set_profile_value(key: String, profile: String, value: Variant) -> void:
	_config.set_value(key, profile if not profile.is_empty() else active_profile(), value)
	_save()


## Anzeigename -> sicherer player_id: klein, Leerzeichen zu '_', nur [a-z0-9_-].
func _sanitize(name: String) -> String:
	var lowered := name.strip_edges().to_lower()
	var out := ""
	for c in lowered:
		if c == " ":
			out += "_"
		elif (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			out += c
	return out


## Lädt die Einstellungen; Reparatur nach ADR 0024 (Punkt 7).
func load_config() -> void:
	var read := SaveStore.read_cfg(config_path)
	match int(read["status"]):
		SaveStore.Status.OK:
			_config.parse(str(read["text"]))
			if bool(read["legacy"]):
				_save()
			return
		SaveStore.Status.MISSING:
			if not _has_player_data():
				_config.set_value("general", "active_profile", DEFAULT_PROFILE)
				_config.set_value("profiles", "roster", PackedStringArray([DEFAULT_PROFILE]))
				_save()
				return
		_:
			var stamp := Backups.stamp_name(int(Time.get_unix_time_from_system() * 1000.0))
			SaveStore.quarantine(config_path, "%s/_settings/%s" % [quarantine_dir, stamp], ".corrupt")
	var copy := SaveStore.decode_cfg(Backups.newest_settings(backup_dir))
	if int(copy["status"]) == SaveStore.Status.OK:
		_config.parse(str(copy["text"]))
		_save()
		push_warning("UserSettings: aus der Sicherung zurückgeholt")
		_recovery_notice = {"kind": "settings_restored"}
		return
	_config.clear()
	var roster := found_profiles()
	if roster.is_empty():
		roster.append(DEFAULT_PROFILE)
	_config.set_value("general", "active_profile", roster[0])
	_config.set_value("profiles", "roster", roster)
	_save()
	push_warning("UserSettings: Profilliste aus den Spielständen gebaut: %s" % ", ".join(roster))
	_recovery_notice = {"kind": "settings_rebuilt"}


## Was beim Laden repariert wurde ({} = nichts), einmal.
func take_recovery_notice() -> Dictionary:
	var out := _recovery_notice
	_recovery_notice = {}
	return out


## Profile mit Spielstand auf der Platte (`<id>.json` oder Sicherung), ohne `zz-`-Profile.
func found_profiles() -> PackedStringArray:
	var out := PackedStringArray()
	if DirAccess.dir_exists_absolute(progress_dir):
		for name in DirAccess.get_files_at(progress_dir):
			if not name.ends_with(".json") or name.ends_with(SaveCoordinator.JOURNAL_SUFFIX):
				continue
			var id := name.get_basename()
			if _is_profile_file(id) and not id.begins_with("zz-") and id not in out:
				out.append(id)
	if DirAccess.dir_exists_absolute(backup_dir):
		for id in DirAccess.get_directories_at(backup_dir):
			if not id.begins_with("zz-") and id not in out:
				out.append(id)
	out.sort()
	return out


## Der Lernstand heißt `<id>.json`; alles andere trägt eine Endung (`_level`, …).
func _is_profile_file(base: String) -> bool:
	for suffix: String in SaveCoordinator.PROFILE_SUFFIXES + ["_runs"]:
		if not suffix.is_empty() and base.ends_with(suffix):
			return false
	return true


func _has_player_data() -> bool:
	return (DirAccess.dir_exists_absolute(progress_dir) and not DirAccess.get_files_at(progress_dir).is_empty()) \
			or DirAccess.dir_exists_absolute(backup_dir)


func _save() -> void:
	var err := SaveStore.write_cfg(config_path, _config.encode_to_text())
	if err != OK:
		push_warning("UserSettings: konnte '%s' nicht schreiben (Fehler %d)" % [config_path, err])
