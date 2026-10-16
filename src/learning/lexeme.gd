class_name Lexeme
extends RefCounted
## Sprache und fremdsprachige Seite eines Lexems oder einer task_definition (ADR 0007).
## Deutsch ist immer die eine Seite, die fremde steht in `lemma_<language>`; ohne Feld
## `language` englisch. Die fremde Seite nur hier lesen, nie `lemma_en` direkt.

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
static func bonus(entry: Dictionary) -> String:
	return str(entry.get("bonus", ""))


## Die Buchsätze eines Lexems (Feld `examples`, ADR 0026): je Satz { key, de,
## <sprache>, <sprache>_alt }. Sätze ohne `key` fallen weg, der Key trägt den Lernstand.
static func examples(entry: Dictionary) -> Array:
	var raw: Variant = entry.get("examples", [])
	if not raw is Array:
		return []
	return (raw as Array).filter(func(e: Variant) -> bool:
			return e is Dictionary and not str((e as Dictionary).get("key", "")).is_empty())


## Der Buchsatz mit `key`, {} ohne.
static func example(entry: Dictionary, key: String) -> Dictionary:
	for e in examples(entry):
		if str(e["key"]) == key:
			return e
	return {}


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


## Die Fremdsprache einer Aufgabe aus ihrer learnable_id, leer wenn unbestimmbar. Eine
## Übersetzung trägt sie in der Richtung; Formen und Relationen erben sie vom Buch ihres
## Lexems, ohne Buch vom Lexem selbst. `lexemes`: Id -> Eintrag (ContentRegistry.lexemes),
## `book_language`: ContentRegistry.book_language.
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
