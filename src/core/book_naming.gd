class_name BookNaming
extends RefCounted
## Wie ein Buch sich und seine beiden Ebenen nennt: Access „Unit 2 · Teil 1", À plus!
## „Dossier 2 · Partie A", das Lateinbuch „Abschnitt 2 · Lektion 10".
##
## Steht unter `naming` in assets/maps/<book>/map.json (ADR 0008) und gehört damit zur EXE
## wie Karte und Punkte, nicht in einen Pack:
##
##     "naming": { "title": "À plus!", "unit": "Dossier", "part": "Partie",
##                 "part_glyph": "letter", "parts_per_unit": 6 }
##
## Jedes Feld ist optional. `part_glyph` "letter" zählt die Teile A, B, C statt 1, 2, 3.
## `parts_per_unit` > 0 zählt die Teile über das ganze Buch durch (Latein: Unit 2, Teil 4
## ist Lektion 10). Intern bleiben Unit und Teil Zahlen — Scope, Karte und Stufen ändern
## sich nicht, nur was dasteht.
##
## Die Regeln stehen als reine Funktionen über dem `naming`-Dictionary (ohne Datei
## prüfbar); die Fassungen mit `book` lesen die Karte.

const UNIT_WORD := "Unit"
const PART_WORD := "Teil"

static var _cache := {}


## Das `naming` eines Buchs, {} ohne Eintrag.
static func of(book: String) -> Dictionary:
	if not _cache.has(book):
		var naming: Variant = MapLayout.data(book).get("naming", {}) if not book.is_empty() else {}
		_cache[book] = naming if naming is Dictionary else {}
	return _cache[book]


## Der Anzeigename des Buchs aus `title`, leer ohne.
static func title(book: String) -> String:
	return str(of(book).get("title", ""))


## „Dossier 2"
static func unit_label(book: String, unit: int) -> String:
	return unit_label_in(of(book), unit)


## „Partie A"
static func part_label(book: String, unit: int, part: int) -> String:
	return part_label_in(of(book), unit, part)


## „Partie A + B"
static func parts_label(book: String, unit: int, parts: Array) -> String:
	return parts_label_in(of(book), unit, parts)


## „A" — was auf dem Ort der Karte und am Haken der Auswahl steht.
static func part_glyph(book: String, unit: int, part: int) -> String:
	return part_glyph_in(of(book), unit, part)


static func unit_label_in(naming: Dictionary, unit: int) -> String:
	return "%s %d" % [str(naming.get("unit", UNIT_WORD)), unit]


static func part_label_in(naming: Dictionary, unit: int, part: int) -> String:
	return "%s %s" % [str(naming.get("part", PART_WORD)), part_glyph_in(naming, unit, part)]


static func parts_label_in(naming: Dictionary, unit: int, parts: Array) -> String:
	var glyphs: Array = parts.map(func(p): return part_glyph_in(naming, unit, int(p)))
	return "%s %s" % [str(naming.get("part", PART_WORD)), " + ".join(glyphs)]


static func part_glyph_in(naming: Dictionary, unit: int, part: int) -> String:
	if str(naming.get("part_glyph", "")) == "letter" and part >= 1 and part <= 26:
		return String.chr(64 + part)
	var per_unit := int(naming.get("parts_per_unit", 0))
	return str(part + (unit - 1) * per_unit if per_unit > 0 else part)
