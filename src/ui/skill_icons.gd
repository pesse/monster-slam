class_name SkillIcons
extends RefCounted
## Die Bilder des Fähigkeitsbaums: Icon je Skill, Medaillon, Fokusring, Haken, Schloss.
## Die Zuordnung liegt in der EXE, die Skills im game-Pack: ein Skill aus einem neueren Pack
## hat womöglich kein Bild, dann zeichnet der Graph sein `icon`-Zeichen (`SkillTree.icon_of`).

const MAP_PATH := "res://assets/ui/skill_tree/skill_icons.json"
const DIR := "res://assets/ui/skill_tree/"

## Id -> Pfad, einmal gelesen.
static var _paths: Dictionary = {}
static var _loaded := false

## Pfad -> Textur. Festgehalten, weil der Graph in `_draw` lädt: eine Textur, die erst im
## selben Bild neu entsteht, zeichnet der Renderer weiß.
static var _textures: Dictionary = {}


## Das Bild eines Skills, oder `null`, wenn es keins gibt.
static func of(id: String) -> Texture2D:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
		if parsed is Dictionary:
			_paths = parsed
		else:
			push_warning("SkillIcons: '%s' ist kein JSON-Objekt" % MAP_PATH)
	var path := str(_paths.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return _texture(path)


## Ob es zu `id` einen Eintrag gibt.
static func has(id: String) -> bool:
	of(id)
	return _paths.has(id)


static func medallion() -> Texture2D:
	return _texture(DIR + "medallions/available.webp")


static func focus_ring() -> Texture2D:
	return _texture(DIR + "medallions/focus_ring.webp")


static func check() -> Texture2D:
	return _texture(DIR + "status/check.webp")


static func lock() -> Texture2D:
	return _texture(DIR + "status/lock.webp")


static func skill_point() -> Texture2D:
	return _texture(DIR + "icons/skill_point.webp")


## Gold (Preis fürs Verlernen).
static func gold() -> Texture2D:
	return _texture("res://assets/ui/statistics/icons/gold_coins.webp")


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]
