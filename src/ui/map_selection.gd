class_name MapSelection
extends RefCounted
## Wo man auf der Karte steht: welches Buch, welche Unit (ADR 0006).
##
## Statisch, damit der Weg zurück aus dem Kampf wieder auf derselben Karte landet — die
## Screens wechseln über change_scene_to_file und behalten nichts. Nicht gespeichert: ein
## Neustart beginnt mit „Wer spielt?“.

## Die Bibliothek ist eine Seite des Start-Screens (ProfileMenu.LIBRARY).
const BOOKS_SCENE := "res://scenes/ui/profile_menu.tscn"
const BOOK_SCENE := "res://scenes/ui/book_map.tscn"
const AREA_SCENE := "res://scenes/ui/area_map.tscn"

static var book := ""
static var unit := 0
## Kommt die Gebietskarte gerade aus der Buchkarte? Dann setzt sie deren Zoom fort; aus dem
## Kampf zurück steht sie einfach da.
static var zoom_in := false
## Kommt die Buchkarte gerade aus einer Gebietskarte? Dann kommt sie aus dieser Unit heraus.
static var zoom_out := false
## Geht es gerade von der Buchkarte zurück in die Bibliothek? Dann beginnt der Start-Screen
## dort, im offenen Buch.
static var to_shelf := false
