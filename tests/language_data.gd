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
