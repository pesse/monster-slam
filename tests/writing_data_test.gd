extends GdUnitTestSuite
## Die ausgelieferten Vorlagen des Schreib-Bosses (ADR 0023 §8) — nicht die Regeln (die
## prüfen tests/summary_card_test.gd und tests/writing_judge_test.gd), sondern die Daten.
## Ein Fehler hier kostet ein Kind einen Stapel, den es nicht verdient hat.
## Gelesen wird direkt aus dem Submodule, wie in tests/sentence_data_test.gd.

const FIELDS := ["id", "kind", "book", "unit", "title", "author", "genre", "text",
		"target_words", "key_points"]

var _tasks: Array = []
var _units: Dictionary = {}


func before(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	_tasks = LanguageData.entries("writing")
	_units = {}
	for lexeme in LanguageData.entries("lexemes"):
		_units["%s/%d" % [lexeme.get("book", ""), int(lexeme.get("unit", 0))]] = true


func test_every_task_has_the_schema(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for task: Dictionary in _tasks:
		var id := str(task.get("id", "?"))
		for field: String in FIELDS:
			assert_bool(task.has(field)).override_failure_message(
					"'%s': Feld %s fehlt" % [id, field]).is_true()
		assert_str(id).override_failure_message("'%s': Id passt nicht zu Buch und Unit" % id)\
				.starts_with("writing.en_%s_unit%d.%s_" % [task.get("book"), int(task.get("unit", 0)),
						task.get("kind")])
		assert_bool(_units.has("%s/%d" % [task.get("book"), int(task.get("unit", 0))]))\
				.override_failure_message("'%s': Unit ohne Vokabeln" % id).is_true()
		var target: Array = task.get("target_words", [])
		assert_bool(target.size() == 2 and int(target[0]) < int(target[1]))\
				.override_failure_message("'%s': target_words %s" % [id, target]).is_true()


## Die Einleitung „<Titel> by <Autor>“ muss SummaryCard als Einleitung erkennen — sonst
## fällt der erste Stapel nie.
func test_title_and_author_are_recognised(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for task: Dictionary in _tasks:
		var intro := "%s by %s is a %s." % [task.get("title"), task.get("author"), task.get("genre")]
		assert_bool(SummaryCard.check(task, intro)["intro"]).override_failure_message(
				"'%s': Einleitung nicht erkannt" % task.get("id")).is_true()


## Kernpunkte mit eindeutigen Ids, mindestens ein Pflichtpunkt, und keiner, der wörtlich
## aus der Vorlage stammt — wer ihn so hinschreibt, gälte als Abschreiber.
func test_key_points_are_sound(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	for task: Dictionary in _tasks:
		var id := str(task.get("id", "?"))
		var seen := {}
		var required := 0
		for point: Dictionary in task.get("key_points", []):
			var point_id := str(point.get("id", ""))
			assert_bool(point_id.is_empty() or seen.has(point_id)).override_failure_message(
					"'%s': Kernpunkt-Id „%s“ leer oder doppelt" % [id, point_id]).is_false()
			seen[point_id] = true
			if bool(point.get("required", true)):
				required += 1
			assert_array(SummaryCard.check(task, str(point.get("text", "")))["quotes"])\
					.override_failure_message("'%s' %s: aus der Vorlage übernommen"
							% [id, point_id]).is_empty()
		assert_int(required).override_failure_message("'%s': kein Pflichtpunkt" % id)\
				.is_greater(0)
