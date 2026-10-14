class_name PackStatus
extends RefCounted
## Zustand eines Content-Packs aus Index-Eintrag und lokalem Stand, auf drei Achsen:
## `install` (da und aktuell?), `block` (steht etwas gegen das Holen?) und
## `content_outdated` (installiert unter einer älteren `minVersion` als der Index; ADR 0001).
## Ein Sperrgrund verdrängt in der Anzeige den Installationsstand, hebt ihn aber nicht auf.

enum Install { AVAILABLE, UPDATE, INSTALLED }
enum Block { NONE, LOCKED, STALE_CODE, APP_OUTDATED }

var id := ""
var name := ""
var description := ""
var license := ""
var protected := false
var version := ""
var file := ""
var sha256 := ""
var size := 0
var file_count := 0
var min_version := ""
var key_version := 1

var install: Install = Install.AVAILABLE
var block: Block = Block.NONE
var content_outdated := false
var installed_version := ""


## Baut den Zustand aus einem Index-Eintrag. `installed`: lokaler Zustand ({} wenn nicht
## installiert); `app_version` "" heißt keine Schranke; `stored_code` aus AccessCodes.get_code().
static func evaluate(
	entry: Dictionary, installed: Dictionary, app_version: String, stored_code: Dictionary
) -> PackStatus:
	var status := PackStatus.new()
	status.id = str(entry.get("id", ""))
	status.name = str(entry.get("name", status.id))
	status.description = str(entry.get("description", ""))
	status.license = str(entry.get("license", ""))
	status.protected = bool(entry.get("protected", false))
	status.version = str(entry.get("version", ""))
	status.file = str(entry.get("file", ""))
	status.sha256 = str(entry.get("sha256", ""))
	status.size = int(entry.get("size", 0))
	status.file_count = int(entry.get("fileCount", 0))
	status.min_version = str(entry.get("minVersion", ""))
	status.key_version = int(entry.get("keyVersion", 1))
	status.installed_version = str(installed.get("version", ""))

	# Installationen ohne `minVersion` erzeugen keine Schranke.
	status.content_outdated = SemVer.too_old_for(
		str(installed.get("minVersion", "")), status.min_version
	)

	if status.installed_version.is_empty():
		status.install = Install.AVAILABLE
	elif status.installed_version == status.version:
		status.install = Install.INSTALLED
	else:
		status.install = Install.UPDATE

	# Die Versionsschranke geht vor: sie hebt auch ein hinterlegter Zugangscode nicht auf.
	if SemVer.too_old_for(app_version, status.min_version):
		status.block = Block.APP_OUTDATED
	elif status.protected:
		if stored_code.is_empty():
			status.block = Block.LOCKED
		elif int(stored_code.get("key_version", 1)) != status.key_version:
			status.block = Block.STALE_CODE
	return status


## Darf dieser Pack jetzt geholt werden?
func installable() -> bool:
	return block == Block.NONE and (install != Install.INSTALLED or content_outdated)


## Gibt es einen Grund, den Nutzer darauf hinzuweisen? Trägt das Abzeichen im Startmenü.
func wants_attention() -> bool:
	if block == Block.APP_OUTDATED:
		return false
	return install == Install.UPDATE or content_outdated
