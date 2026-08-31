extends Node
## Autoload `UpdateService`: der App-Kanal — prüfen, laden, verifizieren, ersetzen.
##
## Getrennt vom Content-Kanal (`ContentService`), weil beide unterschiedlich oft laufen und
## unterschiedlich groß sind: die EXE ist ~120 MB und ändert sich selten, ein Vokabel-Pack
## ist ein paar KB und ändert sich wöchentlich. Siehe docs/adr/0001-app-und-content-update.md.
##
## Jeder Netzfehler ist ein Zustand, kein Abbruch: die Startprüfung schweigt in die Konsole,
## das Spiel läuft mit dem, was installiert ist.

## Zustand hat sich geändert. Empfänger lesen `state`, `version`, `notes`, `progress`, `error`.
signal changed

enum State {
	IDLE,          ## Nichts anzubieten (oder noch nicht geprüft)
	CHECKING,      ## Manifest wird geholt
	AVAILABLE,     ## Neuere Fassung steht bereit
	DOWNLOADING,   ## EXE wird geladen
	VERIFYING,     ## Prüfsumme und Signatur werden geprüft
	READY,         ## Geprüft und bereit, installiert zu werden
	INSTALLING,    ## Dateien werden getauscht, Neustart folgt
	ERROR,         ## Benannter Fehlschlag; `error` trägt den Text
}

const MANIFEST_URL := "https://github.com/pesse/monster-slam/releases/latest/download/latest.json"

## Schlüssel des Plattform-Blocks in latest.json. Es gibt heute nur Windows-Builds; ein
## zweiter Eintrag hier braucht keinen Code, nur einen Build.
const PLATFORM := "windows-x86_64"

const DOWNLOAD_DIR := "user://updates"

## Ein Manifest ist ein paar KB. Die Schranke verhindert, dass ein falsch geroutetes
## Ziel (Fehlerseite, HTML) als Download durchläuft.
const MAX_MANIFEST_BYTES := 256 * 1024

var state: State = State.IDLE
var version := ""
var notes := ""
## Download-Fortschritt 0..1, oder -1 solange die Gesamtgröße unbekannt ist.
var progress := -1.0
var error := ""
## Gesetzt ab State.READY: die geprüfte, noch nicht installierte Fassung.
var ready_path := ""

var _http: HTTPRequest
## Der Plattform-Block des Manifests: url, sha256, signature.
var _entry: Dictionary = {}
## True, solange der laufende Vorgang von einem Klick ausgelöst wurde. Nur dann werden
## Fehler in der Oberfläche benannt — die Startprüfung bleibt still.
var _loud := false


func _ready() -> void:
	_http = HTTPRequest.new()
	# Ohne Thread blockiert das Schreiben der 120-MB-Datei den Renderer.
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	add_child(_http)
	_cleanup_leftovers()
	_cleanup_old_executable()
	# Stille Startprüfung: im Editor gar nicht, sonst ohne jede Meldung bei Netzfehlern.
	check()


func _process(_delta: float) -> void:
	if state != State.DOWNLOADING:
		return
	var total := _http.get_body_size()
	var got := _http.get_downloaded_bytes()
	var next := (float(got) / float(total)) if total > 0 else -1.0
	if not is_equal_approx(next, progress):
		progress = next
		changed.emit()


## Holt das Manifest und vergleicht es mit der laufenden Fassung.
##
## `loud` unterscheidet den Klick von der Startprüfung: still bleibt still. Im Editor wird
## ohne `loud` nicht geprüft — committet steht in project.godot immer die Version des
## LETZTEN Releases, die Prüfung meldete dort also dauerhaft ein Update auf sich selbst.
func check(loud := false) -> void:
	if state in [State.CHECKING, State.DOWNLOADING, State.VERIFYING, State.INSTALLING]:
		return
	if not loud and OS.has_feature("editor"):
		return
	_loud = loud
	_set_state(State.CHECKING)
	# Erst anfragen, dann verbinden: request_completed wird nie synchron aus request()
	# heraus gemeldet, und so gibt es keinen Callable, den ein Fehlerpfad wieder lösen muss.
	var err := _http.request(MANIFEST_URL)
	if err != OK:
		_fail("Update-Prüfung nicht möglich (Fehler %d)." % err)
		return
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)


func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Update-Server nicht erreichbar.")
		return
	if code != 200:
		_fail("Update-Server antwortet mit HTTP %d." % code)
		return
	if body.size() > MAX_MANIFEST_BYTES:
		_fail("Update-Manifest unplausibel groß — verworfen.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Update-Manifest unlesbar.")
		return

	var manifest: Dictionary = parsed
	var platforms: Dictionary = manifest.get("platforms", {})
	if not platforms.has(PLATFORM):
		# Kein Fehler des Nutzers: für diese Plattform gibt es das Release nicht.
		_set_state(State.IDLE)
		return
	var entry: Dictionary = platforms[PLATFORM]
	for field in ["url", "sha256", "signature"]:
		if str(entry.get(field, "")).is_empty():
			_fail("Update-Manifest unvollständig (%s fehlt)." % field)
			return

	var offered := str(manifest.get("version", ""))
	if not SemVer.is_newer(offered, SemVer.app_version()):
		_set_state(State.IDLE)
		return

	version = offered
	notes = str(manifest.get("notes", ""))
	_entry = entry
	_set_state(State.AVAILABLE)


## Lädt die angebotene Fassung und prüft sie. Endet in READY (installierbar) oder ERROR.
func download() -> void:
	if state != State.AVAILABLE:
		return
	_loud = true
	if DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR) != OK:
		_fail("Download-Verzeichnis nicht anlegbar.")
		return
	var target := "%s/MonsterSlam-%s.exe" % [DOWNLOAD_DIR, version]
	progress = -1.0
	_set_state(State.DOWNLOADING)
	_http.download_file = target
	var err := _http.request(str(_entry["url"]))
	if err != OK:
		_http.download_file = ""
		_fail("Download nicht startbar (Fehler %d)." % err)
		return
	_http.request_completed.connect(_on_download.bind(target), CONNECT_ONE_SHOT)


func _on_download(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, target: String) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_discard(target)
		_fail("Download fehlgeschlagen (HTTP %d)." % code)
		return

	progress = 1.0
	_set_state(State.VERIFYING)
	# Einen Frame durchlassen, damit „Wird geprüft" sichtbar wird, bevor Hash und
	# Signatur den Frame belegen.
	await get_tree().process_frame

	var problem := ReleaseVerifier.problem(
		target, str(_entry.get("sha256", "")), str(_entry.get("signature", ""))
	)
	if not problem.is_empty():
		# Eine Datei, die die Prüfung nicht besteht, bleibt nicht liegen.
		_discard(target)
		_fail(problem)
		return

	ready_path = target
	_set_state(State.READY)


## Ersetzt die laufende Programmdatei durch die geprüfte Fassung und startet neu.
##
## Reihenfolge und Rückrollpfad sind der eigentliche Inhalt dieser Funktion: ein halb
## ersetztes Spiel ist der einzige Ausgang, den es nicht geben darf. Deshalb wird zuerst
## umbenannt (unter Windows auch für die laufende Datei erlaubt) und erst dann geschrieben —
## scheitert der zweite Schritt, kommt der alte Name zurück.
func install() -> void:
	if state != State.READY:
		return
	_loud = true
	_set_state(State.INSTALLING)
	var problem := _swap()
	if problem.is_empty():
		return
	_fail(problem)


## "" bei Erfolg (danach läuft der Prozess nur noch bis zum quit()), sonst der Grund.
func _swap() -> String:
	if OS.has_feature("editor"):
		# Im Editor wäre die „Programmdatei" die Godot-Binärdatei.
		return "Im Editor wird nichts ersetzt — Update nur im gebauten Spiel."
	var current := OS.get_executable_path()
	var backup := current + ".old"
	var fresh := ProjectSettings.globalize_path(ready_path)
	if not FileAccess.file_exists(fresh):
		return "Die geladene Fassung ist nicht mehr da."

	# Ein Rest aus einem früheren, unvollständigen Versuch würde das Umbenennen blockieren.
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)

	if DirAccess.rename_absolute(current, backup) != OK:
		return "Programmdatei ist gesperrt. Neue Fassung liegt hier: %s" % fresh

	var moved := DirAccess.rename_absolute(fresh, current)
	if moved != OK:
		# Über Laufwerksgrenzen hinweg kann nicht umbenannt werden — dann kopieren.
		moved = DirAccess.copy_absolute(fresh, current)
	if moved != OK:
		DirAccess.rename_absolute(backup, current)
		return "Ersetzen fehlgeschlagen, alter Stand wiederhergestellt. Neue Fassung: %s" % fresh

	if OS.create_process(current, []) == -1:
		# Ersetzt ist ersetzt; ein Rückroll wäre hier schlimmer als ein Handstart.
		return "Ersetzt, aber Neustart fehlgeschlagen. Bitte das Spiel neu starten."
	get_tree().quit()
	return ""


## Löscht die verdrängte Programmdatei des vorigen Starts.
##
## Nicht früher: bis zum Prozessende ist die Datei gesperrt, das Löschen scheiterte also
## genau in dem Moment, in dem es versucht würde.
func _cleanup_old_executable() -> void:
	if OS.has_feature("editor"):
		return
	var backup := OS.get_executable_path() + ".old"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)


## Räumt liegengebliebene Downloads eines früheren Starts weg.
##
## Beim Start ist nie etwas anderes im Verzeichnis unterwegs, deshalb kann es vollständig
## leer gemacht werden: ein abgebrochener Download ist eine halbe Datei und wertlos.
func _cleanup_leftovers() -> void:
	var dir := DirAccess.open(DOWNLOAD_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


func _discard(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _set_state(next: State) -> void:
	state = next
	if next != State.ERROR:
		error = ""
	changed.emit()


func _fail(message: String) -> void:
	if _loud:
		push_warning("UpdateService: %s" % message)
		error = message
		state = State.ERROR
		changed.emit()
	else:
		# Startprüfung: nichts anzeigen, nur vermerken.
		print("UpdateService: %s" % message)
		_set_state(State.IDLE)
