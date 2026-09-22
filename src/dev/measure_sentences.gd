extends Node
## Misst die Satzbewertung gegen einen festen Antwortbogen — das Werkzeug, das die Frage
## beantwortet, die docs/SATZBEWERTUNG_MODELLE.md unter „Was zu messen wäre" offen lässt.
##
##     tools/godot.sh res://scenes/dev/measure_sentences.tscn
##     tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --serve --timeout=60
##     tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --model
##     tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --model \
##         --url=http://127.0.0.1:1234/v1/chat/completions --name=qwen2.5:3b-instruct
##
## `--serve` startet den Dienst SELBST (LocalModelServer, Programm und Gewichte aus
## user://model/) — das ist der Durchstich für „Stufe 1 muss installierbar sein". `--model`
## setzt dagegen einen voraus, den jemand anders gestartet hat (Ollama, LM Studio).
##
## Eine Szene und kein `-s`-Skript, obwohl es nichts zeichnet: mit `--script` registriert
## Godot die Autoloads nicht, und schon SentenceCard bezieht sich auf die ContentRegistry
## (für Forderungen, die ihre Formen nicht selbst nennen). Die Klasse ließe sich dann gar
## nicht erst übersetzen — gemessen würde nichts.
##
## Wozu ein Skript und nicht die Werkbank: scenes/dev/boss_lab.tscn beurteilt EINE Antwort
## und liefert einen Eindruck. Die Entscheidung über eine zweite Stufe hängt aber an einer
## Zahl, und zwar an der teuersten — wie viele RICHTIGE Antworten abgewiesen werden. Die
## bekommt man nur aus einem festen Bogen, der sich nicht mit der Laune des Tippenden
## ändert und der nach einem Modellwechsel dieselbe Messung wiederholt.
##
## Der Bogen ist der Maßstab, nicht das Erwartungsprotokoll des Codes: `expect` sagt, was
## eine Lehrkraft gelten ließe. Weicht die Messung ab, ist das ein Befund und kein
## kaputter Test — deshalb ist das hier ein Messskript und keine gdUnit-Suite. Dass der
## Bogen IN SICH stimmt (keine Stolperstelle auf einer richtigen Lösung), hält daneben
## tests/answer_sheet_test.gd.
##
## Gemessen wird ohne das private Submodule: die Sätze im Bogen sind erfunden und nennen
## ihre `forms` selbst. Das Skript liegt unter src/dev/ und ist damit aus dem Export
## ausgeschlossen; es verbucht nichts und schreibt nichts.

const SHEET := "res://src/dev/answer_sheet.json"

## Ab welcher Güte eine Antwort als angenommen gilt. **Das ist eine Annahme dieses
## Skripts und keine entschiedene Spielregel** — ADR 0004 spricht von einer „Güteschwelle",
## ohne sie festzulegen. Weil die Zahl der Falsch-Negativen vollständig an ihr hängt,
## steht sie im Bogen, ist per --pass= verstellbar, und darunter läuft die Messung noch
## einmal über eine ganze Reihe von Schwellen.
const DEFAULT_PASS := 0.6
const SWEEP := [0.4, 0.5, 0.6, 0.7, 0.8]

const RULE := "────────────────────────────────────────────────────────────────────────"

var _sheet_path := SHEET
var _pass := DEFAULT_PASS
var _use_model := false
## Den Dienst selbst starten, statt einen vorzufinden.
var _serve := false
var _model_dir := LocalModelServer.DEFAULT_DIR
var _port := LocalModelServer.DEFAULT_PORT
var _url := LocalModelBackend.URL
var _model := LocalModelBackend.MODEL
var _timeout := SentenceJudge.DEFAULT_TIMEOUT
var _verbose := true

var _judge: SentenceJudge
var _backend: LocalModelBackend
var _server: LocalModelServer
## Gefüllt vom `refined`-Signal, geleert vor jeder Frage — der Unterschied zwischen
## „Stufe 1 hat angehoben" und „Stufe 1 hatte nichts beizutragen".
var _lift: Dictionary = {}


func _ready() -> void:
	_parse_args()
	var rows := _load_rows()
	if rows.is_empty():
		push_error("Kein Antwortbogen unter %s" % _sheet_path)
		get_tree().quit(1)
		return
	print("\nAntwortbogen: %s — %d Sätze, %d Antworten, Schwelle %.2f"
			% [_sheet_path, _count_sentences(rows), rows.size(), _pass])

	for row in rows:
		row["card"] = SentenceCard.evaluate(row["sentence"], str(row["text"]))
		row["quality"] = float(row["card"]["quality"])
	_report("Stufe 0 · Prüfkarte (offline, deterministisch)", rows, "card")
	_report_sweep(rows)

	if _use_model:
		await _run_model(rows)
	else:
		print("\nStufe 1 nicht gemessen. Mit --model dazunehmen (braucht einen Dienst "
				+ "auf 127.0.0.1).")
	print("")
	get_tree().quit()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--model":
			_use_model = true
		elif arg == "--quiet":
			_verbose = false
		elif arg.begins_with("--sheet="):
			_sheet_path = arg.substr(8)
		elif arg.begins_with("--pass="):
			_pass = float(arg.substr(7))
		elif arg.begins_with("--url="):
			_url = arg.substr(6)
			_use_model = true
		elif arg.begins_with("--name="):
			_model = arg.substr(7)
			_use_model = true
		elif arg.begins_with("--timeout="):
			_timeout = float(arg.substr(10))
		elif arg == "--serve":
			_serve = true
			_use_model = true
		elif arg.begins_with("--model-dir="):
			_model_dir = arg.substr(12)
			_serve = true
			_use_model = true
		elif arg.begins_with("--port="):
			_port = int(arg.substr(7))
			_serve = true
			_use_model = true


## Eine Zeile je Antwort: der Satz OHNE seine Antworten (die Bewertung soll genau das
## sehen, was der Kampf ihr gäbe), dazu Erwartung, Art und Anmerkung aus dem Bogen.
func _load_rows() -> Array:
	var raw := FileAccess.get_file_as_string(_sheet_path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return []
	var sheet: Dictionary = parsed
	if sheet.has("pass_quality"):
		# Der Bogen bringt seine Schwelle mit; die Kommandozeile sticht sie.
		var from_args := false
		for arg in OS.get_cmdline_user_args():
			from_args = from_args or arg.begins_with("--pass=")
		if not from_args:
			_pass = float(sheet["pass_quality"])
	var rows: Array = []
	for entry in Array(sheet.get("sentences", [])):
		var sentence: Dictionary = (entry as Dictionary).duplicate(true)
		var answers := Array(sentence.get("answers", []))
		sentence.erase("answers")
		for a in answers:
			var answer: Dictionary = a
			rows.append({
				"sentence": sentence,
				"id": str(sentence.get("id", "?")),
				"text": str(answer.get("text", "")),
				"expect": str(answer.get("expect", "richtig")),
				"kind": str(answer.get("kind", "")),
				"note": str(answer.get("note", "")),
			})
	return rows


func _count_sentences(rows: Array) -> int:
	var seen := {}
	for row in rows:
		seen[row["id"]] = true
	return seen.size()


# ── Auswertung ──────────────────────────────────────────────────────────────────────

func _report(title: String, rows: Array, field: String) -> void:
	print("\n%s\n%s\n%s" % [RULE, title, RULE])
	if _verbose:
		var current := ""
		for row in rows:
			if str(row["id"]) != current:
				current = str(row["id"])
				print("  %s — %s" % [current, row["sentence"].get("source_text", "")])
			print("    %s" % _line(row, field))
	_matrix(rows, _pass, field)


## Eine Antwortzeile. Das Zeichen vorn ist das Urteil ÜBER das Urteil:
##   ·  richtig eingeordnet
##   ✗  Falsch-Negativ — eine richtige Antwort abgewiesen. Der teuerste Fehler.
##   !  Falsch-Positiv — eine falsche Antwort durchgewinkt. Seit die Prüfkarte ohne Urteil
##      keine Güte mehr ausgibt, kann das nur noch aus dem SCHLÜSSEL kommen: eine falsche
##      Lösung in `accepted` oder eine Stolperstelle, die zu spät greift.
func _line(row: Dictionary, field: String) -> String:
	var result: Dictionary = row.get(field, {})
	var quality := float(result.get("quality", 0.0))
	var text := str(row["text"])
	if text.is_empty():
		text = "(leer)"
	var out := "%s %.2f %-8s %-9s %s" % [
		_verdict_mark(quality, str(row["expect"])),
		quality,
		"sicher" if bool(result.get("sure", true)) else "unsicher",
		row["kind"],
		text,
	]
	if not str(row["note"]).is_empty():
		out += "\n         ↳ %s" % row["note"]
	return out


func _verdict_mark(quality: float, expect: String) -> String:
	var accepted := quality >= _pass
	if accepted == (expect == "richtig"):
		return "·"
	return "!" if accepted else "✗"


## Die Vierfeldertafel und die beiden Quoten, um die es geht.
func _matrix(rows: Array, threshold: float, field: String) -> Dictionary:
	var tally := _tally(rows, threshold, field, false)
	print("\n  Vierfeldertafel bei Schwelle %.2f" % threshold)
	print("                        angenommen   abgelehnt")
	print("    erwartet richtig       %5d       %5d" % [tally["tp"], tally["fn"]])
	print("    erwartet falsch        %5d       %5d" % [tally["fp"], tally["tn"]])
	print("    Falsch-Negative %d von %d (%.1f %%)    Falsch-Positive %d von %d (%.1f %%)"
			% [tally["fn"], tally["pos"], _percent(tally["fn"], tally["pos"]),
			tally["fp"], tally["neg"], _percent(tally["fp"], tally["neg"])])

	# Der Topf ohne Urteil ist das, was Stufe 1 auflösen muss, und die Aufteilung darin ist
	# ihr Auftrag: die richtigen anheben, die falschen liegen lassen. Weil sie nur heben
	# darf, kann sie an den falschen gar nichts verderben.
	var split := _unsure_split(rows)
	print("\n    Ohne Urteil     %d von %d (%.1f %%)" % [
			tally["unsure"], rows.size(), _percent(tally["unsure"], rows.size())])
	print("                    davon %d richtig — die muss Stufe 1 anheben" % split["richtig"])
	print("                    davon %d falsch  — die darf sie NICHT anheben" % split["falsch"])
	print("    Fehlurteile     %d, davon %d aus dem Pfad ohne Urteil"
			% [tally["fn"] + tally["fp"], _misjudged_unsure(rows, threshold, field)])

	# Die Zusicherung aus SentenceCard: wo eine Stufe kein Urteil hat, trägt sie auch keine
	# Güte. Beide Lesarten müssen deshalb dasselbe ergeben — täten sie es nicht, wäre die
	# Schwelle wieder der Hebel, und der Wortsalat käme durch.
	var strict := _tally(rows, threshold, field, true)
	if strict["fn"] != tally["fn"] or strict["fp"] != tally["fp"]:
		print("    ACHTUNG: eine Stufe meldet eine Güte über der Schwelle, ohne sich sicher "
				+ "zu sein (%d/%d gegen %d/%d)"
				% [tally["fn"], tally["fp"], strict["fn"], strict["fp"]])
	return tally


## Wie sich der Topf ohne Urteil auf richtig und falsch verteilt.
func _unsure_split(rows: Array) -> Dictionary:
	var out := {"richtig": 0, "falsch": 0}
	for row in rows:
		if bool(row["card"].get("sure", true)):
			continue
		out["richtig" if str(row["expect"]) == "richtig" else "falsch"] += 1
	return out


## Wie viele der Fehlurteile aus dem RATENDEN Teil stammen. Steht diese Zahl auf der Summe
## der Fehlurteile, ist nicht der Schlüssel schlecht, sondern das Raten daneben.
func _misjudged_unsure(rows: Array, threshold: float, field: String) -> int:
	var count := 0
	for row in rows:
		var result: Dictionary = row.get(field, row.get("card", {}))
		var accepted := float(result.get("quality", 0.0)) >= threshold
		if accepted == (str(row["expect"]) == "richtig"):
			continue
		if not bool(row["card"].get("sure", true)):
			count += 1
	return count


## `require_sure` liest dasselbe Ergebnis nach dem Vertrag statt nach der Zahl: eine
## Antwort gilt nur als getroffen, wenn die bewertende Stufe auch sagt, dass sie ein
## Urteil HAT. Der Unterschied zwischen beiden Lesarten ist die Frage dieses Skripts.
func _tally(rows: Array, threshold: float, field: String, require_sure := false) -> Dictionary:
	var out := {"tp": 0, "fn": 0, "fp": 0, "tn": 0, "pos": 0, "neg": 0, "unsure": 0}
	for row in rows:
		var result: Dictionary = row.get(field, row.get("card", {}))
		var accepted := float(result.get("quality", 0.0)) >= threshold
		if require_sure and not bool(result.get("sure", true)):
			accepted = false
		var wanted := str(row["expect"]) == "richtig"
		if not bool(row["card"].get("sure", true)):
			out["unsure"] += 1
		if wanted:
			out["pos"] += 1
			out["tp" if accepted else "fn"] += 1
		else:
			out["neg"] += 1
			out["fp" if accepted else "tn"] += 1
	return out


## Dieselbe Messung über eine Reihe von Schwellen. Sie kostet nichts und beantwortet die
## Frage, die sonst als Erstes kommt: „liegt es an der Schwelle?" — die Antwort lautet
## inzwischen fast überall nein, und das ist der Sinn der Änderung: eine Antwort ohne
## Urteil ist kein Treffer, bei welcher Schwelle auch immer.
func _report_sweep(rows: Array) -> void:
	var head := "\n  Schwelle     "
	var fn := "    Falsch-Neg.  "
	var fp := "    Falsch-Pos.  "
	for threshold in SWEEP:
		var tally := _tally(rows, float(threshold), "card")
		head += "%6.2f" % threshold
		fn += "%6d" % tally["fn"]
		fp += "%6d" % tally["fp"]
	print(head)
	print(fn)
	print(fp)


func _percent(part: int, whole: int) -> float:
	return 0.0 if whole == 0 else 100.0 * float(part) / float(whole)


# ── Stufe 1 ─────────────────────────────────────────────────────────────────────────

## Fragt für jede Antwort, bei der die Prüfkarte zweifelt, den lokalen Dienst — über
## GENAU den Weg, den auch das Spiel nähme (SentenceJudge → LocalModelBackend). Eine
## Anfrage nach der anderen: das Backend lässt bewusst nur eine zur Zeit zu, und gemessen
## wird hier ohnehin nicht der Durchsatz.
func _run_model(rows: Array) -> void:
	print("\n%s\nStufe 1 · lokales Modell\n%s" % [RULE, RULE])
	if _serve and not await _start_server():
		return

	_judge = SentenceJudge.new()
	_judge.timeout = _timeout
	add_child(_judge)
	_backend = LocalModelBackend.new()
	_backend.url = _url
	_backend.model = _model
	# Die HTTP-Seite muss länger warten dürfen als der Kampf. Ein 3-B-Modell auf der CPU
	# ist nach 3,5 s nicht fertig, und ohne das lief jede Anfrage in den Abbruch — gemeldet
	# als „kein Dienst erreichbar", während der Dienst einwandfrei rechnete.
	_backend.http_timeout = maxf(_timeout, LocalModelBackend.HTTP_TIMEOUT)
	add_child(_backend)
	_judge.model_backend = _backend.judge
	_judge.refined.connect(func(result: Dictionary): _lift = result)

	print("  URL     %s" % _url)
	print("  Modell  %s  (Zeitlimit %.1f s)" % [_model, _timeout])

	var asked := 0
	var lifted := 0
	var silent := 0
	var notes := {}
	var started := Time.get_ticks_msec()
	for row in rows:
		row["final"] = row["card"]
		if bool(row["card"].get("sure", true)):
			continue
		asked += 1
		_lift = {}
		_judge.judge(row["sentence"], str(row["text"]))
		while _judge.pending():
			await get_tree().process_frame
		# Erst weiter, wenn die Leitung wieder frei ist. Gibt SentenceJudge früher auf,
		# als das Backend wartet (--timeout kleiner als LocalModelBackend.HTTP_TIMEOUT),
		# steht die Anfrage noch — und die nächste fiele in „eine Anfrage zur Zeit",
		# ohne je gestellt worden zu sein. Gemessen würde dann eine einzige Frage.
		while _backend.busy():
			await get_tree().process_frame
		if _lift.is_empty():
			silent += 1
			var note := _backend.last_note
			notes[note] = int(notes.get(note, 0)) + 1
			if _verbose:
				print("    –  %.2f  %-9s %s" % [
						float(row["card"]["quality"]), row["kind"], row["text"]])
				if not note.is_empty():
					print("         ↳ %s" % note)
		else:
			lifted += 1
			row["final"] = _lift
			if _verbose:
				print("    ↑  %.2f → %.2f  %-9s %s" % [
						float(row["card"]["quality"]), float(_lift["quality"]),
						row["kind"], row["text"]])
				print("         ↳ %s" % _lift.get("feedback", ""))

	var seconds := float(Time.get_ticks_msec() - started) / 1000.0
	print("\n  %d unsichere Antworten gefragt, %d angehoben, %d ohne Beitrag — %.1f s (%.1f s je Frage)"
			% [asked, lifted, silent, seconds, seconds / maxf(1.0, float(asked))])
	for note in notes:
		if not str(note).is_empty():
			print("    %dx %s" % [notes[note], note])
	if _server != null:
		_server.stop()
	_report("Stufe 0 + 1 · nach dem Modell", rows, "final")


## Startet den Dienst aus user://model/ und richtet die Messung auf ihn. Fehlt etwas, sagt
## das Skript WO es gesucht hat und hört auf — eine Messung gegen einen Dienst, der nicht
## läuft, ist die teuerste Art, nichts zu erfahren (einmal passiert, 25 Anfragen, 0 Antworten).
func _start_server() -> bool:
	_server = LocalModelServer.new()
	_server.dir = _model_dir
	_server.port = _port
	add_child(_server)
	print("  Starte  %s" % ProjectSettings.globalize_path(_server.exe_path()))
	var started := Time.get_ticks_msec()
	if not await _server.start():
		print("  ✗ %s" % _server.last_note)
		print("\n  Für den Durchstich gehören zwei Dateien nach %s:"
				% ProjectSettings.globalize_path(_model_dir))
		print("    %s   aus einem llama.cpp-Release (ggml-org/llama.cpp)"
				% LocalModelServer.EXE_NAME)
		print("    %s         eine GGUF-Datei, z. B. ein 1–3-B-Instruct-Modell in Q4"
				% LocalModelServer.WEIGHTS_NAME)
		return false
	print("  ✓ bereit nach %.1f s" % (float(Time.get_ticks_msec() - started) / 1000.0))
	_url = _server.url()
	# Und der Name im Protokoll ist die Datei, die wirklich antwortet. llama-server ist das
	# Feld gleichgültig, das Protokoll nicht: es stand sonst „qwen2.5:3b-instruct" über
	# einer Messung, die EuroLLM gemessen hat — die Vorgabe aus LocalModelBackend.MODEL,
	# die für einen fremden Ollama-Dienst gilt und hier niemanden meint. Ein --name= sticht.
	if _model == LocalModelBackend.MODEL:
		_model = ProjectSettings.globalize_path(_server.weights_path()).get_file()
	return true
