class_name WritingLog
extends RefCounted
## Die Abgaben beim Schreib-Boss (docs/adr/0023-schreib-boss.md, §7): je Abgabe, was der
## Anbieter verbraucht hat, und was dabei herauskam.
##
## Gespeichert wird der Ursprungswert — Modell, Token, Dauer, erfüllte Kriterien —, nie
## ein Betrag. Die Kosten rechnet `ModelPrices` beim Lesen; kein Zähler daneben. Dieselbe
## Datei liest die Anzeige in „Inhalte“ (letzte 30 Tage) und der Statistik-Kanal
## (`StatsUploader.SNAPSHOT_FILES["_writing"]`).
##
## Kein Text, kein Schlüssel: `record` übernimmt nur die Felder in `FIELDS`. Was der
## Aufrufer sonst noch in den Eintrag legt, bleibt draußen.
##
## Ablage: user://progress/<profil>_writing.json = { "submissions": [ … ] }, wie BossRecord.
## Statisch und mit Profil-Argument, damit Tests auf einem `zz-`-Profil laufen.

const SAVE_DIR := "user://progress"

## Die Felder einer Abgabe. at: Unix-Zeit; boss, task: Ids; round: Abgabe-Nummer im Kampf
## (1 = erste, danach Überarbeitungen); model: Modell-Id der Antwort; in, out, cr, cw:
## Eingabe-, Ausgabe-, Cache-Lese-, Cache-Schreib-Token; s: Sekunden bis zur Antwort;
## met: Ids der erfüllten Kriterien (WritingJudge.CRITERIA); words: Wortzahl des Textes.
## `failed`: der Anbieter hat Token berechnet, aber kein brauchbares Urteil geliefert — die
## Abgabe zählte im Kampf nicht, ihre Kosten zählen trotzdem.
const FIELDS := ["at", "boss", "task", "round", "model", "in", "out", "cr", "cw", "s", "met", "words",
		"failed"]

## So weit zurück reicht die Kostenanzeige in den Einstellungen.
const RECENT_DAYS := 30


static func path(profile: String) -> String:
	return "%s/%s_writing.json" % [SAVE_DIR, profile]


## Bucht eine Abgabe. Fehlt `at`, gilt jetzt.
static func record(entry: Dictionary, profile: String) -> void:
	var clean := {}
	for field in FIELDS:
		if entry.has(field):
			clean[field] = entry[field]
	if not clean.has("at"):
		clean["at"] = int(Time.get_unix_time_from_system())
	var all := entries(profile)
	all.append(clean)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(path(profile), FileAccess.WRITE)
	if file == null:
		push_warning("WritingLog: %s nicht schreibbar" % path(profile))
		return
	file.store_string(JSON.stringify({"submissions": all}, "\t"))
	file.close()


## Alle Abgaben des Profils, älteste zuerst.
static func entries(profile: String) -> Array:
	var text := FileAccess.get_file_as_string(path(profile))
	if text.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return []
	var list: Variant = (parsed as Dictionary).get("submissions", [])
	return list if list is Array else []


## Die Kosten der Abgaben in US-Dollar.
static func cost_usd(list: Array) -> float:
	var total := 0.0
	for entry in list:
		if entry is Dictionary:
			total += ModelPrices.cost_usd(entry)
	return total


## Die Abgaben ab `unix` (einschließlich).
static func since(list: Array, unix: int) -> Array:
	return list.filter(func(entry): return entry is Dictionary \
			and int((entry as Dictionary).get("at", 0)) >= unix)


## Was das Profil in den letzten `days` Tagen gekostet hat — für die Anzeige.
static func recent_cost_usd(profile: String, days := RECENT_DAYS) -> float:
	var start := int(Time.get_unix_time_from_system()) - days * 86400
	return cost_usd(since(entries(profile), start))
