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


## Lautstärke der Musik (0.0..1.0, Default 1.0). Ebenfalls geräteweit, siehe sfx_volume().
func music_volume() -> float:
	return clampf(float(_config.get_value("general", "music_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func set_music_volume(value: float) -> void:
	_config.set_value("general", "music_volume", clampf(value, 0.0, 1.0))
	_save()


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
