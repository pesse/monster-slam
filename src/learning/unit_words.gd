class_name UnitWords
extends RefCounted
## Welche Wörter der Unit ein Schülertext benutzt — für den Wortschatz-Bonus des
## Schreib-Bosses (docs/adr/0023-schreib-boss.md, Nachtrag 2026-10-15). Offline und ohne
## Zustand; das Modell sieht davon nichts (tests/unit_words_test.gd).
##
## Gesucht wird der Kern von `lemma_en` („annoyed (with sb./about sth.)“ → „annoyed“,
## „be attracted to sb.“ → „attracted to“). Das erste Wort darf gebeugt sein (regelmäßige
## Endungen und die Formen aus `lexeme_forms`), die übrigen stehen wie im Lemma. Großzügig
## gezählt: es ist ein Bonus, kein Urteil.

## Wortarten, die jeder Text ohnehin enthält.
const SKIPPED_TYPES := ["preposition", "conjunction"]

## Platzhalter und Satzzeichen, die im Lemma stehen, aber nicht im Text.
static var _strip_re := RegEx.create_from_string("\\(.*?\\)|\\b(?:sb|sth)\\b\\.?|…|\\.\\.\\.")
## Ein Lemma, das mit „be“/„to“ beginnt, wird ohne gesucht („is attracted to“).
static var _lead_re := RegEx.create_from_string("^(?:be|to)\\s+")
static var _short_vowel_re := RegEx.create_from_string("[^aeiou][aeiou][bdgmnprt]$")


## Die Lexeme der Unit einer Schreibaufgabe, ohne die übersprungenen Wortarten.
static func lexemes_for(task: Dictionary) -> Array:
	var key := "%s/%d" % [str(task.get("book", "")), int(task.get("unit", 0))]
	return ContentRegistry.lexemes_scoped([key], []).filter(func(lexeme: Dictionary) -> bool:
		return not (str(lexeme.get("type", "")) in SKIPPED_TYPES))


## Die Formen je Lexem aus `lexeme_forms`: { lexeme_id: [Wert, …] }.
static func forms_for(lexemes: Array) -> Dictionary:
	var out := {}
	for lexeme in lexemes:
		var id := str(lexeme.get("id", ""))
		var values: Array = []
		for form in ContentRegistry.forms_for(id):
			values.append(str(form.get("value", "")))
		out[id] = values
	return out


## Was im Text steht: je Lexem der erste Treffer, in der Reihenfolge des Textes —
## [{ "id", "lemma", "from", "to" }] mit Zeichenpositionen im Originaltext.
static func found(text: String, lexemes: Array, forms: Dictionary = {}) -> Array:
	var words := SummaryCard.split_words(text)
	var out: Array = []
	for lexeme in lexemes:
		var core := core_of(str(lexeme.get("lemma_en", "")))
		if core.is_empty():
			continue
		var heads := variants(core[0])
		for value in forms.get(str(lexeme.get("id", "")), []):
			for token in _tokens(str(value)):
				heads[token] = true
		var at := _find(words, heads, core)
		if at >= 0:
			out.append({"id": str(lexeme.get("id", "")), "lemma": str(lexeme.get("lemma_en", "")),
					"from": int(words[at]["from"]),
					"to": int(words[at + core.size() - 1]["to"])})
	out.sort_custom(func(a, b): return int(a["from"]) < int(b["from"]))
	return out


## Der Kern eines Lemmas als normalisierte Wörter; leer, wenn nichts Suchbares bleibt.
static func core_of(lemma: String) -> PackedStringArray:
	var bare := _strip_re.sub(lemma.to_lower(), " ", true).strip_edges()
	bare = _lead_re.sub(bare, "").strip_edges()
	var tokens := _tokens(bare)
	if tokens.size() > 1 and tokens[tokens.size() - 1] == "do":
		tokens.remove_at(tokens.size() - 1)
	return tokens


## Ein Wort mit seinen regelmäßigen Endungen (Plural, 3. Person, -ed, -ing, Steigerung):
## { Form: true }.
static func variants(token: String) -> Dictionary:
	var out := {}
	for suffix in ["", "s", "es", "ed", "d", "ing", "er", "est"]:
		out[token + suffix] = true
	var stem := token.substr(0, token.length() - 1)
	if token.ends_with("y"):
		for suffix in ["ies", "ied", "ier", "iest"]:
			out[stem + suffix] = true
	if token.ends_with("e"):
		out[stem + "ing"] = true
	if _short_vowel_re.search(token) != null:
		var last := token.substr(token.length() - 1)
		out[token + last + "ed"] = true
		out[token + last + "ing"] = true
	return out


static func _tokens(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for word in SummaryCard.split_words(text):
		out.append(str(word["token"]))
	return out


## Index des ersten Worts, an dem der Kern steht (erstes Wort aus `heads`), sonst -1.
static func _find(words: Array, heads: Dictionary, core: PackedStringArray) -> int:
	for i in words.size() - core.size() + 1:
		if not heads.has(str(words[i]["token"])):
			continue
		var whole := true
		for j in range(1, core.size()):
			if str(words[i + j]["token"]) != core[j]:
				whole = false
				break
		if whole:
			return i
	return -1
