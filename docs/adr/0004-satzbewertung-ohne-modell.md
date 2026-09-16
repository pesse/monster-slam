# ADR 0004 — Sätze bewerten, ohne ein Modell auszuliefern

Status: **angenommen** · Datum: 2026-09-16 · Baut auf: ADR 0001 (Pack-Kanal,
`min_app_version`) · Grenzt ab gegen: ADR 0002 (Rückkanal)

**Nachtrag vom 2026-09-16 am Ende dieses Dokuments: Stufe 0 gibt ohne Schlüsseltreffer
kein Urteil mehr ab.** Entscheidung 3 ist damit in einem Punkt verschärft, und Stufe 1 ist
für Bosskämpfe keine Kür mehr.

Umgesetzt am 2026-09-16, ohne den Kampf: `SentenceCard`, `SentenceJudge`,
`LocalModelBackend` und `SentenceSelector` stehen samt Tests und der Werkbank
`scenes/dev/boss_lab.tscn`, die ausgelieferten Sätze tragen den Schlüssel, und der Golem
hat seine Auswahlregel. Wer sie aufruft, ist weiter niemand — das ist das, was unter
„Nicht entschieden" steht.

## Kontext

Die Vision sieht Bosskämpfe als die zweite Aufgabenart vor: kein Zeitdruck, ein ganzer
Satz statt eines Wortes, und „ein LLM kann alternative Formulierungen akzeptieren und
semantisch bewerten, anstatt nur exakte Übereinstimmungen zu prüfen"
(`docs/VISION.md`). Angelegt ist das seit Langem und nirgends benutzt: die Signale
`boss_started`/`boss_sentence_presented`/`boss_answer_evaluated` haben keinen Emitter
(`src/core/event_bus.gd:28`), `ContentRegistry.sentences`/`sentence_lexemes` sind als
Kategorien vorhanden und leer, `data/bosses/grammar_golem.json` trägt zwei Sätze mit je
EINER `reference`, und `AnswerEvaluator.evaluate_sentence()` fällt auf eine
Token-Überschneidung zurück, deren Ergebnis niemand sehen sollte
(`src/learning/answer_evaluator.gd:110`).

Die Frage ist nicht, ob ein Sprachmodell besser bewertet als ein Wortabgleich — das tut
es. Die Frage ist, **was zur Laufzeit auf dem Rechner des Spielers laufen muss**. Das Spiel
wird als eine self-contained Windows-EXE an Schülerinnen und Schüler ausgeliefert (ADR
0001); die Zielhardware ist der Familien-Laptop, nicht die Entwicklungsmaschine. Ein
mitgeliefertes Modell wäre die größte Einzelentscheidung der Anwendung: es bestimmt die
Größe des Downloads, den Arbeitsspeicherbedarf, die Antwortzeit und die Frage, ob das
Spiel auf einem Gerät überhaupt startet.

Dazu kommt ein Umstand, der leicht übersehen wird: **ein kleines Sprachmodell ist als
Prüfer nicht nur ungenau, sondern auf eine schädliche Weise ungenau.** Es lehnt richtige
Antworten ab. In einem Lernspiel für Kinder ist ein zu Unrecht getadelter Satz der
teuerste Fehler, den das System machen kann — teurer als eine durchgewinkte falsche
Antwort und teurer als gar keine Bewertung. Wer einmal erlebt hat, dass das Spiel seine
richtige Übersetzung nicht anerkennt, glaubt ihm den nächsten Tadel nicht mehr.

## Entscheidung

### 1. Der Satz entsteht zur Autorenzeit, nicht zur Laufzeit

„KI-generiert" heißt: von Claude in der Pipeline erzeugt, die
`docs/prompts/vocab_generation.md` schon beschreibt, geprüft, und über den Pack-Kanal
ausgeliefert. Ein Satz ist **Inhalt und kein Ereignis** — er hängt an Unit und Wortschatz,
nicht an der Situation im Kampf. Ein ausreichend großer Vorrat je Unit, aus dem nach
Lernstand ausgewählt wird, ist vom Spielgefühl her nicht von Live-Erzeugung zu
unterscheiden und kostet zur Laufzeit nichts.

### 2. Der Lösungsschlüssel steht in den Daten

Dieselbe Offline-KI, die den Satz schreibt, schreibt **die Bewertungsgrundlage gleich
mit**. Das ist der eigentliche Hebel dieses ADR: Bewerten ist nur deshalb teuer, weil man
es als offene Aufgabe behandelt — dabei kennt der Autor den Satz, die geforderten Lexeme
(`sentence_lexemes` gibt es), die geprüfte Grammatik (`grammar_tags` gibt es) und die
typischen Fehler. Das `sentences`-Schema wächst deshalb um drei Felder:

```json
{
  "id": "sen.a4u1.reef",
  "source_text": "Gestern haben wir das Riff gesehen.",
  "reference_translation": "Yesterday we saw the reef.",
  "accepted": ["We saw the reef yesterday.", "Yesterday, we saw the reef."],
  "must_contain": [{"lexeme_id": "lex.en.a4.reef", "forms": ["reef", "reefs"]}],
  "pitfalls": [{"contains": ["have seen", "yesterday"],
                "feedback": "Mit *yesterday* steht das Simple Past: „saw\"."}],
  "grammar_tags": ["past_simple"], "difficulty": 2
}
```

`accepted` sind semantisch gleichwertige Lösungen, `must_contain` die Lexeme, um
derentwillen der Satz überhaupt gestellt wird (mit den zulässigen Formen aus
`lexeme_forms`), `pitfalls` die vorweggenommenen Fehler mit der Rückmeldung, die sie
verdienen. Eine Stolperstelle ist eine **Liste von Bestandteilen, kein regulärer
Ausdruck**: sie soll von einem Generierungslauf zuverlässig erzeugt und von einem Test
geprüft werden können, und ein fehlerhaftes Muster in den Daten darf nicht mehr kaputt
machen als eine ausbleibende Rückmeldung.

### 3. Bewertet wird in Stufen; Stufe 0 trägt das Spiel allein

```
Antwort ─► Stufe 0  Prüfkarte (offline, deterministisch, immer vorhanden)
             ├─ klarer Treffer oder bekannter Fehler ─► fertig
             └─ unsicher ─► Stufe 1  lokaler Dienst über HTTP (optional)
                              └─ Zeitlimit überschritten ─► Ergebnis aus Stufe 0
```

**Stufe 0 („Prüfkarte")** gleicht die Antwort gegen `accepted` ab — mit derselben
Normalisierung, die `AnswerEvaluator._variants()` für Vokabeln schon leistet (Artikel,
Platzhalter, Klammergruppen) —, prüft `must_contain` gegen die Formen und sucht die
`pitfalls`. Ergebnis ist eine Güte von 0 bis 1 und ein Rückmeldetext. Deterministisch, mit
gdUnit prüfbar, unter einer Millisekunde, ohne nennenswerten Speicherbedarf.

> **Verschärft durch den Nachtrag unten:** findet die Karte weder eine Lösung noch einen
> bekannten Fehler, gibt sie **gar keine** Güte aus (0 bei `sure == false`) statt einer
> geschätzten. Die Schätzung war eine Überschneidung von Wortmengen, und die winkte im
> Bosskampf genau das durch, was er übt.

**Stufe 1 ist nicht Teil der Auslieferung.** Wenn auf dem Rechner ein lokaler
Modell-Dienst läuft (Ollama, llama.cpp-Server, LM Studio — alle sprechen HTTP auf
`127.0.0.1`), benutzt das Spiel ihn; wenn nicht, existiert er für das Spiel nicht. Kein
GDExtension, keine Modellgewichte in der EXE, kein Pack mit Gewichten. Wer den Zusatz
will, installiert ihn; wer den schwachen Rechner hat, zahlt nichts dafür.

**Es gibt keine Stufe 2 in der Cloud.** Kindertexte gehen nicht ins Netz. Das ist der
Unterschied zu ADR 0002: dort steht ein eigener Server, aber er bekommt nur Ids und kennt
keine Wörter. Eine frei getippte Schülerantwort ist etwas anderes.

### 4. Ein Vertrag für alle Stufen, und er blockiert nie

`SentenceJudge` liefert `{ "quality": float, "feedback": String, "matched": String }` —
unabhängig davon, welche Stufe geantwortet hat. Die Naht dafür steht schon:
`AnswerEvaluator.sentence_backend` (`src/learning/answer_evaluator.gd:14`); sie wird
asynchron, weil Stufe 1 es sein muss.

**Stufe 0 wird immer zuerst gerechnet und liegt bereit**, während der Boss ausholt.
Antwortet Stufe 1 innerhalb des Zeitfensters, verfeinert sie das Ergebnis; antwortet sie
nicht, schlägt der Boss trotzdem zu. Kein Zustand des Kampfes hängt an einem Modell — die
Wartezeit ist Inszenierung, nicht Blockade.

## Folgen

**`min_app_version` muss steigen** (0.7.0 → 0.8.0; die App ist mit dieser Änderung auf
0.8.0 gegangen). Ein Client vor dieser Änderung liest `accepted`, `must_contain` und
`pitfalls` nicht; er würde einen Satz mit reichem Schlüssel gegen die eine
`reference_translation` prüfen und dabei still schlechter bewerten, als die Daten
hergeben. Genau dafür gibt es das Feld aus ADR 0001.

**Die Kategorienliste bleibt unberührt.** `sentences` und `sentence_lexemes` stehen bereits
in `_by_category` (`src/core/content_registry.gd:86`), in `CATEGORIES`
(`src/content/pack_installer.gd:20`), in `tools/packs/build_packs.py:62` und in den
`roots` von `data/language/packs.yaml`. Der Vierfach-Abgleich aus ADR 0003 entfällt hier —
es kommen Felder dazu, keine Kategorie.

**Die neuen Felder sind Lehrbuchmaterial.** `accepted` und `pitfalls` sind aus dem Satz
abgeleitet und der Satz aus der Unit; sie gehören ins private Submodule unter
`data/language/sentences/`, nicht ins Hauptrepo. `data/bosses/` bleibt öffentlich: ein
Boss ist Spielkonfiguration und trägt künftig **keine Sätze mehr selbst**, sondern eine
Auswahlregel. Die zwei Beispielsätze in `grammar_golem.json` müssen dabei verschwinden.

**Zwei Datentests, bevor der erste Satz ausgeliefert wird** (in der Art von
`tests/skill_data_test.gd`, das unbekannte Effektschlüssel abfängt, ehe ein bezahlter
Knoten wirkungslos bleibt):

- Keine Stolperstelle darf auf eine akzeptierte Lösung passen. Sonst steht irgendwann ein
  Satz im Pack, der eine richtige Antwort tadelt — der Fehler aus dem Kontext dieses ADR,
  nur eben in den Daten statt im Modell.
- Jedes `must_contain`-Lexem muss im Bestand stehen und seine Formen zu `lexeme_forms`
  passen.

**Die Sätze brauchen eine Werkbank**, `scenes/dev/boss_lab.tscn`, nach dem Vorbild von
`chest_lab.tscn`: Satz wählen, Antwort tippen, Bewertung und Rückmeldung beider Stufen
nebeneinander sehen. Um eine Bewertungsregel zu beurteilen, will man zwanzig Antworten
durchprobieren und nicht zwanzig Wellen spielen. `scenes/dev/*` und `src/dev/*` stehen
schon im `exclude_filter`.

**Die Auswahl benutzt das vorhandene Schwierigkeitsmaß.** Welcher Satz drankommt, ergibt
sich aus `sentence_lexemes` → Lexem → `book`/`unit` gegen `UserSettings.selected_scope()`,
gewichtet nach `PlayerProgress.confidence` — dieselbe Rechnung, die `WaveGenerator` für
Monster fährt. Kein zweites Maß daneben, aus demselben Grund, aus dem XP und Punkte sich
eines teilen.

**Gelernt wird über die vorhandenen Wege**: `item_reviewed` je beteiligtem Lexem, mit
`correct` an einer Güteschwelle. Der Satz ist damit im Spaced-Repetition-Bestand dasselbe
Ereignis wie ein besiegtes Monster, und der Lernstand bleibt eine Quelle.

## Verworfene Alternativen

Der volle Recherchestand — welche kleinen en↔de-Modelle es gibt, was sie wiegen, unter welcher Lizenz sie stehen und was noch zu messen wäre — liegt in
[`../SATZBEWERTUNG_MODELLE.md`](../SATZBEWERTUNG_MODELLE.md).

**Ein Sprachmodell in der EXE.** Ein 0,6-B-Modell in Q4 kostet grob 500–700 MB
Arbeitsspeicher und braucht auf einem älteren Laptop mehrere Sekunden je Urteil; brauchbar
zu bewerten beginnen Modelle etwa ab 3 B, also bei rund 2,5 GB. Das erste ist zu schlecht,
das zweite zu groß — und beides bezahlt jeder Spieler, auch der, dessen Antwort Stufe 0
längst erkannt hat.

**Ein Übersetzungsmodell statt eines Sprachmodells.** Spezialisierung schlägt Größe: ein
`opus-mt-de-en` wiegt rund 300 MB, int8-quantisiert ein Viertel davon, und übersetzt sein
Paar besser als manches Vielfache seiner Größe. Nur beantwortet es die falsche Frage. Es
übersetzt, es bewertet nicht, und es schreibt keine Rückmeldung. Als *Bewerter* wäre die
passende Familie die Qualitätsschätzung (COMETKiwi, xCOMET-lite) — die liefert eine Zahl
ohne Begründung, und für die Begründung ist der Schlüssel aus Entscheidung 2 ohnehin
besser, weil er weiß, worum es in der Aufgabe ging.

**Ein Embedding-Modell für semantische Ähnlichkeit** (mehrsprachiges MiniLM, int8, rund
150 MB, wenige Dutzend Millisekunden) ist der ernsthafteste verworfene Kandidat: es
verträgt Umformulierungen, die in `accepted` nicht stehen. Es liefert aber nur eine Zahl,
verlangt eine native Erweiterung je Plattform und einen Modell-Download. Es bleibt als
mögliche Stufe 1b vorgemerkt — der Vertrag aus Entscheidung 4 hält die Tür offen, ohne
dass ein Aufrufer davon weiß.

## Nicht entschieden

**Der Kampf selbst.** Wie die Szene aussieht, wie Güte zu Schaden wird, wie viele Sätze
ein Boss hat und ob er im Lauf nach Welle N steht oder ein eigener Einstieg am
Startbildschirm ist — das ist eine Gestaltungsfrage und wird hier bewusst nicht
beantwortet. Dieses ADR entscheidet, **woher die Bewertung kommt**; das ist die
Festlegung, die sich später teuer korrigieren ließe, weil Daten, Pack-Version und
ausgelieferte Binärgröße daran hängen. Die Szene lässt sich jederzeit anders bauen — sie
konsumiert `SentenceJudge` und `SentenceSelector` und hat keinen eigenen Zugriff auf die
Bewertung.

---

## Nachtrag 2026-09-16: ohne Urteil kein Treffer

**Anlass.** Der Antwortbogen aus `docs/SATZBEWERTUNG_MODELLE.md` (63 getippte Antworten zu
10 Sätzen mit vollem Schlüssel) wurde gegen Stufe 0 gerechnet. Ergebnis in der ersten
Fassung: 2 Falsch-Negative, aber **4 Falsch-Positive — und alle sechs Fehlurteile stammten
aus demselben Zweig**, dem Fall ohne Schlüsseltreffer. Die 38 Antworten, bei denen die
Karte `sure` meldete, waren ausnahmslos richtig eingeordnet.

**Der Fehler war die Schätzung.** Fand die Karte nichts, gab sie `SentenceCard.overlap()`
als Güte aus: ein F1 über Wort*mengen*. „Always she walks to school." enthält exakt
dieselben Wörter wie „She always walks to school." und bekam damit **1,00** — nicht knapp
über einer Schwelle, sondern die volle Punktzahl. Reihenfolge und Beugung sind für dieses
Maß bauartbedingt unsichtbar. Über alle Schwellen von 0,40 bis 0,80 blieb der Befund
gleich; es war nie eine Frage der Einstellung.

Damit fiel eine Annahme dieses ADR: die Abwägung „ein zu Unrecht getadelter Satz ist der
teuerste Fehler" ist für die **Vokabel**seite formuliert, wo der Schlüssel den Antwortraum
wirklich abdeckt. Ein Bosskampf prüft Satzbau und Konjugation. Dort ist die durchgewinkte
falsche Antwort genauso teuer: sie bestätigt die falsche Form als richtig, und zwar genau
an der Stelle, um derentwillen die Aufgabe gestellt wird.

**Entscheidung.** Ohne Schlüsseltreffer gibt die Prüfkarte kein Urteil ab:

- `quality` ist dort `SentenceCard.NO_VERDICT` (0). Eine Antwort ohne Urteil ist **kein
  Treffer**, bei welcher Schwelle auch immer.
- Die Nähe am Wortlaut bleibt als eigenes Feld `overlap` erhalten. Sie wählt die
  Rückmeldung („nah dran" gegen „ein anderer Satz") und **urteilt nicht**.
- `sure` ist damit der einzige Weg zu einem Treffer: entweder die Karte hat einen Grund,
  oder Stufe 1 hebt an.

**Folge: Stufe 1 wird tragend.** Sie ist jetzt das Einzige, was aus einem Zweifel einen
Treffer machen kann. Zugleich trägt die Regel „nur heben, nie senken" erst dadurch
richtig: die falschen Antworten im Topf ohne Urteil sind bereits abgewiesen, ein Modell
kann sie gar nicht mehr durchwinken — anzuheben hat es nur, was richtig und bloß nicht
hinterlegt ist. Was vorher eine Einschränkung war, ist damit die passende Regel.

Am Bogen gemessen (Schwelle 0,60):

| | vorher | nachher |
|---|---|---|
| Falsch-Positive | 4 von 26 (15,4 %) | **0 von 26** |
| Falsch-Negative | 2 von 37 (5,4 %) | 12 von 37 (32,4 %) |
| ohne Urteil | 25 von 63 | 25 von 63 — davon 12 richtig, 13 falsch |

Die 12 Falsch-Negativen sind exakt die richtigen Antworten im Topf ohne Urteil. Sie sind
damit **der Auftrag an Stufe 1** und ihr Erfolgskriterium: 0 Falsch-Positive halten und
diese Zahl Richtung 2 drücken. Vorher hätte ein Modellversuch keinen Maßstab gehabt.

**Was das für den Kampf heißt** (der weiter unentschieden ist, siehe „Nicht entschieden"):
„ohne Urteil" ist ein dritter Ausgang neben richtig und falsch und sollte auch so
aussehen — Musterlösung zeigen, kein Schaden, keine Gutschrift —, statt als Treffer oder
als Tadel verbucht zu werden. Wer den Kampf baut, entscheidet das; der Vertrag hält die
Unterscheidung in `sure` bereit.

**Nicht geändert.** Die Rückmeldungen, die Stolperstellen, `must_contain`, die
Normalisierung und `min_app_version`. Es ist eine Änderung an der Bewertung, nicht an den
Daten — ein Pack von gestern verhält sich mit dieser App genauso wie einer von morgen.

Gehalten von `tests/sentence_card_test.gd`
(`test_without_a_verdict_nothing_scores`,
`test_the_same_words_in_the_wrong_order_are_not_a_hit`) und nachgerechnet von
`tools/godot.sh res://scenes/dev/measure_sentences.tscn`, das die beiden Lesarten
gegeneinander prüft und anschlägt, sobald wieder eine Güte ohne Urteil auftaucht.
