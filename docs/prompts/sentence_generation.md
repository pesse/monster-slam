# Sätze für den Bosskampf erzeugen

Vorgabe für einen Generierungslauf (Lauf #4, `docs/CONTENT_GENERATION_RUNS.md`). Sie fasst
zusammen, was die Messungen in der Werkstatt `prompt-eval` über gute Sätze gelernt haben
(`STAND.md`, `befunde/2026-09-25-war-geschlossen.md`). Die Sätze selbst liegen im privaten
Submodule, je Unit eine Datei: `sentences/en_<band>_unit<n>.json` und
`sentence_lexemes/en_<band>_unit<n>.json`.

## Warum die Sätze so aussehen müssen

- **Der Satz entscheidet mehr als der Prompt.** Stimmen Tag, deutscher Text und
  Musterlösung nicht überein, lehnt das Modell richtige Antworten ab und erklärt einen
  Fehler, den es nicht gibt. Eine passende Musterlösung repariert Urteil und Erklärung;
  eine schärfere Regel repariert nur die Erklärung.
- **Was sich vorhersehen lässt, gehört in die Daten.** Eine Lösung in `accepted`
  entscheidet die Prüfkarte sofort und sicher, eine Stolperstelle in `pitfalls` bekommt
  eine richtige Rückmeldung. Das Modell ist nur für das Unvorhersehbare da.
- **Einzelsätze.** Der Bosskampf stellt einen Satz je Aufgabe (ADR 0005).

## Regeln je Satz

1. **Ein Satz, 6 bis 16 Wörter**, kindgerecht, zum Thema der Unit. Eigene Sätze, keine
   aus dem Lehrbuch abgeschrieben.
2. **Mindestens ein Wort der Unit** steht im Satz und in `must_contain`, höchstens zwei.
   Alle Wörter der Unit, die im Satz vorkommen, stehen in `lexeme_ids`.
3. **Ein Grammatikschwerpunkt**, höchstens zwei, und nur Tags aus dem Katalog
   (`src/learning/grammar_rules.gd`, `GrammarRules.RULES`): `present_simple`,
   `present_continuous`, `past_simple`, `present_perfect`, `past_perfect`,
   `going_to_future`, `future_simple`, `passive`, `conditional_1`, `comparative`,
   `modals`, `gerund`, `question`, `adverb_position`. Keine Schreibvarianten.
4. **Der deutsche Satz legt die englische Form eindeutig fest.** Tag, deutscher Text und
   Musterlösung tragen dieselbe Form:
   - `past_perfect`: nur echtes Plusquamperfekt, also „hatte“ + Partizip oder „war“ +
     Partizip eines Verbs der Bewegung oder Veränderung (gegangen, gekommen, passiert,
     eingeschlafen). Dazu gehört ein zweites, späteres Ereignis im Satz (als, nachdem,
     bevor). **Nie** „war geschlossen / kaputt / fertig“: Das ist ein Zustand und wird
     mit „was“ + Adjektiv übersetzt.
   - `passive`: Vorgangspassiv mit „werden“ (wird, wurde, ist … worden, wird … werden).
     Die Übersetzung muss im Passiv stehen; eine Aktiv-Fassung ist falsch. Kein
     Zustandspassiv („ist geöffnet“).
   - `present_perfect`: mit Signalwort (seit, schon, noch nie, gerade eben, jemals,
     bisher). Ein deutsches Perfekt ohne Signalwort ist meist Simple Past. Ist beides
     richtig, stehen beide Fassungen in den Lösungen.
   - `past_simple`: mit einer abgeschlossenen Zeitangabe (gestern, letzte Woche, vor
     zwei Jahren, eine Jahreszahl).
   - `present_continuous`: mit „gerade“, „jetzt“ oder „im Moment“.
   - `going_to_future`: ein Plan oder eine Absicht („haben vor“, „wollen“ + Plan).
     `future_simple`: eine Vorhersage oder Vermutung („wahrscheinlich“, „bestimmt“).
     Deutsches „will“ heißt „want“, nicht „will“.
   - `conditional_1`: „Wenn“ + Präsens, im if-Satz kein „will“.
   - `modals`: „muss nicht“ ist „don't have to“, „darf nicht“ ist „mustn't“.
   - `adverb_position`: Häufigkeitsadverb vor dem Vollverb, nach „be“.
   - `present_simple`: Gewohnheit oder Tatsache, he/she/it mit -s.
5. **Die Musterlösung** ist die natürliche englische Fassung, die dem Deutschen am
   nächsten ist, in britischer Schreibung.
6. **`accepted`: jede andere richtige Fassung, die ein Kind realistisch schreibt.**
   Zeitangabe am Anfang oder am Ende, andere richtige Wörter für Wörter, die nicht aus
   der Unit sind, beide Zeitformen, wo beide richtig sind. Kommas und Kurzformen („don't“
   / „do not“) ergänzt das Zusammenführungsskript selbst.
   **Nie** eine Fassung, die die geübte Form umgeht (Aktiv statt Passiv, Simple Past
   statt Past Perfect) oder das Wort der Unit nicht enthält.
7. **`must_contain`**: je Wort die Formen, die im Satz vorkommen dürfen, und zwar nur
   Formen aus dem Bestand (Lemma, `lemma_en_alt`, `lexeme_forms`), wörtlich. Steht die
   Form, die der Satz braucht, nicht im Bestand (etwa ein Plural), gehört das Wort nicht
   in `must_contain`.
8. **`pitfalls`: ein bis drei vorhersehbare Fehler zur geübten Form.** `contains` sind
   die wenigen Wörter, an denen der Fehler eindeutig zu erkennen ist. Sie dürfen in
   keiner richtigen Lösung zusammen vorkommen. `feedback` ist ein deutscher Satz, der
   die richtige Form nennt und keine falsche Regel behauptet.
9. **`difficulty`** 1 bis 4: 1 ein Hauptsatz mit einer Form; 2 mit Zeitangabe oder
   Objekt; 3 mit Nebensatz; 4 zwei Formen oder schwierige Wortstellung. Der
   Grammatik-Golem zieht derzeit alle Stufen.

## Verteilung je Band

| Band | Klasse | Tags |
|---|---|---|
| Access 2 | 6 | present_simple, present_continuous, past_simple, going_to_future, future_simple, comparative, modals, question, adverb_position; wenig present_perfect; kein Passiv, kein Past Perfect |
| Access 3 | 7 | wie Access 2, dazu present_perfect, conditional_1, gerund, einfaches Passiv |
| Access 4 | 8 | alle, Schwerpunkt past_perfect, passive, present_perfect, conditional_1, gerund |

Rund 40 Sätze je Unit, davon mindestens 25 mit einer Zeitform oder dem Passiv. Der Golem
zieht derzeit alle Sätze der Auswahl (`data/bosses/grammar_golem.json` ohne
`grammar_tags`); eine engere Regel soll später genug Vorrat finden. Verteilung der
Schwierigkeit etwa 10 / 15 / 10 / 5.
