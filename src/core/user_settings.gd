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
