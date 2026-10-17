class_name TaskResolver
extends RefCounted
## Löst eine task_definition + ein Lexem (× Form/Relation) zur Laufzeit in eine spielbare
## Aufgabe auf; Sprachdaten kommen aus der ContentRegistry.
##
## resolve(definition, source, extra) -> {
##   "learnable_id": String,          # kanonischer, deterministischer Fortschritts-Key
##   "prompt": String,                # was dem Spieler angezeigt wird
##   "accepted_answers": Array,       # gültige Antworten (AnswerEvaluator normalisiert)
##   "task_type": String,
##   "direction": String,
##   "difficulty": int,               # kommt aus der Definition
##   "meaning": String,               # Bedeutung fürs Reveal, leer wenn schon in der Aufgabe
## }
## `extra` trägt die aufgaben-spezifischen Bausteine:
##   opposite/synonym/confusables -> { "target_lexeme_id": String }
##   conjugation                  -> { "form_type": String }
##   example                      -> { "example_key": String }
## Gibt {} zurück, wenn die Aufgabe nicht auflösbar ist (fehlende Daten oder ein
## nicht unterstützter task_type wie fill_gap/sentence).

## Menschlich lesbare Labels für Formen (UI-Sprache Deutsch).
const FORM_LABELS := {
	"base": "Grundform",
	"3sg_present": "3. Person Singular",
	"past_simple": "Simple Past",
	"past_participle": "Past Participle",
	"present_participle": "-ing-Form",
	"la_present_1sg": "1. Person Singular",
	"la_genitive": "Genitiv",
	"la_gender": "Genus",
	"la_infinitive": "Infinitiv",
	"la_perfect": "Perfekt",
	"la_ppp": "PPP",
	"fr_pres_1sg": "Präsens, je",
	"fr_pres_2sg": "Präsens, tu",
	"fr_pres_3sg": "Präsens, il/elle/on",
	"fr_pres_1pl": "Präsens, nous",
	"fr_pres_2pl": "Präsens, vous",
	"fr_pres_3pl": "Präsens, ils/elles",
	"fr_passe_compose": "Passé composé, je",
}

## Genus ist als Buchstabe hinterlegt (m/f/n); getippt werden darf auch das Wort dazu.
const GENDER_ANSWERS := {
	"m": ["m", "maskulin", "maskulinum", "männlich"],
	"f": ["f", "feminin", "femininum", "weiblich"],
	"n": ["n", "neutrum", "sächlich"],
}

## Formen, die das Reveal einer lateinischen Übersetzung als Lexikonform dazuschreibt
## („Gen. amīcī · m“), in dieser Reihenfolge, mit Präfix.
const DICTIONARY_FORMS := {
	"la_present_1sg": "",
	"la_genitive": "Gen.",
	"la_gender": "",
	"la_perfect": "Perf.",
	"la_ppp": "PPP",
}

## Curriculum-Scope des Laufs: Formen außerhalb (ContentRegistry.form_in_scope) stehen
## weder in der Aufgabe noch im Reveal. Leer heißt alle Formen.
var scope: Array = []


func resolve(definition: Dictionary, source: Dictionary, extra: Dictionary = {}) -> Dictionary:
	if source.is_empty():
		return {}
	var task_type := str(definition.get("task_type", ""))
	match task_type:
		"translate":
			return _resolve_translate(definition, source, extra)
		"opposite", "synonym":
			return _resolve_relation(definition, source, extra)
		"confusables":
			return _resolve_confusables(definition, source, extra)
		"conjugation", "tense", "forms":
			return _resolve_conjugation(definition, source, extra)
		"example":
			return _resolve_example(definition, source, extra)
		"fill_gap", "sentence":
			push_warning("TaskResolver: task_type '%s' noch nicht unterstützt (%s)" % [task_type, definition.get("id", "")])
			return {}
		_:
			push_warning("TaskResolver: unbekannter task_type '%s' (%s)" % [task_type, definition.get("id", "")])
			return {}


## Kanonischer Fortschritts-Key aus den Bausteinen (einzige Quelle des Schemas).
##   translate   -> "translate:<direction>:<source>"
##   opposite    -> "opposite:<source>:<target>"     (paar-basiert)
##   synonym     -> "synonym:<source>:<target>"      (paar-basiert)
##   conjugation -> "conjugation:<source>:<form_type>"
##   example     -> "example:<source>:<example_key>"
static func learnable_id(task_type: String, direction: String, source_id: String, extra: Dictionary = {}) -> String:
	match task_type:
		"translate":
			return "translate:%s:%s" % [direction, source_id]
		"opposite", "synonym", "confusables":
			return "%s:%s:%s" % [task_type, source_id, str(extra.get("target_lexeme_id", ""))]
		"conjugation", "tense", "forms":
			return "%s:%s:%s" % [task_type, source_id, str(extra.get("form_type", ""))]
		"example":
			return "example:%s:%s" % [source_id, str(extra.get("example_key", ""))]
		_:
			return "%s:%s:%s" % [task_type, direction, source_id]


## Wandelt einen learnable_id in ein lesbares Label (Umkehrung von learnable_id()).
## Nicht auflösbare ids bleiben roh stehen.
func describe_learnable(id: String) -> String:
	var parts := id.split(":")
	if parts.size() < 3:
		return id
	match parts[0]:
		"translate":
			var lex := _lexeme(parts[2])
			if lex.is_empty():
				return id
			var de := str(lex.get("lemma_de", ""))
			var foreign := Lexeme.foreign(lex)
			return "%s → %s" % [foreign, de] if _asks_foreign(parts[1], lex) else "%s → %s" % [de, foreign]
		"opposite", "synonym", "confusables":
			var src := _lexeme(parts[1])
			var tgt := _lexeme(parts[2])
			if src.is_empty() or tgt.is_empty():
				return id
			var label := str({
				"opposite": "Gegenteil", "synonym": "Synonym", "confusables": "Verwechslung",
			}.get(parts[0], parts[0]))
			return "%s: %s → %s" % [label, Lexeme.foreign(src), Lexeme.foreign(tgt)]
		"conjugation", "tense", "forms":
			var lex := _lexeme(parts[1])
			if lex.is_empty():
				return id
			return "%s (%s)" % [Lexeme.foreign(lex), FORM_LABELS.get(parts[2], parts[2])]
		"example":
			var lex := _lexeme(parts[1])
			if lex.is_empty():
				return id
			return "%s (Buchsatz %s)" % [Lexeme.foreign(lex), parts[2]]
		_:
			return id


func _resolve_translate(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var direction := str(definition.get("direction", Lexeme.to_foreign(Lexeme.language(source))))
	var prompt: String
	var answers: Array = []
	# Alternativen der Aufgabenseite fürs Reveal („go, auch: walk“).
	var prompt_alt: Array = []
	if _asks_foreign(direction, source):
		prompt = Lexeme.foreign(source)
		prompt_alt.append_array(Lexeme.foreign_alt(source))
		answers.append(str(source.get("lemma_de", "")))
		answers.append_array(source.get("lemma_de_alt", []))
	else: # de_to_<sprache> (Standard)
		prompt = str(source.get("lemma_de", ""))
		prompt_alt.append_array(source.get("lemma_de_alt", []))
		answers.append(Lexeme.foreign(source))
		answers.append_array(Lexeme.foreign_alt(source))
		for rel in ContentRegistry.relations_of(str(source.get("id", "")), "synonym"):
			var syn := _lexeme(rel.get("to_lexeme_id", ""))
			if not syn.is_empty():
				answers.append(Lexeme.foreign(syn))
	return _build(definition, source, prompt, answers, extra, _dictionary_form(source), prompt_alt)


## Fragt die Richtung die fremde Seite ab (en_to_de, la_to_de)?
func _asks_foreign(direction: String, lex: Dictionary) -> bool:
	return direction == Lexeme.from_foreign(Lexeme.language(lex))


## Die Lexikonform fürs Reveal (DICTIONARY_FORMS), leer ohne solche Formen.
func _dictionary_form(lex: Dictionary) -> String:
	var bits: Array = []
	for form_type in DICTIONARY_FORMS:
		var forms := ContentRegistry.forms_for(str(lex.get("id", "")), form_type, scope)
		if forms.is_empty():
			continue
		var value := str(forms[0].get("value", ""))
		var prefix := str(DICTIONARY_FORMS[form_type])
		bits.append(value if prefix.is_empty() else "%s %s" % [prefix, value])
	return " · ".join(PackedStringArray(bits))


func _resolve_relation(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var relation_type := str(definition.get("task_type", "")) # "opposite" | "synonym"
	var label := "Gegenteil von" if relation_type == "opposite" else "Synonym für"
	var prompt := "%s %s" % [label, Lexeme.foreign(source)]
	var target := _lexeme(extra.get("target_lexeme_id", ""))
	if target.is_empty():
		push_warning("TaskResolver: kein Ziel-Lexem für %s (%s)" % [relation_type, definition.get("id", "")])
		return {}
	var answers: Array = [Lexeme.foreign(target)]
	answers.append_array(Lexeme.foreign_alt(target))
	return _build(definition, source, prompt, answers, extra, _meaning_of(target))


## Verwechslungspaare (`confused_with`): die deutsche Bedeutung des Quell-Lexems plus
## beide fremdsprachigen Kandidaten, alphabetisch sortiert; Antwort ist das Quell-Lemma.
func _resolve_confusables(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var target := _lexeme(extra.get("target_lexeme_id", ""))
	if target.is_empty():
		push_warning("TaskResolver: kein Partner-Lexem für confusables (%s)" % definition.get("id", ""))
		return {}
	var options := [Lexeme.foreign(source), Lexeme.foreign(target)]
	options.sort()
	var prompt := "%s — %s oder %s?" % [source.get("lemma_de", ""), options[0], options[1]]
	var answers: Array = [Lexeme.foreign(source)]
	answers.append_array(Lexeme.foreign_alt(source))
	return _build(definition, source, prompt, answers, extra)


func _resolve_conjugation(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var form_type := str(extra.get("form_type", ""))
	var forms := ContentRegistry.forms_for(str(source.get("id", "")), form_type, scope)
	if forms.is_empty():
		push_warning("TaskResolver: keine Form '%s' für %s (%s)" % [form_type, source.get("id", ""), definition.get("id", "")])
		return {}
	var label := str(FORM_LABELS.get(form_type, form_type))
	var prompt := "%s → %s" % [Lexeme.foreign(source), label]
	var answers: Array = []
	for form in forms:
		var value := str(form.get("value", ""))
		answers.append_array(GENDER_ANSWERS.get(value, [value]) if form_type == "la_gender" else [value])
	return _build(definition, source, prompt, answers, extra, _meaning_of(source))


## Buchsatz (ADR 0026): der deutsche Satz, getippt wird der ganze fremdsprachige. Der
## Buchsatz steht vorn, damit ihn das Reveal nach der Welle zeigt. Der Zauber deckt nur das
## Stichwort auf (`alt_label`).
func _resolve_example(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var example := Lexeme.example(source, str(extra.get("example_key", "")))
	var lang := Lexeme.language(source)
	var book := str(example.get(lang, ""))
	if example.is_empty() or book.is_empty() or str(example.get("de", "")).is_empty():
		push_warning("TaskResolver: kein Buchsatz '%s' an %s" % [extra.get("example_key", ""), source.get("id", "")])
		return {}
	var answers: Array = [book]
	answers.append_array(example.get("%s_alt" % lang, []))
	var task := _build(definition, source, str(example["de"]), answers, extra, _meaning_of(source),
			[Lexeme.foreign(source)])
	task["alt_label"] = "Wort"
	return task


## Die Bedeutung eines Lexems fürs Reveal („bully = schikanieren“), mit Alternativen.
## Leer, wenn eine der beiden Seiten fehlt.
func _meaning_of(lex: Dictionary) -> String:
	var foreign := Lexeme.foreign(lex)
	var de: Array = [str(lex.get("lemma_de", ""))]
	de.append_array(lex.get("lemma_de_alt", []))
	de = de.filter(func(x): return not str(x).is_empty())
	if foreign.is_empty() or de.is_empty():
		return ""
	return "%s = %s" % [foreign, " / ".join(PackedStringArray(de))]


func _lexeme(lexeme_id: Variant) -> Dictionary:
	return ContentRegistry.get_entry("lexemes", str(lexeme_id))


func _build(definition: Dictionary, source: Dictionary, prompt: String, answers: Array, extra: Dictionary, meaning := "", prompt_alt: Array = []) -> Dictionary:
	var task_type := str(definition.get("task_type", ""))
	var direction := str(definition.get("direction", ""))
	var source_id := str(source.get("id", ""))
	return {
		"learnable_id": learnable_id(task_type, direction, source_id, extra),
		"source_id": source_id,        # Quell-Lexem, für Dedup gleicher Grundwörter auf dem Feld
		"prompt": prompt,
		"accepted_answers": answers,
		"task_type": task_type,
		"direction": direction,
		"difficulty": int(definition.get("difficulty", 1)),
		"lexeme_type": str(source.get("type", "")),   # Wortart fürs Monster-Outline (siehe WordTypePalette)
		"meaning": meaning,            # Bedeutung fürs Reveal; leer, wo die Aufgabe sie schon zeigt
		"prompt_alt": prompt_alt,      # Alternativen zur Aufgabe fürs Reveal; beim Buchsatz das Stichwort
	}
