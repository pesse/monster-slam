class_name Lexeme
extends RefCounted
## Sprache und fremdsprachige Seite eines Lexems (Issue #31).
##
## Deutsch ist immer die eine Seite. Die Fremdsprache steht in `lemma_<language>` und
## `lemma_<language>_alt`, die Sprache im Feld `language`. Fehlt es, ist das Lexem englisch
## — so ist der ganze Bestand vor Latein geschrieben, und Felder der Pack-Formate werden
## nicht umbenannt. Wer die fremde Seite braucht, fragt hier und liest `lemma_en` nie direkt.
##
## Dieselbe Regel gilt für task_definitions: eine Definition ohne `language` ist englisch,
## und der WaveGenerator paart sie nur mit Lexemen ihrer Sprache.
##
## Die Übersetzungsrichtungen tragen die Sprache im Namen (`de_to_la`, `la_to_de`). Aus
## einer Richtung allein lässt sich die Sprache also zurückrechnen — die Meisterung zählt
## über Record-Ids und kommt so ohne Katalog aus (PlayerProgress.mastered_lexemes_in).

const DEFAULT_LANGUAGE := "en"
## Anzeigenamen der Sprachen (UI-Sprache Deutsch).
const LANGUAGE_NAMES := {"en": "Englisch", "fr": "Französisch", "la": "Latein"}


## Die Sprache eines Lexems oder einer task_definition, "en" ohne Feld.
static func language(entry: Dictionary) -> String:
	var lang := str(entry.get("language", ""))
	return DEFAULT_LANGUAGE if lang.is_empty() else lang


## Das fremdsprachige Lemma, leer wenn es fehlt.
static func foreign(entry: Dictionary) -> String:
	return str(entry.get("lemma_%s" % language(entry), ""))


## Die fremdsprachigen Alternativen.
static func foreign_alt(entry: Dictionary) -> Array:
	return entry.get("lemma_%s_alt" % language(entry), [])


## Das Thema des Wort-Bonus, in dem das Lexem steht (Feld `bonus`, ADR 0013), leer ohne.
## Ein solches Wort gehört nicht zu den Wörtern seiner Unit, sondern zu ihrem Bonus.
static func bonus(entry: Dictionary) -> String:
	return str(entry.get("bonus", ""))


## „de_to_la": Deutsch gefragt, Fremdsprache getippt.
static func to_foreign(lang: String) -> String:
	return "de_to_%s" % lang


## „la_to_de": Fremdsprache gefragt, Deutsch getippt.
static func from_foreign(lang: String) -> String:
	return "%s_to_de" % lang


## Die beiden Richtungen, in denen ein Wort sitzen muss, damit es gemeistert ist.
static func mastery_directions(lang: String) -> Array:
	return [to_foreign(lang), from_foreign(lang)]


## Die Fremdsprache einer Übersetzungsrichtung („de_to_la" und „la_to_de" -> „la"), leer
## für alles andere (auch „en_to_en" der Relationsaufgaben).
static func language_of_direction(direction: String) -> String:
	var parts := direction.split("_to_")
	if parts.size() != 2:
		return ""
	if parts[0] == "de" and parts[1] != "de":
		return parts[1]
	if parts[1] == "de" and parts[0] != "de":
		return parts[0]
	return ""


## Die Fremdsprache einer Aufgabe aus ihrer learnable_id (TaskResolver.learnable_id), leer
## wenn sie sich nicht bestimmen lässt (Lexem fehlt im Katalog).
##
## Eine Übersetzung trägt die Sprache in der Richtung und braucht keinen Katalog; Formen und
## Relationen („conjugation:<lexem>:<form>", „opposite:<lexem>:<ziel>") erben sie vom Buch
## ihres Lexems — ein Buch hat genau eine Sprache. Gerechnet und nicht im Record
## gespeichert. `lexemes` ist ContentRegistry.lexemes (Id -> Eintrag), `book_language`
## ContentRegistry.book_language; ein Lexem ohne Buch fällt auf sein eigenes Feld zurück.
static func language_of_learnable(id: String, lexemes: Dictionary, book_language: Callable) -> String:
	var parts := id.split(":")
	if parts.size() != 3:
		return ""
	var lexeme_id := parts[1]
	if parts[0] not in ["opposite", "synonym", "confusables", "conjugation", "tense", "forms"]:
		var lang := language_of_direction(parts[1])
		if not lang.is_empty():
			return lang
		lexeme_id = parts[2]
	var entry: Variant = lexemes.get(lexeme_id)
	if not entry is Dictionary:
		return ""
	var book := str(entry.get("book", ""))
	return language(entry) if book.is_empty() else str(book_language.call(book))


## „de_to_la" -> „de → la" (mit `separator`), unbekanntes unverändert.
static func direction_label(direction: String, separator := " → ") -> String:
	var parts := direction.split("_to_")
	if parts.size() != 2:
		return direction
	return "%s%s%s" % [parts[0], separator, parts[1]]


## „Latein", oder der Code selbst für eine Sprache ohne Namen.
static func language_name(lang: String) -> String:
	return str(LANGUAGE_NAMES.get(lang, lang))
