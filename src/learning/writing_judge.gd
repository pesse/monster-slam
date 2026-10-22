class_name WritingJudge
extends RefCounted
## Das Urteil über eine Summary, je Kriterium ein Stapel an The Rambler
## (docs/adr/0023-schreib-boss.md, Abschnitte 5 und 6). Die Länge rechnet SummaryCard
## offline, alles andere kommt aus der Antwort des Modells (CloudModelBackend).
##
## Drei Regeln aus dem ADR stehen hier und nirgends sonst:
##
## **Jedes Zitat des Modells wird im Schülertext gesucht** (SummaryCard.locate, also
## normalisiert: Groß/Klein, Leerraum, typografische Zeichen egal). Was dort nicht steht,
## fällt weg — ein erfundener Fehler kostet keinen Stapel, und ein Kernpunkt ohne Beleg
## gilt nicht als erfasst. `from`/`to` einer Markierung sind Zeichenpositionen im
## Originaltext, damit das Überarbeiten-Overlay genau die Stelle anstreicht.
##
## **Ein Hinweis verrät nie die Lösung.** Enthält er wörtlich eine Korrektur (CORRECTION_
## PATTERNS), wird er durch die Standardregel seiner Kategorie ersetzt (DEFAULT_HINTS).
##
## **Gewertet wird in Stufen, nicht in Punkten:** ein Kriterium ist erfüllt oder nicht.
##
## **Ohne Fehler ist nicht ohne Text.** Textsorte und Sprache gelten als erfüllt, wenn das
## Modell nichts findet — in einem Fetzen wie „dsgf“ findet es auch nichts. Sie fallen erst
## ab `MIN_SHARE` der Mindestlänge (`substantial`), sonst halten sie ohne Markierung.
##
## Reine Rechnung ohne Zustand und ohne Netz (tests/writing_judge_test.gd).
##
## Rückgabe von `criteria`, je Kriterium in CRITERIA-Reihenfolge:
##   { "id", "decided", "met", "source": "offline" | "model",
##     "marks": [{ "quote", "from", "to", "category", "severity", "hint" }] }
## `decided` falsch heißt: ohne Modellantwort lässt sich das Kriterium nicht entscheiden,
## der Stapel bleibt hängen, ohne dass es als Fehlschlag zählt. Das gilt für alle außer
## der Länge.

const CRITERIA := ["intro", "content", "genre", "language", "length"]

## Die Regel je Fehlerkategorie — der Hinweis, wenn das Modell keinen brauchbaren liefert.
## Nennt die Regel, nie das Ergebnis.
const DEFAULT_HINTS := {
	"grammar": "Prüfe den Satzbau an dieser Stelle.",
	"spelling": "Prüfe die Schreibweise.",
	"word_choice": "Hier passt ein anderes Wort besser.",
	"tense": "Eine Summary steht im Present Tense.",
	"style": "Eine Summary ist sachlich und knapp.",
	"quote": "Keine direkte Rede und nichts wörtlich abschreiben – sag es mit eigenen Worten.",
	"opinion": "Eine Summary gibt den Text wieder, ohne deine eigene Meinung.",
}

## Für eine Kategorie, die DEFAULT_HINTS nicht kennt.
const FALLBACK_HINT := "Prüfe diese Stelle."

## Muster, an denen ein Hinweis als verratene Lösung erkannt wird (Groß/Klein egal):
## Anweisungen mit Ersatzwort in Anführungszeichen, Pfeile, „statt“-Formeln, „sollte …
## heißen“. „Change the verb to the present tense“ nennt die Regel und bleibt stehen.
const CORRECTION_PATTERNS := [
	"\\b(use|write|say|try|put)\\s+[\"'‘“„]",
	"→|->|=>",
	"\\binstead of\\b",
	"\\bshould be\\b",
	"\\bshould read\\b",
	"\\bcorrect (form|version|spelling|word) is\\b",
	"\\bchange\\b.*\\bto\\s+[\"'‘“„]",
	"\\breplace\\b.*\\bwith\\s+[\"'‘“„]",
	"\\b(an)?statt\\b",
	"\\banstelle\\b",
	"\\brichtig (ist|wäre|heißt|lautet)\\b",
	"\\b(heißt|lautet) (es )?richtig\\b",
	"\\b(sollte|muss|müsste)\\b.*\\b(heißen|lauten)\\b",
	"\\bschreib\\w*\\s+[\"'‘“„]",
	"\\bersetz\\w*\\b.*\\bdurch\\b",
]

## Ab diesem Anteil der unteren Zielwortzahl lassen sich Textsorte und Sprache beurteilen.
const MIN_SHARE := 0.5
## Dasselbe für eine Aufgabe ohne Zielbereich (Wörter).
const MIN_WORDS := 20

static var _correction_res: Array = []


static func criteria(task: Dictionary, text: String, card: Dictionary,
		reply: Dictionary) -> Array:
	if card.is_empty():
		card = SummaryCard.check(task, text)
	var has_reply := not reply.is_empty()
	var judgeable := substantial(task, int(card.get("words", 0)))
	var out: Array = []
	for id in CRITERIA:
		if id == "length":
			out.append(_entry(id, true, bool(card.get("length_ok", false)), "offline", []))
		elif not has_reply:
			out.append(_entry(id, false, false, "model", []))
		else:
			match id:
				"intro":
					out.append(_intro(text, reply))
				"content":
					out.append(_content(task, text, reply))
				"genre":
					out.append(_genre(text, reply) if judgeable
							else _entry(id, true, false, "model", []))
				"language":
					out.append(_language(text, reply) if judgeable
							else _entry(id, true, false, "model", []))
	return out


## Ob ein Text lang genug ist, dass Textsorte und Sprache etwas über ihn sagen.
static func substantial(task: Dictionary, words: int) -> bool:
	var target: Array = Array(task.get("target_words", []))
	var floor_words := MIN_WORDS
	if target.size() == 2:
		floor_words = ceili(int(target[0]) * MIN_SHARE)
	return words >= floor_words


## Titel und Autor im ersten Satz — erfüllt nur mit einem Zitat, das im Text steht.
static func _intro(text: String, reply: Dictionary) -> Dictionary:
	var intro: Dictionary = reply.get("intro", {})
	var met := bool(intro.get("met", false)) \
			and not SummaryCard.locate(text, str(intro.get("quote", ""))).is_empty()
	return _entry("intro", true, met, "model", [])


## Alle Pflicht-Kernpunkte erfasst, jeder mit einem Zitat, das im Text steht. Ein Kernpunkt
## ohne `required` zählt als Pflicht. Markiert wird nichts: was fehlt, steht nicht im Text,
## und es zu nennen hieße, den Inhalt vorzusagen.
static func _content(task: Dictionary, text: String, reply: Dictionary) -> Dictionary:
	var covered := {}
	for point in Array(reply.get("key_points", [])):
		if not point is Dictionary or not bool(point.get("covered", false)):
			continue
		if not SummaryCard.locate(text, str(point.get("quote", ""))).is_empty():
			covered[str(point.get("id", ""))] = true
	var met := true
	for point in Array(task.get("key_points", [])):
		if bool(point.get("required", true)) and not covered.has(str(point.get("id", ""))):
			met = false
	return _entry("content", true, met, "model", [])


## Textsorte: Präsens, keine direkte Rede, nichts abgeschrieben, keine eigene Meinung.
## Jede Stelle zählt nur mit Beleg im Text: ein Urteil ohne findbare Stelle könnte das Kind
## nicht überarbeiten, und ein erfundenes soll keinen Stapel kosten.
static func _genre(text: String, reply: Dictionary) -> Dictionary:
	var marks: Array = []
	if not bool(reply.get("present_tense", true)):
		for quote in Array(reply.get("tense_quotes", [])):
			_add_mark(marks, text, str(quote), "tense", "major", "")
	for quote in Array(reply.get("direct_speech", [])) + Array(reply.get("copied", [])):
		_add_mark(marks, text, str(quote), "quote", "major", "")
	for phrase in Array(reply.get("opinion", [])):
		_add_mark(marks, text, str(phrase), "opinion", "major", "")
	return _entry("genre", true, marks.is_empty(), "model", marks)


## Sprache: erfüllt, solange kein belegter schwerer Fehler bleibt. Leichte Fehler werden
## markiert, kosten aber nichts.
static func _language(text: String, reply: Dictionary) -> Dictionary:
	var marks: Array = []
	for error in Array(reply.get("errors", [])):
		if not error is Dictionary:
			continue
		var severity := "minor" if str(error.get("severity", "")) == "minor" else "major"
		_add_mark(marks, text, str(error.get("quote", "")), str(error.get("category", "")),
				severity, str(error.get("hint", "")))
	var met := not marks.any(func(m): return str(m["severity"]) == "major")
	return _entry("language", true, met, "model", marks)


## Der Hinweis, wie er gezeigt wird: der des Modells, außer er ist leer oder verrät die
## Lösung — dann die Regel der Kategorie.
static func safe_hint(category: String, hint: String) -> String:
	var trimmed := hint.strip_edges()
	if trimmed.is_empty() or reveals_solution(trimmed):
		return str(DEFAULT_HINTS.get(category, FALLBACK_HINT))
	return trimmed


static func reveals_solution(hint: String) -> bool:
	if _correction_res.is_empty():
		for pattern in CORRECTION_PATTERNS:
			_correction_res.append(RegEx.create_from_string("(?i)" + pattern))
	for re in _correction_res:
		if (re as RegEx).search(hint) != null:
			return true
	return false


## Hängt eine Markierung an, wenn das Zitat im Text steht; dieselbe Stelle mit derselben
## Kategorie nur einmal.
static func _add_mark(marks: Array, text: String, quote: String, category: String,
		severity: String, hint: String) -> void:
	var at := SummaryCard.locate(text, quote)
	if at.is_empty():
		return
	for m in marks:
		if int(m["from"]) == int(at["from"]) and int(m["to"]) == int(at["to"]) \
				and str(m["category"]) == category:
			return
	marks.append({
		"quote": text.substr(int(at["from"]), int(at["to"]) - int(at["from"])),
		"from": int(at["from"]),
		"to": int(at["to"]),
		"category": category,
		"severity": severity,
		"hint": safe_hint(category, hint),
	})


static func _entry(id: String, decided: bool, met: bool, source: String,
		marks: Array) -> Dictionary:
	return {"id": id, "decided": decided, "met": met, "source": source, "marks": marks}
