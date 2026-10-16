class_name RunRequest
extends RefCounted
## Was der nächste Kampf spielt und wohin es danach zurückgeht (ADR 0006): ein Level der
## Karte, eine Testliste oder der Expertenmodus (ohne gesetztes Level). Statisch, damit es
## den Szenenwechsel überdauert; gehört dem Lauf, nicht dem Profil.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const AREA_SCENE := "res://scenes/ui/area_map.tscn"
const TEST_SCENE := "res://scenes/ui/test_prep.tscn"

## Das Level von der Karte (MapLevel.levels_for), oder leer im Expertenmodus.
static var _level: Dictionary = {}

## Gewünschte Ich-Sicht; ob sie gilt, entscheidet `first_person()` mit dem Skill-Baum.
static var _first_person_wanted := false

## Spielt „Gesamt“ die Sätze aus dem Buch mit (ADR 0026)? Steht nicht im Level und nicht im
## begonnenen Lauf (RunSave): Umschalten ändert nur, was ab jetzt kommt.
static var _examples_wanted := true

## Die Testliste (TestLists) eines Testlaufs, sonst leer. Er spielt genau ihre Wörter.
static var _test: Dictionary = {}
## Ihr Scope (TestLists.run_scope), beim Start einmal gerechnet.
static var _test_scope: Array = []

## Der begonnene Lauf, den der nächste Kampf fortsetzt (RunSave), sonst leer; genau einmal
## über `take_resume` abzuholen.
static var _resume: Dictionary = {}


## Der nächste Kampf spielt dieses Level. Mit `resume` (RunSave) setzt er einen begonnenen
## Lauf fort; `level` ist dann RunSave.resumable_level.
static func start_level(level: Dictionary, resume: Dictionary = {}) -> void:
	_level = level.duplicate(true)
	_test = {}
	_resume = resume.duplicate(true)


## Der nächste Kampf spielt die Auswahl des Profils (Expertenmodus).
static func start_expert() -> void:
	_level = {}
	_test = {}
	_resume = {}


## Der nächste Kampf übt die Wörter einer Testliste.
static func start_test(list: Dictionary) -> void:
	_level = {}
	_test = list.duplicate(true)
	_resume = {}
	_test_scope = TestLists.run_scope(_test, ContentRegistry.lexemes,
			ContentRegistry.narrowest_scope)


static func is_test() -> bool:
	return not _test.is_empty()


static func test_list() -> Dictionary:
	return _test


## Führt den Stand der Testliste im Lauf mit.
static func update_test(list: Dictionary) -> void:
	if is_test():
		_test = list.duplicate(true)


static func want_first_person(on: bool) -> void:
	_first_person_wanted = on


static func wants_first_person() -> bool:
	return _first_person_wanted


static func want_examples(on: bool) -> void:
	_examples_wanted = on


static func wants_examples() -> bool:
	return _examples_wanted


## Der Scope eines Levels; „Gesamt“ mit `examples` nimmt den Buchsatz-Bonus seiner Unit dazu.
static func level_scope(level: Dictionary, examples: bool) -> Array:
	var out: Array = Array(level.get("scope", [])).duplicate()
	if not examples or str(level.get("kind", "")) != MapLevel.KIND_ALL:
		return out
	var key := ContentRegistry.examples_bonus_of(str(level.get("book", "")),
			int(level.get("unit", 0)))
	if not key.is_empty() and not key in out:
		out.append(key)
	return out


## Beginnt der nächste Wellenkampf aus der Ich-Sicht? Nur gewünscht und mit gelerntem
## Späherblick.
static func first_person() -> bool:
	return first_person_with(SkillBook.bonuses(), OS.is_debug_build())


## Steht der Schalter zur Verfügung? Mit gelerntem Späherblick, im Debug-Build immer.
static func first_person_selectable() -> bool:
	return first_person_selectable_with(SkillBook.bonuses(), OS.is_debug_build())


static func first_person_selectable_with(bonuses: Dictionary, debug: bool) -> bool:
	return debug or FirstPersonView.unlocked(bonuses)


## Dieselbe Regel mit übergebenen Boni und Build, für Tests.
static func first_person_with(bonuses: Dictionary, debug := false) -> bool:
	return _first_person_wanted and first_person_selectable_with(bonuses, debug)


## Gibt den begonnenen Lauf heraus, den dieser Kampf fortsetzt, und vergisst ihn.
static func take_resume() -> Dictionary:
	var out := _resume
	_resume = {}
	return out


static func is_level() -> bool:
	return not _level.is_empty()


## Kann dieser Lauf rasten? Ein Level von der Karte, das nicht nur Boni spielt (RunSave.keeps).
static func keeps_run() -> bool:
	return is_level() and RunSave.keeps(_level)


static func level() -> Dictionary:
	return _level


static func scope() -> Array:
	if is_test():
		return _test_scope.duplicate()
	if is_level():
		return level_scope(_level, _examples_wanted)
	return Array(UserSettings.selected_scope())


## Die Themen-Tags des Laufs. Ein Level filtert nicht nach Themen: es ist ein Stück Buch.
static func tags() -> Array:
	if is_level() or is_test():
		return []
	return Array(UserSettings.selected_tags())


## Der Aufgaben-Pool des Wellenkampfs; ein Level spielt alle Aufgaben- und Wortarten.
static func task_pool() -> Dictionary:
	if is_test():
		return {
			"task_types": [],
			"lexeme_types": [],
			"scope": scope(),
			"tags": [],
			"lexeme_ids": Array(_test.get("lexeme_ids", [])),
			"direction_mode": str(_test.get("direction", "")),
		}
	if not is_level():
		return WaveGenerator.pool_from_settings()
	return {
		"task_types": [],
		"lexeme_types": [],
		"scope": scope(),
		"tags": [],
	}


## Die Unit des Levels („<book>/<unit>“), leer außerhalb eines Levels.
static func unit_key() -> String:
	if not is_level():
		return ""
	return "%s/%d" % [_level.get("book", ""), int(_level.get("unit", 0))]


## Wohin „Zurück“ nach dem Kampf führt.
static func return_scene() -> String:
	if is_test():
		return TEST_SCENE
	return AREA_SCENE if is_level() else MENU_SCENE


## Wo der Kampf steht (BattleTheme.for_level): das Level, im Testlauf die Unit mit den
## meisten Wörtern der Liste.
static func theme_level() -> Dictionary:
	if is_test():
		return {"book": str(_test.get("book", "")),
				"unit": TestLists.main_unit(_test, ContentRegistry.lexemes), "key": ""}
	return _level
