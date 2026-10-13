class_name MapSelection
extends RefCounted
## Wo man auf der Karte steht (ADR 0006); statisch über Szenenwechsel, nicht gespeichert.

## Die Bibliothek ist eine Seite des Start-Screens (ProfileMenu.LIBRARY).
const BOOKS_SCENE := "res://scenes/ui/profile_menu.tscn"
const BOOK_SCENE := "res://scenes/ui/book_map.tscn"
const AREA_SCENE := "res://scenes/ui/area_map.tscn"

static var book := ""
static var unit := 0
## Kommt die Gebietskarte gerade aus der Buchkarte? Dann setzt sie deren Zoom fort.
static var zoom_in := false
## Kommt die Buchkarte gerade aus einer Gebietskarte? Dann kommt sie aus dieser Unit heraus.
static var zoom_out := false
## Geht es von der Buchkarte zurück in die Bibliothek? Dann beginnt der Start-Screen dort.
static var to_shelf := false


## „Profil wechseln“ an der Plakette einer Karte: zurück zum Start-Screen auf „Wer spielt?“.
static func to_profile_pick(from: Node) -> void:
	to_shelf = false
	zoom_in = false
	zoom_out = false
	ProfileMenu.intro_done = false
	from.get_tree().change_scene_to_file(BOOKS_SCENE)
