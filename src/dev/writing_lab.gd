extends Control
## Werkbank für den Schreib-Boss (scenes/dev/writing_lab.tscn) — docs/adr/0023-schreib-boss.md.
##
## Wozu: um den Ablauf von The Rambler durchzuspielen, ohne einen Schlüssel einzutragen und
## ohne Geld für Abgaben auszugeben. Links oben läuft der echte Kampf (scenes/battle/
## writing_boss.tscn) und füllt den Platz; den engen Fall 1152×648 prüft man im Spiel selbst.
## Darunter steht nach jeder Abgabe, was an die API geht — System- und Nutzerteil und die
## ganze Anfrage — und was zurückkam: bei „Echt“ die rohe Antwort des Dienstes, sonst die
## erfundene. Die Trennlinie dazwischen lässt sich ziehen. Rechts wählt man, was das
## Backend auf die nächste Abgabe antwortet:
##
##   1  gut              — alle Kernpunkte belegt, Präsens, keine Fehler
##   2  Kernpunkt fehlt  — der letzte Pflicht-Kernpunkt fehlt
##   3  Fehler           — ein schwerer Sprachfehler mit einem Hinweis, der die Lösung
##                         verrät (WritingJudge muss ihn auf die Regel zurücksetzen), dazu
##                         eine Stelle im falschen Tempus
##   4  Dienstfehler     — kein Urteil, nur ein Grund; der Text muss stehen bleiben
##   5  Echt             — die Abgabe geht wirklich an Anthropic (CloudModelBackend) mit
##                         dem Schlüssel aus „Inhalte“; nur mit eingetragenem Schlüssel
##   W  Wartezeit an/aus — so lange „lädt“ der Angriff auf
##   T  Beispieltext ins Schreibfeld
##   R  Kampf neu starten
##
## Jede Taste hat auch einen Knopf. Die Aufgabe ist die Test-Fixture
## (tests/fixtures/writing/summary_fixture.json), ein erfundener Text, kein Lehrbuch.
##
## **Hier wird nichts gebucht**: kein WritingLog, kein BossRecord und keine EventBus-Signale
## (also auch keine Spur) — die Urteile sind erfunden. Ausnahme „Echt“: die Abgabe kostet
## wirklich Geld, deshalb landet ihr Verbrauch im WritingLog des aktiven Profils (und damit
## in der Kostenanzeige unter „Inhalte“); Signale und Spur bleiben aus.
##
## Bilder der Phasen (rendern geht nicht headless):
##     GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/writing_lab.tscn -- --shoot
## legt sie unter reports/writing_lab/ ab, je Phase eine PNG in der Größe des Kampffelds.
##
## Liegt unter scenes/dev/ und src/dev/, im Export ausgeschlossen.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const FIGHT_SCENE := "res://scenes/battle/writing_boss.tscn"
const FIXTURE := "res://tests/fixtures/writing/summary_fixture.json"
const SHOT_DIR := "res://reports/writing_lab"
## So lange lädt der Angriff, wenn die Wartezeit an ist.
const DELAY := 2.0

enum Answer { GOOD, MISSING, ERRORS, FAILURE, REAL }
const ANSWER_NAMES := ["gut", "Kernpunkt fehlt", "Fehler", "Dienstfehler", "echt (API)"]

## Ein Beispieltext, selbst geschrieben — offline sauber (tests/writing_boss_test.gd).
const SAMPLE := "In the short story The Lighthouse Cat by Mara Linden, an old keeper called Tom looks after the lamp of a lighthouse on an island together with his cat Pepper. One stormy night the lamp stops working, and a small fishing boat is in danger of hitting the rocks. Tom is too slow for the wet stairs, so Pepper fetches a rope that is tied to an old lantern. Together they pull it up, and Tom holds the burning lantern in the window. The boat turns away and reaches the harbour safely. The next day the fishermen thank Tom, but he says that the cat deserves the thanks."

@onready var _viewport: SubViewport = %FightViewport
@onready var _answer_buttons: Array[Button] = [%GoodButton, %MissingButton, %ErrorsButton, %FailureButton,
		%RealButton]
@onready var _delay_button: Button = %DelayButton
@onready var _status: Label = %Status
@onready var _exchange: TabContainer = %Exchange
@onready var _system_view: TextEdit = %System
@onready var _user_view: TextEdit = %User
@onready var _response_view: TextEdit = %Response
@onready var _request_view: TextEdit = %Request

var _fight: WritingBoss
var _task: Dictionary = {}
var _answer: Answer = Answer.GOOD
var _delay := true
var _room: Window
## Für „Echt“: das wirkliche Backend, einmal für die ganze Werkbank.
var _cloud: CloudModelBackend


func _ready() -> void:
	_room = get_window()
	LabRoom.enlarge(_room)
	_task = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_cloud = CloudModelBackend.new()
	add_child(_cloud)
	for tab in [[_system_view, "System"], [_user_view, "User"], [_response_view, "Antwort"],
			[_request_view, "Anfrage (JSON)"]]:
		_exchange.set_tab_title(tab[0].get_index(), tab[1])
	_system_view.text = WritingPrompts.SUMMARY_SYSTEM
	_user_view.text = "(noch keine Abgabe)"
	_response_view.text = "(noch keine Abgabe)"
	for i in _answer_buttons.size():
		_answer_buttons[i].pressed.connect(_choose.bind(i))
	_delay_button.pressed.connect(_toggle_delay)
	(%SampleButton as Button).pressed.connect(_insert_sample)
	(%RestartButton as Button).pressed.connect(_restart)
	(%BackButton as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	_choose(Answer.GOOD)
	_render_delay()
	_restart()
	if OS.get_cmdline_user_args().has("--shoot"):
		_delay = true
		_shoot.call_deferred()


func _exit_tree() -> void:
	LabRoom.restore(_room)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed:
		return
	# Im Schreibfeld getippte Ziffern gehören dem Text, nicht der Werkbank.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is TextEdit or _viewport.gui_get_focus_owner() is TextEdit:
		return
	match key.keycode:
		KEY_1: _choose(Answer.GOOD)
		KEY_2: _choose(Answer.MISSING)
		KEY_3: _choose(Answer.ERRORS)
		KEY_4: _choose(Answer.FAILURE)
		KEY_5: _choose(Answer.REAL)
		KEY_W: _toggle_delay()
		KEY_T: _insert_sample()
		KEY_R: _restart()
		_: return
	get_viewport().set_input_as_handled()


func _choose(answer: int) -> void:
	if answer == Answer.REAL and not ApiKeys.available():
		_answer_buttons[answer].set_pressed_no_signal(false)
		_status.text = "Kein Schlüssel — erst unter „Inhalte“ eintragen."
		return
	_answer = answer as Answer
	for i in _answer_buttons.size():
		_answer_buttons[i].set_pressed_no_signal(i == answer)
	_status.text = "Nächste Antwort: " + ANSWER_NAMES[answer]
	if _fight != null:
		_fight.record = _answer == Answer.REAL


func _toggle_delay() -> void:
	_delay = not _delay
	_render_delay()


func _render_delay() -> void:
	_delay_button.set_pressed_no_signal(_delay)
	_delay_button.text = "Wartezeit %.0f s (W)" % DELAY if _delay else "Sofort (W)"


## Stellt einen neuen Kampf auf — mit der Fixture und dem erfundenen Backend.
func _restart() -> void:
	if _fight != null:
		_viewport.remove_child(_fight)
		_fight.queue_free()
	_fight = load(FIGHT_SCENE).instantiate()
	_fight.fake_backend = _fake_backend
	_fight.record = _answer == Answer.REAL
	_fight.emit_events = false
	_fight.on_leave = _restart
	_viewport.add_child(_fight)
	_fight.begin(ContentRegistry.get_entry("bosses", WritingBoss.BOSS_ID), _task)


## Schreibt den Beispieltext in das Schreibfeld der aktuellen Phase.
func _insert_sample() -> void:
	if _fight == null:
		return
	if _fight.phase in [WritingBoss.Phase.ENCOUNTER, WritingBoss.Phase.READING]:
		_fight.goto(WritingBoss.Phase.WRITING)
	var panel := "%Revision" if _fight.phase == WritingBoss.Phase.REVISION else "%Writing"
	var edit: TextEdit = _fight.get_node(panel).get_node("%TextEdit")
	edit.text = SAMPLE
	edit.text_changed.emit()


func _fake_backend(task: Dictionary, text: String, on_done: Callable) -> void:
	var answer := _answer
	_show_request(task, text)
	if answer == Answer.REAL:
		_response_view.text = "(wartet auf Anthropic …)"
		_cloud.judge_summary(task, text, func(reply: Dictionary) -> void:
			_show_real_response(reply)
			on_done.call(reply))
		return
	_response_view.text = "(erfunden, „%s“ — wartet …)" % ANSWER_NAMES[answer]
	if _delay:
		await get_tree().create_timer(DELAY).timeout
	var reply := fake_reply(answer, task, text)
	_response_view.text = "Erfunden („%s“), nichts gesendet:\n\n%s" % [ANSWER_NAMES[answer],
			JSON.stringify(reply, "  ")]
	on_done.call(reply)


# --- Was hin- und zurückgeht ------------------------------------------------------------

## Zeigt die Anfrage, so wie CloudModelBackend sie bauen würde — auch bei den erfundenen
## Antworten, damit man den Prompt ohne Kosten lesen kann.
func _show_request(task: Dictionary, text: String) -> void:
	var body := CloudModelBackend.request_body(task, text)
	_system_view.text = str(body.get("system", WritingPrompts.SUMMARY_SYSTEM))
	_user_view.text = WritingPrompts.summary_user(task, text)
	_request_view.text = JSON.stringify(body, "  ")


## Die rohe Antwort des Dienstes, als JSON eingerückt; der Text der Modellantwort steckt
## darin als String und wird darunter noch einmal geparst gezeigt.
func _show_real_response(reply: Dictionary) -> void:
	if not _cloud.last_request.is_empty():
		_request_view.text = JSON.stringify(_cloud.last_request, "  ")
	var lines: Array[String] = ["HTTP %d · %.1f s" % [_cloud.last_code, _cloud.last_seconds]]
	if str(reply.get("note", "")) != "":
		lines.append("Hinweis: " + str(reply["note"]))
	lines.append("Kosten: %.4f USD" % ModelPrices.cost_usd(_usage_entry(reply)))
	var raw = JSON.parse_string(_cloud.last_response) if _cloud.last_response != "" else null
	lines.append("")
	lines.append("— Rohe Antwort —")
	lines.append(JSON.stringify(raw, "  ") if raw != null else _cloud.last_response)
	if not (reply.get("result", {}) as Dictionary).is_empty():
		lines.append("")
		lines.append("— Geparstes Urteil —")
		lines.append(JSON.stringify(reply["result"], "  "))
	_response_view.text = "\n".join(lines)


## Der Verbrauch in der Form, die ModelPrices rechnet (wie im WritingLog).
func _usage_entry(reply: Dictionary) -> Dictionary:
	var usage: Dictionary = reply.get("usage", {})
	return {"at": int(Time.get_unix_time_from_system()), "model": str(usage.get("model", "")),
			"in": int(usage.get("input_tokens", 0)), "out": int(usage.get("output_tokens", 0)),
			"cr": int(usage.get("cache_read_input_tokens", 0)),
			"cw": int(usage.get("cache_creation_input_tokens", 0))}


## Die Antwort des erfundenen Backends. Belege werden aus dem abgegebenen Text genommen,
## damit WritingJudge sie dort findet — sonst fiele jeder Kernpunkt als unbelegt weg.
static func fake_reply(answer: Answer, task: Dictionary, text: String) -> Dictionary:
	var usage := {"model": "werkbank", "input_tokens": 0, "output_tokens": 0,
			"cache_read_input_tokens": 0, "cache_creation_input_tokens": 0, "seconds": 0.0}
	if answer == Answer.FAILURE:
		return {"result": {}, "usage": usage,
				"note": "Keine Verbindung zum Dienst (Werkbank)."}
	var words := text.strip_edges().split(" ", false)
	var proof := " ".join(words.slice(0, mini(4, words.size())))
	var points: Array = []
	var required: Array = Array(task.get("key_points", [])).filter(
			func(p): return bool(p.get("required", true)))
	var missing := str(required[-1].get("id", "")) if answer == Answer.MISSING and not required.is_empty() else ""
	for point in task.get("key_points", []):
		var id := str(point.get("id", ""))
		points.append({"id": id, "covered": id != missing, "quote": proof if id != missing else ""})
	var result := {"key_points": points, "present_tense": true, "tense_quotes": [], "errors": []}
	if answer == Answer.ERRORS and words.size() > 12:
		result["errors"] = [{"quote": " ".join(words.slice(8, 11)), "category": "word_choice",
				"severity": "major", "hint": "Use 'better words' instead."}]
		result["present_tense"] = false
		result["tense_quotes"] = [" ".join(words.slice(words.size() - 4, words.size()))]
	return {"result": result, "usage": usage, "note": ""}


# --- Bilder -----------------------------------------------------------------------------

## Spielt alle Phasen einmal durch und legt von jeder ein Bild ab.
func _shoot() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	_fight.reveal_step = 0.15
	await _settle(1.5)
	await _save(dir, "1_begegnung")
	_fight.goto(WritingBoss.Phase.READING)
	await _save(dir, "2_lesen")
	_insert_sample()
	_fight._refresh_checks()
	await _save(dir, "3_schreiben")
	_choose(Answer.ERRORS)
	_fight.submit()
	await _settle(0.6)
	await _save(dir, "4_angriff_laedt")
	await _settle(DELAY + 1.5)
	await _save(dir, "5_angriff_urteil")
	(_fight.get_node("%Attack").get_node("%ContinueButton") as Button).pressed.emit()
	await _save(dir, "6_ueberarbeiten")
	_choose(Answer.FAILURE)
	_fight.submit()
	await _settle(DELAY + 0.5)
	await _save(dir, "7_dienstfehler")
	(_fight.get_node("%Attack").get_node("%ContinueButton") as Button).pressed.emit()
	_choose(Answer.GOOD)
	_fight.submit()
	await _settle(DELAY + 1.5)
	(_fight.get_node("%Attack").get_node("%ContinueButton") as Button).pressed.emit()
	await _settle(1.0)
	await _save(dir, "8_sieg")
	get_tree().quit()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [dir, name]
	_viewport.get_texture().get_image().save_png(path)
	print("writing_lab: ", path)
