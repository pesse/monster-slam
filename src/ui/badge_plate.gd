@tool
class_name BadgePlate
extends Control
## Die Plakette eines kleinen Erfolgs (Badges, Issue #63): eine Medaille am Band aus
## `assets/ui/badges/` (Geometrie im README dort), darüber die Zahl der Stufe in der
## Spielschrift — Zahlen stehen nie im Bild. Plaketten ohne Stufe tragen ihr Zeichen im Bild
## und keine Zahl. Größe und Feld der Zahl stehen in badge_plate.tscn.

const ART_DIR := "res://assets/ui/badges/"
## Mitte der Scheibe als Anteil am Bild (128/256, 120/320, README in ART_DIR).
const DISC_CENTER := Vector2(0.5, 0.375)
## Farbe der Funken je Palette (die Innenfläche der Medaille).
const GLOW := {
	&"bronze": Color(0.86, 0.57, 0.32),
	&"silver": Color(0.87, 0.9, 0.95),
	&"gold": Color(0.98, 0.84, 0.38),
	&"diamond": Color(0.8, 0.97, 1.0),
	&"comeback": Color(1.0, 0.62, 0.35),
	&"better": Color(0.5, 0.92, 0.86),
	&"revenge": Color(0.78, 0.6, 1.0),
	&"catch_up": Color(0.62, 0.95, 0.5),
}

## Palette = Dateiname der Medaille (Badges.make).
@export var palette: StringName = &"gold":
	set(value):
		palette = value
		_apply()
## Zahl auf der Plakette; leer bei Plaketten mit Zeichen.
@export var mark: String = "10":
	set(value):
		mark = value
		_apply()


func _ready() -> void:
	_apply()


func setup(new_palette: StringName, new_mark: String) -> void:
	palette = new_palette
	mark = new_mark


## Die Farbe der Funken zur Plakette.
static func glow(name: StringName) -> Color:
	return GLOW.get(name, GLOW[&"gold"])


func _apply() -> void:
	if not is_node_ready():
		return
	var path := "%s%s.webp" % [ART_DIR, palette]
	($Medal as TextureRect).texture = load(path) if ResourceLoader.exists(path) else null
	($Mark as Label).text = mark
	# Drei Ziffern (100, 250) passen nur kleiner auf die Scheibe.
	($Mark as Label).theme_type_variation = &"CelebrateBadgeMarkLong" if mark.length() >= 3 \
			else &"CelebrateBadgeMark"
