extends Control
## Werkbank für die Satzbewertung (ADR 0004, 0005): Satz wählen, Antwort tippen, das Urteil
## beider Stufen nebeneinander. Stufe 1 fragt erst nach dem Urteil, nur bei „falsch“ nach der
## Erklärung; gezeigt werden beide mit Dauer und Rohtext. „Dienst starten“ startet
## `llama-server` aus `user://model/` (LocalModelServer). Zeitlimits großzügiger als im Kampf
## (`LAB_HTTP_TIMEOUT`). Der Schlüssel ist editierbar und gilt nur für diesen Klick; die
## Werkbank schreibt und verbucht nichts.
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/boss_lab.tscn   (oder F6 im Editor)

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"

## So viele Sätze stehen höchstens zur Wahl.
const MAX_CHOICES := 60

## Wartezeit auf eine Antwort, in s. Der Richter wartet länger als das Backend, sonst
## stünde die Anfrage noch und jede weitere fiele in die Sperre.
const LAB_HTTP_TIMEOUT := 120.0
const LAB_JUDGE_TIMEOUT := LAB_HTTP_TIMEOUT + 2.0

## Die Felder des Lösungsschlüssels, in der Werkbank veränderbar.
const KEY_FIELDS := ["accepted", "must_contain", "pitfalls"]

@onready var _boss_select: OptionButton = %BossSelect
@onready var _sentence_select: OptionButton = %SentenceSelect
@onready var _only_keyed: CheckButton = %OnlyKeyed
@onready var _use_profile: CheckButton = %UseProfile
@onready var _pool_info: Label = %PoolInfo
@onready var _source_text: Label = %SourceText
@onready var _sentence_info: Label = %SentenceInfo
@onready var _key_edit: TextEdit = %KeyEdit
@onready var _key_status: Label = %KeyStatus
@onready var _answer_edit: LineEdit = %AnswerEdit
@onready var _card_result: Label = %CardResult
@onready var _model_result: Label = %ModelResult
@onready var _model_toggle: CheckButton = %ModelToggle
@onready var _model_url: LineEdit = %ModelUrl
@onready var _serve_button: Button = %ServeButton
@onready var _serve_status: Label = %ServeStatus

var _judge: SentenceJudge
var _backend: LocalModelBackend
var _server: LocalModelServer
## Die Sätze der aktuellen Auswahl, in der Reihenfolge der Liste.
var _choices: Array = []
## Das Fenster, dessen Größe die Werkbank geliehen hat.
var _room: Window
## Das Urteil über der Erklärung, solange die Erklärung noch rechnet.
var _verdict_text := ""


func _ready() -> void:
	# Drei Spalten passen nicht in 1152×648 (LabRoom).
	_room = get_window()
	LabRoom.enlarge(_room)
	_judge = SentenceJudge.new()
	_judge.timeout = LAB_JUDGE_TIMEOUT
	add_child(_judge)
	_judge.refined.connect(_on_refined)
	_judge.denied.connect(_on_denied)
	_judge.explained.connect(_on_explained)
	_judge.gave_up.connect(_on_gave_up)
	_backend = LocalModelBackend.new()
	# Vor dem Einhängen: LocalModelBackend liest den Wert in seinem _ready().
	_backend.http_timeout = LAB_HTTP_TIMEOUT
	add_child(_backend)
	# Angelegt, nicht gestartet; so steht die Adresse für den Knopf fest.
	_server = LocalModelServer.new()
	# Nur llama-servers eigenes Log sagt, warum er die Gewichte ablehnt.
	_server.show_console = true
	add_child(_server)

	_boss_select.add_item("— alle Sätze —", 0)
	for boss in ContentRegistry.bosses.values():
		_boss_select.add_item(str((boss as Dictionary).get("name", boss.get("id", "?"))))
	_model_url.text = _server.url()

	_boss_select.item_selected.connect(func(_i: int): _refill())
	_only_keyed.toggled.connect(func(_on: bool): _refill())
	_use_profile.toggled.connect(func(_on: bool): _refill())
	_sentence_select.item_selected.connect(func(_i: int): _show_sentence())
	(%RollButton as Button).pressed.connect(_roll)
	(%JudgeButton as Button).pressed.connect(_judge_now)
	_answer_edit.text_submitted.connect(func(_t: String): _judge_now())
	_model_toggle.toggled.connect(_on_model_toggled)
	_serve_button.pressed.connect(_on_serve_pressed)
	(%BackButton as Button).pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))

	_render_serve()
	_refill()


## Gibt das geliehene Fenster zurück, bei jedem Ausgang.
func _exit_tree() -> void:
	LabRoom.restore(_room)


func _input(event: InputEvent) -> void:
	# Escape führt zurück ins Menü.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU_SCENE)


## Der Pool, nach dem ausgewählt wird: die Regel des gewählten Bosses, wahlweise über der
## Auswahl des aktiven Profils. Ohne Profil-Häkchen bleiben Scope und Themen leer, also
## ohne Einschränkung.
func pool() -> Dictionary:
	var out := {"scope": [], "tags": [], "grammar_tags": [], "difficulty_max": 0}
	if _use_profile.button_pressed:
		out = SentenceSelector.pool_from_settings()
	var index := _boss_select.selected
	if index > 0:
		var bosses: Array = ContentRegistry.bosses.values()
		if index - 1 < bosses.size():
			var boss: Dictionary = bosses[index - 1]
			var rule: Dictionary = boss.get("sentence_rule", {})
			out["grammar_tags"] = Array(rule.get("grammar_tags", []))
			if int(rule.get("difficulty_max", 0)) > 0:
				out["difficulty_max"] = int(rule["difficulty_max"])
	return out


## Alles, was zum Pool passt; dieselbe Menge, aus der „Satz ziehen“ zieht.
func _pool_sentences() -> Array:
	var found := SentenceSelector.new().candidates(pool())
	if _only_keyed.button_pressed:
		found = found.filter(func(s): return has_key(s))
	return found


## Füllt die Auswahlliste neu: was zum Pool passt, das Schwerste zuerst (Netto-Maß).
func _refill() -> void:
	var all := SentenceSelector.new().candidates(pool())
	var found := _pool_sentences()
	found.sort_custom(func(a, b):
		return SentenceSelector.net_difficulty(a) > SentenceSelector.net_difficulty(b))
	_pool_info.text = "%d Sätze im Pool, davon %d mit Schlüssel — höchstens %d zur Wahl." % [
		all.size(), all.filter(func(s): return has_key(s)).size(), MAX_CHOICES]
	if found.is_empty():
		_pool_info.text += "\n" + empty_note(all)
	show_sentences(found.slice(0, MAX_CHOICES))


## Warum nichts zur Wahl steht. Häufigster Grund ist ein liegengebliebener Pack ohne
## Schlüsselfelder, der das Submodule verdeckt.
static func empty_note(pool_sentences: Array) -> String:
	if pool_sentences.is_empty():
		return "Nichts zur Wahl: kein Satz passt zu dieser Auswahlregel."
	var packs := {}
	for sentence in pool_sentences:
		var pack := ContentRegistry.pack_of(
				"sentences", str((sentence as Dictionary).get("id", "")))
		if not pack.is_empty():
			packs[pack] = true
	if packs.is_empty():
		return "Nichts zur Wahl: kein Satz im Pool trägt einen Schlüssel."
	return ("Nichts zur Wahl: kein Satz im Pool trägt einen Schlüssel — sie kommen aus "
			+ "Pack „%s“, und ein Pack verdeckt das Submodule. " % ", ".join(
					PackedStringArray(packs.keys().map(str)))
			+ "Aufräumen unter user://content.")


## Stellt eine Liste von Sätzen zur Wahl und zeigt den ersten. Naht für Tests mit
## erfundenen Sätzen.
func show_sentences(list: Array) -> void:
	_choices = list
	_sentence_select.clear()
	for sentence in _choices:
		_sentence_select.add_item(str((sentence as Dictionary).get("source_text", "?")))
	if not _choices.is_empty():
		_sentence_select.select(0)
	_show_sentence()


## Trägt der Satz einen Lösungsschlüssel, oder nur seine eine Musterlösung?
static func has_key(sentence: Dictionary) -> bool:
	for field in KEY_FIELDS:
		if not Array(sentence.get(field, [])).is_empty():
			return true
	return false


## Zieht einen Satz so, wie das Spiel ihn ziehen würde — gewichtet nach dem Netto-Maß.
func _roll() -> void:
	var picked := SentenceSelector.pick_from(_pool_sentences())
	if picked.is_empty():
		return
	for i in _choices.size():
		if str((_choices[i] as Dictionary).get("id", "")) == str(picked.get("id", "")):
			_sentence_select.select(i)
			_show_sentence()
			return
	# Die Liste zeigt nur den Anfang des Pools; der gezogene Satz kommt vorn dazu.
	show_sentences(([picked] + _choices).slice(0, MAX_CHOICES))


func _show_sentence() -> void:
	var sentence := selected()
	_source_text.text = str(sentence.get("source_text", "—"))
	if sentence.is_empty():
		_sentence_info.text = "Kein Satz im Pool."
		_key_edit.text = ""
	else:
		var lexemes := SentenceSelector.lexeme_ids(str(sentence.get("id", "")))
		_sentence_info.text = "%s · Schwierigkeit %d · %s · Lernstand %.2f · netto %+.2f" % [
			sentence.get("id", "?"), int(sentence.get("difficulty", 1)),
			", ".join(PackedStringArray(Array(sentence.get("grammar_tags", [])).map(str))),
			SentenceSelector.confidence(str(sentence.get("id", ""))),
			SentenceSelector.net_difficulty(sentence),
		]
		if lexemes.is_empty():
			_sentence_info.text += " · ohne Lexeme"
		_sentence_info.text += " · %s" % origin_label(str(sentence.get("id", "")))
		_key_edit.text = JSON.stringify(key_of(sentence), "  ")
	_key_status.text = ""
	_card_result.text = "—"
	_model_result.text = _model_idle_text()


## Woher der Satz kommt: ein installierter Pack verdeckt das Submodule (CONVENTIONS „Tests“).
static func origin_label(sentence_id: String) -> String:
	var pack := ContentRegistry.pack_of("sentences", sentence_id)
	return "aus Pack „%s“" % pack if not pack.is_empty() else "aus dem Submodule"


## Der Lösungsschlüssel eines Satzes als eigenes Dictionary.
static func key_of(sentence: Dictionary) -> Dictionary:
	var out := {}
	for field in KEY_FIELDS:
		out[field] = sentence.get(field, [])
	return out


## Der gewählte Satz aus dem Bestand (ohne die Änderungen im Schlüssel-Feld).
func selected() -> Dictionary:
	var index := _sentence_select.selected
	if index < 0 or index >= _choices.size():
		return {}
	return _choices[index]


## Der gewählte Satz mit dem Schlüssel aus dem Feld. Ist das Feld kein gültiges JSON,
## gilt der Schlüssel aus den Daten.
func sentence_under_test() -> Dictionary:
	var sentence := selected().duplicate(true)
	if sentence.is_empty():
		return sentence
	var raw := _key_edit.text.strip_edges()
	if raw.is_empty():
		return sentence
	# JSON.new().parse() statt JSON.parse_string(): das halb Getippte ist hier der
	# Normalfall und kein Fehler, den jemand in der Konsole lesen müsste.
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		_key_status.text = "Schlüssel ist kein gültiges JSON — es gilt der aus den Daten."
		return sentence
	for field in KEY_FIELDS:
		sentence[field] = Array((json.data as Dictionary).get(field, []))
	_key_status.text = "Schlüssel aus dem Feld (nicht gespeichert)."
	return sentence


func _judge_now() -> void:
	var sentence := sentence_under_test()
	if sentence.is_empty():
		return
	var card := _judge.judge(sentence, _answer_edit.text)
	_card_result.text = describe(card)
	if not _model_toggle.button_pressed:
		_model_result.text = _model_idle_text()
	elif _judge.pending():
		_model_result.text = "Fragt %s …" % _model_url.text
	else:
		_model_result.text = "Nicht gefragt — die Prüfkarte ist sich sicher."


## Ein Ergebnis in Klartext. Dieselben Felder, die auch der Kampf bekäme.
static func describe(result: Dictionary) -> String:
	var lines := PackedStringArray([
		"Güte: %d %%" % roundi(float(result.get("quality", 0.0)) * 100.0),
		str(result.get("feedback", "")),
	])
	var matched := str(result.get("matched", ""))
	if not matched.is_empty():
		lines.append("Getroffen: %s" % matched)
	var missing: Array = result.get("missing", [])
	if not missing.is_empty():
		lines.append("Fehlt: %s" % ", ".join(PackedStringArray(missing.map(str))))
	if bool(result.get("sure", true)):
		lines.append("sicher")
	else:
		# Ohne Urteil ist die Güte 0; die Nähe zeigt, was die Karte trotzdem weiß.
		lines.append("kein Urteil (Nähe %d %%) — Stufe 1 darf ran"
				% roundi(float(result.get("overlap", 0.0)) * 100.0))
	return "\n".join(lines)


## Startet den Dienst aus `user://model/` oder beendet ihn. Nach dem Start ist Stufe 1 an.
func _on_serve_pressed() -> void:
	if _server.running():
		_server.stop()
		_render_serve()
		return
	_serve_button.disabled = true
	_serve_status.text = "Startet … die Gewichte (mehrere Gigabyte) laden von der Platte."
	var started := await _server.start()
	_serve_button.disabled = false
	if started:
		_model_url.text = _server.url()
		_model_toggle.button_pressed = true
		# `toggled` feuert nur bei einer Änderung; war Stufe 1 schon an, fehlte sonst die Adresse.
		_on_model_toggled(true)
	_render_serve()


## Was der Knopf gerade anbietet und woran es sonst liegt, immer mit dem Suchpfad.
func _render_serve() -> void:
	if _server.running():
		_serve_button.text = "Dienst beenden"
		_serve_status.text = "Läuft auf Port %d." % _server.port
		return
	_serve_button.text = "Dienst starten"
	var where := ProjectSettings.globalize_path(_server.dir)
	if not _server.last_note.is_empty():
		_serve_status.text = _server.last_note
	elif not _server.missing_files().is_empty():
		_serve_status.text = "Kein Modell in %s — es fehlt: %s. Zu holen im Inhalte-Screen." % [
				where, ", ".join(_server.missing_files())]
	else:
		_serve_status.text = "Bereit: %s" % where


func _on_model_toggled(on: bool) -> void:
	_backend.url = _model_url.text.strip_edges()
	_judge.model_backend = _backend.judge if on else Callable()
	_judge.explainer = _backend.explain if on else Callable()
	_model_result.text = _model_idle_text()


func _on_refined(result: Dictionary) -> void:
	_model_result.text = "Urteil: richtig (%.1f s)\n%s%s" % [
		_backend.last_seconds, describe(result), _raw_output()]


## Das Urteil „falsch“ steht sofort da, die Erklärung rechnet noch.
func _on_denied(_result: Dictionary) -> void:
	_verdict_text = "Urteil: falsch (%.1f s)%s" % [_backend.last_seconds, _raw_output()]
	_model_result.text = _verdict_text + "\n\nErklärung wird geschrieben …"


func _on_explained(result: Dictionary) -> void:
	_model_result.text = _verdict_text + "\n\n" + explanation_text(result, _backend.last_seconds) \
			+ _raw_output()


## Die Erklärung wie im Kampf, oder die Musterlösung, wo der Erklärer keinen Fehler fand
## (ADR 0005).
static func explanation_text(result: Dictionary, seconds: float) -> String:
	var text := str(result.get("explanation", ""))
	if text.is_empty():
		return "Keine Erklärung (%.1f s) — der Erklärer findet keinen Fehler.\nMusterlösung: %s" % [
			seconds, str(result.get("reference", ""))]
	return "Erklärung (%.1f s):\n%s" % [seconds, text]


## Was das Modell wörtlich geschrieben hat, zum Abgleich der Prompts.
func _raw_output() -> String:
	var raw := _backend.last_content.strip_edges()
	return "" if raw.is_empty() else "\n\nRoh: %s" % raw


func _on_gave_up() -> void:
	# Das Backend unterscheidet „kein Dienst“ von „Modell hält sich nicht an die Form“.
	var note := _backend.last_note
	if note.is_empty():
		note = "Zeitlimit überschritten — oder das Modell hatte nichts beizutragen."
	_model_result.text = "Keine Antwort — es bleibt bei der Prüfkarte.\n%s" % note


func _model_idle_text() -> String:
	if _model_toggle != null and _model_toggle.button_pressed:
		return "Bereit — fragt bei unsicherem Urteil, bei „falsch“ auch nach dem Grund."
	return "Aus. Stufe 1 ist nicht Teil der Auslieferung;\nsie braucht einen Dienst — siehe „Dienst starten“."
