extends Node
## Autoload `ModelService`: holt Programm und Gewichte des lokalen Modell-Dienstes nach dem
## Manifest im Release-Kanal nach `user://model/`, wo `LocalModelServer` sucht. Die
## Sicherheit hängt allein an `sha256` im Manifest (ADR 0004, Nachtrag „Stufe 1 auf eigenen
## Beinen“).

## Zustand oder Fortschritt hat sich geändert.
signal changed

enum State { IDLE, LOADING, WORKING, READY, ERROR }

const MANIFEST_FILE := "model.json"
const TMP_DIR := "user://tmp"

## Höchstgröße des Manifests (Bytes); fängt eine falsch geroutete Antwort ab.
const MAX_MANIFEST_BYTES := 64 * 1024

## Schranken gegen einen still verworfenen Verbindungsaufbau (Issue #30); ein Gesamt-Limit
## gibt es für Teile nicht. Sekunden bis zum ersten Byte, Weiterleitungen eingeschlossen.
const CONNECT_TIMEOUT := 30.0
## Sekunden ohne neues Byte, während übertragen wird.
const STALL_TIMEOUT := 60.0
## Gesamtschranke für das Manifest (s).
const MANIFEST_TIMEOUT := 20.0
## Bytes je Frame beim Download.
const DOWNLOAD_CHUNK := 1024 * 1024

## Phasen eines Teils, für Anzeige und Fehlermeldung.
const PHASE_CONNECT := "Verbindungsaufbau"
const PHASE_TRANSFER := "Übertragung"
const PHASE_VERIFY := "Prüfsumme"
const PHASE_SETUP := "Einrichten"

## Wohin installiert wird; verstellbar, damit ein Test nicht ins echte Modell schreibt.
var dir := LocalModelServer.DEFAULT_DIR

var state: State = State.IDLE
var error := ""
## Was gerade passiert, für die Anzeige („Gewichte werden geladen …").
var activity := ""
var message := ""

## Der Inhalt des letzten Manifests: name, note, min_app_version, parts.
var manifest: Dictionary = {}
## Fortschritt über alle Teile, 0 bis 1.
var progress := 0.0
## Index des Teils, der gerade läuft (-1: keiner), seine Phase und seine geladenen Bytes.
## Teile davor sind fertig.
var current_part := -1
var current_phase := ""
var current_bytes := 0
## Was beim letzten Fehlschlag bekannt war: file, part, parts, host, phase, bytes, total,
## result, status, reason. Leer, wenn der Fehler keinen Teil betraf.
var failure: Dictionary = {}

var _http: HTTPRequest
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	# Teile gehen über `download_file` direkt auf die Platte, nicht in den Speicher.
	# Ohne Threads: mit `use_threads` liest der HTTPClient blockierend, und `cancel_request()`
	# wartet auf den Thread, sodass eine stumme Verbindung das Spiel einfriert (Issue #30).
	# Ein Block je Frame, darum groß.
	_http.use_threads = false
	_http.download_chunk_size = DOWNLOAD_CHUNK
	add_child(_http)


## Ist der Zusatz einsatzbereit? Fragt dieselben Dateien ab wie LocalModelServer.
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


## Wird gerade ein Zusatz angeboten?
func available() -> bool:
	return not parts().is_empty()


## Holt das Manifest. Kein Manifest ist kein Fehler, nur kein Angebot; der Grund geht als
## Warnung ins Log (ADR 0004).
func refresh() -> void:
	if _busy:
		return
	# Das Manifest nennt ein Windows-Programm; anderswo gibt es den Zusatz noch nicht.
	if not OS.has_feature("windows"):
		manifest = {}
		_set_state(State.READY)
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


## Lädt alle Teile und legt sie nach `dir` ab. Geprüft wird vor dem Ablegen; bis dahin liegt
## der Rohdownload unter user://tmp.
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
	failure = {}
	current_part = -1
	_set_state(State.WORKING)

	if DirAccess.make_dir_recursive_absolute(TMP_DIR) != OK \
			or DirAccess.make_dir_recursive_absolute(dir) != OK:
		_finish_failed("Zielverzeichnis nicht anlegbar.")
		return

	var total := maxi(1, total_bytes())
	var carried := 0
	var all := parts()
	for index in all.size():
		var part: Dictionary = all[index]
		var name := str(part.get("file", ""))
		if name.is_empty():
			_finish_failed("Manifest nennt einen Teil ohne Dateinamen.")
			return
		current_part = index
		current_bytes = 0
		_enter(PHASE_CONNECT, "%s wird geladen …" % name)

		var raw := "%s/%s.download" % [TMP_DIR, name.get_file()]
		var outcome := await _download(raw, str(part.get("url", "")), carried, total)
		if not str(outcome["reason"]).is_empty():
			_finish_part_failed(outcome)
			return

		_enter(PHASE_VERIFY, "%s wird geprüft …" % name)
		await get_tree().process_frame
		if not Digest.equal(Digest.of_file(raw), str(part.get("sha256", ""))):
			# Der einzige Halt dieses Weges: ohne ihn liefe ein beliebiges Programm aus dem Netz.
			_finish_part_failed({"reason": "Prüfsumme weicht ab — verworfen."})
			return

		_enter(PHASE_SETUP, "%s wird eingerichtet …" % name)
		await get_tree().process_frame
		var placed := _place(raw, name, bool(part.get("unzip", false)))
		if not placed.is_empty():
			_finish_part_failed({"reason": placed})
			return
		carried += int(part.get("bytes", 0))
		progress = float(carried) / float(total)

	_clear_tmp()
	current_part = -1
	current_phase = ""
	var missing := LocalModelServer.missing_in(dir)
	if not missing.is_empty():
		_finish_failed("Nach dem Einrichten fehlt noch: %s" % ", ".join(missing))
		return
	_busy = false
	activity = ""
	progress = 1.0
	message = "Sprachmodell einsatzbereit."
	_set_state(State.READY)


## Räumt den Zusatz wieder weg.
func remove() -> void:
	if _busy:
		return
	var folder := DirAccess.open(dir)
	if folder != null:
		for file in folder.get_files():
			folder.remove(file)
	message = "Sprachmodell entfernt."
	_set_state(State.READY)


## Größenangabe für die Anzeige („1,1 GB“).
static func humanized(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))
	if bytes >= 1024 * 1024:
		return "%d MB" % int(round(float(bytes) / (1024.0 * 1024.0)))
	if bytes >= 1024:
		return "%d KB" % int(round(float(bytes) / 1024.0))
	return "%d Bytes" % bytes


## Eine Zeile je Teil für die Anzeige: „model.gguf (2/2): 120 MB von 4.3 GB“. Die Größe kommt
## aus dem Manifest: `get_body_size()` schneidet die Content-Length über 4 GB auf 32 Bit ab.
func part_line(index: int) -> String:
	var all := parts()
	var part: Dictionary = all[index]
	var head := "%s (%d/%d)" % [str(part.get("file", "")), index + 1, all.size()]
	var size := humanized(int(part.get("bytes", 0)))
	if busy() and index < current_part:
		return "✓ %s: fertig" % head
	if busy() and index == current_part:
		match current_phase:
			PHASE_CONNECT:
				return "%s: Verbindung wird aufgebaut …" % head
			PHASE_TRANSFER:
				return "%s: %s von %s" % [head, humanized(current_bytes), size]
			_:
				return "%s: %s …" % [head, current_phase]
	return "%s: %s" % [head, size]


## Die Fehlermeldung zu `failure` in drei Zeilen: was, die Fakten, was man tun kann.
static func describe(info: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s (%d/%d) — %s: %s" % [info.get("file", "?"), int(info.get("part", 0)) + 1,
			int(info.get("parts", 0)), info.get("phase", "?"), info.get("reason", "")])
	var facts: Array[String] = []
	if not str(info.get("host", "")).is_empty():
		facts.append("Server: %s" % info["host"])
	facts.append("bis dahin %s von %s" % [humanized(int(info.get("bytes", 0))),
			humanized(int(info.get("total", 0)))])
	if info.has("result"):
		facts.append(result_name(int(info["result"])))
	if int(info.get("status", 0)) > 0:
		facts.append("HTTP %d" % int(info["status"]))
	lines.append(" · ".join(facts))
	lines.append(_advice(info))
	return "\n".join(lines)


static func _advice(info: Dictionary) -> String:
	var host := str(info.get("host", ""))
	if int(info.get("status", 0)) > 0:
		return "Der Server lehnt die Datei ab. Später noch einmal versuchen."
	if int(info.get("result", -1)) in [HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN,
			HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR]:
		return "Freien Speicherplatz prüfen und noch einmal versuchen."
	match str(info.get("phase", "")):
		PHASE_CONNECT:
			return "Im Browser prüfen, ob %s erreichbar ist. Ein Jugendschutz- oder " % host \
					+ "DNS-Filter oder eine Sicherheitssoftware kann die Adresse sperren."
		PHASE_TRANSFER:
			return "Die Verbindung ist abgerissen. Noch einmal versuchen; hält es wieder " \
					+ "an, im Browser prüfen, ob %s erreichbar ist." % host
		PHASE_VERIFY:
			return "Die Datei kam unvollständig oder verändert an. Noch einmal versuchen."
		_:
			return "Freien Speicherplatz prüfen und noch einmal versuchen."


## `HTTPRequest.Result` als Name statt als Zahl.
static func result_name(result: int) -> String:
	var names := {
		HTTPRequest.RESULT_SUCCESS: "RESULT_SUCCESS",
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "RESULT_CHUNKED_BODY_SIZE_MISMATCH",
		HTTPRequest.RESULT_CANT_CONNECT: "RESULT_CANT_CONNECT",
		HTTPRequest.RESULT_CANT_RESOLVE: "RESULT_CANT_RESOLVE",
		HTTPRequest.RESULT_CONNECTION_ERROR: "RESULT_CONNECTION_ERROR",
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "RESULT_TLS_HANDSHAKE_ERROR",
		HTTPRequest.RESULT_NO_RESPONSE: "RESULT_NO_RESPONSE",
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "RESULT_BODY_SIZE_LIMIT_EXCEEDED",
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "RESULT_BODY_DECOMPRESS_FAILED",
		HTTPRequest.RESULT_REQUEST_FAILED: "RESULT_REQUEST_FAILED",
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: "RESULT_DOWNLOAD_FILE_CANT_OPEN",
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: "RESULT_DOWNLOAD_FILE_WRITE_ERROR",
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "RESULT_REDIRECT_LIMIT_REACHED",
		HTTPRequest.RESULT_TIMEOUT: "RESULT_TIMEOUT",
	}
	return str(names.get(result, "RESULT_%d" % result))


## Nur der Host, nie die ganze URL: Weiterleitungsziele tragen signierte Query-Parameter.
static func host_of(url: String) -> String:
	var rest := url.get_slice("://", 1) if url.contains("://") else url
	var host := rest.get_slice("/", 0)
	host = host.get_slice("@", host.get_slice_count("@") - 1)
	return host.get_slice(":", 0)


## Hängt der Download? Vor dem ersten Byte gilt CONNECT_TIMEOUT, danach STALL_TIMEOUT —
## jeweils seit dem letzten Fortschritt.
static func stalled(receiving: bool, idle_seconds: float) -> bool:
	return idle_seconds > (STALL_TIMEOUT if receiving else CONNECT_TIMEOUT)


## Legt einen geladenen Teil an seinen Platz: ein ZIP wird ausgepackt, alles andere
## umbenannt. Gibt "" zurück, wenn es geklappt hat, sonst den Grund. Aus dem ZIP wird nur der
## Dateiname übernommen, nie der Pfad darin (Sicherheitsregel, ADR 0004).
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
	var has_server := false
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
		has_server = has_server or file_name == LocalModelServer.EXE_NAME
	reader.close()
	if not has_server:
		return "ZIP enthält %s nicht." % LocalModelServer.EXE_NAME
	return ""


## Was aus einem Archiv übernommen wird: der Server, alle DLLs (welche `ggml-cpu-*.dll` er
## braucht, entscheidet er beim Start) und die Lizenztexte. Andere Programme bleiben draußen.
static func _is_wanted(file_name: String) -> bool:
	var lower := file_name.to_lower()
	if lower.ends_with(".dll") or lower.begins_with("license"):
		return true
	return file_name == LocalModelServer.EXE_NAME


## Ein Download mit Fortschritt, gepollt statt auf das Signal gewartet, damit ein Stillstand
## zum Fehler wird (`stalled`). Gibt `reason` leer zurück, wenn es geklappt hat, sonst dazu
## `result` und `status`, soweit bekannt.
func _download(to: String, url: String, carried: int, total: int) -> Dictionary:
	if url.is_empty():
		return {"reason": "Manifest nennt keine Adresse."}
	var outcome: Array = []
	var on_done := func(result: int, code: int, _h: PackedStringArray,
			_b: PackedByteArray) -> void:
		# Füllen statt zuweisen: ein Lambda fängt Variablen als Kopie.
		outcome.append_array([result, code])
	_http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	_http.download_file = to
	_http.timeout = 0.0
	var err := _http.request(url)
	if err != OK:
		if _http.request_completed.is_connected(on_done):
			_http.request_completed.disconnect(on_done)
		_http.download_file = ""
		return {"reason": "Anfrage nicht startbar (%s)." % error_string(err)}

	var last_bytes := 0
	var last_change := Time.get_ticks_msec()
	while outcome.is_empty():
		var got := _http.get_downloaded_bytes()
		var now := Time.get_ticks_msec()
		if got != last_bytes:
			last_bytes = got
			last_change = now
		var receiving := got > 0 \
				or _http.get_http_client_status() == HTTPClient.STATUS_BODY
		if receiving and current_phase == PHASE_CONNECT:
			current_phase = PHASE_TRANSFER
		current_bytes = got
		if stalled(got > 0, float(now - last_change) / 1000.0):
			_http.cancel_request()
			if _http.request_completed.is_connected(on_done):
				_http.request_completed.disconnect(on_done)
			_http.download_file = ""
			if got > 0:
				return {"reason": "seit %d s kein neues Byte." % int(STALL_TIMEOUT)}
			return {"reason": "keine Antwort nach %d s." % int(CONNECT_TIMEOUT)}
		progress = float(carried + got) / float(total)
		changed.emit()
		await get_tree().process_frame
	_http.download_file = ""
	current_bytes = _http.get_downloaded_bytes()

	var result := int(outcome[0])
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"reason": "Download abgebrochen.", "result": result}
	if int(outcome[1]) != 200:
		return {"reason": "Server lehnt ab.", "result": result, "status": int(outcome[1])}
	return {"reason": ""}


## Ein kleiner HTTP-Vorgang in den Speicher — nur für das Manifest.
func _fetch(url: String) -> Dictionary:
	_http.download_file = ""
	_http.timeout = MANIFEST_TIMEOUT
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
	current_part = -1
	current_phase = ""
	_clear_tmp()
	_fail(text)


## Ein Teil ist gescheitert: hält fest, was bekannt ist, und meldet es ausführlich.
func _finish_part_failed(outcome: Dictionary) -> void:
	var all := parts()
	var part: Dictionary = all[current_part]
	failure = outcome.duplicate()
	failure.merge({
		"file": str(part.get("file", "")),
		"part": current_part,
		"parts": all.size(),
		"host": host_of(str(part.get("url", ""))),
		"phase": current_phase,
		"bytes": current_bytes,
		"total": int(part.get("bytes", 0)),
	})
	_finish_failed(describe(failure))


func _enter(phase: String, text: String) -> void:
	current_phase = phase
	activity = text
	changed.emit()


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
