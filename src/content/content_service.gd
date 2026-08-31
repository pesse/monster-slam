extends Node
## Autoload `ContentService`: der Content-Kanal — Verzeichnis holen, Packs installieren,
## Zugangscodes einlösen.
##
## Getrennt vom App-Kanal (`UpdateService`), siehe docs/adr/0001-app-und-content-update.md.
## Das Verzeichnis `index.json` ist unverschlüsselt: der Update-Check funktioniert damit
## ohne jeden Zugangscode, und ein geschützter Pack ist sichtbar, bevor er lesbar ist.
##
## Offline ist der Normalfall — jeder Netzfehler ist ein Zustand, kein Abbruch.

## Zustand oder Pack-Liste hat sich geändert.
signal changed

enum State { IDLE, LOADING, WORKING, READY, ERROR }

## Release mit festem Tag im öffentlichen Transport-Repo — der stabile Download-Ort. Die
## Packs selbst entstehen im privaten Content-Repo (siehe dessen packs.yaml).
const DEFAULT_RELEASE_BASE := "https://github.com/pesse/monster-slam-packs/releases/download/packs"

## Nur im Debug-Build aus MONSTER_SLAM_PACKS_BASE übernehmbar — so lässt sich die ganze
## Kette gegen ein lokales Verzeichnis durchspielen. Im Release ist die Quelle fest: eine
## umlenkbare Bezugsquelle wäre eine Angriffsfläche, die kein Nutzen aufwiegt.
var release_base := DEFAULT_RELEASE_BASE

const TMP_DIR := "user://tmp"

## Ein Verzeichnis ist wenige KB. Die Schranke fängt eine falsch geroutete Antwort ab,
## bevor sie als Verzeichnis durchläuft.
const MAX_INDEX_BYTES := 512 * 1024

var state: State = State.IDLE
var packs: Array[PackStatus] = []
var error := ""
## Was gerade passiert, für die Anzeige („Access 2 wird geladen …").
var activity := ""
## Ergebnis des letzten Vorgangs, für die Anzeige.
var message := ""
## Packs, deren Installation auf bereits vorhandene Fremddateien gestoßen ist. Kein Fehler,
## sondern eine Rückfrage: die UI kann `install_many(needs_adopt, true)` anbieten.
var needs_adopt: Array[String] = []

var _http: HTTPRequest
var _busy := false
## Roh-Einträge aus dem Verzeichnis, id -> Dictionary. Getrennt von `packs` gehalten, weil
## die Installation die Originalfelder braucht (file, sha256, minVersion).
var _entries: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	if OS.is_debug_build():
		var override := OS.get_environment("MONSTER_SLAM_PACKS_BASE")
		if not override.is_empty():
			release_base = override
			print("ContentService: Pack-Quelle überschrieben -> %s" % release_base)
	_clear_tmp()


## Die App-Version, an der die Schranke gemessen wird — "" heißt: keine Schranke.
##
## Im Debug-Build gilt keine: committet steht in project.godot immer die Version des
## LETZTEN Releases, eine Pack-Deklaration auf die kommende Fassung sperrte die Entwicklung
## sonst an den eigenen Inhalten aus.
func gate_version() -> String:
	return "" if OS.is_debug_build() else SemVer.app_version()


## Holt das Verzeichnis und verschneidet es mit dem lokalen Stand.
func refresh() -> void:
	if _busy:
		return
	_busy = true
	activity = ""
	message = ""
	_set_state(State.LOADING)

	var response := await _fetch("%s/index.json" % release_base)
	_busy = false
	if not response["error"].is_empty():
		_fail(response["error"])
		return
	if response["body"].size() > MAX_INDEX_BYTES:
		_fail("Pack-Verzeichnis unplausibel groß — verworfen.")
		return

	var parsed: Variant = JSON.parse_string(response["body"].get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).has("packs"):
		_fail("Pack-Verzeichnis unlesbar.")
		return

	_entries.clear()
	for entry in (parsed as Dictionary)["packs"]:
		if entry is Dictionary and not str(entry.get("id", "")).is_empty():
			_entries[str(entry["id"])] = entry
	rebuild()
	_set_state(State.READY)


## Baut die Pack-Liste aus dem letzten Verzeichnis und dem aktuellen lokalen Stand neu.
## Ohne Netz — nach einer Installation oder einem eingelösten Code.
func rebuild() -> void:
	var installed := PackInstaller.installed()
	var app_version := gate_version()
	packs.clear()
	for id in _entries:
		packs.append(PackStatus.evaluate(
			_entries[id],
			installed.get(id, {}),
			app_version,
			AccessCodes.get_code(id),
		))
	changed.emit()


## Anzahl Packs, die einen Hinweis wert sind — trägt das Abzeichen im Startmenü.
func attention_count() -> int:
	var count := 0
	for pack in packs:
		if pack.wants_attention():
			count += 1
	return count


func find(pack_id: String) -> PackStatus:
	for pack in packs:
		if pack.id == pack_id:
			return pack
	return null


## Installiert oder aktualisiert mehrere Packs, einen nach dem anderen.
##
## Ein Fehlschlag beendet den Lauf, statt die Reihe fortzusetzen: wer nicht weiß, warum der
## erste Pack scheiterte, soll nicht drei weitere Meldungen dazu bekommen.
func install_many(ids: Array, adopt := false) -> void:
	if _busy or ids.is_empty():
		return
	_busy = true
	message = ""
	_set_state(State.WORKING)

	var written := 0
	var removed := 0
	var skipped := 0
	var adopt_wanted := 0
	needs_adopt.clear()
	for id in ids:
		var pack := find(str(id))
		if pack == null:
			continue
		activity = "%s wird geladen …" % pack.name
		changed.emit()
		var summary := await _install_one(pack, adopt)
		if not summary.error.is_empty():
			_busy = false
			activity = ""
			_fail("%s: %s" % [pack.name, summary.error])
			return
		written += summary.written
		removed += summary.removed
		skipped += summary.skipped_modified
		if summary.needs_adopt > 0:
			adopt_wanted += summary.needs_adopt
			needs_adopt.append(pack.id)

	_busy = false
	activity = ""
	_clear_tmp()
	# Der Katalog liest die neu geschriebenen Dateien erst nach einem Scan.
	ContentRegistry.reload()
	rebuild()
	message = "%d Datei(en) geschrieben" % written
	if removed > 0:
		message += ", %d entfernt" % removed
	if skipped > 0:
		message += ", %d lokal geändert und übersprungen" % skipped
	if adopt_wanted > 0:
		message += ". %d Datei(en) liegen dort, stammen aber nicht aus einem Pack." % adopt_wanted
	_set_state(State.READY)


func _install_one(pack: PackStatus, adopt: bool) -> PackInstaller.Summary:
	var summary := PackInstaller.Summary.new()

	# Zweite Sicherung neben dem Zustand APP_OUTDATED: hier endet der Weg auch dann, wenn
	# die Oberfläche die Sperre nicht beachtet.
	if SemVer.too_old_for(gate_version(), pack.min_version):
		summary.error = "setzt Monster Slam %s oder neuer voraus (installiert: %s)." % [
			pack.min_version, SemVer.app_version()
		]
		return summary
	if pack.file.is_empty():
		summary.error = "Verzeichnis nennt keine Datei."
		return summary

	if DirAccess.make_dir_recursive_absolute(TMP_DIR) != OK:
		summary.error = "Arbeitsverzeichnis nicht anlegbar."
		return summary
	var raw_path := "%s/%s.download" % [TMP_DIR, pack.id]
	var response := await _fetch("%s/%s" % [release_base, pack.file], PackedStringArray(), raw_path)
	if not response["error"].is_empty():
		summary.error = response["error"]
		return summary

	if not Digest.equal(Digest.of_file(raw_path), pack.sha256):
		summary.error = "Prüfsumme weicht ab — Download verworfen."
		return summary

	var zip_path := raw_path
	if pack.protected:
		var stored := AccessCodes.get_code(pack.id)
		if stored.is_empty():
			summary.error = "Kein Zugangscode hinterlegt."
			return summary
		activity = "%s wird entschlüsselt …" % pack.name
		changed.emit()
		# Die Schlüsselableitung kostet rund eine Sekunde; erst anzeigen, dann rechnen.
		await get_tree().process_frame
		var result := PackCrypto.decrypt(FileAccess.get_file_as_bytes(raw_path), str(stored["code"]))
		if not str(result["error"]).is_empty():
			summary.error = str(result["error"])
			return summary
		zip_path = "%s/%s.zip" % [TMP_DIR, pack.id]
		var file := FileAccess.open(zip_path, FileAccess.WRITE)
		if file == null:
			summary.error = "Entschlüsselter Pack nicht ablegbar."
			return summary
		file.store_buffer(result["zip"])
		file.close()

	return PackInstaller.install_zip(pack.id, zip_path, _entries.get(pack.id, {}), adopt)


## Probiert einen Zugangscode gegen alle geschützten Packs und gibt die Namen zurück, die er
## entsperrt hat.
##
## Der Nutzer bekommt einen Code und weiß in der Regel nicht, wozu er gehört — deshalb
## ordnet das Spiel ihn selbst zu, statt eine Auswahl zu verlangen. Geprüft wird nur am
## Kopf: die ersten 108 Bytes je Pack, nicht der ganze Download.
func redeem(code: String) -> PackedStringArray:
	var unlocked := PackedStringArray()
	var trimmed := code.strip_edges()
	if trimmed.is_empty() or _busy:
		return unlocked
	_busy = true
	message = ""
	activity = "Zugangscode wird geprüft …"
	_set_state(State.WORKING)

	for pack in packs:
		if not pack.protected or pack.file.is_empty():
			continue
		var headers := PackedStringArray(["Range: bytes=0-%d" % (PackCrypto.HEADER_LEN - 1)])
		var response := await _fetch("%s/%s" % [release_base, pack.file], headers)
		if not response["error"].is_empty():
			# Ein nicht ladbarer Pack darf die Prüfung der anderen nicht abbrechen.
			continue
		# Server ohne Range-Unterstützung liefern die ganze Datei; der Kopf steht trotzdem
		# vorn, read_header nimmt sich nur die ersten Bytes.
		var header := PackCrypto.read_header(response["body"])
		if PackCrypto.code_matches(header, trimmed):
			AccessCodes.store(pack.id, trimmed, pack.key_version)
			unlocked.append(pack.name)

	_busy = false
	activity = ""
	rebuild()
	message = "Der Code passt zu keinem Pack." if unlocked.is_empty() \
		else "Zugangscode gilt für: %s." % ", ".join(unlocked)
	_set_state(State.READY)
	return unlocked


func forget_code(pack_id: String) -> void:
	AccessCodes.forget(pack_id)
	rebuild()


## Ein HTTP-Vorgang, awaitbar. Rückgabe: {"error": String, "body": PackedByteArray}.
func _fetch(url: String, headers := PackedStringArray(), download_to := "") -> Dictionary:
	_http.download_file = download_to
	var err := _http.request(url, headers)
	if err != OK:
		return {"error": "Anfrage nicht startbar (Fehler %d)." % err, "body": PackedByteArray()}
	var result: Array = await _http.request_completed
	_http.download_file = ""
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Server nicht erreichbar.", "body": PackedByteArray()}
	var code := int(result[1])
	# 206 = Teilinhalt, die Antwort auf einen Range-Request.
	if code != 200 and code != 206:
		return {"error": "Server antwortet mit HTTP %d." % code, "body": PackedByteArray()}
	return {"error": "", "body": result[3] as PackedByteArray}


## Räumt Arbeitsdateien weg. Ein abgebrochener Download ist eine halbe Datei und wertlos.
func _clear_tmp() -> void:
	var dir := DirAccess.open(TMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


func _set_state(next: State) -> void:
	state = next
	if next != State.ERROR:
		error = ""
	changed.emit()


func _fail(text: String) -> void:
	error = text
	state = State.ERROR
	push_warning("ContentService: %s" % text)
	changed.emit()
