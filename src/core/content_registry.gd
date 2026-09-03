extends Node
## Central, data-driven content registry (autoload).
##
## Scans <root>/<category>/ at startup and loads EVERY .json file it finds
## (recursively, so subfolders per language or unit work). Es gibt DREI Roots, in
## Vorrangfolge: Spielkonfiguration unter res://data, Sprachdaten unter res://data/language
## (privates Submodule, siehe LANGUAGE_ROOT) und installierte Content-Packs unter
## user://content/<pack-id>/ (siehe USER_CONTENT_ROOT).
##
## To add new content — a monster, a skill, a vocab pack, a boss, a wave —
## drop a JSON file into the matching folder. No code changes required.
## Each JSON file may contain a single object OR an array of objects.
## Every object MUST have a unique string "id".

const DATA_ROOT := "res://data"

## Sprachdaten (Lexeme, Formen, Relationen, Sätze) liegen in einem separaten,
## PRIVATEN Repo — sie sind aus urheberrechtlich geschütztem Lehrbuchmaterial
## abgeleitet und dürfen nicht ins öffentliche Hauptrepo. Eingehängt als
## Submodule unter res://data/language (`git submodule update --init`).
## Ohne ausgecheckten Submodule startet das Spiel, hat aber keine Vokabeln.
const LANGUAGE_ROOT := "res://data/language"

## Die Kategorien, die aus LANGUAGE_ROOT statt aus DATA_ROOT gelesen werden.
## Installierte Content-Packs. Jeder Pack liegt in seinem eigenen Unterverzeichnis
## (user://content/<pack-id>/<kategorie>/…) und wird NACH den res://-Roots gelesen: bei
## gleicher `id` gewinnt der Pack. Das ist der Weg, auf dem die ausgelieferte EXE zu
## Vokabeln kommt — sie enthält keine (siehe docs/adr/0001-app-und-content-update.md).
const USER_CONTENT_ROOT := "user://content"

const LANGUAGE_CATEGORIES: Array[String] = [
	"lexemes",
	"lexeme_forms",
	"lexeme_relations",
	"sentences",
	"sentence_lexemes",
]

## Per-category catalogs (id -> entry Dictionary). Filled by reload().
##
## Sprachdaten und Aufgaben sind normalisiert (ERM, siehe docs/ARCHITECTURE.md):
## lexemes/forms/relations beschreiben die Sprache, task_definitions die Aufgaben-Regeln
## (die konkrete Aufgabe wird zur Laufzeit aus Definition × Lexeme erzeugt),
## monster_task_rules nur die Darstellung. sentences/sentence_lexemes sind für das
## (noch zurückgestellte) Satz-/Boss-Feature reserviert und vorerst leer.
var lexemes: Dictionary = {}
var lexeme_forms: Dictionary = {}
var lexeme_relations: Dictionary = {}
var sentences: Dictionary = {}
var sentence_lexemes: Dictionary = {}
var task_definitions: Dictionary = {}
var monster_task_rules: Dictionary = {}
var monsters: Dictionary = {}
var bosses: Dictionary = {}
var skills: Dictionary = {}
var waves: Dictionary = {}

## category name -> the Dictionary above (Dictionaries are references in GDScript,
## so clearing/filling these in place also updates the member vars).
var _by_category: Dictionary = {}

## "<category>|<id>" -> Quelldatei-Pfad. Wird beim Laden gefüllt, damit
## Bearbeitungen (z.B. flag_lexeme) in die richtige Quell-JSON zurückschreiben.
var _source_files: Dictionary = {}

## "<category>|<id>" -> Root, aus dem der Eintrag stammt. Trennt die zwei Fälle, die sonst
## gleich aussehen: zwei Dateien DESSELBEN Roots mit gleicher id sind ein Fehler, ein Pack,
## der einen eingebauten Eintrag überschreibt, ist der Zweck der Übung.
var _origins: Dictionary = {}


func _ready() -> void:
	_by_category = {
		"lexemes": lexemes,
		"lexeme_forms": lexeme_forms,
		"lexeme_relations": lexeme_relations,
		"sentences": sentences,
		"sentence_lexemes": sentence_lexemes,
		"task_definitions": task_definitions,
		"monster_task_rules": monster_task_rules,
		"monsters": monsters,
		"bosses": bosses,
		"skills": skills,
		"waves": waves,
	}
	reload()


## Rescans the whole data tree. Safe to call at runtime (e.g. after adding files) —
## ContentService ruft es nach jeder Pack-Installation.
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

	_apply_flags()


## Die Roots in Vorrangfolge: ein späterer überschreibt bei gleicher `id` einen früheren.
func _roots() -> Array:
	var game_categories: Array[String] = []
	for category in _by_category:
		if category not in LANGUAGE_CATEGORIES:
			game_categories.append(category)

	var roots: Array = [
		{"path": DATA_ROOT, "categories": game_categories, "required": true},
	]
	# Der Submodule-Checkout ist der Weg der Entwicklung; im Export fehlt er absichtlich.
	if DirAccess.dir_exists_absolute(LANGUAGE_ROOT):
		roots.append({"path": LANGUAGE_ROOT, "categories": LANGUAGE_CATEGORIES, "required": false})
	for pack_path in _pack_roots():
		roots.append({"path": pack_path, "categories": _by_category.keys(), "required": false})
	return roots


## Verzeichnisse installierter Packs, alphabetisch — damit die Vorrangfolge unter Packs
## nicht von der Reihenfolge des Dateisystems abhängt. Punkt-Verzeichnisse (der
## Installationszustand) bleiben außen vor.
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


## Returns all entries of a category as an Array of Dictionaries.
## Alle bekannten Kategorien. Muss mit `CATEGORIES` in src/content/pack_installer.gd und
## in tools/packs/build_packs.py übereinstimmen — sonst liefert ein Pack Dateien aus, die
## der Installer verwirft (oder umgekehrt).
func categories() -> Array:
	return _by_category.keys()


func all(category: String) -> Array:
	return _by_category.get(category, {}).values()


## Returns a single entry by id, or {} if not found.
func get_entry(category: String, id: String) -> Dictionary:
	return _by_category.get(category, {}).get(id, {})


## Returns lexeme entries whose "tags" intersect the requested tags.
## Leere `tags` -> alle Lexeme (kein Filter).
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


## Alle distinkten Bücher (Lexem-Feld "book") über den Katalog, alphabetisch sortiert.
## Für den Curriculum-Scope-Picker im Session-Setup. Lexeme ohne "book" (z.B. Grundwortschatz)
## erscheinen hier nicht — sie sind bewusst keinem Buch/Unit zugeordnet.
func all_books() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		var book := str(entry.get("book", ""))
		if not book.is_empty():
			seen[book] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## „access2" -> „Access 2": nachgestellte Ziffern mit Leerzeichen abtrennen, Rest als
## Titel. Die Buch-Ids sind klein und ohne Trennzeichen, für die Anzeige taugen sie nicht.
## Steht hier und nicht in einem Screen, weil inzwischen mehrere Screens Bücher benennen
## (Session-Setup, Statistik) und zwei Regeln irgendwann auseinanderlaufen.
func book_label(book: String) -> String:
	var i := book.length()
	while i > 0 and book[i - 1] >= "0" and book[i - 1] <= "9":
		i -= 1
	var name := book.substr(0, i).capitalize()
	var num := book.substr(i)
	return name if num.is_empty() else "%s %s" % [name, num]


## Alle distinkten Units eines Buchs (Lexem-Feld "unit"), numerisch aufsteigend sortiert.
func units_for(book: String) -> Array:
	var seen := {}
	for entry in lexemes.values():
		if str(entry.get("book", "")) == book and entry.has("unit"):
			seen[int(entry["unit"])] = true
	var result: Array = seen.keys()
	result.sort()
	return result


## Curriculum-Scope-Schlüssel eines Lexems: ["<book>", "<book>/<unit>"] — beides, damit
## sowohl "ganzes Buch" als auch "einzelne Unit" im Scope matchen. Leer, wenn kein "book".
func _scope_keys(entry: Dictionary) -> Array:
	var book := str(entry.get("book", ""))
	if book.is_empty():
		return []
	if entry.has("unit"):
		return [book, "%s/%d" % [book, int(entry["unit"])]]
	return [book]


## Lexeme gefiltert nach Curriculum-Scope UND Themen-Tags (die beiden Achsen aus dem
## Session-Setup). `scope`: Schlüssel wie "access2" (ganzes Buch) oder "access2/6" (eine Unit)
## — leer = keine Scope-Einschränkung (auch Lexeme ohne Buch/Unit bleiben drin). `tags` wird
## wie in lexemes_by_tags() als ODER innerhalb der Themen behandelt (leer = alle Themen).
## Ein Lexem muss BEIDE Achsen erfüllen (Schnitt): so ergibt z.B. scope=["access2/6"] +
## tags=["body"] genau die Körperteile aus Unit 6.
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


## Alle distinkten Lexem-Tags über den gesamten Katalog, alphabetisch sortiert.
## Für datengetriebene Auswahl-UIs (Session-Setup).
func all_lexeme_tags() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		for tag in entry.get("tags", []):
			seen[str(tag)] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## Alle distinkten Vokabel-Typen (Lexem-Feld "type") über den gesamten Katalog,
## alphabetisch sortiert. Für die Vokabel-Typ-Auswahl im Session-Setup.
func all_lexeme_types() -> PackedStringArray:
	var seen := {}
	for entry in lexemes.values():
		var type := str(entry.get("type", ""))
		if not type.is_empty():
			seen[type] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## Alle distinkten task_type-Werte aus den task_definitions, alphabetisch sortiert.
func all_task_types() -> PackedStringArray:
	var seen := {}
	for definition in task_definitions.values():
		var task_type := str(definition.get("task_type", ""))
		if not task_type.is_empty():
			seen[task_type] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


## Alle Formen eines Lexems; optional auf einen form_type gefiltert.
func forms_for(lexeme_id: String, form_type: String = "") -> Array:
	var result: Array = []
	for entry in lexeme_forms.values():
		if entry.get("lexeme_id", "") != lexeme_id:
			continue
		if form_type != "" and entry.get("form_type", "") != form_type:
			continue
		result.append(entry)
	return result


## Relationen, die von `lexeme_id` ausgehen und den gewünschten Typ haben
## (opposite | synonym | confused_with | related).
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


## Root, aus dem der Eintrag stammt (DATA_ROOT, LANGUAGE_ROOT oder
## USER_CONTENT_ROOT/<pack-id>), oder "" wenn unbekannt.
func origin(category: String, id: String) -> String:
	return str(_origins.get("%s|%s" % [category, id], ""))


## Pack-Id, aus deren Installation der Eintrag stammt, oder "" wenn er aus `res://` kommt.
## Trägt im Rückkanal die Herkunft mit: eine Meldung zu einem Wort, das inzwischen
## korrigiert wurde, ist sonst nicht von einer aktuellen zu unterscheiden.
func pack_of(category: String, id: String) -> String:
	var from := origin(category, id)
	if not from.begins_with(USER_CONTENT_ROOT + "/"):
		return ""
	return from.trim_prefix(USER_CONTENT_ROOT + "/").split("/")[0]


## Lexeme, die eine Nutzer-Meldung tragen (Feld "flag"), für die Menü-Anzeige.
func flagged_lexemes() -> Array:
	var result: Array = []
	for entry in lexemes.values():
		if entry.has("flag"):
			result.append(entry)
	return result


## Speichert eine Meldung ("flag") zum Lexem in `user://` und aktualisiert die
## In-Memory-Kopie, damit `flagged_lexemes()` ohne `reload()` stimmt.
## Gibt false zurück, wenn das Lexem unbekannt oder die Datei nicht schreibbar ist.
## Bewusst NICHT in die Quell-JSON: `res://` ist im Export read-only, und eine geänderte
## Pack-Datei würde beim nächsten Pack-Update übersprungen (siehe LexemeFlags).
func flag_lexeme(lexeme_id: String, comment: String, learnable_id: String) -> bool:
	if not lexemes.has(lexeme_id):
		push_warning("ContentRegistry: flag für unbekanntes Lexem '%s'" % lexeme_id)
		return false
	var flags := LexemeFlags.load_all()
	flags[lexeme_id] = LexemeFlags.entry(comment, learnable_id)
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


## Hakt eine Meldung als gesendet ab (Rückkanal, siehe
## docs/adr/0002-melde-rueckkanal.md) — in der Datei UND in der In-Memory-Kopie, damit die
## Anzeige ohne `reload()` stimmt. Wie `flag_lexeme`, nur in die andere Richtung.
func mark_flag_sent(lexeme_id: String) -> bool:
	if not LexemeFlags.mark_sent(lexeme_id):
		return false
	if lexemes.has(lexeme_id) and lexemes[lexeme_id].has("flag"):
		lexemes[lexeme_id]["flag"]["sent"] = true
	return true


## Meldungen liegen getrennt vom Content, müssen also nach jedem Laden wieder über die
## Lexeme gelegt werden. Meldungen zu Lexemen, die es nicht mehr gibt (Pack deinstalliert),
## bleiben in der Datei stehen und tauchen wieder auf, wenn der Pack zurückkommt.
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
	# Nur innerhalb EINES Roots ist eine doppelte id ein Fehler; über Roots hinweg ist das
	# Überschreiben die Vorrangregel.
	if target.has(id) and str(_origins.get(key, "")) == origin:
		push_warning("ContentRegistry: duplicate %s id '%s' (from %s)" % [category, id, file_path])
	target[id] = entry
	_source_files[key] = file_path
	_origins[key] = origin
