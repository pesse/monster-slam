class_name TraceView
extends RefCounted
## Liest Zeilen des Ereignis-Protokolls (TraceLog) als Einträge für den Reiter „Protokoll".
##
## Reine Regeln, statisch und ohne Autoload — dieselbe Aufteilung wie `StatsScreen.unit_rows`:
## der Screen instanziert Zeilen, was darin steht, entscheidet und prüft sich hier.
##
## Die Ansicht ist ein LESER der Datei, keine zweite Buchführung: sie rechnet nichts
## zusammen, sie übersetzt Zeile für Zeile. Das Einzige, was sie über Zeilen hinweg
## verknüpft, ist der Prompt zu einer learnable_id — die answer-Zeile kennt nur die Id, und
## „✔ coral" ohne das Wort, zu dem es gehört, sagt nichts. Nachgeschlagen wird in den
## spawn-Zeilen desselben Ausschnitts; fehlt die (weiter oben abgeschnitten), steht die Id.
##
## Unbekannte Ereignisarten erscheinen mit ihrem Namen statt zu verschwinden: Felder und
## Arten kommen im Protokoll dazu (TraceLog, Regel 2), und eine Ansicht, die Neues still
## verschluckt, lügt über das, was in der Datei steht.

const DIRECTIONS := {"de_to_en": "de → en", "en_to_de": "en → de"}


## Einträge, NEUESTE zuerst, mit einer Tageszeile vor jedem Tag. `lines` wie von
## `TraceLog.recent()` (älteste zuerst). `bias_minutes` ist der Abstand der Ortszeit zu UTC
## (`Time.get_time_zone_from_system().bias`) — als Parameter, damit der Test nicht an der
## Zeitzone des Rechners hängt.
##
## Jeder Eintrag: `kind` ("day" | "event"), `time`, `text`, `style` (Type-Variation oder
## leer) und `hint` (`title`, `body`, `note`, `list` für `Hints.attach`).
static func rows(lines: Array, bias_minutes: int = 0) -> Array:
	var tasks := _tasks_by_id(lines)
	var out: Array = []
	var day := ""
	for i in range(lines.size() - 1, -1, -1):
		var line: Dictionary = lines[i]
		var local := int(line.get("at", 0)) + bias_minutes * 60
		var line_day := Time.get_date_string_from_unix_time(local)
		if line_day != day:
			day = line_day
			out.append({"kind": "day", "time": "", "text": _day_label(local), "style": "Hint",
					"hint": {}})
		var entry := describe(line, tasks)
		entry["kind"] = "event"
		entry["time"] = Time.get_time_string_from_unix_time(local)
		out.append(entry)
	return out


## Ein Eintrag aus einer Zeile. `tasks` ist learnable_id → spawn-Zeile (siehe rows()).
static func describe(line: Dictionary, tasks: Dictionary = {}) -> Dictionary:
	var e := str(line.get("e", ""))
	match e:
		"run_start":
			return _entry("▶ Lauf beginnt")
		"run_end":
			var outcome := "gewonnen" if bool(line.get("won", false)) else "verloren"
			return _entry("■ Lauf endet · bis Welle %d · letzte Welle %s" % [
					int(line.get("wave_reached", 0)), outcome], "",
					{"title": "Lauf beendet",
					"body": "Schwierigkeit der letzten Welle: %d" % int(line.get("difficulty", 0))})
		"wave_start":
			var text := "⚑ %s beginnt · ❤ %d" % [_wave(line), int(line.get("hp", 0))]
			if int(line.get("armor", 0)) > 0:
				text += " · 🛡 %d" % int(line.get("armor", 0))
			return _entry(text)
		"wave_clear":
			return _entry("✔ %s geschafft · ❤ %d" % [_wave(line), int(line.get("hp", 0))])
		"fast_resolve":
			return _entry("⏩ schnell aufgelöst · %d unterwegs, %d noch nicht erschienen" % [
					int(line.get("on_field", 0)), int(line.get("unspawned", 0))], "Hint",
					{"title": "Schnell aufgelöst",
					"body": "Der Rest von %s lief im Zeitraffer durch." % _wave(line)})
		"spawn":
			return _entry("Aufgabe: %s" % str(line.get("prompt", "")), "Hint", _task_hint(line))
		"answer":
			return _answer(line, tasks)
		"leak":
			return _entry("💥 durchgelassen: %s → %s · −%d ❤" % [
					str(line.get("prompt", "")), _answers(line), int(line.get("dmg", 0))],
					"Accent", {"title": str(line.get("prompt", "")),
					"body": "Richtig wäre gewesen: %s" % _answers(line),
					"note": str(line.get("id", ""))})
	return _entry("· %s" % e, "Hint")


static func _answer(line: Dictionary, tasks: Dictionary) -> Dictionary:
	var typed := "„%s“" % str(line.get("text", ""))
	if not bool(line.get("hit", false)):
		# Auf kein Monster gepasst: der Grund, aus dem es das Protokoll gibt. Die Karte zeigt,
		# was stattdessen auf dem Feld stand — daran liest man ab, warum sie nicht zählte.
		var field: Array = []
		for id in line.get("field", []):
			var task: Dictionary = tasks.get(str(id), {})
			if task.is_empty():
				field.append(["", str(id), ""])
			else:
				field.append(["", str(task.get("prompt", "")), _answers(task)])
		var body := "Auf dem Feld stand nichts." if field.is_empty() \
				else "Auf dem Feld standen:"
		return _entry("✘ %s passte auf keine Aufgabe" % typed, "Accent",
				{"title": "Nicht gewertet", "body": body, "list": field})
	var id := str(line.get("id", ""))
	var task: Dictionary = tasks.get(id, {})
	var prompt := str(task.get("prompt", id))
	var note := "Antwortzeit %.1f s" % (int(line.get("rt", 0)) / 1000.0)
	if line.has("conf"):
		note += " · Sicherheit danach %d %%" % roundi(float(line.get("conf", 0.0)) * 100.0)
	if bool(line.get("full", true)):
		return _entry("✔ %s — %s" % [typed, prompt], "", {"title": prompt, "note": note})
	return _entry("◐ %s — %s, unvollständig" % [typed, prompt], "",
			{"title": prompt, "body": "Vollständig: %s" % str(line.get("canonical", "")),
			"note": note})


static func _task_hint(line: Dictionary) -> Dictionary:
	var parts: Array = [str(line.get("type", ""))]
	var dir := str(line.get("dir", ""))
	if not dir.is_empty():
		parts.append(DIRECTIONS.get(dir, dir))
	parts.append("Schwierigkeit %d" % int(line.get("diff", 0)))
	var conf := float(line.get("conf", -1.0))
	if conf >= 0.0:
		parts.append("Sicherheit %d %%" % roundi(conf * 100.0))
	return {"title": str(line.get("prompt", "")), "body": "Lösung: %s" % _answers(line),
			"note": " · ".join(parts)}


static func _tasks_by_id(lines: Array) -> Dictionary:
	var out := {}
	for line in lines:
		if str(line.get("e", "")) == "spawn":
			out[str(line.get("id", ""))] = line
	return out


static func _answers(line: Dictionary) -> String:
	var answers: Array = line.get("answers", [])
	return " / ".join(answers.map(func(a): return str(a)))


## „procedural_3" → „Welle 3"; eine Welle mit eigenem Namen behält ihn.
static func _wave(line: Dictionary) -> String:
	var id := str(line.get("wave", ""))
	var number := id.get_slice("_", id.get_slice_count("_") - 1)
	return "Welle %s" % number if number.is_valid_int() else id


static func _day_label(local_unix: int) -> String:
	var d := Time.get_date_dict_from_unix_time(local_unix)
	return "%02d.%02d.%d" % [d.day, d.month, d.year]


static func _entry(text: String, style := "", hint := {}) -> Dictionary:
	return {"text": text, "style": style, "hint": hint}
