extends GdUnitTestSuite
## Der Schreib-Boss (scenes/battle/writing_boss.tscn, ADR 0023) — mit erfundener Aufgabe
## (tests/fixtures/writing/summary_fixture.json), einem erfundenen Backend und einer
## Stub-Bühne. Kein Test spricht mit dem Dienst.

const SCENE := "res://scenes/battle/writing_boss.tscn"
const SETUP_SCENE := "res://scenes/ui/session_setup.tscn"
const FIXTURE := "res://tests/fixtures/writing/summary_fixture.json"
const PROFILE := "zz-writing-boss-test"
const KEY_FILE := "user://zz-writing-boss-keys.cfg"

const BOSS := {"id": "boss.zz_rambler", "name": "Test-Rambler", "writing_rule": {"kind": "summary"}}

## Eine Summary, die offline alles erfüllt: Titel und Autor im ersten Satz, im Zielbereich,
## keine direkte Rede, keine Meinung, nichts abgeschrieben.
const GOOD := "In the short story The Lighthouse Cat by Mara Linden, an old keeper called Tom looks after the lamp of a lighthouse on an island together with his cat Pepper. One stormy night the lamp stops working, and a small fishing boat is in danger of hitting the rocks. Tom is too slow for the wet stairs, so Pepper fetches a rope that is tied to an old lantern. Together they pull it up, and Tom holds the burning lantern in the window. The boat turns away and reaches the harbour safely. The next day the fishermen thank Tom, but he says that the cat deserves the thanks."

## Belege für die Kernpunkte — wörtlich aus GOOD.
const QUOTES := {
	"kp1": "an old keeper called Tom looks after the lamp",
	"kp2": "a small fishing boat is in danger of hitting the rocks",
	"kp3": "Pepper fetches a rope that is tied to an old lantern",
	"kp4": "The boat turns away and reaches the harbour safely",
	"kp5": "the fishermen thank Tom",
}


## Eine Bühne, die nur mitschreibt, was der Kampf von ihr will.
class StubStage:
	extends Node3D
	var stack_count := 0
	var calls: Array = []

	func set_focus(front: bool) -> void:
		calls.append(["set_focus", front])

	func speak() -> void:
		calls.append(["speak"])

	func drop_stack(index: int) -> void:
		calls.append(["drop_stack", index])

	func hold_stack(index: int) -> void:
		calls.append(["hold_stack", index])

	func restore_all() -> void:
		calls.append(["restore_all"])

	func gloat() -> void:
		calls.append(["gloat"])

	func fall() -> void:
		calls.append(["fall"])

	func named(method: String) -> Array:
		return calls.filter(func(c): return c[0] == method)


var _fight: WritingBoss
var _stage: StubStage
var _task: Dictionary
var _reply_to: Callable = Callable()
var _asked := 0
var _asked_text := ""
var _submitted: Array = []


func before_test() -> void:
	_task = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_submitted = []
	_reply_to = Callable()
	_asked = 0


func after_test() -> void:
	DirAccess.remove_absolute(WritingLog.path(PROFILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEY_FILE))
	ApiKeys.path = ApiKeys.DEFAULT_PATH
	ContentRegistry.writing.erase(str(_task.get("id", "")))
	if EventBus.writing_submitted.is_connected(_on_submitted):
		EventBus.writing_submitted.disconnect(_on_submitted)


func _backend(_t: Dictionary, text: String, on_done: Callable) -> void:
	_asked += 1
	_asked_text = text
	_reply_to = on_done


func _on_submitted(entry: Dictionary) -> void:
	_submitted.append(entry)


func _build() -> void:
	_stage = StubStage.new()
	_fight = auto_free(load(SCENE).instantiate())
	_fight.stage = _stage
	_fight.fake_backend = _backend
	_fight.reveal_step = 0.0
	_fight.log_profile = PROFILE
	add_child(_fight)
	_fight.begin(BOSS, _task)


func _press(panel: String, button: String) -> void:
	(_fight.get_node("%" + panel).get_node("%" + button) as Button).pressed.emit()


func _type(panel: String, text: String) -> void:
	var edit: TextEdit = _fight.get_node("%" + panel).get_node("%TextEdit")
	edit.text = text
	edit.text_changed.emit()


func _editor_text(panel: String) -> String:
	return (_fight.get_node("%" + panel).get_node("%TextEdit") as TextEdit).text


## Zur ersten Abgabe: Begegnung → Lesen → Schreiben, Text tippen, abgeben.
func _write_and_submit(text: String) -> void:
	_press("Encounter", "ActionButton")
	_press("Reading", "WriteButton")
	_type("Writing", text)
	_press("Writing", "SubmitButton")


## Eine Modellantwort: alle Kernpunkte erfasst außer `missing`, Präsens, Fehler wie gegeben.
func _result(missing: Array = [], errors: Array = []) -> Dictionary:
	var points: Array = []
	for id in QUOTES:
		points.append({"id": id, "covered": not missing.has(id), "quote": QUOTES[id] if not missing.has(id) else ""})
	return {"key_points": points, "present_tense": true, "tense_quotes": [], "errors": errors}


func _reply(result: Dictionary, note := "", billed := true) -> void:
	_reply_to.call({
		"result": result,
		"usage": {"model": "claude-opus-5-5", "input_tokens": 1200 if billed else 0,
				"output_tokens": 300 if billed else 0,
				"cache_read_input_tokens": 0, "cache_creation_input_tokens": 0, "seconds": 4.2},
		"note": note,
	})


func _row_icons(panel: String, list: String) -> Array:
	var out: Array = []
	for row in _fight.get_node("%" + panel).get_node("%" + list).get_children():
		out.append((row as WritingCriterionRow).icon())
	return out


## Die Testsummary selbst ist offline sauber — sonst prüfte jeder Test unten etwas anderes.
func test_the_good_summary_passes_offline() -> void:
	var card := SummaryCard.check(_task, GOOD)
	assert_bool(card["intro"]).is_true()
	assert_bool(card["length_ok"]).is_true()
	assert_array(card["quotes"]).is_empty()
	assert_array(card["opinion"]).is_empty()
	for id in QUOTES:
		assert_bool(GOOD.contains(QUOTES[id])).is_true()


func test_the_fight_opens_with_the_encounter() -> void:
	_build()
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.ENCOUNTER)
	assert_bool((_fight.get_node("%Encounter") as Control).visible).is_true()
	assert_str((_fight.get_node("%Encounter").get_node("%TaskTitle") as Label).text).contains("The Lighthouse Cat")
	assert_str((_fight.get_node("%StackLabel") as Label).text).contains("5/5")
	assert_array(_stage.named("set_focus")).contains([["set_focus", true]])
	assert_int(_stage.stack_count).is_equal(WritingJudge.CRITERIA.size())


## Begegnung → Lesen → Schreiben; zwischendurch zurück zur Vorlage, ohne dass der Text weg ist.
func test_the_phases_follow_each_other_and_keep_the_text() -> void:
	_build()
	_press("Encounter", "ActionButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.READING)
	assert_bool((_fight.get_node("%Reading") as Control).visible).is_true()
	assert_bool((_fight.get_node("%Encounter") as Control).visible).is_false()
	assert_array(_stage.calls.back()).is_equal(["set_focus", false])
	_press("Reading", "WriteButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.WRITING)
	_type("Writing", "In the story")
	_press("Writing", "ReadButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.READING)
	_press("Reading", "WriteButton")
	assert_str(_editor_text("Writing")).is_equal("In the story")


## Die Randleiste rechnet die Offline-Prüfung mit (entprellt; hier direkt angestoßen).
func test_the_sidebar_counts_words_and_checks() -> void:
	_build()
	_press("Encounter", "ActionButton")
	_press("Reading", "WriteButton")
	_type("Writing", GOOD)
	_fight._refresh_checks()
	var words := SummaryCard.split_words(GOOD).size()
	assert_str((_fight.get_node("%Writing").get_node("%Words") as Label).text).is_equal("%d Wörter" % words)
	assert_array(_row_icons("Writing", "Checks").slice(0, 4)).is_equal(["✔", "✔", "✔", "✔"])
	_type("Writing", "I think the story is great.")
	_fight._refresh_checks()
	assert_array(_row_icons("Writing", "Checks").slice(0, 4)).is_equal(["○", "○", "✔", "✖"])


## Leer abgeben ist keine Abgabe: kein Aufruf, die Phase bleibt.
func test_an_empty_text_is_not_submitted() -> void:
	_build()
	_write_and_submit("   ")
	assert_int(_asked).is_equal(0)
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.WRITING)


## Abgabe → Aufladen → Kriterien: was erfüllt ist, wirft seinen Stapel ab, der Rest hält.
func test_a_submission_drops_the_stacks_of_met_criteria() -> void:
	_build()
	_write_and_submit(GOOD)
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.ATTACK)
	assert_bool(_fight.pending()).is_true()
	assert_int(_asked).is_equal(1)
	assert_str(_asked_text).is_equal(GOOD)
	# Solange er urteilt, gibt es keine zweite Abgabe.
	_fight.submit()
	assert_int(_asked).is_equal(1)
	_reply(_result(["kp5"]))
	assert_bool(_fight.pending()).is_false()
	assert_int(_fight.rounds).is_equal(1)
	# content (Index 1) hält, alles andere fällt.
	assert_array(_stage.named("drop_stack")).is_equal([["drop_stack", 0], ["drop_stack", 2],
			["drop_stack", 3], ["drop_stack", 4]])
	assert_array(_stage.named("hold_stack")).is_equal([["hold_stack", 1]])
	assert_array(_row_icons("Attack", "Criteria")).is_equal(["✔", "✖", "✔", "✔", "✔"])
	assert_str((_fight.get_node("%StackLabel") as Label).text).contains("1/5")
	assert_bool(_fight.won()).is_false()


## Kein Urteil vom Dienst: der Text bleibt, der Grund steht da, die Abgabe zählt nicht.
func test_a_service_failure_keeps_the_text_and_does_not_count() -> void:
	_build()
	EventBus.writing_submitted.connect(_on_submitted)
	_write_and_submit(GOOD)
	_reply({}, "Keine Verbindung zum Dienst.", false)
	assert_int(_fight.rounds).is_equal(0)
	assert_str(_fight.last_note).is_equal("Keine Verbindung zum Dienst.")
	assert_str((_fight.get_node("%Attack").get_node("%Note") as Label).text).contains("Keine Verbindung")
	assert_array(_stage.named("drop_stack")).is_empty()
	assert_array(_submitted).is_empty()
	assert_array(WritingLog.entries(PROFILE)).is_empty()
	_press("Attack", "ContinueButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.WRITING)
	assert_str(_editor_text("Writing")).is_equal(GOOD)
	assert_str(_fight.text).is_equal(GOOD)


## Ein unbrauchbares Urteil zählt im Kampf nicht, seine Kosten werden trotzdem gebucht.
func test_a_billed_failure_is_logged_as_failed() -> void:
	_build()
	EventBus.writing_submitted.connect(_on_submitted)
	_write_and_submit(GOOD)
	_reply({}, "Die Antwort hatte nicht die erwartete Form.")
	assert_int(_fight.rounds).is_equal(0)
	assert_array(_stage.named("drop_stack")).is_empty()
	var entries := WritingLog.entries(PROFILE)
	assert_int(entries.size()).is_equal(1)
	assert_bool(bool(entries[0]["failed"])).is_true()
	assert_array(entries[0]["met"]).is_empty()
	assert_int(int(entries[0]["in"])).is_equal(1200)
	assert_int(_submitted.size()).is_equal(1)


## Erste Abgabe: der Inhalt hält, ein schwerer Fehler auch, beide markiert. Überarbeiten,
## erneut abgeben — der Rest fällt, und The Rambler ist besiegt. Gefallene Stapel kommen
## nicht zurück, auch wenn die zweite Antwort sie anders sähe.
func test_revising_wins_and_fallen_stacks_stay_fallen() -> void:
	_build()
	var ended: Array = []
	var on_ended := func(id: String, won: bool) -> void: ended.append([id, won])
	EventBus.boss_ended.connect(on_ended)
	_write_and_submit(GOOD)
	var error := {"quote": "too slow for the wet stairs", "category": "word_choice",
			"severity": "major", "hint": "Use 'slippery' instead of 'wet'."}
	_reply(_result(["kp5"], [error]))
	assert_array(_row_icons("Attack", "Criteria")).is_equal(["✔", "✖", "✔", "✖", "✔"])
	_press("Attack", "ContinueButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.REVISION)
	assert_str(_editor_text("Revision")).is_equal(GOOD)
	var marks: Array = _fight.get_node("%Revision").get_node("%Marks").get_children()
	assert_int(marks.size()).is_equal(1)
	assert_str((marks[0] as WritingMarkRow).quote).is_equal("too slow for the wet stairs")
	# Der Hinweis verrät die Lösung nicht (WritingJudge setzt auf die Regel zurück).
	assert_str((marks[0] as WritingMarkRow).hint()).not_contains("slippery")
	# Überarbeiten: anderer Wortlaut, erneut abgeben.
	var revised := GOOD.replace("too slow for the wet stairs", "too slow for the stairs")
	_type("Revision", revised)
	_press("Revision", "SubmitButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.ATTACK)
	assert_str(_asked_text).is_equal(revised)
	# Die zweite Antwort sieht plötzlich die Zeitform falsch — die Textsorte ist aber schon
	# gefallen und bleibt es.
	var second := _result()
	second["present_tense"] = false
	second["tense_quotes"] = ["The boat turns away"]
	_reply(second)
	assert_int(_fight.rounds).is_equal(2)
	assert_bool(_fight.won()).is_true()
	assert_int(_stage.named("drop_stack").size()).is_equal(5)
	_press("Attack", "ContinueButton")
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.VICTORY)
	assert_array(_stage.named("fall")).is_not_empty()
	assert_array(ended).is_equal([[BOSS["id"], true]])
	EventBus.boss_ended.disconnect(on_ended)


## Je gewertete Abgabe ein Eintrag in WritingLog und ein Signal — mit genau den Feldern des
## Vertrags und ohne Text.
func test_each_judged_submission_is_logged() -> void:
	_build()
	EventBus.writing_submitted.connect(_on_submitted)
	_write_and_submit(GOOD)
	_reply(_result(["kp5"]))
	var entries := WritingLog.entries(PROFILE)
	assert_int(entries.size()).is_equal(1)
	var entry: Dictionary = entries[0]
	assert_str(entry["boss"]).is_equal(BOSS["id"])
	assert_str(entry["task"]).is_equal(_task["id"])
	assert_int(int(entry["round"])).is_equal(1)
	assert_str(entry["model"]).is_equal("claude-opus-5-5")
	assert_int(int(entry["in"])).is_equal(1200)
	assert_int(int(entry["out"])).is_equal(300)
	assert_float(float(entry["s"])).is_equal(4.2)
	assert_array(entry["met"]).is_equal(["intro", "genre", "language", "length"])
	assert_int(int(entry["words"])).is_equal(SummaryCard.split_words(GOOD).size())
	assert_int(_submitted.size()).is_equal(1)
	assert_array((_submitted[0] as Dictionary).keys()).contains_exactly_in_any_order(WritingLog.FIELDS)
	assert_str(JSON.stringify(_submitted[0])).not_contains("Lighthouse")


## Ohne Aufgabe im Bereich gibt es nichts zu schreiben.
func test_without_a_task_there_is_nothing_to_write() -> void:
	_build()
	_fight.begin(BOSS, {})
	assert_int(_fight.phase).is_equal(WritingBoss.Phase.EMPTY)
	_fight.submit()
	assert_int(_asked).is_equal(0)


## Die Auswahl der Aufgabe folgt dem Scope: Unit-, Teil- und Buch-Schlüssel, leer = alle.
func test_tasks_follow_the_scope() -> void:
	ContentRegistry.writing[_task["id"]] = _task
	assert_array(WritingBoss.tasks_in_scope(BOSS, ["test/1"])).contains([_task])
	assert_array(WritingBoss.tasks_in_scope(BOSS, ["test/1/2"])).contains([_task])
	assert_array(WritingBoss.tasks_in_scope(BOSS, ["test"])).contains([_task])
	assert_array(WritingBoss.tasks_in_scope(BOSS, [])).contains([_task])
	assert_array(WritingBoss.tasks_in_scope(BOSS, ["test/2"])).not_contains([_task])
	var mediation := {"id": "boss.zz_m", "writing_rule": {"kind": "mediation"}}
	assert_array(WritingBoss.tasks_in_scope(mediation, ["test/1"])).not_contains([_task])


## Ohne Schlüssel gibt es The Rambler nicht — auch wenn eine Aufgabe im Bereich liegt.
func test_no_key_no_rambler() -> void:
	ContentRegistry.writing[_task["id"]] = _task
	assert_bool(WritingBoss.can_start_with(false, ["test/1"])).is_false()
	assert_bool(WritingBoss.can_start_with(true, ["test/2"])).is_false()
	if not ContentRegistry.get_entry("bosses", WritingBoss.BOSS_ID).is_empty():
		assert_bool(WritingBoss.can_start_with(true, ["test/1"])).is_true()


## Der Knopf in „Runde vorbereiten“ ist ohne Schlüssel unsichtbar, nicht gesperrt.
func test_the_entry_button_is_invisible_without_a_key() -> void:
	ApiKeys.path = KEY_FILE
	assert_bool(ApiKeys.available()).is_false()
	var setup: Control = auto_free(load(SETUP_SCENE).instantiate())
	add_child(setup)
	assert_bool((setup.get_node("%WritingStartButton") as Button).visible).is_false()
