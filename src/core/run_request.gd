class_name RunRequest
extends RefCounted
## Was der nächste Kampf spielt — und wohin es danach zurückgeht (ADR 0006).
##
## Zwei Wege führen in einen Kampf: die Karte (ein Level einer Unit) und der Expertenmodus
## („Runde vorbereiten" mit den gespeicherten Filtern des Profils). Kampf und Boss lesen
## ihren Bereich HIER und nicht mehr direkt aus UserSettings — sonst spielte ein Level
## von der Karte mit den Filtern, die jemand irgendwann im Expertenmodus gesetzt hat.
##
## Der Zustand ist statisch, damit er den Szenenwechsel überdauert; er gehört dem Lauf,
## nicht dem Profil, und wird nicht gespeichert. Ohne gesetztes Level gilt der
## Expertenmodus — so verhält sich jeder Einstieg, der RunRequest nicht kennt, wie bisher.

const MENU_SCENE := "res://scenes/ui/profile_menu.tscn"
const AREA_SCENE := "res://scenes/ui/area_map.tscn"
const TEST_SCENE := "res://scenes/ui/test_prep.tscn"

## Das Level von der Karte (MapLevel.levels_for), oder leer im Expertenmodus.
static var _level: Dictionary = {}

## Die Wahl „Ich-Sicht" auf der Gebietskarte. Nur der Wunsch: ob er gilt, entscheidet
## `first_person()` mit dem Skill-Baum. Hält wie das Level nur bis zum Programmende.
static var _first_person_wanted := false

## Die Testliste (TestLists), wenn der Lauf eine Arbeit vorbereitet — sonst leer. Ein
## Testlauf ist weder Level noch Expertenmodus: er spielt genau die Wörter der Liste.
static var _test: Dictionary = {}
## Ihr Scope (TestLists.run_scope), beim Start einmal gerechnet.
static var _test_scope: Array = []


## Der nächste Kampf spielt dieses Level (von der Gebietskarte).
static func start_level(level: Dictionary) -> void:
	_level = level.duplicate(true)
	_test = {}


## Der nächste Kampf spielt die Auswahl des Profils (Expertenmodus).
static func start_expert() -> void:
	_level = {}
	_test = {}


## Der nächste Kampf übt die Wörter einer Testliste.
static func start_test(list: Dictionary) -> void:
	_level = {}
	_test = list.duplicate(true)
	_test_scope = TestLists.run_scope(_test, ContentRegistry.lexemes,
			ContentRegistry.narrowest_scope)


static func is_test() -> bool:
	return not _test.is_empty()


static func test_list() -> Dictionary:
	return _test


## Die Liste hat sich im Lauf geändert (neue Runde) — der Stand wird mitgeführt.
static func update_test(list: Dictionary) -> void:
	if is_test():
		_test = list.duplicate(true)


## Auf der Gebietskarte gewählt oder abgewählt.
static func want_first_person(on: bool) -> void:
	_first_person_wanted = on


static func wants_first_person() -> bool:
	return _first_person_wanted


## Spielt der nächste Wellenkampf aus der Ich-Sicht? Nur ein Level von der Karte (dort
## steht der Schalter) und nur mit gelerntem Späherblick — wer den Knoten verlernt,
## steht wieder auf der Festung, ohne dass ein zweiter Merker nachgezogen werden muss.
## Der Bosskampf fragt nicht: er bleibt, wie er ist.
static func first_person() -> bool:
	return first_person_with(SkillBook.bonuses(), OS.is_debug_build())


## Steht der Schalter auf der Gebietskarte? Mit gelerntem Späherblick — und im Debug-Build
## immer, damit man die Ich-Sicht ohne fünf Skillpunkte ausprobieren kann (wie das
## Debug-Panel gibt es das im veröffentlichten Build nicht).
static func first_person_selectable() -> bool:
	return first_person_selectable_with(SkillBook.bonuses(), OS.is_debug_build())


static func first_person_selectable_with(bonuses: Dictionary, debug: bool) -> bool:
	return debug or FirstPersonView.unlocked(bonuses)


## Dieselbe Regel mit übergebenen Boni und Build — prüfbar ohne das SkillBook des Profils
## und unabhängig davon, dass die Tests selbst im Debug-Build laufen.
static func first_person_with(bonuses: Dictionary, debug := false) -> bool:
	return _first_person_wanted and is_level() and first_person_selectable_with(bonuses, debug)


static func is_level() -> bool:
	return not _level.is_empty()


static func level() -> Dictionary:
	return _level


## Der Curriculum-Scope des Laufs.
static func scope() -> Array:
	if is_test():
		return _test_scope.duplicate()
	if is_level():
		return Array(_level.get("scope", []))
	return Array(UserSettings.selected_scope())


## Die Themen-Tags des Laufs. Ein Level filtert nicht nach Themen: es ist ein Stück Buch.
static func tags() -> Array:
	if is_level() or is_test():
		return []
	return Array(UserSettings.selected_tags())


## Der Aufgaben-Pool des Wellenkampfs. Ein Level spielt alle Aufgaben- und Wortarten
## seines Bereichs; der Expertenmodus die Auswahl des Profils (WaveGenerator).
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


## Die Unit des Levels („<book>/<unit>"), leer im Expertenmodus. Nur ein Boss mit Unit
## zählt als Sieg auf der Karte (BossRecord).
static func unit_key() -> String:
	if not is_level():
		return ""
	return "%s/%d" % [_level.get("book", ""), int(_level.get("unit", 0))]


## Wohin „Zurück" nach dem Kampf führt: auf die Gebietskarte des Levels oder ins Menü.
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
