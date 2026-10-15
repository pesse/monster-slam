class_name ApiKeys
extends RefCounted
## Der eigene API-Schlüssel des Spielers für den Schreib-Boss (docs/adr/0023-schreib-boss.md,
## §1: Cloud nur mit eigenem Schlüssel und Bestätigung).
##
## - **Ohne Bestätigung wird nichts gespeichert.** Wer den Schlüssel einträgt, bestätigt,
##   dass die geschriebenen Texte den Rechner verlassen und an Anthropic gehen. Gespeichert
##   werden Schlüssel und Zeitpunkt der Bestätigung zusammen; ein Schlüssel ohne
##   Zeitpunkt (von Hand in die Datei geschrieben) gilt als nicht da.
## - **Gerätweit, nicht je Profil**: der Schlüssel gehört dem, der zahlt, nicht dem Kind,
##   das spielt. Die Kosten zeigt `WritingLog` dagegen je Profil.
## - **Nicht im Klartext**: der Schlüssel liegt im Schlüsselspeicher des Betriebssystems
##   (`SecretVault`: DPAPI unter Windows, Schlüsselbund unter macOS). In
##   `user://api_keys.cfg` stehen nur Bestätigung, der verschlüsselte Block (bzw. unter
##   macOS eine Marke) und die verdeckte Anzeigeform. Wo es keinen Schlüsselspeicher gibt,
##   wird nichts gespeichert. Ein Klartext-Schlüssel aus einer älteren Fassung (Feld `key`)
##   wird beim ersten Zugriff in den Speicher übernommen und aus der Datei gelöscht.
## - Der Schlüssel erscheint nie in Spur, Log, Statistik oder Meldung. Angezeigt wird nur
##   `shown()`.
##
## `available()` und `shown()` lesen nur die Datei; entschlüsselt wird erst in `anthropic()`,
## also beim Senden — einmal je Spielstart, danach aus dem Speicher dieser Klasse.
##
## Statisch, damit Kampf, Einstellungen und Backend ohne Autoload daran kommen. `path` und
## `vault` sind statische Variablen, damit ein Test eigene Datei und eigenen Speicher nutzt.

const DEFAULT_PATH := "user://api_keys.cfg"
const SECTION := "anthropic"

static var path := DEFAULT_PATH
static var vault: SecretVault = SecretVault.new()

## Das zuletzt Entschlüsselte, mit dem Block, aus dem es kam — ändert sich der Block
## (neuer Schlüssel, anderer Pfad im Test), gilt es nicht mehr.
static var _cache := ""
static var _cache_from := ""


## Der Schlüssel — "" ohne Schlüssel, ohne Bestätigung oder wenn er sich nicht mehr
## entschlüsseln lässt (z. B. die Datei von einem anderen Rechner).
static func anthropic() -> String:
	var config := _load()
	if int(config.get_value(SECTION, "confirmed_at", 0)) <= 0:
		return ""
	var stored := str(config.get_value(SECTION, "secret", ""))
	if stored.is_empty():
		return ""
	var origin := path + "|" + stored
	if _cache_from != origin:
		_cache = vault.reveal(SECTION, stored).strip_edges()
		_cache_from = origin if not _cache.is_empty() else ""
	return _cache


## Gibt es einen bestätigten Schlüssel? Ohne ihn gibt es den Schreib-Boss nicht
## (unsichtbar statt gesperrt). Liest nur die Datei, entschlüsselt nichts.
static func available() -> bool:
	var config := _load()
	return int(config.get_value(SECTION, "confirmed_at", 0)) > 0 \
			and not str(config.get_value(SECTION, "secret", "")).is_empty()


## Speichert den Schlüssel — nur mit Bestätigung. `false`, wenn nichts gespeichert wurde:
## keine Bestätigung, leerer Schlüssel, Leerraum darin, kein Schlüsselspeicher, der
## Speicher gibt ihn nicht unverändert zurück, oder die Datei ist nicht schreibbar. Ein
## abgelehnter Versuch lässt einen vorhandenen Schlüssel unberührt.
static func store_anthropic(key: String, confirmed: bool) -> bool:
	var clean := key.strip_edges()
	if not confirmed or clean.is_empty() or _has_space(clean) or not vault.supported():
		return false
	return _store(_load(), clean, int(Time.get_unix_time_from_system()))


## Entfernt Schlüssel und Bestätigung. Wer wieder einen einträgt, bestätigt neu.
static func clear() -> void:
	var config := _load()
	if config.has_section(SECTION):
		vault.forget(SECTION, str(config.get_value(SECTION, "secret", "")))
		config.erase_section(SECTION)
	_cache = ""
	_cache_from = ""
	if config.get_sections().is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	config.save(path)


## Unix-Zeit der Bestätigung, 0 = nie (oder entfernt).
static func confirmed_at() -> int:
	return int(_load().get_value(SECTION, "confirmed_at", 0)) if available() else 0


## Der Schlüssel verdeckt, zum Anzeigen — ohne zu entschlüsseln.
static func shown() -> String:
	return str(_load().get_value(SECTION, "shown", "…")) if available() else ""


## Zum Anzeigen: Anfang und die letzten vier Zeichen, dazwischen nichts. Ein kurzer
## Schlüssel wird ganz verdeckt.
static func masked(key: String) -> String:
	var clean := key.strip_edges()
	if clean.is_empty():
		return ""
	if clean.length() <= 12:
		return "…"
	return "%s…%s" % [clean.substr(0, 7), clean.substr(clean.length() - 4)]


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	_migrate(config)
	return config


## Schreibt den Schlüssel in den Speicher und prüft, ob er unverändert zurückkommt — erst
## dann landet der Block in der Datei.
static func _store(config: ConfigFile, clean: String, confirmed: int) -> bool:
	var stored := vault.protect(SECTION, clean)
	if stored.is_empty() or vault.reveal(SECTION, stored) != clean:
		return false
	if config.has_section_key(SECTION, "key"):
		config.erase_section_key(SECTION, "key")
	config.set_value(SECTION, "secret", stored)
	config.set_value(SECTION, "shown", masked(clean))
	config.set_value(SECTION, "confirmed_at", confirmed)
	if config.save(path) != OK:
		return false
	_cache = clean
	_cache_from = path + "|" + stored
	return true


## Ein Klartext-Schlüssel aus einer älteren Fassung: bestätigt → in den Speicher; ohne
## Bestätigung galt er nie und wird nur gelöscht. Klappt der Speicher nicht, bleibt die
## Datei, wie sie ist (der Schlüssel gilt dann trotzdem nicht: `anthropic()` liest nur
## `secret`).
static func _migrate(config: ConfigFile) -> void:
	if not config.has_section_key(SECTION, "key"):
		return
	var legacy := str(config.get_value(SECTION, "key", "")).strip_edges()
	var confirmed := int(config.get_value(SECTION, "confirmed_at", 0))
	if confirmed > 0 and not legacy.is_empty() and not _has_space(legacy):
		if vault.supported():
			_store(config, legacy, confirmed)
		return
	config.erase_section_key(SECTION, "key")
	config.save(path)


static func _has_space(text: String) -> bool:
	for c in [" ", "\t", "\n", "\r"]:
		if text.contains(c):
			return true
	return false
