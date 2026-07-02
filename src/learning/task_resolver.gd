class_name TaskResolver
extends RefCounted
## Löst ein task_template (ERM) in eine spielbare Laufzeit-Aufgabe auf.
##
## Trennt Aufgaben-Definition (task_templates + lexemes/forms/relations) von der
## Darstellung: der WaveRunner bekommt nur noch { prompt, accepted_answers, ... }
## und muss die Sprachdaten nicht kennen. Sprachdaten werden über die ContentRegistry
## (Autoload) nachgeschlagen.
##
## resolve(template) -> {
##   "template_id": String,
##   "prompt": String,               # was dem Spieler angezeigt wird
##   "accepted_answers": Array,       # gültige Antworten (AnswerEvaluator normalisiert)
##   "task_type": String,
##   "direction": String,
##   "difficulty": int,
## }
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


func resolve(template: Dictionary) -> Dictionary:
	var task_type := str(template.get("task_type", ""))
	match task_type:
		"translate":
			return _resolve_translate(template)
		"opposite", "synonym":
			return _resolve_relation(template)
		"conjugation", "tense":
			return _resolve_conjugation(template)
		"fill_gap", "sentence":
			# Satz-/Boss-Feature ist zurückgestellt (siehe docs/ARCHITECTURE.md).
			push_warning("TaskResolver: task_type '%s' noch nicht unterstützt (%s)" % [task_type, template.get("id", "")])
			return {}
		_:
			push_warning("TaskResolver: unbekannter task_type '%s' (%s)" % [task_type, template.get("id", "")])
			return {}


func _resolve_translate(template: Dictionary) -> Dictionary:
	var source := _lexeme(template.get("source_lexeme_id", ""))
	if source.is_empty():
		return {}
	var direction := str(template.get("direction", "de_to_en"))
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
	return _build(template, prompt, answers)


func _resolve_relation(template: Dictionary) -> Dictionary:
	var source := _lexeme(template.get("source_lexeme_id", ""))
	if source.is_empty():
		return {}
	var relation_type := str(template.get("task_type", "")) # "opposite" | "synonym"
	var label := "Gegenteil von" if relation_type == "opposite" else "Synonym für"
	var prompt := "%s %s" % [label, source.get("lemma_en", "")]

	var answers: Array = []
	# Bevorzugt das explizit hinterlegte Ziel-Lexem, sonst über die Relationen.
	var target := _lexeme(template.get("target_lexeme_id", ""))
	if not target.is_empty():
		answers.append(str(target.get("lemma_en", "")))
	else:
		for rel in ContentRegistry.relations_of(str(source.get("id", "")), relation_type):
			var other := _lexeme(rel.get("to_lexeme_id", ""))
			if not other.is_empty():
				answers.append(str(other.get("lemma_en", "")))
	if answers.is_empty():
		push_warning("TaskResolver: keine %s-Antwort für %s" % [relation_type, template.get("id", "")])
		return {}
	return _build(template, prompt, answers)


func _resolve_conjugation(template: Dictionary) -> Dictionary:
	var source := _lexeme(template.get("source_lexeme_id", ""))
	if source.is_empty():
		return {}
	var form_type := str(template.get("form_type", ""))
	var forms := ContentRegistry.forms_for(str(source.get("id", "")), form_type)
	if forms.is_empty():
		push_warning("TaskResolver: keine Form '%s' für %s" % [form_type, template.get("id", "")])
		return {}
	var label := str(FORM_LABELS.get(form_type, form_type))
	var prompt := "%s → %s" % [source.get("lemma_en", ""), label]
	var answers: Array = []
	for form in forms:
		answers.append(str(form.get("value", "")))
	return _build(template, prompt, answers)


func _lexeme(lexeme_id: Variant) -> Dictionary:
	return ContentRegistry.get_entry("lexemes", str(lexeme_id))


func _build(template: Dictionary, prompt: String, answers: Array) -> Dictionary:
	return {
		"template_id": str(template.get("id", "")),
		"prompt": prompt,
		"accepted_answers": answers,
		"task_type": str(template.get("task_type", "")),
		"direction": str(template.get("direction", "")),
		"difficulty": int(template.get("difficulty", 1)),
	}
