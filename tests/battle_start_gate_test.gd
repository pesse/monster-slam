extends GdUnitTestSuite
## Der erste Start ohne Inhalte darf keine Falle sein (Issue #1).
##
## Ohne spielbare Aufgabe spawnt der WaveRunner nichts; ohne Spawn zählt `_spawned`
## nicht hoch, das Wellenende tritt nie ein und aus dem leeren Schlachtfeld führte kein
## Weg zurück. Geprüft wird deshalb die Kette VOR dem Kampf: erkennt der Generator einen
## leeren Pool, sperrt das Session-Setup den Start, und startet der Kampf gar nicht,
## falls doch jemand dort landet.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SETUP_SCENE := "res://scenes/ui/session_setup.tscn"

## Tag, den keine Vokabel trägt: erzwingt einen leeren Pool, auch WENN die Sprachdaten
## ausgecheckt sind. Damit gelten diese Tests in beiden Umgebungen (siehe LanguageData)
## und auch neben installierten Content-Packs.
const NO_MATCH_TAG := "kein-tag-mit-diesem-namen"

var _scope: PackedStringArray
var _tags: PackedStringArray
var _task_types: PackedStringArray
var _lexeme_types: PackedStringArray


## Die Auswahl hängt am aktiven Profil und wird hier verstellt — vorher sichern,
## hinterher zurückgeben, sonst erbt der nächste Test einen leeren Pool.
func before_test() -> void:
	_scope = UserSettings.selected_scope()
	_tags = UserSettings.selected_tags()
	_task_types = UserSettings.selected_task_types()
	_lexeme_types = UserSettings.selected_lexeme_types()


func after_test() -> void:
	UserSettings.set_selected_scope(_scope)
	UserSettings.set_selected_tags(_tags)
	UserSettings.set_selected_task_types(_task_types)
	UserSettings.set_selected_lexeme_types(_lexeme_types)


## Auswahl, die garantiert nichts trifft.
func _select_nothing_playable() -> void:
	UserSettings.set_selected_scope(PackedStringArray([]))
	UserSettings.set_selected_task_types(PackedStringArray([]))
	UserSettings.set_selected_lexeme_types(PackedStringArray([]))
	UserSettings.set_selected_tags(PackedStringArray([NO_MATCH_TAG]))


func test_has_playable_false_for_pool_without_match() -> void:
	assert_bool(WaveGenerator.new().has_playable({"tags": [NO_MATCH_TAG]})).is_false()


## Mit ausgecheckten Sprachdaten muss der ungefilterte Pool etwas hergeben — sonst
## sperrte das Startmenü den Kampf, obwohl Vokabeln vorhanden sind.
func test_has_playable_true_without_filters(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	assert_bool(WaveGenerator.new().has_playable({})).is_true()


## Kernregression: der Kampf startet ohne spielbare Aufgabe NICHT. Ein Wellenstart
## wäre daran erkennbar, dass ein Soll (wave_total) bekanntgegeben wird.
func test_battle_does_not_start_wave_without_playable_task() -> void:
	_select_nothing_playable()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(2)
	var battle := runner.scene()
	assert_bool((battle.get_node("UI/EndLabel") as Label).visible).is_true()
	assert_bool((battle.get_node("UI/AnswerInput") as LineEdit).visible).is_false()
	assert_int(GameState.wave_total).is_equal(0)


func test_session_setup_locks_start_without_playable_task() -> void:
	_select_nothing_playable()
	var runner := scene_runner(SETUP_SCENE)
	var setup := runner.scene()
	assert_bool((setup.get_node("%StartButton") as Button).disabled).is_true()
	assert_bool((setup.get_node("%StartHint") as Label).visible).is_true()


func test_session_setup_allows_start_with_playable_task(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	UserSettings.set_selected_scope(PackedStringArray([]))
	UserSettings.set_selected_tags(PackedStringArray([]))
	UserSettings.set_selected_task_types(PackedStringArray([]))
	UserSettings.set_selected_lexeme_types(PackedStringArray([]))
	var runner := scene_runner(SETUP_SCENE)
	var setup := runner.scene()
	assert_bool((setup.get_node("%StartButton") as Button).disabled).is_false()
	assert_bool((setup.get_node("%StartHint") as Label).visible).is_false()
