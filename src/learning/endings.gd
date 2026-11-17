class_name Endings
extends RefCounted
## Endungen als Lerneinheit (ADR 0032): welche Zellen ein Wort als Träger anbietet, die
## Lexikonform der Aufgabe und die Ids. Die Formen bildet LatinMorphology; was ein Wort
## ausgeschrieben in `lexeme_forms` trägt, gehört zum Wort und nicht zur Endung.

const TASK_TYPE := "ending"

## Je Registry-Stand (ContentRegistry.generation) gerechnet.
static var _generation := -1
## Lexem-Id -> Zellen nach der Regel, ohne die ausgeschriebenen (LatinMorphology).
static var _cells := {}
## Lexem-Id -> { form_type: erste Form }, nur lateinische Nomen und Verben.
static var _forms := {}


## „ending:la:decl.3.gen_pl".
static func learnable_id(language: String, unit: String) -> String:
	return "%s:%s:%s" % [TASK_TYPE, language, unit]


static func is_ending(learnable: String) -> bool:
	return learnable.begins_with(TASK_TYPE + ":")


## Die Lerneinheit einer learnable_id („decl.3.gen_pl"), leer für andere Aufgaben.
static func unit_of(learnable: String) -> String:
	var parts := learnable.split(":")
	return parts[2] if parts.size() == 3 and parts[0] == TASK_TYPE else ""


## Die Zellen, die `lexeme` in `table` trägt, in `scope` eingeführt: Perfektzellen erst mit
## eingeführtem Perfekt (ADR 0011). Jede ist { cell, form, unit }.
static func carrier_cells(lexeme: Dictionary, table: String, scope: Array) -> Array:
	_ensure()
	var id := str(lexeme.get("id", ""))
	var out: Array = []
	for entry in _cells.get(id, []):
		if not str(entry["cell"]).begins_with(table + "."):
			continue
		if table == "perf" and not ContentRegistry.form_in_scope(_forms[id]["la_perfect"], scope):
			continue
		out.append(entry)
	return out


## Die Form einer Zelle an `lexeme`, leer, wenn es sie nach der Regel nicht trägt.
static func form_of(lexeme: Dictionary, cell: String) -> String:
	_ensure()
	for entry in _cells.get(str(lexeme.get("id", "")), []):
		if entry["cell"] == cell:
			return str(entry["form"])
	return ""


## Die Lexikonform vor dem Pfeil: „rēx, rēgis m", „mittere, mittō", beim Perfekt mit
## Perfekt. Nur Formen, die in `scope` eingeführt sind.
static func head(lexeme: Dictionary, table: String, scope: Array) -> String:
	_ensure()
	var forms: Dictionary = _forms.get(str(lexeme.get("id", "")), {})
	var shown := func(form_type: String) -> String:
		var form: Dictionary = forms.get(form_type, {})
		if form.is_empty() or not ContentRegistry.form_in_scope(form, scope):
			return ""
		return str(form.get("value", ""))
	var bits: Array = [Lexeme.foreign(lexeme)]
	if str(lexeme.get("type", "")) == "noun":
		var genitive: String = shown.call("la_genitive")
		if not genitive.is_empty():
			bits.append(genitive)
		var text := ", ".join(PackedStringArray(bits))
		var gender: String = shown.call("la_gender")
		return text if gender.is_empty() else "%s %s" % [text, gender]
	for form_type in ["la_present_1sg", "la_perfect"]:
		if form_type == "la_perfect" and table != "perf":
			continue
		var value: String = shown.call(form_type)
		if not value.is_empty():
			bits.append(value)
	return ", ".join(PackedStringArray(bits))


static func _ensure() -> void:
	if _generation == ContentRegistry.generation:
		return
	_generation = ContentRegistry.generation
	_cells.clear()
	_forms.clear()
	var written := {}   # Lexem-Id -> {form_type: true}
	for id in ContentRegistry.lexemes:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		if Lexeme.language(entry) == "la" and str(entry.get("type", "")) in ["noun", "verb"]:
			_forms[id] = {}
			written[id] = {}
	for form in ContentRegistry.lexeme_forms.values():
		var lexeme_id := str(form.get("lexeme_id", ""))
		if not _forms.has(lexeme_id):
			continue
		var form_type := str(form.get("form_type", ""))
		written[lexeme_id][form_type] = true
		if not _forms[lexeme_id].has(form_type):
			_forms[lexeme_id][form_type] = form
	for id in _forms:
		var entry: Dictionary = ContentRegistry.lexemes[id]
		var value := func(form_type: String) -> String:
			return str((_forms[id] as Dictionary).get(form_type, {}).get("value", ""))
		var cells: Array
		if str(entry.get("type", "")) == "noun":
			cells = LatinMorphology.noun_cells(Lexeme.foreign(entry), value.call("la_genitive"),
					value.call("la_gender"))
		else:
			cells = LatinMorphology.verb_cells(Lexeme.foreign(entry), value.call("la_present_1sg"),
					value.call("la_perfect"))
		_cells[id] = cells.filter(func(c):
			return not written[id].has(LatinMorphology.form_type_of(str(c["cell"]))))
