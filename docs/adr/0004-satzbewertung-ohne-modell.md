# ADR 0004 — Sätze bewerten, ohne ein Modell auszuliefern

Status: **angenommen** · Datum: 2026-09-16 · Baut auf: ADR 0001 (Pack-Kanal,
`min_app_version`) · Grenzt ab gegen: ADR 0002 (Rückkanal)

**Nachtrag vom 2026-09-16 am Ende dieses Dokuments: Stufe 0 gibt ohne Schlüsseltreffer
kein Urteil mehr ab.** Entscheidung 3 ist damit in einem Punkt verschärft, und Stufe 1 ist
für Bosskämpfe keine Kür mehr.

**Zweiter Nachtrag vom 2026-09-16: Stufe 1 steht nicht mehr nur herum, sie wird
mitgeliefert.** Entscheidung 3 ist damit in ihrem zweiten Absatz überholt — „kein Pack mit
Gewichten" gilt nicht mehr.

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

> **Überholt durch den zweiten Nachtrag unten:** „kein Pack mit Gewichten" hieß in der
> Praxis „nur für Leute, die ohnehin Ollama betreiben" — und das ist nicht der
> Familien-Laptop, für den dieses Spiel gebaut wird. Das Spiel bringt den Dienst jetzt
> selbst mit, optional und auf Nachfrage. Was bleibt: **kein** Modell in der EXE, und wer
> es nicht holt, zahlt nichts dafür.

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

---

## Nachtrag 2026-09-16: Stufe 1 auf eigenen Beinen

**Anlass.** Der erste Nachtrag macht Stufe 1 für Bosskämpfe tragend: sie ist das Einzige,
was aus einem Zweifel einen Treffer macht. Damit wird die Formulierung aus Entscheidung 3
— „wenn auf dem Rechner ein lokaler Modell-Dienst läuft, benutzt das Spiel ihn" — zur
Aussage, dass Bosskämpfe nur für Leute richtig funktionieren, die Ollama betreiben. Das
ist nicht die Zielgruppe. Die Zielgruppe ist der Familien-Laptop einer Neuntklässlerin,
und dort heißt „installier dir vorher Ollama und lade ein Modell" schlicht: findet nicht
statt.

**Was daran wirklich falsch war.** Entscheidung 3 hat zwei Dinge in einen Satz gepackt,
die nichts miteinander zu tun haben:

1. *In der EXE liegt kein Modell.* Das steht und ist der Kern dieses ADR — die Größe des
   Downloads, der Speicherbedarf und die Frage, ob das Spiel auf einem schwachen Gerät
   startet, hängen daran. Auch: **jeder** Spieler bezahlte es, auch der, dessen Antwort
   Stufe 0 längst erkannt hat.
2. *Den Dienst stellt jemand anders hin.* Das war keine Entscheidung, sondern eine
   Bequemlichkeit. Sie kostet nichts, solange Stufe 1 Kür ist, und sie kostet die halbe
   Aufgabenart, sobald sie es nicht mehr ist.

Der zweite Punkt fällt. Der erste bleibt — und er bleibt gerade dadurch, dass der Zusatz
**optional und auf Nachfrage** kommt: wer ihn nicht holt, lädt nichts, belegt nichts und
spielt dieselbe Stufe 0 wie vorher.

### Entscheidung: llama-server statt einer Fremd-App

Bedient wird `llama-server.exe` aus [llama.cpp](https://github.com/ggml-org/llama.cpp) —
ein Programm ohne Abhängigkeiten, MIT-Lizenz, das dieselbe OpenAI-Form spricht wie Ollama
und LM Studio. Das Spiel startet es als Kindprozess und beendet es wieder.

Gegen die Alternative — den Nutzer eine der fertigen Anwendungen installieren lassen
(Ollama, LM Studio, Jan, GPT4All, Foundry Local) — sprechen drei Dinge, und keines davon
ist technisch:

- Es ist **eine zweite Anwendung** mit eigenem Updatezyklus, eigenem Autostart und einem
  Serverschalter, der an sein muss. Wer ihn vergisst, sieht kein Modell und weiß nicht,
  warum.
- Der **Modell-Download passiert dort**, in einer fremden Oberfläche, in einer Größe und
  Auswahl, über die wir nichts sagen. Welches Modell geladen ist, entscheidet dann die
  Qualität unserer Bewertung, und wir haben es nicht gemessen.
- Die **Unterstützungslast landet trotzdem bei uns** („das Spiel sagt, es findet kein
  Modell"), während die Ursache in Software liegt, die wir nicht ausgeliefert haben.

`llama-server` dreht das um: eine Datei, ein Aufruf, ein Port, ein Modell, das wir
ausgesucht und gegen den Antwortbogen gemessen haben.

**Ausgeliefert wird das als optionaler Pack** — dieselbe Mechanik wie bei den Inhalten
(ADR 0001), dieselbe Signatur, dasselbe Ziel `user://`. „Für Benutzer installierbar" heißt
damit: ein Knopf im Einstellungs-Screen, kein Kommandozeilenaufruf.

**`--host 127.0.0.1` steht ausdrücklich in der Argumentliste**, obwohl llama-server ohnehin
so vorbelegt ist. Eine Voreinstellung kann sich ändern; die Entscheidung, dass Kindertexte
diesen Rechner nicht verlassen, soll man in den Argumenten lesen können. **Es gibt weiter
keine Stufe 2 in der Cloud.**

### Was jetzt gebaut ist: der Durchstich

Bewusst der dünnste Pfad, der end-to-end trägt — Feintuning kommt danach, sonst optimiert
man an einem Weg, der noch gar nicht steht.

- **`LocalModelServer`** (`src/learning/local_model_server.gd`) startet
  `user://model/llama-server.exe` mit `user://model/model.gguf`, wartet auf `/health` und
  beendet den Prozess wieder — auch in `_exit_tree()`, sonst bleibt nach einem Messlauf
  ein Dienst stehen und der nächste findet den Port belegt.
- **An der Bewertung ändert sich nichts.** `LocalModelBackend` bekommt eine andere `url`,
  mehr nicht. Das ist der Beleg dafür, dass der Vertrag aus Entscheidung 4 die richtige
  Naht hatte: wer den Dienst hinstellt, geht die Bewertung nichts an.
- **`LocalModelBackend.http_timeout`** ist jetzt verstellbar (Vorgabe bleibt
  `HTTP_TIMEOUT`, 3,5 s). Ein 3-B-Modell auf der CPU ist danach nicht fertig; ohne diese
  Naht lief jede Anfrage einer Messung in den Abbruch und wurde als „kein Dienst
  erreichbar" gemeldet, während der Dienst einwandfrei rechnete. Im Kampf bleibt es bei
  3,5 s — der Boss holt vier Sekunden lang aus.
- **Gemessen wird damit**, nicht ausprobiert:
  `tools/godot.sh res://scenes/dev/measure_sentences.tscn -- --serve --timeout=60` startet
  den Dienst selbst und rechnet denselben Antwortbogen wie zuvor. Fehlt etwas, sagt das
  Skript, **wo** es gesucht hat.

Fehlt Programm oder Gewichte, ist das kein Fehler, sondern der Normalfall: `start()` gibt
`false` zurück, der Grund steht in `last_note`, und das Spiel bleibt bei Stufe 0. Genau
wie ein nicht laufender Ollama vorher.

### Und der Weg dorthin: ein Knopf, keine Anleitung

Der Durchstich verlangte, zwei Dateien von Hand nach `user://model/` zu legen. Das ist als
Nachweis in Ordnung und als Auslieferung nichts: **Eltern legen keine Dateien in ein
AppData-Verzeichnis.** Ein Zusatz, den man sich zusammensuchen muss, ist eine Anleitung,
und eine Anleitung erreicht die Zielgruppe dieses Spiels nicht.

`ModelService` (Autoload, `src/content/model_service.gd`) holt beides hinter einem Knopf in
der Inhalte-Verwaltung. Was dabei entschieden ist:

**Wir spiegeln nichts.** llama.cpp und die Gewichte liegen dauerhaft im Netz; ein eigener
Spiegel köstete Speicherplatz und Pflege, ohne etwas zu gewinnen. Was wir liefern müssen,
ist nicht die Datei, sondern die Zusicherung, **welche** Datei gemeint ist — und das ist
die Prüfsumme.

**Damit hängt die Sicherheit dieses Weges an `sha256` und an nichts sonst.** Das Manifest
nennt für jeden Teil URL, Prüfsumme und Größe; was nicht passt, wird verworfen und nicht
installiert. `tools/model/make_manifest.py` rechnet die Prüfsummen selbst aus, statt sie
von einer Webseite abzuschreiben — eine abgeschriebene Prüfsumme sichert nur zu, dass der
Download zu der Webseite passt.

**Das Manifest liegt im Release-Kanal**, neben dem Pack-Verzeichnis (`model.json` neben
`index.json`). Ein anderes Modell ist damit eine Datei und kein App-Release. Es ist wie
`index.json` unsigniert — dieselbe Haltung wie in ADR 0001, und die Prüfsumme darin ist
das, was zählt:

```json
{
  "name": "Sprachmodell für Bosskämpfe",
  "min_app_version": "0.8.0",
  "parts": [
    {"file": "llama-server.exe", "url": "https://…/llama-bXXXX-bin-win-cpu-x64.zip",
     "sha256": "…", "bytes": 21000000, "unzip": true},
    {"file": "model.gguf", "url": "https://huggingface.co/…/resolve/<commit>/….gguf",
     "sha256": "…", "bytes": 1100000000}
  ]
}
```

**Aus einem Archiv kommt nur, was das Programm zum Laufen braucht** (`.exe`, `.dll` — ohne
seine DLLs startet llama-server nicht). Übernommen wird dabei **nur der Dateiname, nie der
Pfad im Archiv**: ein Eintrag wie `../../autostart.exe` landet damit im Zielverzeichnis
statt im Autostart, und zugleich ist es egal, ob ein llama.cpp-Release seine Dateien in der
Wurzel oder unter `build/bin` führt.

**Entfernen gehört dazu.** Ein Gigabyte, das man nicht mehr braucht, muss man auch wieder
loswerden können — sonst ist der Knopf eine Einbahnstraße.

**Die Größe steht vor dem Klick**, nicht danach. „Einmalig 1,1 GB" ist die Angabe, nach der
die Entscheidung fällt.

### Noch nicht gebaut

Das Folgende gehört zur Entscheidung, aber nicht zum Durchstich — es steht hier, damit
niemand es für vergessen hält:

- **SmartScreen.** Eine heruntergeladene, nicht von uns signierte `.exe` bekommt unter
  Windows eine Warnung, sobald jemand sie doppelklickt. Das Spiel startet sie als
  Kindprozess, was diesen Weg wahrscheinlich umgeht — *wahrscheinlich* ist hier aber nicht
  gemessen, und es ist das größte offene Risiko der Route.
- **Welches Modell.** `docs/SATZBEWERTUNG_MODELLE.md` empfiehlt EuroLLM-1.7B-Instruct
  (Apache 2.0, für genau diese Sprachrichtung gebaut). Entschieden wird das am
  Antwortbogen und nicht an der Modellkarte: **0 Falsch-Positive halten und die 12
  Falsch-Negativen Richtung 2 drücken.** Solange diese Zahl nicht gemessen ist, ist auch
  nicht entschieden, ob der Zusatz überhaupt ausgeliefert wird — ein Gigabyte für zwei
  Antworten wäre keine gute Abwägung. **Das `model.json` steht deshalb noch nicht im
  Release-Kanal**: der Knopf ist gebaut, das Ziel ist gewählt, das Modell nicht.
  `tools/model/make_manifest.py` erzeugt es, sobald es so weit ist.
- **Der Lebenszyklus im Spiel**: wann der Dienst startet (beim Spielstart? vor dem
  Bosskampf?), was bei einem Absturz passiert, und ob ein zweites laufendes Spiel den Port
  streitig macht. Der Durchstich startet ihn einmal für einen Messlauf.
- **Der Schlüssel zuerst.** Die 12 Falsch-Negativen sind richtige Antworten, die bloß
  nicht in `accepted` stehen. Jede Zeile dort kostet zur Autorenzeit nichts und wirkt bei
  jedem Spieler sofort — ohne Download. Was der Schlüssel schafft, muss kein Modell
  schaffen.

Gehalten von `tests/local_model_server_test.gd` und `tests/model_service_test.gd`. Kein
Test startet einen Prozess, keiner lädt etwas herunter und keiner spricht mit 127.0.0.1:
Programm und Gewichte liegen in keinem Repo, und ein Test, der sie bräuchte, wäre auf
jedem anderen Rechner rot. Geschrieben wird in ein `zz-`Verzeichnis — unter `user://model`
liegt auf einem Entwicklungsrechner das echte Modell.
