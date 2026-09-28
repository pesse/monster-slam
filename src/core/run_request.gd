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

## Das Level von der Karte (MapLevel.levels_for), oder leer im Expertenmodus.
static var _level: Dictionary = {}


## Der nächste Kampf spielt dieses Level (von der Gebietskarte).
static func start_level(level: Dictionary) -> void:
	_level = level.duplicate(true)


## Der nächste Kampf spielt die Auswahl des Profils (Expertenmodus).
static func start_expert() -> void:
	_level = {}


static func is_level() -> bool:
	return not _level.is_empty()


static func level() -> Dictionary:
	return _level


## Der Curriculum-Scope des Laufs.
static func scope() -> Array:
	if is_level():
		return Array(_level.get("scope", []))
	return Array(UserSettings.selected_scope())


## Die Themen-Tags des Laufs. Ein Level filtert nicht nach Themen: es ist ein Stück Buch.
static func tags() -> Array:
	if is_level():
		return []
	return Array(UserSettings.selected_tags())


## Der Aufgaben-Pool des Wellenkampfs. Ein Level spielt alle Aufgaben- und Wortarten
## seines Bereichs; der Expertenmodus die Auswahl des Profils (WaveGenerator).
static func task_pool(difficulty: int) -> Dictionary:
	if not is_level():
		return WaveGenerator.pool_from_settings(difficulty)
	return {
		"task_types": [],
		"lexeme_types": [],
		"scope": scope(),
		"tags": [],
		"difficulty_max": clampi(difficulty, 1, 5),
	}


## Die Unit des Levels („<book>/<unit>"), leer im Expertenmodus. Nur ein Boss mit Unit
## zählt als Sieg auf der Karte (BossRecord).
static func unit_key() -> String:
	if not is_level():
		return ""
	return "%s/%d" % [_level.get("book", ""), int(_level.get("unit", 0))]


## Wohin „Zurück" nach dem Kampf führt: auf die Gebietskarte des Levels oder ins Menü.
static func return_scene() -> String:
	return AREA_SCENE if is_level() else MENU_SCENE
