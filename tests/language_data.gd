class_name LanguageData
extends RefCounted
## Liegen die Sprachdaten vor?
##
## `data/language/` ist ein privates Submodule und wird im CI des öffentlichen Hauptrepos
## bewusst NICHT ausgecheckt — die verteilte EXE darf das Lehrbuchmaterial nicht enthalten,
## also hat der Build es auch nicht. Tests, die auf konkreten Vokabeln bestehen, können dort
## nicht laufen. Sie werden mit `do_skip := LanguageData.missing()` übersprungen statt rot:
## ein Test, der ohne Daten stillschweigend durchläuft (leere Liste, Schleife ohne
## Durchlauf), wäre ein falsches Grün — schlimmer als ein sichtbares „skipped".
##
## Geprüft wird das Verzeichnis, nicht `ContentRegistry.lexemes`: das ist unabhängig davon,
## ob der Autoload schon geladen hat, und stimmt auch, wenn ein Pack in `user://` liegt.

const LEXEME_DIR := "res://data/language/lexemes"

## Warum ein Test übersprungen wurde — für die Testausgabe.
const REASON := "Sprachdaten nicht ausgecheckt (privates Submodule data/language)"


static func missing() -> bool:
	return not DirAccess.dir_exists_absolute(LEXEME_DIR)


## Alle Einträge einer Kategorie DIREKT aus dem Submodule, ohne ContentRegistry.
##
## Für Datentests ist das der einzig richtige Weg: die Registry liest installierte Packs
## NACH res:// und lässt sie bei gleicher Id gewinnen. Ein liegengebliebener Pack in
## `user://content` verdeckt damit genau die Dateien, die hier committet werden — ein
## Datentest prüfte dann den Pack von gestern statt das, was ausgeliefert werden soll, und
## zwar still (die gefilterte Liste ist einfach leer).
static func entries(category: String) -> Array:
	var out: Array = []
	_collect("res://data/language/%s" % category, out)
	return out


static func _collect(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		_collect("%s/%s" % [path, name], out)
	for name in dir.get_files():
		if not name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("%s/%s" % [path, name]))
		if parsed is Array:
			out.append_array(parsed)
		elif parsed is Dictionary:
			out.append(parsed)
