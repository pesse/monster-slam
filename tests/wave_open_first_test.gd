extends GdUnitTestSuite
## Mindestanteil nicht gemeisterter Monster je Welle: WaveGenerator.open_due() und
## pick_with(open_first).
##
## Mit erfundenen Kandidaten und einem Generator, der jeden Kandidaten spielbar nennt —
## ohne Sprachdaten und ohne den Lernstand des Entwicklungsprofils.

const GENERATOR := preload("res://src/battle/wave_generator.gd")
const NOW := 1790877600


class AlwaysPlayable extends WaveGenerator:
	func _build_plan(candidate: Dictionary) -> Dictionary:
		return {"task": {"source_id": candidate["source"]["id"]}, "net": 0.0}


func _cand(source_id: String, mastered: bool, repeat := false) -> Dictionary:
	return {"source": {"id": source_id}, "learnable_id": source_id, "definition": {},
		"extra": {}, "mastered": mastered, "repeat": repeat, "group": WaveGenerator.GROUP_REST}


func _picked(plan: Dictionary) -> String:
	return str(plan["task"]["source_id"])


func test_open_first_skips_mastered_candidates() -> void:
	var cands := [_cand("m1", true), _cand("m2", true), _cand("open", false)]
	assert_str(_picked(AlwaysPlayable.new().pick_with(cands, {}, true))).is_equal("open")


func test_without_open_first_the_order_decides() -> void:
	var cands := [_cand("m1", true), _cand("open", false)]
	assert_str(_picked(AlwaysPlayable.new().pick_with(cands))).is_equal("m1")


## Ist alles gemeistert, kommt trotzdem ein Monster.
func test_open_first_falls_back_when_everything_is_mastered() -> void:
	var cands := [_cand("m1", true), _cand("m2", true)]
	assert_str(_picked(AlwaysPlayable.new().pick_with(cands, {}, true))).is_equal("m1")


## Ein Wort doppelt auf dem Feld wiegt schwerer als der Vorzug für Offenes.
func test_the_field_lock_beats_open_first() -> void:
	var cands := [_cand("open", false), _cand("m1", true)]
	var plan := AlwaysPlayable.new().pick_with(cands, {"open": true}, true)
	assert_str(_picked(plan)).is_equal("m1")


## Ein offenes Wort, das in der Welle schon dran war, füllt den Anteil nicht.
func test_open_first_does_not_repeat_a_shown_open_word() -> void:
	var cands := [_cand("m1", true), _cand("open", false, true)]
	assert_str(_picked(AlwaysPlayable.new().pick_with(cands, {}, true))).is_equal("m1")


## Bei 0,5: das erste offen, danach jedes zweite.
func test_open_due_spreads_the_share_over_the_wave() -> void:
	var due: Array = []
	var open := 0
	for spawned in 6:
		var must := WaveGenerator.open_due(open, spawned)
		due.append(must)
		if must:
			open += 1
	assert_array(due).is_equal([true, false, true, false, true, false])


## Kam schon genug Offenes von selbst, muss nichts vorgezogen werden.
func test_open_due_is_off_when_the_share_is_met() -> void:
	assert_bool(WaveGenerator.open_due(3, 3)).is_false()


func test_ordered_marks_mastered_like_player_progress() -> void:
	var states := {
		"sure": {"confidence": PlayerProgress.MASTERY_CONFIDENCE, "last_seen": NOW - 60,
			"due_at": NOW + 86400},
		"shaky": {"confidence": 0.5, "last_seen": NOW - 60, "due_at": NOW + 86400},
	}
	var cands := [_cand("sure", false), _cand("shaky", false), _cand("unseen", false)]
	var order := GENERATOR.ordered(cands, func(id: String) -> Dictionary:
		return states.get(id, {}), {}, NOW)
	var mastered := {}
	for c in order:
		mastered[str(c["learnable_id"])] = bool(c["mastered"])
	assert_dict(mastered).is_equal({"sure": true, "shaky": false, "unseen": false})
