extends Node
## Central, data-driven content registry (autoload). Loads every .json under
## <root>/<category>/ (recursively) from three roots in order of precedence: DATA_ROOT,
## LANGUAGE_ROOT, then installed packs. Each file holds one object or an array of objects,
## each with a unique string "id". See docs/ADDING_CONTENT.md.

const DATA_ROOT := "res://data"

## Sprachdaten aus dem privaten Submodule; fehlt es, startet das Spiel ohne Vokabeln.
const LANGUAGE_ROOT := "res://data/language"

## Installierte Content-Packs (user://content/<pack-id>/<kategorie>/…), gelesen nach den
## res://-Roots: bei gleicher `id` gewinnt der Pack (ADR 0001).
const USER_CONTENT_ROOT := "user://content"

## In so viele Teile zerfällt eine Unit (etwa eine Woche Unterricht je Teil).
const PART_COUNT := 4

## Die Kategorien, die aus LANGUAGE_ROOT statt aus DATA_ROOT gelesen werden.
const LANGUAGE_CATEGORIES: Array[String] = [
	"lexemes",
	"lexeme_forms",
	"lexeme_relations",
	"sentences",
	"sentence_lexemes",
	"writing",
]

## Per-category catalogs (id -> entry), filled by reload(); model in docs/ARCHITECTURE.md,
## writing in ADR 0023.
var lexemes: Dictionary = {}
var lexeme_forms: Dictionary = {}
var lexeme_relations: Dictionary = {}
var sentences: Dictionary = {}
var sentence_lexemes: Dictionary = {}
## Schreibaufgaben für den Schreib-Boss (docs/adr/0023-schreib-boss.md): je Aufgabe eine
## Vorlage mit Kernpunkten, Ablage wie die Sätze je Unit (`writing/en_<band>_unit<n>.json`).
var writing: Dictionary = {}
var task_definitions: Dictionary = {}
var monster_task_rules: Dictionary = {}
var monsters: Dictionary = {}
var bosses: Dictionary = {}
## Zauber: Verbrauchsgegenstände, gekauft mit Gold (ADR 0014).
var spells: Dictionary = {}
## Skills: Knoten der Fähigkeitsbäume, gekauft mit Skillpunkten (ADR 0003).
var skills: Dictionary = {}
var waves: Dictionary = {}

## category name -> the Dictionary above (same reference, filled in place).
var _by_category: Dictionary = {}

var _source_files: Dictionary = {}

## "<category>|<id>" -> Root, aus dem der Eintrag stammt. Eine doppelte id ist nur
## innerhalb desselben Roots ein Fehler.
var _origins: Dictionary = {}

## Lexem-Id -> Teil (1…PART_COUNT oder Feld `part`) innerhalb seiner Unit.
var _parts: Dictionary = {}

## Lexem-Id -> learnable_ids, die für seine Meisterung sitzen müssen; nur `irregular: true`.
var _form_requirements: Dictionary = {}

## Die Bonus-Level (ADR 0012, 0013): Scope-Schlüssel -> { key, book, unit, part, topic,
## form_type, lexeme_ids, task_ids }.
var _bonuses: Dictionary = {}
## Form-Id -> Schlüssel ihres Bonus, nur für Formen, die in einem Bonus stehen.
var _bonus_of_form: Dictionary = {}

## Präfix eines Bonus-Scope-Schlüssels „bonus:<book>/<unit>/<part>/<topic>“ (Thema: die
## Formart, beim Wort-Bonus das Feld `bonus`, Teil 0). Hält ihn aus Buch-/Unit-Vergleichen.
const BONUS_PREFIX := "bonus:"


func _ready() -> void:
	_by_category = {
		"lexemes": lexemes,
		"lexeme_forms": lexeme_forms,
		"lexeme_relations": lexeme_relations,
		"sentences": sentences,
		"sentence_lexemes": sentence_lexemes,
		"writing": writing,
		"task_definitions": task_definitions,
		"monster_task_rules": monster_task_rules,
		"monsters": monsters,
		"bosses": bosses,
		"spells": spells,
		"skills": skills,
		"waves": waves,
	}
	reload()


## Rescans the whole data tree; safe at runtime (e.g. after a pack installation).
func reload() -> void:
	_source_files.clear()
	_origins.clear()
	for category in _by_category:
		(_by_category[category] as Dictionary).clear()

	for root in _roots():
		for category in root["categories"]:
			var path := "%s/%s" % [root["path"], category]
			if not DirAccess.dir_exists_absolute(path):
				if root["required"]:
					push_warning("ContentRegistry: missing data folder '%s'" % path)
				continue
			_scan_dir(path, _by_category[category], category, root["path"])

	if lexemes.is_empty():
		push_warning(
			"ContentRegistry: keine Sprachdaten. Im Spiel einen Vokabel-Pack installieren; "
			+ "in der Entwicklung das Submodule '%s' auschecken " % LANGUAGE_ROOT
			+ "('git submodule update --init')."
		)

	_index_parts()
	_index_bonuses()
	_index_form_requirements()
	_apply_flags()


## Teilt jede Unit nach Bestandsreihenfolge in PART_COUNT Teile, Rest nach vorn; mit Feld
## `part` gilt das Feld (docs/ARCHITECTURE.md).
func _index_parts() -> void:
	_parts.clear()
	var by_unit: Dictionary = {}   # "<book>/<unit>" -> Array[id], in Bestandsreihenfolge
	for id in lexemes:
		var entry: Dictionary = lexemes[id]
		var book := str(entry.get("book", ""))
		if book.is_empty() or not entry.has("unit") or not Lexeme.bonus(entry).is_empty():
			continue
		var key := "%s/%d" % [book, int(entry["unit"])]
		if not by_unit.has(key):
			by_unit[key] = []
		(by_unit[key] as Array).append(id)

	for key in by_unit:
		var ids: Array = by_unit[key]
		if ids.any(func(id): return lexemes[id].has("part")):
			for id in ids:
				var explicit := int(lexemes[id].get("part", 0))
				if explicit > 0:
					_parts[id] = explicit
			continue
		var parts := mini(PART_COUNT, ids.size())
		if parts <= 0:
			continue
		var base := ids.size() / parts
		var rest := ids.size() % parts
		var index := 0
		for part in range(1, parts + 1):
			var size := base + (1 if part <= rest else 0)
			for _i in range(size):
				_parts[ids[index]] = part
				index += 1


## Sammelt je unregelmäßigem Verb die learnable_ids, die für seine Meisterung sitzen
## müssen: beide Richtungen und seine Formaufgaben (ADR 0009), ohne Bonus-Formen (ADR 0012).
func _index_form_requirements() -> void:
	_form_requirements.clear()
	var form_types: Dictionary = {}   # lexeme_id -> {form_type: true}, nur unregelmäßige
	for id in lexemes:
		if bool(lexemes[id].get("irregular", false)):
			form_types[id] = {}
	if form_types.is_empty():
		return
	for entry in lexeme_forms.values():
		var lexeme_id := str(entry.get("lexeme_id", ""))
		if not form_types.has(lexeme_id):
			continue
		if _bonus_of_form.has(str(entry.get("id", ""))):
			continue
		form_types[lexeme_id][str(entry.get("form_type", ""))] = true
	var resolver := TaskResolver.new()
	for lexeme_id in form_types:
		var lexeme: Dictionary = lexemes[lexeme_id]
		var ids := _form_task_ids(resolver, lexeme, form_types[lexeme_id])
		if ids.is_empty():
			continue
		for direction in Lexeme.mastery_directions(Lexeme.language(lexeme)):
			ids.push_front(resolver.learnable_id("translate", direction, lexeme_id))
		_form_requirements[lexeme_id] = ids


## Die learnable_ids der Formaufgaben zu `lexeme` für `form_types` (form_type -> true).
## Muss dieselbe Auswahl treffen wie WaveGenerator._instances.
func _form_task_ids(resolver: TaskResolver, lexeme: Dictionary, form_types: Dictionary) -> Array:
	var ids: Array = []
	var lexeme_id := str(lexeme.get("id", ""))
	for definition in task_definitions.values():
		var form_type := str(definition.get("requires_form", ""))
		if form_type.is_empty() or not form_types.has(form_type):
			continue
		var task_type := str(definition.get("task_type", ""))
		if Lexeme.language(definition) != Lexeme.language(lexeme) \
				or task_type in lexeme.get("excluded_task_types", []):
			continue
		var allowed: Array = definition.get("allowed_types", ["*"])
		if not (allowed.is_empty() or "*" in allowed or str(lexeme.get("type", "")) in allowed):
			continue
		ids.append(resolver.learnable_id(task_type, str(definition.get("direction", "")),
				lexeme_id, {"form_type": form_type}))
	return ids


## Sammelt die Bonus-Level (ADR 0012): eine Form, deren Lektion (`unit`/`part` an der Form,
## ADR 0011) hinter der ihres Lexems liegt, steht im Bonus ihrer Lektion und Formart.
func _index_bonuses() -> void:
	_bonuses.clear()
	_bonus_of_form.clear()
	var resolver := TaskResolver.new()
	for form_id in lexeme_forms:
		var form: Dictionary = lexeme_forms[form_id]
		if not form.has("unit"):
			continue
		var lexeme_id := str(form.get("lexeme_id", ""))
		var lexeme: Dictionary = lexemes.get(lexeme_id, {})
		var book := str(lexeme.get("book", ""))
		if book.is_empty() or not lexeme.has("unit"):
			continue
		var unit := int(form["unit"])
		var part := int(form.get("part", 0))
		var own_unit := int(lexeme["unit"])
		if unit < own_unit or (unit == own_unit and part <= part_of(lexeme_id)):
			continue
		var form_type := str(form.get("form_type", ""))
		var task_ids := _form_task_ids(resolver, lexeme, {form_type: true})
		if task_ids.is_empty():
			continue
		var key := bonus_key(book, unit, part, form_type)
		if not _bonuses.has(key):
			_bonuses[key] = {"key": key, "book": book, "unit": unit, "part": part,
					"topic": form_type, "form_type": form_type, "lexeme_ids": [], "task_ids": []}
		var bonus: Dictionary = _bonuses[key]
		if not lexeme_id in bonus["lexeme_ids"]:
			(bonus["lexeme_ids"] as Array).append(lexeme_id)
		for id in task_ids:
			if not id in bonus["task_ids"]:
				(bonus["task_ids"] as Array).append(id)
		_bonus_of_form[str(form_id)] = key
	_index_word_bonuses(resolver)


## Sammelt die Wort-Boni (ADR 0013): je Unit und Thema, Teil 0. Ihre Aufgaben sind die der
## Meisterung, dieselbe Regel wie _index_form_requirements.
func _index_word_bonuses(resolver: TaskResolver) -> void:
	for lexeme_id in lexemes:
		var lexeme: Dictionary = lexemes[lexeme_id]
		var book := str(lexeme.get("book", ""))
		var keys := word_bonus_keys(lexeme)
		if keys.is_empty() or "translate" in lexeme.get("excluded_task_types", []):
			continue
		var task_ids: Array = []
		for direction in Lexeme.mastery_directions(Lexeme.language(lexeme)):
			task_ids.append(resolver.learnable_id("translate", direction, lexeme_id))
		if bool(lexeme.get("irregular", false)):
			var form_types := {}
			for form in lexeme_forms.values():
				if str(form.get("lexeme_id", "")) == lexeme_id:
					form_types[str(form.get("form_type", ""))] = true
			task_ids.append_array(_form_task_ids(resolver, lexeme, form_types))
		for key in keys:
			if not _bonuses.has(key):
				var bits := str(key).trim_prefix(BONUS_PREFIX).split("/")
				_bonuses[key] = {"key": key, "book": book, "unit": int(bits[1]), "part": 0,
						"topic": bits[3], "form_type": "", "lexeme_ids": [], "task_ids": []}
			var bonus: Dictionary = _bonuses[key]
			(bonus["lexeme_ids"] as Array).append(lexeme_id)
			(bonus["task_ids"] as Array).append_array(task_ids)


## Der Scope-Schlüssel eines Bonus; `topic` ist die Formart oder das Thema des Wort-Bonus.
static func bonus_key(book: String, unit: int, part: int, topic: String) -> String:
	return "%s%s/%d/%d/%s" % [BONUS_PREFIX, book, unit, part, topic]


## Der Scope-Schlüssel des Wort-Bonus, in dem das Lexem steht, leer ohne Feld `bonus`.
static func word_bonus_key(lexeme: Dictionary) -> String:
	var topic := Lexeme.bonus(lexeme)
	if topic.is_empty():
		return ""
	return bonus_key(str(lexeme.get("book", "")), int(lexeme.get("unit", 0)), 0, topic)


## Die Wort-Boni, in denen das Lexem mitspielt: sein eigener (`bonus`) und die unter
## `also_bonus` ([{ unit, bonus }], derselbe Band).
static func word_bonus_keys(lexeme: Dictionary) -> Array:
	var book := str(lexeme.get("book", ""))
	if book.is_empty() or not lexeme.has("unit"):
		return []
	var out: Array = []
	var own := word_bonus_key(lexeme)
	if not own.is_empty():
		out.append(own)
	var also: Variant = lexeme.get("also_bonus", [])
	for ref in (also if also is Array else []):
		if ref is Dictionary and not str(ref.get("bonus", "")).is_empty():
			var key := bonus_key(book, int(ref.get("unit", 0)), 0, str(ref["bonus"]))
			if not key in out:
				out.append(key)
	return out


## Spielt das Lexem in `scope` über einen Wort-Bonus mit (ADR 0013)?
func in_word_bonus(lexeme: Dictionary, scope: Array) -> bool:
	return word_bonus_keys(lexeme).any(func(key): return bonus_in_scope(str(key), scope))


## Die Boni einer Unit, nach Lektion und Thema: [{ key, book, unit, part, topic, form_type,
## lexeme_ids, task_ids }]. Wort-Boni (Teil 0) stehen vorn.
func bonuses_of(book: String, unit: int) -> Array:
	var out: Array = _bonuses.values().filter(func(b):
			return str(b["book"]) == book and int(b["unit"]) == unit)
	out.sort_custom(func(a, b):
			if int(a["part"]) != int(b["part"]):
				return int(a["part"]) < int(b["part"])
			return str(a["topic"]) < str(b["topic"]))
	return out


func bonuses() -> Dictionary:
	return _bonuses


## Der Bonus, in dem die Form steht, oder "".
func bonus_of_form(form: Dictionary) -> String:
	return str(_bonus_of_form.get(str(form.get("id", "")), ""))


## Spielt `scope` den Bonus `key` mit? Wenn er selbst gewählt ist oder der Scope seine
## ganze Unit oder sein Buch umfasst (ADR 0012); ein Teil bringt keinen Bonus mit.
func bonus_in_scope(key: String, scope: Array) -> bool:
	if key in scope:
		return true
	var bonus: Dictionary = _bonuses.get(key, {})
	if bonus.is_empty():
		return false
	return str(bonus["book"]) in scope or "%s/%d" % [bonus["book"], int(bonus["unit"])] in scope


## Kommt die Form in `scope` als Aufgabe dran? Wie form_in_scope, eine Bonus-Form aber nur,
## wo ihr Bonus mitspielt.
func form_task_in_scope(form: Dictionary, scope: Array) -> bool:
	if not form_in_scope(form, scope):
		return false
	var bonus := bonus_of_form(form)
	return bonus.is_empty() or scope.is_empty() or bonus_in_scope(bonus, scope)


## Die Units („<book>/<unit>“) der Boni, die `scope` ausdrücklich nennt.
func bonus_units(scope: Array) -> Array:
	var out: Array = []
	for key in scope:
		var bonus: Dictionary = _bonuses.get(str(key), {})
		if bonus.is_empty():
			continue
		var unit := "%s/%d" % [bonus["book"], int(bonus["unit"])]
		if not unit in out:
			out.append(unit)
	return out


## Lexem-Id -> learnable_ids, die ein unregelmäßiges Verb für seine Meisterung braucht.
func form_requirements() -> Dictionary:
	return _form_requirements


## Die Roots in Vorrangfolge: ein späterer überschreibt bei gleicher `id` einen früheren.
func _roots() -> Array:
	var game_categories: Array[String] = []
	for category in _by_category:
		if category not in LANGUAGE_CATEGORIES:
			game_categories.append(category)

	var roots: Array = [
		{"path": DATA_ROOT, "categories": game_categories, "required": true},
	]
	if DirAccess.dir_exists_absolute(LANGUAGE_ROOT):
		roots.append({"path": LANGUAGE_ROOT, "categories": LANGUAGE_CATEGORIES, "required": false})
	for pack_path in _pack_roots():
		roots.append({"path": pack_path, "categories": _by_category.keys(), "required": false})
	return roots


## Verzeichnisse installierter Packs, alphabetisch, ohne Punkt-Verzeichnisse.
func _pack_roots() -> Array:
	var dir := DirAccess.open(USER_CONTENT_ROOT)
	if dir == null:
		return []
	var names: Array = []
	for name in dir.get_directories():
		if not name.begins_with("."):
			names.append(name)
	names.sort()
	var out: Array = []
	for name in names:
		out.append("%s/%s" % [USER_CONTENT_ROOT, name])
	return out


## Alle bekannten Kategorien; stehen an vier Stellen (CONVENTIONS „Packs“).
func categories() -> Array:
	return _by_category.keys()


## Returns all entries of a category as an Array of Dictionaries.
func all(category: String) -> Array:
	return _by_category.get(category, {}).values()


## Returns a single entry by id, or {} if not found.
func get_entry(category: String, id: String) -> Dictionary:
	return _by_category.get(category, {}).get(id, {})


## Returns lexeme entries whose "tags" intersect `tags`; empty `tags` -> all lexemes.
func lexemes_by_tags(tags: Array) -> Array:
	if tags.is_empty():
		return lexemes.values()
	var result: Array = []
	for entry in lexemes.values():
		for tag in entry.get("tags", []):
			if tag in tags:
				result.append(entry)
				break
	return result


## Alle distinkten Bücher (Lexem-Feld "book"), alphabetisch sortiert.
func all_books() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		var book := str(entry.get("book", ""))
		if not book.is_empty():
			seen[book] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## Anzeigename eines Buchs: der Titel aus BookNaming, sonst „access2“ -> „Access 2“.
func book_label(book: String) -> String:
	var titled := BookNaming.title(book)
	if not titled.is_empty():
		return titled
	var i := book.length()
	while i > 0 and book[i - 1] >= "0" and book[i - 1] <= "9":
		i -= 1
	var name := book.substr(0, i).capitalize()
	var num := book.substr(i)
	return name if num.is_empty() else "%s %s" % [name, num]


## Die Sprache eines Buchs (die seines ersten Lexems), "" für ein unbekanntes Buch.
func book_language(book: String) -> String:
	for entry in lexemes.values():
		if str(entry.get("book", "")) == book:
			return Lexeme.language(entry)
	return ""


func units_for(book: String) -> Array:
	var seen := {}
	for entry in lexemes.values():
		if str(entry.get("book", "")) == book and entry.has("unit"):
			seen[int(entry["unit"])] = true
	var result: Array = seen.keys()
	result.sort()
	return result


## Die Schreibaufgaben einer Unit für eine Textart (ADR 0023), sortiert nach Id — damit die
## Reihenfolge nicht davon abhängt, ob die Aufgabe aus dem Submodule oder aus einem Pack
## kam. Leer, wenn die Unit keine hat; der Schreib-Boss bleibt dann unsichtbar.
func writing_tasks(book: String, unit: int, kind := "summary") -> Array:
	var result: Array = []
	for entry in writing.values():
		if str(entry.get("book", "")) == book and int(entry.get("unit", -1)) == unit \
				and str(entry.get("kind", "")) == kind:
			result.append(entry)
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result


## Curriculum-Scope-Schlüssel eines Lexems: ["<book>", "<book>/<unit>", "<book>/<unit>/<teil>"]
## plus seine Wort-Boni. Leer, wenn kein "book".
func _scope_keys(entry: Dictionary) -> Array:
	var book := str(entry.get("book", ""))
	if book.is_empty():
		return []
	if not entry.has("unit"):
		return [book]
	# Ein Wort eines Wort-Bonus steht nur in seinen Boni (ADR 0013).
	if not word_bonus_key(entry).is_empty():
		return word_bonus_keys(entry)
	var keys := [book, "%s/%d" % [book, int(entry["unit"])]]
	keys.append_array(word_bonus_keys(entry))
	var part: int = _parts.get(str(entry.get("id", "")), 0)
	if part > 0:
		keys.append("%s/%d/%d" % [book, int(entry["unit"]), part])
	return keys


## Der engste Scope-Schlüssel eines Lexems: sein Wort-Bonus, sein Teil oder seine Unit.
func narrowest_scope(entry: Dictionary) -> String:
	var bonus := word_bonus_key(entry)
	if not bonus.is_empty():
		return bonus
	var keys := _scope_keys(entry)
	if keys.is_empty():
		return ""
	var part: int = _parts.get(str(entry.get("id", "")), 0)
	if part > 0:
		return str(keys[-1])
	return str(keys[1]) if keys.size() > 1 else str(keys[0])


## Der Teil eines Lexems innerhalb seiner Unit, 0 ohne Teil.
func part_of(lexeme_id: String) -> int:
	return int(_parts.get(lexeme_id, 0))


## Die höchste Teilnummer einer Unit: PART_COUNT oder weniger bei wenigen Lexemen, bei
## Feld `part` die höchste Lektion. Davor darf ein Teil leer sein (part_has_words).
func parts_for(book: String, unit: int) -> int:
	var count := 0
	var highest := 0
	for id in lexemes:
		var entry: Dictionary = lexemes[id]
		if str(entry.get("book", "")) == book and entry.has("unit") and int(entry["unit"]) == unit \
				and Lexeme.bonus(entry).is_empty():
			count += 1
			if entry.has("part"):
				highest = maxi(highest, part_of(str(id)))
	return highest if highest > 0 else mini(PART_COUNT, count)


## Hat Teil `part` der Unit mindestens ein Lexem?
func part_has_words(book: String, unit: int, part: int) -> bool:
	for id in _parts:
		if int(_parts[id]) != part:
			continue
		var entry: Dictionary = lexemes.get(id, {})
		if str(entry.get("book", "")) == book and int(entry.get("unit", -1)) == unit:
			return true
	return false


## Lexeme im Schnitt von Curriculum-Scope und Themen-Tags (Tags untereinander ODER);
## leer heißt jeweils keine Einschränkung.
func lexemes_scoped(scope: Array, tags: Array) -> Array:
	var base := lexemes_by_tags(tags)
	if scope.is_empty():
		return base
	var result: Array = []
	for entry in base:
		for key in _scope_keys(entry):
			if key in scope:
				result.append(entry)
				break
	return result


## Die Lexeme für den Aufgabenpool eines Kampfs: die des Scopes plus die der mitspielenden
## Boni (ADR 0012, 0013). Festungsstufe, Statistik und Sätze zählen über lexemes_scoped.
func lexemes_for_run(scope: Array, tags: Array) -> Array:
	var result := lexemes_scoped(scope, tags)
	if scope.is_empty():
		return result
	var seen: Dictionary = {}
	for entry in result:
		seen[str(entry.get("id", ""))] = true
	var tagged: Dictionary = {}
	for entry in lexemes_by_tags(tags):
		tagged[str(entry.get("id", ""))] = true
	for key in _bonuses:
		if not bonus_in_scope(key, scope):
			continue
		for lexeme_id in _bonuses[key]["lexeme_ids"]:
			if seen.has(lexeme_id) or not tagged.has(lexeme_id):
				continue
			seen[lexeme_id] = true
			result.append(lexemes[lexeme_id])
	return result


## Gilt die Form in `scope` als eingeführt (ADR 0011)? Ab ihrer Lektion in jeder späteren;
## eine Unit zählt bis zu ihrem Ende, Buch und leerer Scope zählen alles, ein Bonus wie
## seine Lektion. Ob sie als Aufgabe kommt, entscheidet form_task_in_scope.
func form_in_scope(form: Dictionary, scope: Array) -> bool:
	if scope.is_empty():
		return true
	var lesson := _form_lesson(form)
	if lesson.is_empty():
		return false
	for each in scope:
		var key := str(each)
		var bonus: Dictionary = _bonuses.get(key, {})
		if not bonus.is_empty():
			key = "%s/%d/%d" % [bonus["book"], int(bonus["unit"]), int(bonus["part"])]
		var bits := key.split("/")
		if bits[0] != lesson["book"]:
			continue
		if bits.size() == 1:
			return true
		var unit := int(bits[1])
		if int(lesson["unit"]) < unit:
			return true
		if int(lesson["unit"]) == unit and (bits.size() == 2 \
				or int(lesson["part"]) <= int(bits[2])):
			return true
	return false


## Die Lektion einer Form: { book, unit, part } aus `unit`/`part` an der Form, sonst die
## ihres Lexems (part 0 ohne Teil). Leer, wenn das Lexem zu keinem Buch gehört.
func _form_lesson(form: Dictionary) -> Dictionary:
	var lexeme_id := str(form.get("lexeme_id", ""))
	var lexeme: Dictionary = lexemes.get(lexeme_id, {})
	var book := str(lexeme.get("book", ""))
	if book.is_empty() or not (form.has("unit") or lexeme.has("unit")):
		return {}
	if form.has("unit"):
		return {"book": book, "unit": int(form["unit"]), "part": int(form.get("part", 0))}
	return {"book": book, "unit": int(lexeme["unit"]), "part": part_of(lexeme_id)}


func all_lexeme_tags() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		for tag in entry.get("tags", []):
			seen[str(tag)] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


func all_lexeme_types() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		var type := str(entry.get("type", ""))
		if not type.is_empty():
			seen[type] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


func all_task_types() -> PackedStringArray:
	var seen := {}
	for definition in task_definitions.values():
		var task_type := str(definition.get("task_type", ""))
		if not task_type.is_empty():
			seen[task_type] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## Alle Formen eines Lexems; optional auf einen form_type und auf die in `scope`
## gelehrten (form_in_scope) gefiltert.
func forms_for(lexeme_id: String, form_type: String = "", scope: Array = []) -> Array:
	var result: Array = []
	for entry in lexeme_forms.values():
		if entry.get("lexeme_id", "") != lexeme_id:
			continue
		if form_type != "" and entry.get("form_type", "") != form_type:
			continue
		if not form_in_scope(entry, scope):
			continue
		result.append(entry)
	return result


## Relationen ab `lexeme_id` vom Typ opposite | synonym | confused_with | related.
func relations_of(lexeme_id: String, relation_type: String) -> Array:
	var result: Array = []
	for entry in lexeme_relations.values():
		if entry.get("from_lexeme_id", "") == lexeme_id \
				and entry.get("relation_type", "") == relation_type:
			result.append(entry)
	return result


## Findet die monster_task_rule für (task_type, direction), oder {} wenn keine passt.
func monster_rule_for(task_type: String, direction: String) -> Dictionary:
	for entry in monster_task_rules.values():
		if entry.get("task_type", "") == task_type \
				and entry.get("direction", "") == direction:
			return entry
	return {}


## Quelldatei-Pfad, aus dem der Eintrag geladen wurde, oder "" wenn unbekannt.
func source_file(category: String, id: String) -> String:
	return _source_files.get("%s|%s" % [category, id], "")


## Root, aus dem der Eintrag stammt, oder "" wenn unbekannt.
func origin(category: String, id: String) -> String:
	return str(_origins.get("%s|%s" % [category, id], ""))


## Pack-Id, aus deren Installation der Eintrag stammt, oder "" wenn er aus `res://` kommt.
func pack_of(category: String, id: String) -> String:
	var from := origin(category, id)
	if not from.begins_with(USER_CONTENT_ROOT + "/"):
		return ""
	return from.trim_prefix(USER_CONTENT_ROOT + "/").split("/")[0]


## Lexeme, die eine Nutzer-Meldung tragen (Feld "flag").
func flagged_lexemes() -> Array:
	var result: Array = []
	for entry in lexemes.values():
		if entry.has("flag"):
			result.append(entry)
	return result


## Speichert eine Meldung ("flag") zum Lexem über LexemeFlags und in der In-Memory-Kopie.
## False, wenn das Lexem unbekannt oder die Datei nicht schreibbar ist.
func flag_lexeme(lexeme_id: String, comment: String, learnable_id: String,
		stats_id := "") -> bool:
	if not lexemes.has(lexeme_id):
		push_warning("ContentRegistry: flag für unbekanntes Lexem '%s'" % lexeme_id)
		return false
	var flags := LexemeFlags.load_all()
	flags[lexeme_id] = LexemeFlags.entry(comment, learnable_id, stats_id)
	if not LexemeFlags.save_all(flags):
		return false
	lexemes[lexeme_id]["flag"] = flags[lexeme_id]
	return true


## Nimmt eine Meldung zurück. false, wenn zu dem Lexem keine gespeichert war.
func unflag_lexeme(lexeme_id: String) -> bool:
	var flags := LexemeFlags.load_all()
	if not flags.erase(lexeme_id):
		return false
	if not LexemeFlags.save_all(flags):
		return false
	if lexemes.has(lexeme_id):
		lexemes[lexeme_id].erase("flag")
	return true


## Hakt eine Meldung als gesendet ab (ADR 0002), in der Datei und in der In-Memory-Kopie.
func mark_flag_sent(lexeme_id: String) -> bool:
	if not LexemeFlags.mark_sent(lexeme_id):
		return false
	if lexemes.has(lexeme_id) and lexemes[lexeme_id].has("flag"):
		lexemes[lexeme_id]["flag"]["sent"] = true
	return true


## Legt die getrennt gespeicherten Meldungen nach jedem Laden über die Lexeme. Meldungen
## zu fehlenden Lexemen bleiben in der Datei.
func _apply_flags() -> void:
	var flags := LexemeFlags.load_all()
	for lexeme_id in flags:
		if lexemes.has(lexeme_id):
			lexemes[lexeme_id]["flag"] = flags[lexeme_id]


func _scan_dir(path: String, target: Dictionary, category: String, origin: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ContentRegistry: missing data folder '%s'" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := "%s/%s" % [path, file_name]
		if dir.current_is_dir():
			_scan_dir(full_path, target, category, origin)
		elif file_name.ends_with(".json"):
			_load_file(full_path, target, category, origin)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_file(file_path: String, target: Dictionary, category: String, origin: String) -> void:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		push_warning("ContentRegistry: empty or unreadable '%s'" % file_path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("ContentRegistry: invalid JSON in '%s'" % file_path)
		return
	if parsed is Array:
		for entry in parsed:
			_register(entry, target, category, file_path, origin)
	elif parsed is Dictionary:
		_register(parsed, target, category, file_path, origin)
	else:
		push_error("ContentRegistry: '%s' must contain an object or array" % file_path)


func _register(
	entry: Variant, target: Dictionary, category: String, file_path: String, origin: String
) -> void:
	if not (entry is Dictionary) or not entry.has("id"):
		push_error("ContentRegistry: entry without 'id' in '%s'" % file_path)
		return
	var id: String = str(entry["id"])
	var key := "%s|%s" % [category, id]
	# Über Roots hinweg ist Überschreiben die Vorrangregel.
	if target.has(id) and str(_origins.get(key, "")) == origin:
		push_warning("ContentRegistry: duplicate %s id '%s' (from %s)" % [category, id, file_path])
	target[id] = entry
	_source_files[key] = file_path
	_origins[key] = origin
