class_name TaskResolver
extends RefCounted
## Löst eine task_definition (ERM) + ein Lexem in eine spielbare Laufzeit-Aufgabe auf.
##
## Trennt Aufgaben-Regel (task_definitions) von Sprachdaten (lexemes/forms/relations)
## und Darstellung: der WaveRunner bekommt nur noch { prompt, accepted_answers, ... }
## und muss die Sprachdaten nicht kennen. Die konkrete Aufgabe entsteht erst zur
## Laufzeit aus Definition × Lexeme (× Form/Relation) — es gibt keine per-Wort-Aufgaben
## mehr. Sprachdaten werden über die ContentRegistry (Autoload) nachgeschlagen.
##
## resolve(definition, source, extra) -> {
##   "learnable_id": String,          # kanonischer, deterministischer Fortschritts-Key
##   "prompt": String,                # was dem Spieler angezeigt wird
##   "accepted_answers": Array,       # gültige Antworten (AnswerEvaluator normalisiert)
##   "task_type": String,
##   "direction": String,
##   "difficulty": int,               # kommt aus der Definition
## }
## `extra` trägt die aufgaben-spezifischen Bausteine:
##   opposite/synonym/confusables -> { "target_lexeme_id": String }
##   conjugation                  -> { "form_type": String }
## Gibt {} zurück, wenn die Aufgabe nicht auflösbar ist (fehlende Daten oder ein
## noch zurückgestellter task_type wie fill_gap/sentence).

## Menschlich lesbare Labels für Formen (UI-Sprache Deutsch).
const FORM_LABELS := {
	"base": "Grundform",
	"3sg_present": "3. Person Singular",
	"past_simple": "Simple Past",
	"past_participle": "Past Participle",
	"present_participle": "-ing-Form",
}


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
		"conjugation", "tense":
			return _resolve_conjugation(definition, source, extra)
		"fill_gap", "sentence":
			# Satz-/Boss-Feature ist zurückgestellt (siehe docs/ARCHITECTURE.md).
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
func learnable_id(task_type: String, direction: String, source_id: String, extra: Dictionary = {}) -> String:
	match task_type:
		"translate":
			return "translate:%s:%s" % [direction, source_id]
		"opposite", "synonym", "confusables":
			return "%s:%s:%s" % [task_type, source_id, str(extra.get("target_lexeme_id", ""))]
		"conjugation", "tense":
			return "%s:%s:%s" % [task_type, source_id, str(extra.get("form_type", ""))]
		_:
			return "%s:%s:%s" % [task_type, direction, source_id]


## Wandelt einen learnable_id in ein menschenlesbares Label für die Statistik-Liste.
## Kehrt das id-Schema aus learnable_id() um und schlägt die Lemmata über die
## ContentRegistry nach. Nicht auflösbare ids (fehlendes Lexem) fallen auf den rohen
## id-String zurück, damit nie ein Eintrag verschluckt wird.
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
			var en := str(lex.get("lemma_en", ""))
			return "%s → %s" % [en, de] if parts[1] == "en_to_de" else "%s → %s" % [de, en]
		"opposite", "synonym", "confusables":
			var src := _lexeme(parts[1])
			var tgt := _lexeme(parts[2])
			if src.is_empty() or tgt.is_empty():
				return id
			var label := str({
				"opposite": "Gegenteil", "synonym": "Synonym", "confusables": "Verwechslung",
			}.get(parts[0], parts[0]))
			return "%s: %s → %s" % [label, src.get("lemma_en", ""), tgt.get("lemma_en", "")]
		"conjugation", "tense":
			var lex := _lexeme(parts[1])
			if lex.is_empty():
				return id
			return "%s (%s)" % [lex.get("lemma_en", ""), FORM_LABELS.get(parts[2], parts[2])]
		_:
			return id


func _resolve_translate(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var direction := str(definition.get("direction", "de_to_en"))
	var prompt: String
	var answers: Array = []
	if direction == "en_to_de":
		prompt = str(source.get("lemma_en", ""))
		# Primäre + alternative deutsche Übersetzungen (z. B. go -> gehen/laufen).
		answers.append(str(source.get("lemma_de", "")))
		answers.append_array(source.get("lemma_de_alt", []))
	else: # de_to_en (Standard)
		prompt = str(source.get("lemma_de", ""))
		# Primäre + alternative englische Übersetzungen (z. B. gehen -> go/walk).
		answers.append(str(source.get("lemma_en", "")))
		answers.append_array(source.get("lemma_en_alt", []))
		# Synonyme sind ebenfalls gültige englische Antworten.
		for rel in ContentRegistry.relations_of(str(source.get("id", "")), "synonym"):
			var syn := _lexeme(rel.get("to_lexeme_id", ""))
			if not syn.is_empty():
				answers.append(str(syn.get("lemma_en", "")))
	return _build(definition, source, prompt, answers, extra)


func _resolve_relation(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var relation_type := str(definition.get("task_type", "")) # "opposite" | "synonym"
	var label := "Gegenteil von" if relation_type == "opposite" else "Synonym für"
	var prompt := "%s %s" % [label, source.get("lemma_en", "")]
	# Das konkrete Ziel-Lexem der Relation kommt aus der Enumeration (WaveGenerator).
	var target := _lexeme(extra.get("target_lexeme_id", ""))
	if target.is_empty():
		push_warning("TaskResolver: kein Ziel-Lexem für %s (%s)" % [relation_type, definition.get("id", "")])
		return {}
	var answers: Array = [str(target.get("lemma_en", ""))]
	answers.append_array(target.get("lemma_en_alt", []))
	return _build(definition, source, prompt, answers, extra)


## „Confusables": typische Verwechslungspaare (borrow/lend, say/tell …). Der Spieler
## bekommt die deutsche Bedeutung des Quell-Lexems plus BEIDE englischen Kandidaten und
## muss den passenden wählen (Freitext). Baut auf `confused_with`-Relationen auf; das
## konkrete Partner-Lexem kommt aus der Enumeration (WaveGenerator). Antwort = das
## Quell-Lemma; die Optionen sind alphabetisch sortiert, damit die Lösung nicht immer
## an derselben Position steht.
func _resolve_confusables(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var target := _lexeme(extra.get("target_lexeme_id", ""))
	if target.is_empty():
		push_warning("TaskResolver: kein Partner-Lexem für confusables (%s)" % definition.get("id", ""))
		return {}
	var options := [str(source.get("lemma_en", "")), str(target.get("lemma_en", ""))]
	options.sort()
	var prompt := "%s — %s oder %s?" % [source.get("lemma_de", ""), options[0], options[1]]
	var answers: Array = [str(source.get("lemma_en", ""))]
	answers.append_array(source.get("lemma_en_alt", []))
	return _build(definition, source, prompt, answers, extra)


func _resolve_conjugation(definition: Dictionary, source: Dictionary, extra: Dictionary) -> Dictionary:
	var form_type := str(extra.get("form_type", ""))
	var forms := ContentRegistry.forms_for(str(source.get("id", "")), form_type)
	if forms.is_empty():
		push_warning("TaskResolver: keine Form '%s' für %s (%s)" % [form_type, source.get("id", ""), definition.get("id", "")])
		return {}
	var label := str(FORM_LABELS.get(form_type, form_type))
	var prompt := "%s → %s" % [source.get("lemma_en", ""), label]
	var answers: Array = []
	for form in forms:
		answers.append(str(form.get("value", "")))
	return _build(definition, source, prompt, answers, extra)


func _lexeme(lexeme_id: Variant) -> Dictionary:
	return ContentRegistry.get_entry("lexemes", str(lexeme_id))


func _build(definition: Dictionary, source: Dictionary, prompt: String, answers: Array, extra: Dictionary) -> Dictionary:
	var task_type := str(definition.get("task_type", ""))
	var direction := str(definition.get("direction", ""))
	var source_id := str(source.get("id", ""))
	return {
		"learnable_id": learnable_id(task_type, direction, source_id, extra),
		"prompt": prompt,
		"accepted_answers": answers,
		"task_type": task_type,
		"direction": direction,
		"difficulty": int(definition.get("difficulty", 1)),
	}
