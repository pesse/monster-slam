extends Node
## Der eine Ort, an dem der Spielstand gespeichert wird (Autoload, ADR 0024): alle Dateien
## eines Profils gemeinsam an der Wellengrenze, mit Journal, Sicherung und Prüfung beim Öffnen.
## Speicher melden sich mit `register` an und bieten
## player_id, save_suffix(), save_path(), save_payload(), reload(). Nicht angemeldete
## Instanzen oder andere Profile schreiben sofort und einzeln, ohne Sicherung.

const SAVE_DIR := "user://progress"
const BACKUP_DIR := "user://backups"
const QUARANTINE_DIR := "user://quarantine"
## Die Dateien eines Profils, die zu einer Sicherung gehören (ohne `_runs`, ADR 0024).
const PROFILE_SUFFIXES := ["", "_sessions", "_wallet", "_level", "_skills", "_inventory",
		"_bosses", "_badges", "_achievements", "_test_lists", "_writing"]
const JOURNAL_SUFFIX := ".commit.json"

## Ein Commit ist durch (`reason` wie beim Aufruf).
signal committed(profile: String, reason: String)
## Es gibt etwas, das der Spieler erfahren soll (take_notices).
signal notices_changed()

## Ordner — Tests setzen eigene.
var progress_dir := SAVE_DIR
var backup_dir := BACKUP_DIR
var quarantine_dir := QUARANTINE_DIR
var settings_path := "user://settings.cfg"
## Abstand der lokalen Zeit zu UTC (s): die Tagesgrenze der Sicherungen ist Mitternacht.
var utc_offset := int(Time.get_time_zone_from_system().get("bias", 0)) * 60

## Das Profil, dessen Dateien gerade gelten.
var profile := ""

var _stores: Array = []
var _held := 0
var _auto_pending := false
## Endungen beschädigter Dateien ohne Sicherung: solange nicht leer, speichert nichts.
var _blocked: Array = []
var _notices: Array = []
## Unter gdUnit4 schreibt das Autoload nichts (user:// enthält das Spielerprofil).
var _quiet := false


func _ready() -> void:
	profile = UserSettings.active_profile()
	_quiet = _under_test()
	var settings_notice: Dictionary = UserSettings.take_recovery_notice()
	if not settings_notice.is_empty():
		_add_notice(settings_notice)
	if not _quiet:
		open_profile(profile)
	# Als erster am Signal: der alte Stand wird gesichert, bevor die Speicher umschalten.
	UserSettings.active_profile_changed.connect(_on_profile_changed)
	EventBus.save_refused.connect(_on_save_refused)
	_check_plausible.call_deferred()


# --- Anmelden und Speichern ---------------------------------------------------

func register(store: Object) -> void:
	if not store in _stores:
		_stores.append(store)


func unregister(store: Object) -> void:
	_stores.erase(store)


## Ein Speicher hat sich geändert: gespeichert wird am Frame-Ende oder, solange `hold`
## gilt, beim nächsten `commit`. Nicht angemeldete sofort.
func mark_dirty(store: Object) -> void:
	if store in _stores and str(store.player_id) == profile:
		if _quiet:
			return
		if _held == 0 and not _auto_pending:
			_auto_pending = true
			_auto_commit.call_deferred()
		return
	write_now(store)


## Schreibt einen einzelnen Speicher sofort (sicher, mit Sperre, ohne Sicherung).
func write_now(store: Object) -> Error:
	return SaveGuard.write(store.save_path(), store.save_suffix(), store.save_payload())


## Hält das automatische Speichern an (Kampf). Paarweise mit `release`.
func hold() -> void:
	_held += 1


func release() -> void:
	_held = maxi(0, _held - 1)


func is_held() -> bool:
	return _held > 0


## Speichert alle angemeldeten Speicher des Profils gemeinsam und legt eine Sicherung an.
## `allow_drop` nennt Endungen, deren monotone Werte hier sinken dürfen. False, wenn nichts
## geschrieben wurde; dann gilt der vorige Stand auf der Platte.
func commit(reason: String, allow_drop: Array = []) -> bool:
	if _quiet:
		return false
	if not _blocked.is_empty():
		push_warning("SaveCoordinator: Profil '%s' ist gesperrt, nichts gespeichert" % profile)
		return false
	var entries: Array = []
	for store in _stores:
		if str(store.player_id) != profile:
			continue
		var path: String = store.save_path()
		var suffix: String = store.save_suffix()
		var data: Dictionary = store.save_payload()
		var refusal := SaveGuard.check(path, suffix, data, suffix in allow_drop)
		if not refusal.is_empty():
			SaveGuard.refuse(path, refusal)
			return false
		entries.append({"path": path, "bytes": SaveStore.encode(data)})
	var staged: Array = []
	for entry: Dictionary in entries:
		if SaveStore.stage(entry["path"], entry["bytes"]) != OK:
			for path: String in staged:
				DirAccess.remove_absolute(path + SaveStore.TMP_SUFFIX)
			return false
		staged.append(entry["path"])
	var journal := _journal_path(profile)
	if SaveStore.write(journal, {"files": staged.map(func(p: String) -> String: return p.get_file())}) != OK:
		for path: String in staged:
			DirAccess.remove_absolute(path + SaveStore.TMP_SUFFIX)
		return false
	for path: String in staged:
		if SaveStore.promote(path) != OK:
			# Das Journal bleibt: das nächste Öffnen bringt den Commit zu Ende.
			return false
	DirAccess.remove_absolute(journal)
	_backup(reason)
	committed.emit(profile, reason)
	return true


## Lädt alle Speicher außer `keep_on_discard` auf den letzten Commit zurück.
func discard_uncommitted() -> void:
	for store in _stores:
		if str(store.player_id) != profile or not store.has_method("reload"):
			continue
		if "keep_on_discard" in store and bool(store.keep_on_discard):
			continue
		store.reload()


func _auto_commit() -> void:
	_auto_pending = false
	if _held == 0:
		commit("auto")


# --- Profil öffnen ------------------------------------------------------------

## Prüft die Dateien des Profils `id` und repariert, was geht. Läuft, bevor die Speicher laden.
func open_profile(id: String) -> void:
	_blocked = []
	_finish_journal(id)
	var newest := Backups.latest(backup_dir, id)
	var backed_up := _suffixes_of(newest)
	var damaged: Array = []
	var legacy: Array = []
	var any := false
	for suffix: String in PROFILE_SUFFIXES:
		var read := SaveStore.read(_path(id, suffix))
		match int(read["status"]):
			SaveStore.Status.OK:
				any = true
				if bool(read["legacy"]):
					legacy.append(suffix)
			SaveStore.Status.MISSING:
				if suffix in backed_up:
					damaged.append(suffix)
			_:
				any = true
				damaged.append(suffix)
	if not damaged.is_empty():
		if newest.is_empty():
			_blocked = damaged
			push_warning("SaveCoordinator: '%s' beschädigt (%s), keine Sicherung" % [id, ", ".join(damaged)])
			_add_notice({"kind": "blocked", "profile": id, "files": damaged})
			EventBus.save_damaged.emit(damaged)
			return
		_restore(id, newest, damaged)
		return
	for suffix: String in legacy:
		SaveStore.write(_path(id, suffix), SaveStore.read(_path(id, suffix))["data"])
	if any and (newest.is_empty() or not legacy.is_empty()):
		_backup("open", id)


func is_blocked() -> bool:
	return not _blocked.is_empty()


## Gesperrtes Profil: beschädigte Dateien in die Quarantäne, für sie mit leerem Stand weiter.
func start_blank() -> void:
	if _quiet or _blocked.is_empty():
		return
	var into := _quarantine_folder(profile)
	for suffix: String in _blocked:
		SaveStore.quarantine(_path(profile, suffix), into, ".corrupt")
	_write_incident(into, {"profile": profile, "damaged": _blocked, "action": "start_blank"})
	var cleared := _blocked
	_blocked = []
	for store in _stores:
		if str(store.player_id) == profile and str(store.save_suffix()) in cleared:
			store.reload()
	commit("start_blank", cleared)


## Die neueste vollständige Sicherung eines Profils (Manifest mit `dir`) oder {}.
func latest_generation(id: String) -> Dictionary:
	return Backups.latest(backup_dir, id)


## Setzt ein Archiv (SaveArchive.read) als Spielstand des aktuellen Profils ein; vorher
## Sicherung, Ersetztes in die Quarantäne. False bei einem Schreibfehler.
func import_files(files: Dictionary) -> bool:
	if _quiet:
		return false
	if _blocked.is_empty():
		commit("before_import")
	else:
		_backup("before_import")
	# Heile Dateien, die das Archiv nicht hat, bleiben.
	var into := _quarantine_folder(profile)
	for suffix: String in PROFILE_SUFFIXES:
		var path := _path(profile, suffix)
		if files.has(suffix) or int(SaveStore.read(path, false)["status"]) not in \
				[SaveStore.Status.OK, SaveStore.Status.MISSING]:
			SaveStore.quarantine(path, into)
	for suffix: String in PROFILE_SUFFIXES:
		if not files.has(suffix):
			continue
		var target := _path(profile, suffix)
		var err := SaveStore.stage(target, files[suffix])
		if err == OK:
			err = SaveStore.promote(target)
		if err != OK:
			return false
	_write_incident(into, {"profile": profile, "action": "import", "files": files.keys()})
	_blocked = []
	for store in _stores:
		if str(store.player_id) == profile and store.has_method("reload"):
			store.reload()
	_backup("import")
	committed.emit(profile, "import")
	return true


## Was der Spieler erfahren soll, einmal: [{kind, profile, …}]. kind ist "restored",
## "blocked", "refused", "settings_restored", "settings_rebuilt" oder "implausible".
func take_notices() -> Array:
	var out := _notices
	_notices = []
	return out


# --- intern -------------------------------------------------------------------

func _on_profile_changed(id: String) -> void:
	if id == profile:
		return
	# Die Speicher stehen noch auf dem alten Profil.
	if _blocked.is_empty():
		commit("profile_switch")
	profile = id
	if not _quiet:
		open_profile(id)
		_check_plausible.call_deferred()


func _on_save_refused(file: String, reason: String) -> void:
	for notice: Dictionary in _notices:
		if notice.get("kind") == "refused":
			return
	_add_notice({"kind": "refused", "profile": profile, "file": file, "reason": reason})


## Mehr Skillpunkte ausgegeben als verdient heißt verlorene Erfahrung; wird nur gemeldet.
func _check_plausible() -> void:
	if SkillBook.unlimited_points or SkillBook.available() >= 0:
		return
	push_warning("SaveCoordinator: '%s' hat %d Skillpunkte" % [profile, SkillBook.available()])
	_add_notice({"kind": "implausible", "profile": profile})


func _restore(id: String, generation: Dictionary, damaged: Array) -> void:
	var into := _quarantine_folder(id)
	for suffix: String in PROFILE_SUFFIXES:
		SaveStore.quarantine(_path(id, suffix), into, ".corrupt" if suffix in damaged else "")
	_write_incident(into, {"profile": id, "damaged": damaged, "action": "restore",
			"restored_from": str(generation.get("dir", ""))})
	if Backups.restore(generation, id, progress_dir) != OK:
		_blocked = damaged
		_add_notice({"kind": "blocked", "profile": id, "files": damaged})
		EventBus.save_damaged.emit(damaged)
		return
	var at := int(generation.get("created_at", 0))
	push_warning("SaveCoordinator: '%s' aus der Sicherung %s zurückgeholt (%s)"
			% [id, str(generation.get("dir", "")), ", ".join(damaged)])
	_add_notice({"kind": "restored", "profile": id, "files": damaged, "backup_at": at})
	EventBus.save_restored.emit(damaged, at)


## Vollendet einen abgebrochenen Commit aus dem Journal. Eine vollständige `.tmp` ersetzt
## auch ein fehlendes oder kaputtes Ziel (Windows löscht beim Umbenennen erst das Ziel).
func _finish_journal(id: String) -> void:
	var journal := _journal_path(id)
	var listed: Array = []
	var read := SaveStore.read(journal)
	if int(read["status"]) == SaveStore.Status.OK:
		listed = (read["data"] as Dictionary).get("files", [])
	for suffix: String in PROFILE_SUFFIXES:
		var path := _path(id, suffix)
		var tmp := path + SaveStore.TMP_SUFFIX
		if not FileAccess.file_exists(tmp):
			continue
		var target_ok := int(SaveStore.read(path)["status"]) == SaveStore.Status.OK
		if SaveStore.pending_tmp(path) and (path.get_file() in listed or not target_ok):
			SaveStore.promote(path)
		else:
			DirAccess.remove_absolute(tmp)
	if FileAccess.file_exists(journal):
		DirAccess.remove_absolute(journal)


func _backup(reason: String, id := "") -> void:
	var who := id if not id.is_empty() else profile
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	Backups.create(backup_dir, who, progress_dir, PROFILE_SUFFIXES, reason, now_ms, settings_path)
	Backups.prune(backup_dir, who, now_ms, utc_offset)


func _add_notice(notice: Dictionary) -> void:
	_notices.append(notice)
	notices_changed.emit()


func _suffixes_of(manifest: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in (manifest.get("files", {}) as Dictionary).values():
		if not bool(entry.get("settings", false)):
			out.append(str(entry.get("suffix", "")))
	return out


func _path(id: String, suffix: String) -> String:
	return progress_dir.path_join(Backups.file_name(id, suffix))


func _journal_path(id: String) -> String:
	return progress_dir.path_join(id + JOURNAL_SUFFIX)


func _quarantine_folder(id: String) -> String:
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	return quarantine_dir.path_join(id).path_join(Backups.stamp_name(now_ms))


func _under_test() -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg).contains("GdUnitCmdTool"):
			return true
	return false


func _write_incident(into: String, info: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(into)
	info["at"] = int(Time.get_unix_time_from_system())
	info["app_version"] = str(ProjectSettings.get_setting("application/config/version", ""))
	SaveStore.write(into.path_join("incident.json"), info)
