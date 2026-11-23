class_name LatinMorphology
extends RefCounted
## Bildet lateinische Formen nach der Regel ihrer Klasse und ordnet jede Zelle einer Endung
## als Lerneinheit zu (ADR 0032). Rein: bekommt Lemma, Genitiv, Genus bzw. Infinitiv,
## 1. Person und Perfekt und kennt weder Registry noch Lernstand.
##
## Eine Zelle ist { cell: "<tabelle>.<zelle>", form, unit: "<tabelle>.<klasse>.<zelle>" }.

const TABLES := ["decl", "pres", "impf", "imp", "perf"]

## Die Zellen einer Tabelle. Nominativ Singular, 1. Person Präsens und 1. Person Perfekt
## stehen in der Aufgabe selbst (Lemma bzw. Lexikonform) und werden nicht gefragt.
const CELLS := {
	"decl": ["gen_sg", "dat_sg", "acc_sg", "abl_sg", "nom_pl", "gen_pl", "dat_pl", "acc_pl", "abl_pl"],
	"pres": ["2sg", "3sg", "1pl", "2pl", "3pl"],
	"impf": ["1sg", "2sg", "3sg", "1pl", "2pl", "3pl"],
	"imp": ["sg", "pl"],
	"perf": ["2sg", "3sg", "1pl", "2pl", "3pl"],
}

## Endung je Klasse und Zelle, an den Stamm gehängt; bei a/e/i trägt sie den Stammvokal
## (amā-s, ama-t). NOM: die Form ist das Lemma.
const NOM := "="
const DECL := {
	"a": ["ae", "ae", "am", "ā", "ae", "ārum", "īs", "ās", "īs"],
	"o": ["ī", "ō", "um", "ō", "ī", "ōrum", "īs", "ōs", "īs"],
	"o_n": ["ī", "ō", NOM, "ō", "a", "ōrum", "īs", "a", "īs"],
	"3": ["is", "ī", "em", "e", "ēs", "um", "ibus", "ēs", "ibus"],
	"3_n": ["is", "ī", NOM, "e", "a", "um", "ibus", "a", "ibus"],
	"3_i": ["is", "ī", "em", "e", "ēs", "ium", "ibus", "ēs", "ibus"],
	"3_in": ["is", "ī", NOM, "ī", "ia", "ium", "ibus", "ia", "ibus"],
	"u": ["ūs", "uī", "um", "ū", "ūs", "uum", "ibus", "ūs", "ibus"],
	"e": ["eī", "eī", "em", "ē", "ēs", "ērum", "ēbus", "ēs", "ēbus"],
}
const CONJ := {
	"pres": {
		"a": ["ās", "at", "āmus", "ātis", "ant"],
		"e": ["ēs", "et", "ēmus", "ētis", "ent"],
		"i": ["īs", "it", "īmus", "ītis", "iunt"],
		"cons": ["is", "it", "imus", "itis", "unt"],
		"mixed": ["is", "it", "imus", "itis", "iunt"],
	},
	"impf": {
		"a": ["ābam", "ābās", "ābat", "ābāmus", "ābātis", "ābant"],
		"e": ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"],
		"i": ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"],
		"cons": ["ēbam", "ēbās", "ēbat", "ēbāmus", "ēbātis", "ēbant"],
		"mixed": ["iēbam", "iēbās", "iēbat", "iēbāmus", "iēbātis", "iēbant"],
	},
	"imp": {
		"a": ["ā", "āte"], "e": ["ē", "ēte"], "i": ["ī", "īte"],
		"cons": ["e", "ite"], "mixed": ["e", "ite"],
	},
	"perf": {"all": ["istī", "it", "imus", "istis", "ērunt"]},
}

## Klassen, deren Endung in einer Zelle mit der einer anderen übereinstimmt, lernen sie
## dort nicht neu: Die Zelle gehört der letzten gleichen Klasse dieser Liste.
const SHARES_WITH := {
	"o_n": ["o"],
	"3_n": ["3"],
	"3_i": ["3"],
	"3_in": ["3_n", "3_i", "3"],
	"mixed": ["i", "cons"],
}

## Gruppe einer Klasse für „Für eine Arbeit üben“ und die Statistik.
const DECL_FAMILY := {"a": "a", "o": "o", "o_n": "o", "3": "3", "3_n": "3", "3_i": "3",
		"3_in": "3", "u": "u", "e": "e"}

const CLASS_LABELS := {
	"a": "a-Deklination", "o": "o-Deklination", "o_n": "o-Deklination, Neutrum",
	"3": "3. Deklination", "3_n": "3. Deklination, Neutrum", "3_i": "3. Deklination, i-Stamm",
	"3_in": "3. Deklination, i-Stamm, Neutrum", "u": "u-Deklination", "e": "e-Deklination",
}
const CONJ_LABELS := {"a": "a-Konjugation", "e": "e-Konjugation", "i": "i-Konjugation",
		"cons": "kons. Konjugation", "mixed": "gemischte Konjugation"}
const TABLE_LABELS := {"decl": "Deklination", "pres": "Präsens", "impf": "Imperfekt",
		"imp": "Imperativ", "perf": "Perfekt"}
const CELL_LABELS := {
	"gen_sg": "Gen. Sg.", "dat_sg": "Dat. Sg.", "acc_sg": "Akk. Sg.", "abl_sg": "Abl. Sg.",
	"nom_pl": "Nom. Pl.", "gen_pl": "Gen. Pl.", "dat_pl": "Dat. Pl.", "acc_pl": "Akk. Pl.",
	"abl_pl": "Abl. Pl.", "1sg": "1. Sg.", "2sg": "2. Sg.", "3sg": "3. Sg.", "1pl": "1. Pl.",
	"2pl": "2. Pl.", "3pl": "3. Pl.", "sg": "Sg.", "pl": "Pl.",
}

const _VOWELS := "aeiouyāēīōūȳ"


## Der form_type in `lexeme_forms`, unter dem ein Wort eine Zelle ausgeschrieben trägt.
## Wer ihn hat, ist für diese Zelle kein Träger (ADR 0032, Punkt 4).
static func form_type_of(cell: String) -> String:
	match cell:
		"decl.gen_sg": return "la_genitive"
		"pres.1sg": return "la_present_1sg"
		"perf.1sg": return "la_perfect"
	var bits := cell.split(".")
	if bits[0] == "decl":
		return "la_" + bits[1]
	return "la_%s_%s" % [bits[0], bits[1]]


## Die Tabelle, deren Zelle ein ausgeschriebener Formtyp ist („la_imp_sg" → „imp"), leer
## für die Grundformen (Genitiv, 1. Person Präsens, Perfekt) und alles andere.
static func table_of_form_type(form_type: String) -> String:
	for table in TABLES:
		for cell in CELLS[table]:
			var key := "%s.%s" % [table, cell]
			if form_type_of(key) == form_type and not key in ["decl.gen_sg", "pres.1sg", "perf.1sg"]:
				return table
	return ""


## Klasse und Stamm eines Nomens, leer, wenn die Regel sie nicht bestimmt. `genitive` darf
## fehlen (das Buch führt ihn später ein); dann reichen Endung und Genus für a/o.
## `plural`: das Wort hat nur Plural (Genitiv auf -um).
static func noun_class(lemma: String, genitive: String, gender: String) -> Dictionary:
	var neuter := gender == "n"
	if genitive.is_empty():
		if lemma.ends_with("a") and not neuter:
			return {"class": "a", "stem": lemma.left(-1), "plural": false}
		if lemma.ends_with("us") and gender == "m":
			return {"class": "o", "stem": lemma.left(-2), "plural": false}
		if lemma.ends_with("um") and neuter:
			return {"class": "o_n", "stem": lemma.left(-2), "plural": false}
		return {}
	for plural_end in ["ārum", "ōrum", "ium", "um"]:
		if genitive.ends_with(plural_end):
			var stem := genitive.left(-plural_end.length())
			var cls: String = {"ārum": "a", "ōrum": "o_n" if neuter else "o",
					"ium": "3_in" if neuter else "3_i", "um": "3_n" if neuter else "3"}[plural_end]
			return {"class": cls, "stem": stem, "plural": true}
	if genitive.ends_with("ae"):
		return {"class": "a", "stem": genitive.left(-2), "plural": false}
	# deus, deī ist o-Deklination: die e-Deklination erkennt erst der Nominativ auf -ēs.
	if lemma.ends_with("ēs") and (genitive.ends_with("ēī") or genitive.ends_with("eī")):
		return {"class": "e", "stem": genitive.left(-2), "plural": false}
	if genitive.ends_with("ī"):
		return {"class": "o_n" if neuter else "o", "stem": genitive.left(-1), "plural": false}
	if genitive.ends_with("ūs") and not neuter:
		return {"class": "u", "stem": genitive.left(-2), "plural": false}
	if genitive.ends_with("is"):
		var stem := genitive.left(-2)
		var cls := "3"
		if neuter:
			cls = "3_in" if _pure_i_stem(lemma) else "3_n"
		elif _mixed_i_stem(lemma, stem):
			cls = "3_i"
		return {"class": cls, "stem": stem, "plural": false}
	return {}


## Neutra auf -e, -al, -ar (mare, animal, exemplar).
static func _pure_i_stem(lemma: String) -> bool:
	return lemma.ends_with("e") or lemma.ends_with("al") or lemma.ends_with("ar")


## Gleichsilbige auf -is/-ēs (nāvis, nāvis) und Wörter auf -s/-x mit zwei Konsonanten vor
## der Genitivendung (urbs, urbis; nox, noctis).
static func _mixed_i_stem(lemma: String, stem: String) -> bool:
	if lemma == stem + "is" or lemma == stem + "ēs":
		return true
	if not (lemma.ends_with("s") or lemma.ends_with("x")) or stem.length() < 2:
		return false
	return not _VOWELS.contains(stem.right(1)) and not _VOWELS.contains(stem.substr(stem.length() - 2, 1))


## Klasse und Stämme eines Verbs, leer, wenn die Regel sie nicht bestimmt (esse, dare,
## unpersönliche Verben ohne 1. Person). `perfect` darf fehlen.
static func verb_class(infinitive: String, present_1sg: String, perfect := "") -> Dictionary:
	if present_1sg.is_empty():
		return {}
	var cls := ""
	var stem := ""
	var short_a := false
	if infinitive.ends_with("āre") and present_1sg.ends_with("ō"):
		cls = "a"
		stem = infinitive.left(-3)
	elif infinitive.ends_with("are") and present_1sg.ends_with("ō"):
		# dare und Komposita: a-Konjugation mit kurzem a, lang nur in dās und dā.
		cls = "a"
		stem = infinitive.left(-3)
		short_a = true
	elif (infinitive.ends_with("ēre") or infinitive.ends_with("ere")) and present_1sg.ends_with("eō"):
		cls = "e"
		stem = infinitive.left(-3)
	elif infinitive.ends_with("īre") and present_1sg.ends_with("iō"):
		cls = "i"
		stem = infinitive.left(-3)
	elif infinitive.ends_with("ere") and present_1sg.ends_with("iō"):
		cls = "mixed"
		stem = present_1sg.left(-2)
	elif infinitive.ends_with("ere") and present_1sg.ends_with("ō"):
		cls = "cons"
		stem = present_1sg.left(-1)
	else:
		return {}
	var out := {"class": cls, "stem": stem, "perfect_stem": "", "short_a": short_a}
	if perfect.ends_with("ī"):
		out["perfect_stem"] = perfect.left(-1)
	return out


## Die gefragten Zellen eines Nomens nach der Regel, leer ohne Klasse.
static func noun_cells(lemma: String, genitive: String, gender: String) -> Array:
	var info := noun_class(lemma, genitive, gender)
	if info.is_empty():
		return []
	var cls: String = info["class"]
	var out: Array = []
	var cells: Array = CELLS["decl"]
	for i in cells.size():
		var cell: String = cells[i]
		if bool(info["plural"]) and (cell.ends_with("_sg") or cell == "nom_pl"):
			continue
		# Der Genitiv steht in der Aufgabe, wo es ihn gibt.
		if cell == "gen_sg" and not genitive.is_empty():
			continue
		var ending: String = DECL[cls][i]
		var form := lemma if ending == NOM else str(info["stem"]) + ending
		out.append({"cell": "decl." + cell, "form": form, "unit": _unit("decl", cls, i, DECL)})
	return out


## Die gefragten Zellen eines Verbs nach der Regel, leer ohne Klasse. Perfektzellen nur mit
## Perfekt.
static func verb_cells(infinitive: String, present_1sg: String, perfect := "") -> Array:
	var info := verb_class(infinitive, present_1sg, perfect)
	if info.is_empty():
		return []
	var cls: String = info["class"]
	var out: Array = []
	for table in ["pres", "impf", "imp"]:
		var cells: Array = CELLS[table]
		for i in cells.size():
			var ending: String = CONJ[table][cls][i]
			if info["short_a"] and ending.length() > 2:
				ending = ending.replace("ā", "a")
			out.append({"cell": "%s.%s" % [table, cells[i]],
					"form": str(info["stem"]) + ending,
					"unit": _unit(table, cls, i, CONJ[table])})
	var perfect_stem := str(info["perfect_stem"])
	if not perfect_stem.is_empty():
		var cells: Array = CELLS["perf"]
		for i in cells.size():
			out.append({"cell": "perf." + str(cells[i]),
					"form": perfect_stem + str(CONJ["perf"]["all"][i]),
					"unit": "perf.%s" % cells[i]})
	return out


## Die Lerneinheit von Klasse `cls` in Zelle `index` einer Tabelle; das Perfekt hat eine
## für alle Klassen.
static func unit_at(table: String, cls: String, index: int) -> String:
	if table == "perf":
		return "perf.%s" % CELLS["perf"][index]
	return _unit(table, cls, index, DECL if table == "decl" else CONJ[table])


## Die Endung von Klasse `cls` in Zelle `index`, wie die Tabelle sie zeigt: „-ārum", „= Nom.".
static func ending_text(table: String, cls: String, index: int) -> String:
	var ending: String
	if table == "decl":
		ending = DECL[cls][index]
	elif table == "perf":
		ending = CONJ["perf"]["all"][index]
	else:
		ending = CONJ[table][cls][index]
	return "= Nom." if ending == NOM else "-" + ending


## Die Lerneinheit einer Zelle (SHARES_WITH).
static func _unit(table: String, cls: String, index: int, endings: Dictionary) -> String:
	var owner := cls
	for other in SHARES_WITH.get(cls, []):
		if endings.has(other) and endings[other][index] == endings[cls][index]:
			owner = other
	return "%s.%s.%s" % [table, owner, CELLS[table][index]]


## Die Gruppe einer Lerneinheit: „decl.3", „pres.a", „imp", „perf".
static func group_of(unit: String) -> String:
	var bits := unit.split(".")
	match bits[0]:
		"decl":
			return "decl." + str(DECL_FAMILY.get(bits[1], bits[1]))
		"pres", "impf":
			return "%s.%s" % [bits[0], bits[1]]
	return bits[0]


## „3. Deklination", „Präsens, a-Konjugation", „Imperativ".
static func group_label(group: String) -> String:
	var bits := group.split(".")
	if bits[0] == "decl":
		return str(CLASS_LABELS.get(bits[1], bits[1]))
	if bits.size() > 1:
		return "%s, %s" % [TABLE_LABELS.get(bits[0], bits[0]), CONJ_LABELS.get(bits[1], bits[1])]
	return str(TABLE_LABELS.get(bits[0], bits[0]))


## Was in der Aufgabe hinter dem Pfeil steht: „Akk. Pl.", „3. Pl. Imperfekt", „Imperativ Pl.".
static func cell_label(cell: String) -> String:
	var bits := cell.split(".")
	var label := str(CELL_LABELS.get(bits[1], bits[1]))
	match bits[0]:
		"decl":
			return label
		"imp":
			return "Imperativ " + label
	return "%s %s" % [label, TABLE_LABELS.get(bits[0], bits[0])]


## Lesbar für Statistik und Debug: „3. Deklination, i-Stamm: Gen. Pl.".
static func unit_label(unit: String) -> String:
	var bits := unit.split(".")
	if bits.size() < 2:
		return unit
	var cell := "%s.%s" % [bits[0], bits[bits.size() - 1]]
	if bits[0] == "decl":
		return "%s: %s" % [CLASS_LABELS.get(bits[1], bits[1]), cell_label(cell)]
	if bits.size() == 3 and bits[0] != "perf":
		return "%s: %s" % [CONJ_LABELS.get(bits[1], bits[1]), cell_label(cell)]
	return cell_label(cell)


## Alle Lerneinheiten einer Gruppe, in Tabellenreihenfolge.
static func units_of_group(group: String) -> Array:
	var out: Array = []
	var bits := group.split(".")
	var table := bits[0]
	if table == "perf":
		for cell in CELLS["perf"]:
			out.append("perf." + str(cell))
		return out
	var classes: Array = []
	if table == "decl":
		for cls in DECL:
			if DECL_FAMILY[cls] == bits[1]:
				classes.append(cls)
	elif bits.size() > 1:
		classes = [bits[1]]
	else:
		classes = CONJ[table].keys()
	var source: Dictionary = DECL if table == "decl" else CONJ[table]
	for cls in classes:
		for i in CELLS[table].size():
			var unit := _unit(table, cls, i, source)
			if group_of(unit) == group and not unit in out:
				out.append(unit)
	return out


## Alle Gruppen in fester Reihenfolge.
static func all_groups() -> Array:
	var out: Array = []
	for family in ["a", "o", "3", "u", "e"]:
		out.append("decl." + family)
	for table in ["pres", "impf"]:
		for cls in ["a", "e", "i", "cons"]:
			out.append("%s.%s" % [table, cls])
	out.append("imp")
	out.append("perf")
	return out
