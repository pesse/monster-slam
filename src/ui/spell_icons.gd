class_name SpellIcons
extends RefCounted
## Die Bilder der Zauber (ADR 0014), wie `SkillIcons` für die Fähigkeiten.
##
## Die Zuordnung Zauber → Icon steht in `assets/ui/spells/spell_icons.json` und liegt in der
## EXE, die Zauber selbst kommen aus dem game-Pack. Ein Zauber, den ein neuerer Pack
## mitbringt, hat womöglich kein Bild — dann gibt es `null`, und Kachel und Platz zeigen das
## Zeichen aus seinem `icon`-Feld. Ein neues Pack-Feld braucht es dafür nicht
## (tests/spell_icons_test.gd prüft, dass jeder ausgelieferte Zauber ein Bild hat).

const MAP_PATH := "res://assets/ui/spells/spell_icons.json"

## Id -> Pfad, einmal gelesen.
static var _paths: Dictionary = {}
static var _loaded := false
## Pfad -> Textur, festgehalten wie in `SkillIcons`.
static var _textures: Dictionary = {}


## Das Bild eines Zaubers, oder `null`, wenn es keins gibt.
static func of(id: String) -> Texture2D:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
		if parsed is Dictionary:
			_paths = parsed
		else:
			push_warning("SpellIcons: '%s' ist kein JSON-Objekt" % MAP_PATH)
	var path := str(_paths.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]


## Ob es zu `id` einen Eintrag gibt — für den Test, nicht für die Anzeige.
static func has(id: String) -> bool:
	of(id)
	return _paths.has(id)


## Bild oder Zeichen von `spell` in `picture` und `glyph`: das Bild, wo es eins gibt, sonst
## das Zeichen. Leeres `spell`: beides leer.
static func show(spell: Dictionary, picture: TextureRect, glyph: Label) -> void:
	var texture := of(str(spell.get("id", ""))) if not spell.is_empty() else null
	picture.texture = texture
	picture.visible = texture != null
	glyph.text = "" if spell.is_empty() or texture != null else str(spell.get("icon", "?"))
	glyph.visible = texture == null
