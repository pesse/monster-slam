extends Node
## Autoload `ModelService`: holt den lokalen Modell-Dienst auf diesen Rechner — Programm
## und Gewichte, in einem Vorgang, hinter einem Knopf.
##
## Der Grund steht in ADR 0004, Nachtrag „Stufe 1 auf eigenen Beinen": Eltern legen keine
## Dateien in ein AppData-Verzeichnis. Ohne diesen Weg wäre der Zusatz eine Anleitung, und
## eine Anleitung ist keine Auslieferung.
##
## Geladen wird nach `user://model/` — genau dorthin, wo `LocalModelServer` sucht.
##
## **Warum kein eigener Pack mit einem Gigabyte darin:** llama.cpp und die Gewichte liegen
## bereits als dauerhafte Downloads im Netz. Ein eigener Spiegel kostete Speicherplatz und
## Pflege, ohne etwas zu gewinnen — was wir liefern müssen, ist nicht die Datei, sondern
## die Zusicherung, WELCHE Datei gemeint ist. Das ist die Prüfsumme im Manifest.
##
## **Deshalb hängt die Sicherheit hier an `sha256` und an nichts sonst.** Das Manifest
## nennt für jeden Teil URL, Prüfsumme und Größe; was nicht passt, wird verworfen und nicht
## installiert. Dieselbe Haltung wie bei den Content-Packs (ADR 0001), nur dass dort der
## Pack von uns kommt und hier nur die Zusicherung darüber.
##
## Das Manifest liegt neben dem Pack-Verzeichnis im Release-Kanal. Es ist damit änderbar,
## ohne die App neu auszuliefern — ein anderes Modell ist eine Datei, kein Release.

## Zustand oder Fortschritt hat sich geändert.
signal changed

enum State { IDLE, LOADING, WORKING, READY, ERROR }

const MANIFEST_FILE := "model.json"
const TMP_DIR := "user://tmp"

## Ein Manifest sind ein paar Zeilen. Die Schranke fängt eine falsch geroutete Antwort ab,
## bevor sie als Manifest durchläuft.
const MAX_MANIFEST_BYTES := 64 * 1024

## Was aus einem ZIP übernommen wird. Ein llama.cpp-Release bringt das Programm und seine
## DLLs mit — ohne die startet es nicht. Alles andere (Kopfdateien, Beispiele) bleibt
## draußen: was nicht ausgepackt wird, kann auch nichts anrichten.
const ALLOWED_SUFFIXES := [".exe", ".dll"]

## Wohin installiert wird. Vorgabe ist genau das Verzeichnis, in dem LocalModelServer
## sucht; verstellbar, damit ein Test nicht in das echte Modell des Spielers schreibt —
## dieselbe Regel wie beim `zz-`Profil von Wallet und PlayerLevel.
var dir := LocalModelServer.DEFAULT_DIR

var state: State = State.IDLE
var error := ""
## Was gerade passiert, für die Anzeige („Gewichte werden geladen …").
var activity := ""
var message := ""

## Der Inhalt des letzten Manifests: name, note, min_app_version, parts.
var manifest: Dictionary = {}
## 0 bis 1 über ALLE Teile — der Balken soll einmal durchlaufen und nicht je Datei neu.
var progress := 0.0

var _http: HTTPRequest
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	# Ein Gigabyte gehört nicht in den Hauptthread und nicht in den Speicher: mit
	# `download_file` schreibt Godot direkt auf die Platte.
	_http.use_threads = true
	add_child(_http)


## Ist der Zusatz einsatzbereit? Fragt dieselben zwei Dateien ab wie LocalModelServer —
## eine zweite Buchführung darüber, was installiert ist, liefe irgendwann auseinander.
func installed() -> bool:
	return LocalModelServer.missing_in(dir).is_empty()


func busy() -> bool:
	return _busy


## Wie groß der Download insgesamt ist, in Bytes — 0, solange kein Manifest da ist.
func total_bytes() -> int:
	var total := 0
	for part in parts():
		total += int((part as Dictionary).get("bytes", 0))
	return total


func parts() -> Array:
	return Array(manifest.get("parts", []))


## Der Name, unter dem der Zusatz in der Oberfläche steht.
func display_name() -> String:
	return str(manifest.get("name", "Sprachmodell für Bosskämpfe"))


## Wird gerade ein Zusatz angeboten? Ohne Manifest gibt es nichts zu holen — und dann hat
## die Oberfläche auch nichts anzuzeigen.
func available() -> bool:
	return not parts().is_empty()


## Holt das Manifest.
##
## **Kein Manifest ist KEIN Fehler.** Es heißt: dieser Kanal bietet gerade keinen Zusatz an
## — weil noch keiner veröffentlicht ist (HTTP 404), weil kein Netz da ist, oder weil die
## Datei unbrauchbar ist. Für den Spieler ist das dreimal dasselbe: es gibt nichts zu
## holen. Ein rotes „Server antwortet mit HTTP 404" an einem Zusatz, den niemand bestellt
## hat, ist eine Fehlermeldung für einen Zustand, der keiner ist.
##
## Gemeldet wird trotzdem — als Warnung ins Log, damit ein kaputtes Manifest beim
## Entwickeln nicht unsichtbar bleibt. Ein Fehler, den der Nutzer sieht, entsteht erst,
## wenn er selbst auf „Herunterladen" gedrückt hat: dann hat er eine Antwort verdient.
func refresh() -> void:
	if _busy:
		return
	_busy = true
	message = ""
	_set_state(State.LOADING)

	var url := "%s/%s" % [ContentService.release_base, MANIFEST_FILE]
	var response := await _fetch(url)
	_busy = false
	if not str(response["error"]).is_empty():
		_no_offer(str(response["error"]))
		return
	var body: PackedByteArray = response["body"]
	if body.size() > MAX_MANIFEST_BYTES:
		_no_offer("Modell-Manifest unplausibel groß — verworfen.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("parts"):
		_no_offer("Modell-Manifest unlesbar.")
		return
	manifest = parsed
	_set_state(State.READY)


## Es gibt nichts anzubieten. Der Grund geht ins Log, nicht auf den Bildschirm.
func _no_offer(reason: String) -> void:
	manifest = {}
	push_warning("ModelService: kein Zusatz verfügbar — %s" % reason)
	_set_state(State.READY)


## Lädt alle Teile und legt sie nach user://model/ ab. Ein Fehlschlag lässt nichts halb
## Installiertes zurück: geprüft wird VOR dem Ablegen, und der Rohdownload liegt bis dahin
## unter user://tmp.
func install() -> void:
	if _busy:
		return
	if parts().is_empty():
		_fail("Kein Modell-Manifest geladen.")
		return
	if not str(manifest.get("min_app_version", "")).is_empty() \
			and SemVer.too_old_for(ContentService.gate_version(),
					str(manifest["min_app_version"])):
		_fail("Setzt Monster Slam %s oder neuer voraus." % manifest["min_app_version"])
		return

	_busy = true
	message = ""
	progress = 0.0
	_set_state(State.WORKING)

	if DirAccess.make_dir_recursive_absolute(TMP_DIR) != OK \
			or DirAccess.make_dir_recursive_absolute(dir) != OK:
		_finish_failed("Zielverzeichnis nicht anlegbar.")
		return

	var total := maxi(1, total_bytes())
	var carried := 0
	for entry in parts():
		var part: Dictionary = entry
		var name := str(part.get("file", ""))
		if name.is_empty():
			_finish_failed("Manifest nennt einen Teil ohne Dateinamen.")
			return
		activity = "%s wird geladen …" % name
		changed.emit()

		var raw := "%s/%s.download" % [TMP_DIR, name.get_file()]
		var outcome := await _download(raw, str(part.get("url", "")), carried, total)
		if not str(outcome["error"]).is_empty():
			_finish_failed("%s: %s" % [name, outcome["error"]])
			return

		if not Digest.equal(Digest.of_file(raw), str(part.get("sha256", ""))):
			# Der einzige Halt, den dieser Weg hat. Ohne ihn lüde das Spiel irgendein
			# Programm aus dem Netz und führte es aus.
			_finish_failed("%s: Prüfsumme weicht ab — verworfen." % name)
			return

		activity = "%s wird eingerichtet …" % name
		changed.emit()
		await get_tree().process_frame
		var placed := _place(raw, name, bool(part.get("unzip", false)))
		if not placed.is_empty():
			_finish_failed("%s: %s" % [name, placed])
			return
		carried += int(part.get("bytes", 0))
		progress = float(carried) / float(total)

	_clear_tmp()
	var missing := LocalModelServer.missing_in(dir)
	if not missing.is_empty():
		_finish_failed("Nach dem Einrichten fehlt noch: %s" % ", ".join(missing))
		return
	_busy = false
	activity = ""
	progress = 1.0
	message = "Sprachmodell einsatzbereit."
	_set_state(State.READY)


## Räumt den Zusatz wieder weg. Ein Gigabyte, das man nicht mehr braucht, muss man auch
## wieder loswerden können — sonst ist der Knopf eine Einbahnstraße.
func remove() -> void:
	if _busy:
		return
	var folder := DirAccess.open(dir)
	if folder != null:
		for file in folder.get_files():
			folder.remove(file)
	message = "Sprachmodell entfernt."
	_set_state(State.READY)


## Größenangabe für die Anzeige. „1,1 GB" beantwortet die Frage, die vor dem Klick steht.
static func humanized(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))
	if bytes >= 1024 * 1024:
		return "%d MB" % int(round(float(bytes) / (1024.0 * 1024.0)))
	if bytes >= 1024:
		return "%d KB" % int(round(float(bytes) / 1024.0))
	return "%d Bytes" % bytes


## Legt einen geladenen Teil an seinen Platz. Ein ZIP wird ausgepackt, alles andere
## umbenannt.
##
## **Aus dem ZIP wird nur der Dateiname übernommen, nie der Pfad darin** (`get_file()`).
## Damit kann ein Eintrag wie `../../autostart.exe` nichts anrichten — und zugleich ist es
## egal, ob ein llama.cpp-Release seine Dateien im Wurzelverzeichnis oder unter `build/bin`
## führt. Gibt "" zurück, wenn es geklappt hat, sonst den Grund.
func _place(raw: String, name: String, unzip: bool) -> String:
	var target_dir := dir
	if not unzip:
		var target := target_dir.path_join(name.get_file())
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(raw),
				ProjectSettings.globalize_path(target)) != OK:
			return "nicht ablegbar."
		return ""

	var reader := ZIPReader.new()
	if reader.open(raw) != OK:
		return "kein gültiges ZIP."
	var written := 0
	for entry in reader.get_files():
		var rel := str(entry)
		if rel.ends_with("/"):
			continue
		var file_name := rel.get_file()
		if not _is_wanted(file_name):
			continue
		var out := FileAccess.open(target_dir.path_join(file_name), FileAccess.WRITE)
		if out == null:
			reader.close()
			return "%s nicht schreibbar." % file_name
		out.store_buffer(reader.read_file(rel))
		out.close()
		written += 1
	reader.close()
	if written == 0:
		return "ZIP enthält kein Programm."
	return ""


static func _is_wanted(file_name: String) -> bool:
	for suffix in ALLOWED_SUFFIXES:
		if file_name.to_lower().ends_with(suffix):
			return true
	return false


## Ein Download mit Fortschritt. Anders als ContentService._fetch wird hier nicht auf das
## Signal gewartet, sondern daneben gepollt: bei einem Gigabyte ist ein Balken, der sich
## nicht bewegt, von einem Absturz nicht zu unterscheiden.
func _download(to: String, url: String, carried: int, total: int) -> Dictionary:
	if url.is_empty():
		return {"error": "Manifest nennt keine Adresse."}
	var outcome: Array = []
	var on_done := func(result: int, code: int, _h: PackedStringArray,
			_b: PackedByteArray) -> void:
		outcome = [result, code]
	_http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	_http.download_file = to
	var err := _http.request(url)
	if err != OK:
		if _http.request_completed.is_connected(on_done):
			_http.request_completed.disconnect(on_done)
		_http.download_file = ""
		return {"error": "Anfrage nicht startbar (Fehler %d)." % err}

	while outcome.is_empty():
		progress = float(carried + _http.get_downloaded_bytes()) / float(total)
		changed.emit()
		await get_tree().process_frame
	_http.download_file = ""

	if int(outcome[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Server nicht erreichbar."}
	if int(outcome[1]) != 200:
		return {"error": "Server antwortet mit HTTP %d." % int(outcome[1])}
	return {"error": ""}


## Ein kleiner HTTP-Vorgang in den Speicher — nur für das Manifest.
func _fetch(url: String) -> Dictionary:
	_http.download_file = ""
	var err := _http.request(url)
	if err != OK:
		return {"error": "Anfrage nicht startbar (Fehler %d)." % err, "body": PackedByteArray()}
	var result: Array = await _http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Server nicht erreichbar.", "body": PackedByteArray()}
	if int(result[1]) != 200:
		return {"error": "Server antwortet mit HTTP %d." % int(result[1]), "body": PackedByteArray()}
	return {"error": "", "body": result[3] as PackedByteArray}


func _clear_tmp() -> void:
	var dir := DirAccess.open(TMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


func _finish_failed(text: String) -> void:
	_busy = false
	activity = ""
	progress = 0.0
	_clear_tmp()
	_fail(text)


func _set_state(next: State) -> void:
	state = next
	if next != State.ERROR:
		error = ""
	changed.emit()


func _fail(text: String) -> void:
	error = text
	state = State.ERROR
	push_warning("ModelService: %s" % text)
	changed.emit()
