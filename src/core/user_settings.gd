extends Node
## Persistente Spieler-Einstellungen (Autoload `UserSettings`).
##
## Hält, welches Profil aktiv ist, welche Profile es gibt und die Standard-Schwierigkeit
## PRO Profil (individueller Könnensstand). Persistenz: ConfigFile unter user://settings.cfg.
## Der Lernfortschritt selbst liegt weiterhin in PlayerProgress (user://progress/<id>.json);
## hier landen NUR die Meta-Einstellungen.
##
## Wird VOR PlayerProgress geladen (siehe [autoload] in project.godot), damit PlayerProgress
## in _ready() bereits das aktive Profil übernehmen kann.

const PATH := "user://settings.cfg"
const DEFAULT_PROFILE := "default"
const DEFAULT_DIFFICULTY := 3
const DEFAULT_BASE_SPEED := 1.0
const MIN_BASE_SPEED := 0.5
const MAX_BASE_SPEED := 1.5
const DEFAULT_VOLUME := 1.0
const DEFAULT_TRACE_ENABLED := true

## Das aktive Profil hat gewechselt (id = neuer player_id). Erlaubt Live-Refresh im UI.
signal active_profile_changed(id: String)

var _config := ConfigFile.new()


func _ready() -> void:
	var err := _config.load(PATH)
	if err != OK:
		# Erststart (oder unlesbar): Default-Profil anlegen und sichern.
		_config.set_value("general", "active_profile", DEFAULT_PROFILE)
		_config.set_value("profiles", "roster", PackedStringArray([DEFAULT_PROFILE]))
		_save()
	# Sicherstellen, dass das Default-Profil einen Anzeigenamen hat (auch für Altbestände
	# ohne [names]-Sektion).
	if str(_config.get_value("names", DEFAULT_PROFILE, "")).is_empty():
		_config.set_value("names", DEFAULT_PROFILE, "Spieler")
		_save()
	GraphicsQuality.apply_window(get_tree().root, graphics_quality())
	# Die Bezugsgröße der Oberfläche folgt dem Fenster (UiScale): beim Start und nach
	# jeder Größenänderung, auch beim Maximieren und im Vollbild.
	var root := get_tree().root
	UiScale.apply(root, ui_size())
	root.size_changed.connect(func() -> void: UiScale.apply(root, ui_size()))
	# Das Vollbild beim Start nur in der EXE: Editor-Läufe und Werkbänke bleiben im freien
	# Fenster, damit ihre Bilder nicht vom Bildschirm abhängen (ADR 0017).
	if OS.has_feature("template") and fullscreen():
		_apply_fullscreen(true)


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
	active_profile_changed.emit(id)


## Liste der bekannten Profile (player_ids).
func profiles() -> PackedStringArray:
	return PackedStringArray(_config.get_value("profiles", "roster", PackedStringArray([DEFAULT_PROFILE])))


## Legt aus einem Anzeigenamen ein neues Profil an (idempotent) und gibt dessen player_id
## zurück. Der sanitisierte Name dient als sicherer Dateiname/Schlüssel, der eingegebene
## Klartext-Name wird als Anzeigename gespeichert. Bei leerer Eingabe wird kein Profil
## angelegt und "" zurückgegeben.
func create_profile(name: String) -> String:
	var id := _sanitize(name)
	if id.is_empty():
		return ""
	var roster := profiles()
	if id not in roster:
		roster.append(id)
		_config.set_value("profiles", "roster", roster)
	# Anzeigename setzen/aktualisieren (Klartext, wie eingegeben).
	_config.set_value("names", id, name.strip_edges())
	_save()
	return id


## Klartext-Anzeigename eines Profils. Leeres `profile` -> aktives Profil. Fällt auf die
## player_id zurück, falls kein Anzeigename hinterlegt ist.
func display_name(profile := "") -> String:
	var id := profile if not profile.is_empty() else active_profile()
	var name := str(_config.get_value("names", id, ""))
	return name if not name.is_empty() else id


## Benennt ein Profil um: ändert nur den Klartext-Anzeigenamen, die player_id (Dateischlüssel)
## bleibt stabil. Leere Eingabe wird ignoriert. Leeres `profile` -> aktives Profil.
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


## Grund-Geschwindigkeit eines Profils als Multiplikator (0.5..1.5, Default 1.0). Wirkt als
## globaler Tempo-Faktor ZUSÄTZLICH zur Schwierigkeit (siehe WaveRunner) und verschiebt so das
## Grundtempo, ohne die Schwierigkeitsskala selbst zu verändern. Leeres `profile` -> aktives Profil.
func base_speed(profile := "") -> float:
	var id := profile if not profile.is_empty() else active_profile()
	return clampf(float(_config.get_value("base_speed", id, DEFAULT_BASE_SPEED)), MIN_BASE_SPEED, MAX_BASE_SPEED)


func set_base_speed(value: float, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("base_speed", id, clampf(value, MIN_BASE_SPEED, MAX_BASE_SPEED))
	_save()


## Lautstärke der Effekte (0.0..1.0, Default 1.0). Bewusst in [general] und damit
## geräteweit statt pro Profil: wie laut es hier sein darf, hängt an Boxen und Uhrzeit,
## nicht daran, wer gerade spielt.
func sfx_volume() -> float:
	return clampf(float(_config.get_value("general", "sfx_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func set_sfx_volume(value: float) -> void:
	_config.set_value("general", "sfx_volume", clampf(value, 0.0, 1.0))
	_save()


## Schreibt das Ereignis-Protokoll mit (TraceLog)? Bewusst in [general] und damit
## geräteweit statt pro Profil: ob protokolliert wird, ist eine Frage an den Rechner und
## nicht an das Kind, das gerade spielt. Vorgabe an — ein Protokoll, das man erst
## einschalten muss, ist beim Fehler von gestern leer.
func trace_enabled() -> bool:
	return bool(_config.get_value("general", "trace_log", DEFAULT_TRACE_ENABLED))


func set_trace_enabled(value: bool) -> void:
	_config.set_value("general", "trace_log", value)
	_save()


## Lautstärke der Musik (0.0..1.0, Default 1.0). Ebenfalls geräteweit, siehe sfx_volume().
func music_volume() -> float:
	return clampf(float(_config.get_value("general", "music_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func set_music_volume(value: float) -> void:
	_config.set_value("general", "music_volume", clampf(value, 0.0, 1.0))
	_save()


## Grafikstufe (GraphicsQuality.Level)? Geräteweit wie die Lautstärke: ob der Rechner
## mitkommt, hängt nicht daran, wer spielt. Vorgabe „Schön". Früher gab es nur
## `graphics_simple` (an = „Einfach"); wer das gesetzt hat, bekommt „Schnell" — das ist
## dieselbe Wahl, und sie bleibt gelesen, solange keine neue Stufe gespeichert ist.
func graphics_quality() -> GraphicsQuality.Level:
	if _config.has_section_key("general", "graphics_quality"):
		return clampi(int(_config.get_value("general", "graphics_quality")),
				GraphicsQuality.Level.FAST, GraphicsQuality.Level.FINE) as GraphicsQuality.Level
	if bool(_config.get_value("general", "graphics_simple", false)):
		return GraphicsQuality.Level.FAST
	return GraphicsQuality.Level.FINE


func set_graphics_quality(value: GraphicsQuality.Level) -> void:
	_config.set_value("general", "graphics_quality", int(value))
	_save()
	GraphicsQuality.apply_window(get_tree().root, value)


## Menügröße (UiScale.Size)? Geräteweit wie die Grafikstufe: wie groß die Menüs stehen
## sollen, hängt am Bildschirm, nicht daran, wer spielt. Gespeichert wird nur die Stufe;
## was „Mittel" in Pixeln heißt, rechnet UiScale aus der Systemskalierung.
func ui_size() -> UiScale.Size:
	return clampi(int(_config.get_value("general", "ui_size", UiScale.Size.MEDIUM)),
			UiScale.Size.SMALL, UiScale.Size.LARGE) as UiScale.Size


func set_ui_size(value: UiScale.Size) -> void:
	_config.set_value("general", "ui_size", int(value))
	_save()
	UiScale.apply(get_tree().root, value)


## Vollbild? Geräteweit wie die Menügröße. Gespeichert wird der Wunsch, was das Fenster
## gerade ist, sagt `window_is_fullscreen()` — verlassen lässt es sich auch über das
## Betriebssystem (macOS: grüner Knopf). Randlos statt exklusiv: Alt+Tab und was das Spiel
## selbst öffnet (Spur-Ordner, Update, Links) kommen nach vorn, ohne dass es minimiert.
func fullscreen() -> bool:
	return bool(_config.get_value("general", "fullscreen", false))


func set_fullscreen(on: bool) -> void:
	_config.set_value("general", "fullscreen", on)
	_save()
	_apply_fullscreen(on)


static func window_is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Ein im Editor eingebettetes Spiel (F5, Reiter „Game“) kennt nur das freie Fenster.
static func can_fullscreen() -> bool:
	return not Engine.is_embedded_in_editor()


## Zurück geht es dorthin, wo das Fenster ohne Vollbild startet: die EXE maximiert, alles
## andere frei (`window/size/mode.template`).
func _apply_fullscreen(on: bool) -> void:
	if not can_fullscreen() or on == window_is_fullscreen():
		return
	var back := DisplayServer.WINDOW_MODE_MAXIMIZED if OS.has_feature("template") \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else back)


## F11 und Alt+Enter schalten überall um, auch während getippt wird — `_input` kommt vor
## der Oberfläche, ein Eingabefeld sieht das Enter dann nicht.
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


## Ausgewählte Lexem-Tags eines Profils (Session-Filter). Leer -> keine Einschränkung
## (alle Tags). Leeres `profile` -> aktives Profil.
func selected_tags(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("tags", id, PackedStringArray([])))


func set_selected_tags(tags: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("tags", id, tags)
	_save()


## Ausgewählter Curriculum-Scope eines Profils (Session-Filter): Schlüssel wie "access2"
## (ganzes Buch) oder "access2/6" (eine Unit). Leer -> keine Einschränkung (alle Lexeme,
## auch die ohne Buch/Unit). Leeres `profile` -> aktives Profil.
func selected_scope(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("scope", id, PackedStringArray([])))


func set_selected_scope(scope: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("scope", id, scope)
	_save()


## Ausgewählte Aufgabentypen eines Profils (Session-Filter). Leer -> keine Einschränkung
## (alle Typen). Leeres `profile` -> aktives Profil.
func selected_task_types(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("task_types", id, PackedStringArray([])))


func set_selected_task_types(types: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("task_types", id, types)
	_save()


## Ausgewählte Vokabel-Typen (Lexem-`type`, z.B. noun/verb) eines Profils. Leer ->
## keine Einschränkung (alle Typen). Leeres `profile` -> aktives Profil.
func selected_lexeme_types(profile := "") -> PackedStringArray:
	var id := profile if not profile.is_empty() else active_profile()
	return PackedStringArray(_config.get_value("lexeme_types", id, PackedStringArray([])))


func set_selected_lexeme_types(types: PackedStringArray, profile := "") -> void:
	var id := profile if not profile.is_empty() else active_profile()
	_config.set_value("lexeme_types", id, types)
	_save()


## Zufällige Kennung eines Profils für die Statistik (ADR 0021), 32 Hex-Zeichen. Wird beim
## ersten Bedarf erzeugt und bleibt beim Umbenennen stehen: der Server soll Verläufe
## zusammenhalten, ohne den Namen zu kennen. Die player_id taugt dafür nicht — sie ist der
## Name. Leeres `profile` -> aktives Profil.
func stats_id(profile := "") -> String:
	var id := profile if not profile.is_empty() else active_profile()
	var value := str(_config.get_value("stats_id", id, ""))
	if value.is_empty():
		value = Crypto.new().generate_random_bytes(16).hex_encode()
		_config.set_value("stats_id", id, value)
		_save()
	return value


## Hat dieser Rechner den Hinweis zur Statistik gesehen? Geräteweit: er gilt dem Rechner,
## nicht dem Kind. Vorher wird nichts gesendet.
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


func _save() -> void:
	var err := _config.save(PATH)
	if err != OK:
		push_warning("UserSettings: konnte '%s' nicht schreiben (Fehler %d)" % [PATH, err])
