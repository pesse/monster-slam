extends Node
## Autoload `StatsUploader`: der Statistik-Rückkanal (ADR 0021).
##
## Schickt je Profil einen Snapshot des Spielstands und die bereinigte Spur an den
## Statistik-Endpunkt (server/statistik/statistik.php). Zugeordnet wird über die zufällige
## `UserSettings.stats_id`, nie über Profilnamen oder player_id.
##
## Was hinausgeht, steht an zwei Stellen und nur dort: `snapshot()` (Allowlist je Datei
## unter user://progress) und `TraceSanitizer` (Allowlist je Spurereignis). Die Rohspur,
## gemeldete Kommentare, Testlisten und Profilnamen gehen nie mit.
##
## Wie die anderen Kanäle ist jeder Netzfehler ein Zustand, kein Abbruch: es bleibt still,
## und der nächste Anlass versucht es neu. Eine Warteschlange gibt es nicht — der Snapshot
## entsteht jedes Mal frisch aus den Dateien, und die Spur geht ab dem Stand, den der Server
## bestätigt hat.
##
## Gesendet wird nur, wenn alles zusammenkommt: Endpunkt und App-Schlüssel (beim Export
## eingesetzt, `KEY_PATH`), der gesehene Hinweis beim ersten Start, und keine
## Debug-Fassung (außer mit `MONSTER_SLAM_STATS_URL`). `zz-`-Profile sendet er nie.

## Vom Export geschrieben (build.sh, release.yml), nicht im Repo. Fehlt die Datei, ist der
## Kanal aus. Die URL steht mit darin, damit eine Fassung ohne Schlüssel auch keinen
## Endpunkt kennt — und ein Umzug des Servers keine Codeänderung ist.
##   [stats]
##   url="https://…/statistik/statistik.php"
##   key="app-1.XXXX-XXXX-XXXX-XXXX"
##   key_version=1
## Derselbe Schlüssel gilt auch fürs Melden; dessen URL steht in `[report]`
## (ReportService, ADR 0022).
const KEY_PATH := "res://stats_key.cfg"

const FORMAT := 1
const TIMEOUT_SECONDS := 20.0
const MAX_RESPONSE_BYTES := 8 * 1024
## Spurzeilen je Sendung. Bereinigt sind das gut 100 Byte je Zeile, gepackt ein Zehntel —
## weit unter der Grenze des Endpunkts.
const TRACE_CHUNK := 3000
## Nach so vielen Stücken je Anlass ist Schluss; der Rest geht beim nächsten Mal.
const MAX_CHUNKS := 20

const SAVE_DIR := "user://progress"

## Je Datei unter user://progress, was davon hinausgeht. `player_id` steht in jeder dieser
## Dateien und ist der Name — es fehlt deshalb überall.
const SNAPSHOT_FILES := {
	"": {"progress": "records"},
	"_sessions": {"sessions": "sessions"},
	"_wallet": {"wallet": ["gold", "total_earned", "chests_opened"]},
	"_level": {"level": ["total_xp"]},
	"_skills": {"skills": ["unlocked", "spent_points"]},
	"_inventory": {"inventory": "slots"},
	"_bosses": {"bosses": "wins"},
}

var endpoint := ""
var _key := ""
var _key_version := 1
var _http: HTTPRequest
var _busy := false
## Profile, die während eines laufenden Versands dazukamen.
var _again: Array[String] = []


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = TIMEOUT_SECONDS
	_http.body_size_limit = MAX_RESPONSE_BYTES
	add_child(_http)
	_load_key()
	if OS.is_debug_build():
		# Editor- und Testläufe senden nie von selbst — sie spielen im Entwicklungsprofil.
		# Für einen Versuch gegen einen lokalen Endpunkt: beide Variablen setzen.
		endpoint = OS.get_environment("MONSTER_SLAM_STATS_URL")
		_key = OS.get_environment("MONSTER_SLAM_STATS_KEY")
		if not endpoint.is_empty():
			print("StatsUploader: Endpunkt überschrieben -> %s" % endpoint)
	EventBus.run_ended.connect(func(_summary): _send_active.call_deferred())
	EventBus.boss_ended.connect(func(_boss, _won): _send_active.call_deferred())
	if can_send():
		_send_all.call_deferred()


## Ist der Kanal für diese Fassung eingerichtet (Endpunkt und App-Schlüssel)?
func configured() -> bool:
	return not endpoint.is_empty() and not _key.is_empty()


## Darf jetzt gesendet werden? Ohne gesehenen Hinweis nicht.
func can_send() -> bool:
	return configured() and UserSettings.stats_notice_seen()


## Der Hinweis wurde bestätigt: ab jetzt senden, gleich mit dem, was schon da ist.
func notice_acknowledged() -> void:
	UserSettings.set_stats_notice_seen(true)
	if can_send():
		_send_all.call_deferred()


static func sendable(profile: String) -> bool:
	return not profile.is_empty() and not profile.begins_with("zz-")


# --- Was hinausgeht -----------------------------------------------------------

## Der Snapshot eines Profils aus seinen Dateien. Statisch und ohne Autoload, damit ein
## Test ihn gegen eigene Dateien prüfen kann; `settings` und `meta` reicht der Aufrufer.
static func snapshot(profile: String, settings: Dictionary, meta: Dictionary,
		dir: String = SAVE_DIR) -> Dictionary:
	var out := {"format": FORMAT}
	out.merge(meta)
	out["settings"] = settings
	for suffix in SNAPSHOT_FILES:
		var path := "%s/%s%s.json" % [dir, profile, suffix]
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed
		var rule: Dictionary = SNAPSHOT_FILES[suffix]
		for key in rule:
			var pick: Variant = rule[key]
			if pick is Array:
				var part := {}
				for field in pick:
					if data.has(field):
						part[field] = data[field]
				out[key] = part
			elif data.has(pick):
				out[key] = data[pick]
	return out


## Die Einstellungen eines Profils, die zur Auswertung gehören. Auf dem Hauptthread
## gelesen: UserSettings ist ein Autoload.
func _settings_of(profile: String) -> Dictionary:
	return {
		"difficulty": UserSettings.default_difficulty(profile),
		"base_speed": UserSettings.base_speed(profile),
		"scope": Array(UserSettings.selected_scope(profile)),
		"tags": Array(UserSettings.selected_tags(profile)),
		"task_types": Array(UserSettings.selected_task_types(profile)),
		"lexeme_types": Array(UserSettings.selected_lexeme_types(profile)),
	}


func _meta(profile: String) -> Dictionary:
	var packs: Array = []
	var installed := PackInstaller.installed()
	for pack_id in installed:
		packs.append({"id": pack_id, "version": str((installed[pack_id] as Dictionary).get("version", ""))})
	return {
		"stats_id": UserSettings.stats_id(profile),
		"app_version": SemVer.app_version(),
		"platform": OS.get_name(),
		"locale": OS.get_locale_language(),
		"packs": packs,
		"sent_at": int(Time.get_unix_time_from_system()),
	}


## Die bereinigte Spur eines Profils nach `after`, älteste zuerst. Liest beide Generationen
## von vorn — die Lösungen für den Editierabstand stehen in früheren spawn-Zeilen.
static func trace_after(profile: String, after: Array, log_dir: String = TraceLog.LOG_DIR) -> Array:
	var lines := TraceSanitizer.read_lines("%s/%s_trace.1.jsonl" % [log_dir, profile])
	lines.append_array(TraceSanitizer.read_lines("%s/%s_trace.jsonl" % [log_dir, profile]))
	return TraceSanitizer.new().sanitize(lines, after)


# --- Versand ------------------------------------------------------------------

func _send_active() -> void:
	await send_profile(UserSettings.active_profile())


## Beim Start: jedes Profil, dessen Dateien sich seit dem letzten Snapshot geändert haben.
func _send_all() -> void:
	for profile in UserSettings.profiles():
		if _changed_since_sent(profile):
			await send_profile(profile)


func _changed_since_sent(profile: String) -> bool:
	var sent := UserSettings.stats_sent_at(profile)
	for suffix in SNAPSHOT_FILES:
		var path := "%s/%s%s.json" % [SAVE_DIR, profile, suffix]
		if FileAccess.file_exists(path) and int(FileAccess.get_modified_time(path)) > sent:
			return true
	return false


## Snapshot und Spur eines Profils. Gibt true zurück, wenn beides angekommen ist.
func send_profile(profile: String) -> bool:
	if not can_send() or not sendable(profile):
		return false
	if _busy:
		if profile not in _again:
			_again.append(profile)
		return false
	_busy = true
	var ok := await _send_snapshot(profile)
	if ok and UserSettings.trace_enabled():
		ok = await _send_trace(profile)
	_busy = false
	if not _again.is_empty():
		send_profile.call_deferred(_again.pop_front())
	return ok


func _send_snapshot(profile: String) -> bool:
	var settings := _settings_of(profile)
	var meta := _meta(profile)
	var body: Dictionary = await _off_thread(func() -> Dictionary:
			return snapshot(profile, settings, meta))
	body["action"] = "snapshot"
	body["key_version"] = _key_version
	var answer := await _post(body)
	if not answer["error"].is_empty():
		print("StatsUploader: Snapshot verschoben — %s" % answer["error"])
		return false
	UserSettings.set_stats_sent_at(profile, int(meta["sent_at"]))
	return true


func _send_trace(profile: String) -> bool:
	var cursor := UserSettings.stats_trace_cursor(profile)
	var events: Array = await _off_thread(func() -> Array: return trace_after(profile, cursor))
	var stats_id := UserSettings.stats_id(profile)
	var start := 0
	for _chunk in MAX_CHUNKS:
		if start >= events.size():
			return true
		var end := chunk_end(events, start, TRACE_CHUNK)
		var part := events.slice(start, end)
		var to := TraceSanitizer.mark_of(part.back())
		var answer := await _post({
			"action": "trace", "key_version": _key_version, "stats_id": stats_id,
			"from": cursor, "to": to, "events": part,
		})
		if not answer["error"].is_empty():
			print("StatsUploader: Spur verschoben — %s" % answer["error"])
			return false
		var have: Variant = (answer["data"] as Dictionary).get("have", to)
		cursor = [int(have[0]), int(have[1])] if have is Array and (have as Array).size() == 2 else to
		UserSettings.set_stats_trace_cursor(profile, cursor)
		if not bool(answer["data"].get("stored", true)):
			# Der Server hatte schon mehr (verlorene Antwort, zurückgesetzter Cursor):
			# ab seinem Stand weiter.
			while start < events.size() and not TraceSanitizer.is_after(
					TraceSanitizer.mark_of(events[start]), cursor):
				start += 1
			continue
		start += part.size()
	return start >= events.size()


## Ende (exklusiv) des Stücks ab `start`. [at, ms] ist nicht eindeutig — mehrere Zeilen
## entstehen in derselben Millisekunde —, und der Cursor sagt „alles bis einschließlich
## dieser Marke“. Ein Stück endet deshalb nie mitten in einer Gruppe gleicher Marken, sonst
## gälte der Rest der Gruppe als gesendet.
static func chunk_end(events: Array, start: int, size: int) -> int:
	var end := mini(start + size, events.size())
	var last := TraceSanitizer.mark_of(events[end - 1])
	while end < events.size() and TraceSanitizer.mark_of(events[end]) == last:
		end += 1
	return end


## Rechnet `work` auf einem Arbeitsthread: Dateien lesen, Spur bereinigen und packen soll
## das Bild am Laufende nicht anhalten.
func _off_thread(work: Callable) -> Variant:
	var result := [null]
	var task := WorkerThreadPool.add_task(func() -> void: result[0] = work.call())
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return result[0]


## Ein Vorgang gegen den Endpunkt, gzip-gepackt. Rückgabe: {"error": String, "data": Dictionary}.
func _post(payload: Dictionary) -> Dictionary:
	var packed := JSON.stringify(payload, "", false).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Content-Encoding: gzip",
		"Authorization: Bearer %s" % _key,
	])
	var err := _http.request_raw(endpoint, headers, HTTPClient.METHOD_POST, packed)
	if err != OK:
		return {"error": "nicht startbar (%d)" % err, "data": {}}
	var result: Array = await _http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "nicht erreichbar (Ergebnis %d)" % int(result[0]), "data": {}}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"error": "unverständliche Antwort (HTTP %d)" % int(result[1]), "data": {}}
	var data: Dictionary = parsed
	if not bool(data.get("ok", false)):
		return {"error": str(data.get("error", "abgewiesen")), "data": data}
	return {"error": "", "data": data}


func _load_key() -> void:
	var config := ConfigFile.new()
	if config.load(KEY_PATH) != OK:
		return
	endpoint = str(config.get_value("stats", "url", ""))
	_key = str(config.get_value("stats", "key", ""))
	_key_version = int(config.get_value("stats", "key_version", 1))
