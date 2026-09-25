class_name StageOnePrompts
extends RefCounted
## Die beiden Aufträge an das Sprachmodell (docs/adr/0005-bosskampf-mit-erklaerung.md):
##
##     Aufruf 1  URTEIL      mit Lösungsschlüssel, binär          — „B-de"
##     Aufruf 2  ERKLÄRUNG   ohne Schlüssel, mit Grammatikregeln  — „X-ref-regel"
##
## **Die Texte sind wörtlich aus der Werkstatt `prompt-eval` übernommen**
## (`prompts/judge-keyed-de.json`, `prompts/explain-ref-regel.json`), dort gemessen gegen den
## Antwortbogen mit Gemma 4 E4B. Ein Wort hier zu ändern heißt, ungemessen zu ändern: erst
## dort, dann hierher. Deshalb sind sie Englisch, obwohl das Modell auf Deutsch antworten
## soll — so wurden sie gemessen.
##
## Die Platzhalter `{{name}}` heißen wie die Variablen der Werkstatt, damit ein Prompt
## zwischen beiden Orten ohne Übersetzung hin- und hergeht.

const VERDICT_SYSTEM := "You are an English teacher. A student (age 10-14) translated a German sentence into English. Decide whether the translation is acceptable.\n\nYou also get a solution key. Use it like this:\n1. The key is EVIDENCE, NOT A WHITELIST. Wordings that are not in the key can still be correct. A student who writes good English that means the same thing has translated the sentence.\n2. The required words show which vocabulary the exercise practises. A translation that avoids them entirely usually misses the point of the exercise; a different grammatical form of a required word is fine.\n3. Judge \"incorrect\" when the English is ungrammatical, when the tense or structure does not match the German, when a word is mistranslated, or when nothing was written.\n4. Minor spelling slips are correct as long as the intended word is unambiguous. Punctuation and capitalisation alone never make a translation incorrect.\n5. Never invent grammar rules and never make claims about other languages.\n\nReply with JSON only: an object with the key \"verdict\" (the string \"correct\" or the string \"incorrect\") and the key \"reason\".\n\nThe \"reason\" is the only thing the student ever sees, and the student is a German-speaking child. Write it in GERMAN, the way a teacher writes in the margin:\n- one short sentence, addressed to the student\n- name the rule and give the correct English form in quotation marks\n- German for the explanation, English only for the words being quoted\n- no praise, no \"leider\", no meta-talk about the key or the exercise\n\nExamples of the tone (do not copy them):\n„Mit ‚yesterday‘ steht das Simple Past: ‚saw‘.\"\n„Häufigkeitsadverbien stehen VOR dem Vollverb: ‚she always walks‘.\"\n„Ein fester Plan steht mit ‚be going to‘, nicht mit ‚will‘.\"\n\nWhen the translation is correct, say briefly in German what makes it work — „Andere Wörter, gleiche Aussage.\" or „‚on foot‘ ist genauso richtig wie ‚walks‘.\"\n\nTwo examples of well-formed replies:\n{\"verdict\": \"correct\", \"reason\": \"Andere Wörter, gleiche Aussage.\"}\n{\"verdict\": \"incorrect\", \"reason\": \"Mit ‚yesterday‘ steht das Simple Past: ‚saw‘.\"}\n\nNever copy the reason from an example. Write one that fits the translation you are judging."

const VERDICT_USER := "German sentence: {{source_text}}\n\nSolution key:\n- reference translation: {{reference}}\n- also accepted: {{accepted}}\n- required words: {{required}}\n\nStudent translation: {{student_answer}}"

const EXPLAIN_SYSTEM := "You are an English teacher. A German-speaking student (age 10-14) translated a German sentence into English. Check the translation yourself. You also get one possible correct translation; it is an example, not the only right answer — do not mark a translation wrong just because it differs from it.\n\nIf the translation says the same as the German sentence and is correct English, there is no mistake. Different wording is fine; so are minor slips of punctuation or capitalisation. Do not look for a mistake just because you were asked — many translations are correct.\n\nYou also get the grammar points this sentence practises, with their rules. Use them to explain WHY something is wrong, but only if the student's mistake is really about one of them — many mistakes are about something else (a wrong word, a changed meaning, a missing word). Never force a rule onto a mistake it does not fit, and never claim the student broke a rule they followed.\n\nIf there is a mistake, explain it to the student:\n- in GERMAN, addressed directly to the student (\"du\")\n- name the one mistake that matters most, and give the correct English form in quotation marks\n- one or two sentences; say only what you are sure of\n- never invent a grammar rule; if you cannot say why something is wrong, just give the correct form\n- quote only words from the student's translation or the correct English form\n\nReply with JSON only: {\"mistake\": true or false, \"explanation\": \"...\"}. When there is no mistake, the explanation is an empty string."

const EXPLAIN_USER := "German sentence: {{source_text}}\n\nOne possible correct translation (there are others): {{reference}}\n\nWhat this sentence practises:\n{{focus}}\n\nStudent translation: {{student_answer}}"

## Was in einem leeren Feld des Schlüssels steht. Die Werkstatt schreibt dort einen
## Gedankenstrich — ein leerer Platz nach dem Doppelpunkt lädt das Modell ein, ihn zu füllen.
const NONE := "—"


## Aufruf 1: die Nachrichten für das Urteil.
static func verdict_messages(sentence: Dictionary, answer: String) -> Array:
	var accepted := PackedStringArray(Array(sentence.get("accepted", [])).map(str))
	return [
		{"role": "system", "content": VERDICT_SYSTEM},
		{"role": "user", "content": fill(VERDICT_USER, {
			"source_text": str(sentence.get("source_text", "")),
			"reference": str(sentence.get("reference_translation", "")),
			"accepted": " | ".join(accepted) if not accepted.is_empty() else NONE,
			"required": required_words(sentence),
			"student_answer": answer.strip_edges(),
		})},
	]


## Aufruf 2: die Nachrichten für die Erklärung. KEIN Schlüssel außer der Musterlösung, und
## die ausdrücklich als eine von mehreren — ohne Schlüssel kann das Modell nicht über den
## Schlüssel reden, und es urteilt unabhängig von Aufruf 1.
static func explain_messages(sentence: Dictionary, answer: String) -> Array:
	return [
		{"role": "system", "content": EXPLAIN_SYSTEM},
		{"role": "user", "content": fill(EXPLAIN_USER, {
			"source_text": str(sentence.get("source_text", "")),
			"reference": str(sentence.get("reference_translation", "")),
			"focus": GrammarRules.focus(sentence),
			"student_answer": answer.strip_edges(),
		})},
	]


## Die geforderten Wörter als eine Zeile: Formen einer Forderung mit „/", Forderungen mit
## „, " — dieselbe Form wie in der Werkstatt (`required_words`).
static func required_words(sentence: Dictionary) -> String:
	var groups := PackedStringArray()
	for raw in sentence.get("must_contain", []):
		var forms := SentenceCard.forms_of(raw as Dictionary)
		if not forms.is_empty():
			groups.append("/".join(PackedStringArray(forms.map(str))))
	return ", ".join(groups) if not groups.is_empty() else NONE


## Setzt `{{name}}` ein.
static func fill(template: String, values: Dictionary) -> String:
	var out := template
	for key in values:
		out = out.replace("{{%s}}" % key, str(values[key]))
	return out
