class_name GrammarRules
extends RefCounted
## Der Regelkatalog je `grammar_tag` — das, was der Erklärer über die Grammatik eines
## Satzes erfährt (docs/adr/0005-bosskampf-mit-erklaerung.md, Entscheidung 5).
##
## Gemessen wurde er in der Werkstatt `prompt-eval` (`rules/grammar.json`): mit ihm nennt
## Gemma bei Einzelsätzen reproduzierbar öfter den richtigen Grund, und keinen der Wort-
## und Rollenfehler hat es dabei in eine Regel gepresst. Die Einträge sind allgemeine
## Grammatik, geschrieben aus dem Tag und nicht aus Lehrbuch oder Antwortbogen — sonst
## lernte der Erklärer eine Lösung abzuschreiben. Deshalb steht der Katalog im öffentlichen
## Repo; Lemmata stehen darin keine.
##
## Geändert wird er zuerst in der Werkstatt und erst gemessen hier. Die Einträge ab
## `past_perfect` sind für die Tags des Bestands dazugekommen, die der Antwortbogen nicht
## kennt; sie folgen demselben Muster (Form, Verwendung, typische Verwechslung).

const RULES := {
	"past_simple": "Simple Past (saw, went, played) für Handlungen, die zu einem abgeschlossenen Zeitpunkt in der Vergangenheit passiert sind. Signalwörter: yesterday, last week, ago, in 2010. Ein deutsches Perfekt (\"haben gesehen\") wird dann mit dem Simple Past übersetzt, nicht mit have + Partizip. Unregelmäßige Verben haben eine eigene Vergangenheitsform (see – saw – seen); das Partizip (seen) steht nie allein als Vergangenheit.",
	"adverb_position": "Häufigkeitsadverbien (always, often, usually, never, sometimes) stehen vor dem Vollverb, aber nach einer Form von be: \"She often reads\", \"He is always late\". Im Simple Present bekommt das Verb nach he/she/it ein -s, auch wenn ein Adverb davorsteht.",
	"going_to_future": "be going to + Grundform für Pläne und Absichten, die schon feststehen: \"We are going to visit ...\". Das deutsche \"vorhaben\", \"planen\" oder ein Präsens mit Zukunftsbedeutung wird oft so übersetzt. Die Form von be muss zum Subjekt passen (I am, you/we/they are, he/she/it is). Zeitangaben müssen zur Zukunft passen (tomorrow, next week).",
	"present_perfect": "Present Perfect (have/has + Partizip: have lived, has been) für etwas, das in der Vergangenheit begonnen hat und bis jetzt andauert oder das jetzt noch wichtig ist. Das deutsche \"seit\" + Präsens wird mit dem Present Perfect übersetzt: for + Zeitdauer (for three years), since + Zeitpunkt (since 2020). Mit einem abgeschlossenen Zeitpunkt (yesterday, ago, in 2010) steht kein Present Perfect.",
	"comparative": "Steigerung beim Vergleich: kurze Adjektive mit -er (bigger, faster), lange Adjektive mit more (more interesting, more difficult). Nicht beides zugleich (nicht \"more bigger\"). Der Vergleich wird mit than angeschlossen (\"than the other one\"), nicht mit as oder then. Wer mit wem verglichen wird, muss wie im deutschen Satz bleiben.",
	"passive": "Passiv: Form von be + Partizip (is made, was built, were sold). Die Zeit steckt in be: wurde = was/were, wird = is/are. Ohne be ist der Satz aktiv und sagt etwas anderes (das Subjekt tut dann selbst etwas). Das Partizip unregelmäßiger Verben lernen: build – built, write – written. Steht der deutsche Satz im Passiv, steht auch die Übersetzung im Passiv: ein Aktiv-Satz („they built the bridge“) sagt zwar dasselbe, umgeht aber die Form, die geübt wird.",
	"conditional_1": "Bedingungssatz Typ 1 für etwas, das wirklich passieren kann: im if-Satz Simple Present, im Hauptsatz will + Grundform: \"If it rains, we will stay ...\". Im if-Satz steht kein will. Would gehört zu Typ 2 (nur vorgestellt, unwahrscheinlich) und passt hier nicht.",
	"question": "Fragen mit einem Vollverb brauchen do/does (Gegenwart) oder did (Vergangenheit), das Vollverb bleibt dann in der Grundform: \"When did you buy ...?\" (nicht \"did you bought\"). Die Zeit der Frage muss zum deutschen Satz passen: hast ... gekauft = did ... buy. Fragewort, Hilfsverb, Subjekt, Verb — in dieser Reihenfolge.",
	"gerund": "Nach bestimmten Verben und Ausdrücken steht die -ing-Form (Gerundium): enjoy, like/love/hate (für Vorlieben), be good at, be interested in, stop, finish. Nach einer Präposition (at, in, of, about) steht immer die -ing-Form, nie die Grundform oder to + Grundform.",
	"modals": "Modalverben (can, must, should, may, have to) stehen mit der Grundform ohne to: \"You must go\" (nicht \"must to go\", nicht \"must goes\"). Sie bekommen kein -s. Bedeutung beachten: must = müssen, mustn't = nicht dürfen (nicht: nicht müssen), don't have to / needn't = nicht müssen, can = können/dürfen, should = sollen.",
	"past_perfect": "Past Perfect (had + Partizip: had finished, had gone) für etwas, das VOR einem anderen Ereignis in der Vergangenheit passiert ist. Das deutsche Plusquamperfekt (\"hatte gesehen\", \"war gegangen\") wird so übersetzt. Die Form ist für alle Personen had, auch wo das Deutsche \"war\" sagt. Das Partizip unregelmäßiger Verben lernen (go – went – gone).",
	"present_continuous": "Present Progressive (am/is/are + -ing: she is reading) für etwas, das gerade jetzt passiert oder nur vorübergehend gilt. Signalwörter: now, at the moment, today. Die Form von be muss zum Subjekt passen; ohne be ist die -ing-Form kein vollständiges Verb. Für Gewohnheiten (always, every day) steht dagegen das Simple Present.",
	"future_simple": "will-Future (will + Grundform: it will rain) für Vorhersagen, Vermutungen und spontane Entschlüsse. will bekommt kein -s und steht ohne to; die Verneinung ist won't. Ein schon feststehender Plan steht eher mit be going to.",
	"present_simple": "Simple Present für Gewohnheiten, Tatsachen und Regeln (every day, usually, always). Nach he/she/it bekommt das Verb ein -s (she plays, he goes). Fragen und Verneinungen mit do/does, das Vollverb bleibt dann in der Grundform (does she play, he doesn't play).",
}

## Tags, unter denen der Bestand dieselbe Grammatik anders nennt. Ein zweiter Eintrag mit
## demselben Text liefe irgendwann auseinander.
const ALIASES := {
	"simple_past": "past_simple",
	"present_progressive": "present_continuous",
	"conditional_if": "conditional_1",
	"comparison": "comparative",
	"modal": "modals",
	"modal_verb": "modals",
	"modal_verbs": "modals",
	"wh_question": "question",
}


## Die Regel zu einem Tag, oder "" wenn der Katalog ihn nicht kennt.
static func rule_for(tag: String) -> String:
	return str(RULES.get(str(ALIASES.get(tag, tag)), ""))


## Die Regeln zu den `grammar_tags` eines Satzes, eine je Zeile mit Spiegelstrich — genau
## die Form, in der die Werkstatt sie in den Prompt setzt. Ein Tag ohne Regel fällt weg,
## zwei Tags derselben Regel ergeben eine Zeile.
static func focus(sentence: Dictionary) -> String:
	var lines := PackedStringArray()
	for tag in sentence.get("grammar_tags", []):
		var rule := rule_for(str(tag))
		var line := "- %s" % rule
		if not rule.is_empty() and not (line in lines):
			lines.append(line)
	return "\n".join(lines)
