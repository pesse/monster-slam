class_name Backups
extends RefCounted
## Sicherungen des Spielstands (docs/adr/0024-spielstand-sicher-speichern.md).
##
## Eine Sicherung ist eine GENERATION des ganzen Profils: alle seine Dateien zusammen, so
## wie sie nach einem Speichern dastanden, dazu eine Kopie der settings.cfg und ein
## Manifest mit den Prüfsummen. Gesichert wird nie Datei für Datei — zurückgespielt kämen
## sonst Erfahrung aus der einen und Skills aus einer anderen Sicherung zusammen, und das
## gibt wieder negative Skillpunkte.
##
##     user://backups/<profil>/<YYYY-MM-DD-HHMMSS-mmm>/
##         <profil>.json, <profil>_level.json, …   (Bytes der Live-Dateien, mit Hülle)
##         settings.cfg
##         manifest.json                          (zuletzt geschrieben)
##
## Gültig ist eine Generation nur mit gültigem Manifest und passenden Prüfsummen; eine, die
## beim Anlegen abbrach, hat kein Manifest und zählt nicht. Im Manifest stehen keine
## Kennzahlen (Level, Gold) — die stehen in den Dateien, ein zweiter Wert daneben könnte
## abweichen.
##
## Aufbewahrt wird gestaffelt (`retained`): die 3 neuesten, dazu die neueste je Tag der
## letzten 7 Tage und je Woche der letzten 8 Wochen — höchstens 18. Fünf Sicherungen je
## Welle reichten nur zehn Minuten zurück; ein Fehler, der still falsche Werte schreibt,
## hätte sie alle erreicht, bevor ihn jemand bemerkt.
##
## Statisch und mit Ordner-Argumenten, damit Tests in eigenen Ordnern laufen.

const MANIFEST := "manifest.json"
const SETTINGS_COPY := "settings.cfg"
const KEEP_LATEST := 3
const KEEP_DAYS := 7
const KEEP_WEEKS := 8
const DAY_MS := 86_400_000


static func file_name(profile: String, suffix: String) -> String:
	return "%s%s.json" % [profile, suffix]


## Ordnername einer Generation: UTC-Zeit mit Millisekunden, lexikografisch sortierbar.
static func stamp_name(at_ms: int) -> String:
	var text := Time.get_datetime_string_from_unix_time(at_ms / 1000)
	return "%s-%03d" % [text.replace(":", "").replace("T", "-"), at_ms % 1000]


## Legt eine Generation an und gibt ihren Ordner zurück ("" bei einem Fehler). Kopiert
## werden die Dateien `suffixes` des Profils, die es gibt — eine unlesbare bricht ab: eine
## Sicherung mit einer kaputten Datei wäre beim Zurückspielen eine Falle.
static func create(base: String, profile: String, progress_dir: String, suffixes: Array,
		reason: String, at_ms: int, settings_path := "user://settings.cfg") -> String:
	var root := base.path_join(profile)
	var dir := root.path_join(stamp_name(at_ms))
	var bump := 0
	while DirAccess.dir_exists_absolute(dir):
		bump += 1
		dir = root.path_join("%s-%d" % [stamp_name(at_ms), bump])
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_warning("Backups: '%s' nicht anlegbar" % dir)
		return ""
	var files := {}
	for suffix: String in suffixes:
		var source := progress_dir.path_join(file_name(profile, suffix))
		if not FileAccess.file_exists(source):
			continue
		var bytes := FileAccess.get_file_as_bytes(source)
		if int(SaveStore.decode(bytes, false)["status"]) != SaveStore.Status.OK:
			push_warning("Backups: '%s' ist nicht lesbar, keine Sicherung" % source)
			_remove_dir(dir)
			return ""
		var name := file_name(profile, suffix)
		if not _put(dir.path_join(name), bytes):
			_remove_dir(dir)
			return ""
		files[name] = {"suffix": suffix, "sha256": SaveStore.sha256_hex(bytes), "bytes": bytes.size()}
	if FileAccess.file_exists(settings_path) \
			and int(SaveStore.read_cfg(settings_path)["status"]) == SaveStore.Status.OK:
		var cfg := FileAccess.get_file_as_bytes(settings_path)
		if _put(dir.path_join(SETTINGS_COPY), cfg):
			files[SETTINGS_COPY] = {"suffix": "", "sha256": SaveStore.sha256_hex(cfg), "bytes": cfg.size(),
					"settings": true}
	var manifest := {
		"format": 1, "profile": profile, "reason": reason,
		"created_at": at_ms / 1000, "created_ms": at_ms,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"files": files,
	}
	if SaveStore.write(dir.path_join(MANIFEST), manifest) != OK:
		_remove_dir(dir)
		return ""
	return dir


## Das Manifest einer Generation ohne Prüfung der Dateien, oder {}.
static func manifest_of(dir: String) -> Dictionary:
	var read := SaveStore.read(dir.path_join(MANIFEST))
	if int(read["status"]) != SaveStore.Status.OK or not (read["data"] as Dictionary).get("files") is Dictionary:
		return {}
	return read["data"]


## Prüft eine Generation: das Manifest (mit `dir`) oder {}, wenn sie nicht vollständig ist.
static func verify(dir: String) -> Dictionary:
	var read := SaveStore.read(dir.path_join(MANIFEST))
	if int(read["status"]) != SaveStore.Status.OK:
		return {}
	var manifest: Dictionary = read["data"]
	var files: Variant = manifest.get("files")
	if not files is Dictionary:
		return {}
	for name: String in files:
		var entry: Variant = files[name]
		if not entry is Dictionary or name.contains("/") or name.contains("\\") or name.contains(".."):
			return {}
		var path := dir.path_join(name)
		if not FileAccess.file_exists(path) \
				or SaveStore.sha256_hex(FileAccess.get_file_as_bytes(path)) != str(entry.get("sha256", "")):
			return {}
	manifest["dir"] = dir
	return manifest


## Alle Ordner einer Profil-Sicherung, älteste zuerst (gültig oder nicht).
static func generation_dirs(base: String, profile: String) -> PackedStringArray:
	var root := base.path_join(profile)
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray()
	var names := DirAccess.get_directories_at(root)
	names.sort()
	var out := PackedStringArray()
	for name in names:
		out.append(root.path_join(name))
	return out


## Die gültigen Generationen eines Profils, neueste zuerst (je ein Manifest mit `dir`).
static func list_valid(base: String, profile: String) -> Array:
	var out: Array = []
	var dirs := generation_dirs(base, profile)
	for i in range(dirs.size() - 1, -1, -1):
		var manifest := verify(dirs[i])
		if not manifest.is_empty():
			out.append(manifest)
	return out


## Die neueste gültige Generation oder {}.
static func latest(base: String, profile: String) -> Dictionary:
	var dirs := generation_dirs(base, profile)
	for i in range(dirs.size() - 1, -1, -1):
		var manifest := verify(dirs[i])
		if not manifest.is_empty():
			return manifest
	return {}


## Spielt eine Generation (Manifest aus `verify`) als Profil `profile` zurück: jede ihrer
## Dateien sicher an ihren Platz. Die settings.cfg bleibt außen vor — sie gilt allen
## Profilen. Was die Live-Menge sonst noch hatte, muss der Aufrufer vorher beiseitelegen.
static func restore(manifest: Dictionary, profile: String, progress_dir: String) -> Error:
	var dir := str(manifest.get("dir", ""))
	var files: Dictionary = manifest.get("files", {})
	for name: String in files:
		var entry: Dictionary = files[name]
		if bool(entry.get("settings", false)):
			continue
		var bytes := FileAccess.get_file_as_bytes(dir.path_join(name))
		var target := progress_dir.path_join(file_name(profile, str(entry.get("suffix", ""))))
		var err := SaveStore.stage(target, bytes)
		if err == OK:
			err = SaveStore.promote(target)
		if err != OK:
			return err
	return OK


## Die Bytes der neuesten gesicherten settings.cfg über alle Profile, oder leer.
static func newest_settings(base: String) -> PackedByteArray:
	if not DirAccess.dir_exists_absolute(base):
		return PackedByteArray()
	var best_ms := -1
	var best := PackedByteArray()
	for profile in DirAccess.get_directories_at(base):
		for manifest: Dictionary in list_valid(base, profile):
			if not (manifest.get("files", {}) as Dictionary).has(SETTINGS_COPY):
				continue
			if int(manifest.get("created_ms", 0)) > best_ms:
				best_ms = int(manifest.get("created_ms", 0))
				best = FileAccess.get_file_as_bytes(str(manifest["dir"]).path_join(SETTINGS_COPY))
			break   # list_valid ist neueste zuerst
	return best


## Welche Zeitpunkte (ms) bleiben? Die KEEP_LATEST neuesten, die neueste je lokalem Tag der
## letzten KEEP_DAYS Tage und je Woche der letzten KEEP_WEEKS Wochen. Zeitpunkte in der
## Zukunft (verstellte Uhr) bleiben immer. Rein rechnend, ohne Dateien.
static func retained(stamps: Array, now_ms: int, utc_offset_s: int) -> Array:
	var sorted := stamps.duplicate()
	sorted.sort()
	sorted.reverse()
	var keep := {}
	var today := _day(now_ms, utc_offset_s)
	var days_seen := {}
	var weeks_seen := {}
	for i in sorted.size():
		var at := int(sorted[i])
		if at > now_ms:
			keep[at] = true
			continue
		if i < KEEP_LATEST:
			keep[at] = true
		# Auch die neuesten belegen ihren Tag und ihre Woche: sonst bliebe am selben Tag eine
		# vierte stehen.
		var age := today - _day(at, utc_offset_s)
		if age < KEEP_DAYS and not days_seen.has(age):
			days_seen[age] = true
			keep[at] = true
		var week := age / 7
		if week < KEEP_WEEKS and not weeks_seen.has(week):
			weeks_seen[week] = true
			keep[at] = true
	var out: Array = []
	for at in sorted:
		if keep.has(int(at)):
			out.append(int(at))
	return out


## Räumt die Sicherungen eines Profils nach `retained` auf. Eine unvollständige Generation
## fällt weg, sobald es eine neuere gültige gibt. Gelöscht wird jede Datei einzeln mit
## Namen, dann der leere Ordner.
static func prune(base: String, profile: String, now_ms: int, utc_offset_s: int) -> void:
	var valid := {}
	var newest_valid := ""
	for dir in generation_dirs(base, profile):
		# Nur das Manifest, ohne die Prüfsummen aller Dateien: Aufräumen läuft nach jedem
		# Speichern, und welche Sicherung taugt, prüft erst das Zurückspielen (verify).
		var manifest := manifest_of(dir)
		if not manifest.is_empty():
			valid[dir] = int(manifest.get("created_ms", 0))
			newest_valid = dir
	var kept := retained(valid.values(), now_ms, utc_offset_s)
	for dir in generation_dirs(base, profile):
		if valid.has(dir):
			if not int(valid[dir]) in kept and dir != newest_valid:
				_remove_dir(dir)
		elif not newest_valid.is_empty() and dir < newest_valid:
			_remove_dir(dir)


static func _day(at_ms: int, utc_offset_s: int) -> int:
	return floori((at_ms / 1000.0 + utc_offset_s) / 86400.0)


static func _put(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Backups: '%s' nicht schreibbar" % path)
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok


## Löscht einen Generationsordner: jede Datei einzeln mit Namen, dann den Ordner.
static func _remove_dir(dir: String) -> void:
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)
