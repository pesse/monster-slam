class_name BattleBackfill
extends RefCounted
## Schätzt die Kampfzeit der Läufe von vor BattleClock aus der Spur (TraceLog), einmal je
## Profil (SessionLog). Die Pause steht nicht in der Spur; eine Lücke zwischen zwei Zeilen
## zählt deshalb höchstens `GAP_CAP_MS`. Ein Kampf ohne eigenes Ende (verloren, verlassen,
## abgestürzt) endet mit seiner letzten Zeile.

## Längste Lücke zwischen zwei Zeilen eines Kampfs, die voll zählt (ms). In einer laufenden
## Welle kommt viel öfter eine Zeile; eine längere Stille ist eine Pause.
const GAP_CAP_MS := 120000
## Spielraum (s) beim Zuordnen einer Welle zu der Sitzung, in der sie lief.
const MATCH_SLACK_S := 2

## Ereignisse, die einen offenen Kampf beenden, ohne zu ihm zu gehören.
const BREAKS := ["run_start", "run_end", "run_suspend", "run_resume", "battle_time"]


## Beide Generationen der Spur von Profil `id`, älteste Zeile zuerst. Unlesbare Zeilen
## fallen weg.
static func read_trace(id: String) -> Array:
	var lines: Array = []
	var json := JSON.new()
	for p: String in [TraceLog.previous_path_for(id), TraceLog.path_for(id)]:
		if not FileAccess.file_exists(p):
			continue
		var file := FileAccess.open(p, FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var raw := file.get_line()
			if not raw.is_empty() and json.parse(raw) == OK and json.data is Dictionary:
				lines.append(json.data)
	return lines


## Die Kämpfe der Spur `lines`: [{kind, started_at, ms}], `kind` "wave" oder die Id des
## Bosses, `started_at` unix.
static func segments(lines: Array) -> Array:
	var out: Array = []
	var open := {}
	var prev_ms := -1
	for line: Dictionary in lines:
		var e := str(line.get("e", ""))
		var ms := int(line.get("ms", 0))
		# Neuer Prozess: die Ticks fangen von vorn an, der offene Kampf endete davor.
		if ms < prev_ms:
			_close(open, out)
			open = {}
		prev_ms = ms
		if e == "wave_start" or e == "boss_start":
			_close(open, out)
			open = {
				"kind": "wave" if e == "wave_start" else str(line.get("boss", "")),
				"started_at": int(line.get("at", 0)), "ms": 0, "last_ms": ms,
			}
		elif open.is_empty():
			continue
		elif e in BREAKS:
			_close(open, out)
			open = {}
		else:
			open["ms"] = int(open["ms"]) + mini(ms - int(open["last_ms"]), GAP_CAP_MS)
			open["last_ms"] = ms
			if e == "wave_clear" or e == "boss_end":
				_close(open, out)
				open = {}
	_close(open, out)
	return out


## Trägt die Kämpfe `segs` ein: eine Welle als `battle_ms` in die Sitzung aus `sessions`,
## in der sie begann. Was keine Sitzung hat (Bosse), kommt zurück, als Einträge wie in
## SessionLog `battles`.
static func apply(sessions: Array, segs: Array) -> Array:
	var rest: Array = []
	for seg: Dictionary in segs:
		var at := int(seg["started_at"])
		var target := {}
		if str(seg["kind"]) == "wave":
			for entry: Dictionary in sessions:
				var from := int(entry.get("started_at", 0))
				var to := maxi(int(entry.get("ended_at", 0)), int(entry.get("last_activity_at", 0)))
				if at >= from - MATCH_SLACK_S and at <= to + MATCH_SLACK_S \
						and (target.is_empty() or from > int(target.get("started_at", 0))):
					target = entry
		if target.is_empty():
			rest.append({"kind": str(seg["kind"]), "started_at": at, "battle_ms": int(seg["ms"])})
		else:
			target["battle_ms"] = int(target.get("battle_ms", 0)) + int(seg["ms"])
	return rest


static func _close(open: Dictionary, out: Array) -> void:
	if not open.is_empty() and int(open["ms"]) > 0:
		out.append({"kind": open["kind"], "started_at": open["started_at"], "ms": open["ms"]})
