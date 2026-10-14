extends Node
## Autoload `ContentService`: der Content-Kanal (ADR 0001) — Verzeichnis holen, Packs
## installieren, Zugangscodes einlösen. Offline ist der Normalfall: jeder Netzfehler ist ein
## Zustand, kein Abbruch.

## Zustand oder Pack-Liste hat sich geändert.
signal changed

enum State { IDLE, LOADING, WORKING, READY, ERROR }

## Release mit festem Tag im öffentlichen Transport-Repo.
const DEFAULT_RELEASE_BASE := "https://github.com/pesse/monster-slam-packs/releases/download/packs"

## Nur im Debug-Build aus MONSTER_SLAM_PACKS_BASE übernehmbar; im Release ist die Quelle fest.
var release_base := DEFAULT_RELEASE_BASE

const TMP_DIR := "user://tmp"

## Höchstgröße des Verzeichnisses (Bytes); fängt eine falsch geroutete Antwort ab.
const MAX_INDEX_BYTES := 512 * 1024

var state: State = State.IDLE
var packs: Array[PackStatus] = []
var error := ""
## Was gerade passiert, für die Anzeige („Access 2 wird geladen …").
var activity := ""
## Ergebnis des letzten Vorgangs, für die Anzeige.
var message := ""
## Packs, deren Installation auf vorhandene Fremddateien stieß; die UI kann
## `install_many(needs_adopt, true)` anbieten.
var needs_adopt: Array[String] = []

var _http: HTTPRequest
var _busy := false
## Roh-Einträge aus dem Verzeichnis, id -> Dictionary; die Installation braucht die
## Originalfelder.
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


## Die App-Version, an der die Schranke gemessen wird; "" heißt keine. Im Debug-Build gilt
## keine, weil project.godot die Version des letzten Releases trägt und Packs für die
## kommende Fassung sonst gesperrt wären.
func gate_version() -> String:
	return "" if OS.is_debug_build() else SemVer.app_version()


## Holt das Verzeichnis und verschneidet es mit dem lokalen Stand. Ohne `loud` endet ein
## Netzfehler still in IDLE, mit `loud` in ERROR mit Text.
func refresh(loud := false) -> void:
	if _busy:
		return
	_busy = true
	activity = ""
	message = ""
	_set_state(State.LOADING)

	var response := await _fetch("%s/index.json" % release_base)
	_busy = false
	if not response["error"].is_empty():
		_fail_refresh(response["error"], loud)
		return
	if response["body"].size() > MAX_INDEX_BYTES:
		_fail_refresh("Pack-Verzeichnis unplausibel groß — verworfen.", loud)
		return

	var parsed: Variant = JSON.parse_string(response["body"].get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).has("packs"):
		_fail_refresh("Pack-Verzeichnis unlesbar.", loud)
		return

	_entries.clear()
	for entry in (parsed as Dictionary)["packs"]:
		if entry is Dictionary and not str(entry.get("id", "")).is_empty():
			_entries[str(entry["id"])] = entry
	_retire_missing()
	rebuild()
	_set_state(State.READY)


## Deinstalliert Packs, die das Verzeichnis nicht mehr führt; `rebuild()` sähe sie nicht,
## geladen würden sie aber weiter.
func _retire_missing() -> void:
	var gone := PackInstaller.retired(PackInstaller.installed(), _entries.keys())
	if gone.is_empty():
		return
	for id in gone:
		PackInstaller.uninstall(id)
	ContentRegistry.reload()
	message = "%d Pack(s) zurückgezogen und entfernt" % gone.size()


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


## Anzahl Packs, die sich jetzt aktualisieren lassen. Gesperrte zählen nicht.
func update_count() -> int:
	var count := 0
	for pack in packs:
		if pack.wants_attention() and pack.installable():
			count += 1
	return count


func find(pack_id: String) -> PackStatus:
	for pack in packs:
		if pack.id == pack_id:
			return pack
	return null


## Installiert oder aktualisiert mehrere Packs nacheinander; der erste Fehlschlag beendet den
## Lauf.
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

	# Zweite Sicherung neben APP_OUTDATED, falls die Oberfläche die Sperre übergeht.
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


## Probiert einen Zugangscode gegen alle geschützten Packs, nur am Kopf jedes Packs, und gibt
## die Namen zurück, die er entsperrt hat.
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
			continue
		# Ohne Range-Unterstützung kommt die ganze Datei; read_header nimmt nur den Kopf.
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


## Räumt Arbeitsdateien weg.
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


func _fail_refresh(text: String, loud: bool) -> void:
	if loud:
		_fail(text)
		return
	print("ContentService: %s" % text)
	_set_state(State.IDLE)


func _fail(text: String) -> void:
	error = text
	state = State.ERROR
	push_warning("ContentService: %s" % text)
	changed.emit()
