# ADR 0005 — Der Bosskampf: Urteil und Erklärung in zwei Aufrufen

Status: **angenommen** · Datum: 2026-09-25 · Baut auf: ADR 0004 (Stufen, Prüfkarte,
lokaler Dienst) · Ersetzt: in ADR 0004 den Nachtrag vom 2026-09-17 in der Modellwahl und
in „Was daraus zu bauen ist"

## Kontext

ADR 0004 hat die Bewertung in Stufen gebaut und den Kampf offen gelassen: Prüfkarte,
Richter, Backend und Werkbank standen, aufgerufen hat sie niemand. Der Nachtrag vom
2026-09-17 wählte Qwen3-4B für das **Urteil** — richtig oder falsch. Was ein Kind in einem
Bosskampf aber am dringendsten braucht, ist das **Warum**: „falsch" ohne Grund übt nichts,
und die Musterlösung daneben zeigt nur, *dass* etwas anders ist.

Gemessen wurde das in der Werkstatt `prompt-eval` (eigenes, privates Repo; die Zahlen im
Einzelnen in dessen `STAND.md`, Nachträge 24. und 25.09.) gegen den Antwortbogen dieses
Repos und gegen erfundene Mehrsatz-Texte. Geprüft wurden Satzlänge (ein Satz, zwei bis
drei, fünf), Hinweise im Prompt (Lösungsschlüssel, Regelkatalog, Stolperstellen, Kontext)
und Prompt-Formen (freier Text, Felder, Rückübersetzung als Beleg) — über fünf Modelle,
bewertet von einem zweiten Modell gegen das `why` der Lehrkraft. Ergebnis:

| Aufgabe | Kette | gut | Schaden¹ | CPU, alle Kerne / 4 Threads |
|---|---|---|---|---|
| ein Satz | Urteil B-de → Erklärung X-ref-regel | 25/32 | 3 | 8,9 s / 12,1 s |
| 2–3 Sätze | B-abdeckung → X-ref-regel | 32/42 | 3 | 13,2 s / 20,4 s |
| 5 Sätze am Stück | beste Kette | 24/42 | 4 | — |
| 5 Sätze, Satz für Satz | mit Sperre je Satz | 33/42 | 6 | 34 s / 48 s (Ø) |

¹ Schaden: eine falsche Antwort durchgewinkt, eine richtige getadelt, oder eine Erklärung,
die etwas Falsches behauptet. Der verbliebene Schaden ist fast durchweg mild — die richtige
Form stimmt, ein Detail der Begründung nicht.

Zeiten auf einem i9-14900HX ohne GPU, Median einer falschen Antwort (beide Aufrufe). Das
Urteil allein steht nach 2,9 s / 5,1 s.

## Entscheidung

### 1. Zwei Aufrufe: erst das Urteil, dann die Erklärung

**Aufruf 1 urteilt** — mit Lösungsschlüssel (Musterlösung, `accepted`, geforderte Wörter),
binär, auf Deutsch begründet. Das ist die Fassung „B-de" aus der Werkstatt.

**Aufruf 2 erklärt** — nur wenn Aufruf 1 „falsch" sagt, und **ohne** Lösungsschlüssel,
dafür mit den Regeln zu den `grammar_tags` des Satzes („X-ref-regel"). Ohne Schlüssel kann
das Modell nicht über den Schlüssel reden, und es urteilt ein zweites Mal unabhängig:
**findet der Erklärer keinen Fehler, zeigt das Spiel keine Erklärung**, sondern nur die
Musterlösung. Das fängt den Fall, in dem Aufruf 1 eine richtige Antwort abweist — sonst
erklärte das Spiel einem Kind einen Fehler, den es nicht gemacht hat.

Die Begründung, die Aufruf 1 selbst mitliefert, wird nicht gezeigt: sie ist mit dem
Schlüssel vor Augen geschrieben und redet über ihn, und gemessen wurde nur die des
Erklärers. Wer nachfragt, warum es kein Aufruf ist: der Abgleich zwischen zwei
unabhängigen Blicken ist genau das, was die abgewiesenen richtigen Antworten auffängt.

**Das Urteil wird sofort gezeigt**, die Erklärung kommt nach. Der Golem reagiert nach
3–7 Sekunden; was das Kind liest, während die Erklärung rechnet, ist das Ergebnis.

### 2. Der Vertrag: Stufe 1 hebt weiter nur — und erklärt, wo sie nicht hebt

Die Regel aus ADR 0004 bleibt in ihrer Sache stehen: **die Güte kann durch ein Modell nur
steigen.** Gefragt wird es nur, wo die Karte kein Urteil hat (Güte 0); sagt es „richtig",
wird daraus ein Treffer, sagt es „falsch", bleibt es bei 0. Ein Treffer der Karte in
`accepted` schlägt jedes Modell.

Neu ist, dass das Modell dort **erklären** darf, wo es nicht hebt. Bisher blieb an dieser
Stelle die Rückmeldung der Karte stehen („Nah dran. Vergleiche Wort für Wort."), weil der
Tadel eines Modells genau die Fehlerart war, gegen die ADR 0004 schützt. Die Messung zeigt,
dass ein zweiter, unabhängiger Aufruf ohne Schlüssel diesen Tadel so weit abfängt, dass
die Erklärung mehr hilft als schadet — und sie ist das, was der Kampf lehren soll.

`SentenceJudge` bekommt dafür zwei Signale: `denied` (Stufe 1 bestätigt: kein Treffer) und
`explained` (die Erklärung, oder leer, wenn es keine gibt).

### 3. Gemma 4 E4B statt Qwen3-4B

`gemma-4-E4B-it` als `Q4_0` (4,6 GB, Apache 2.0) aus `ggml-org/gemma-4-E4B-it-GGUF`,
festgenagelt auf einen Commit, mit llama.cpp `b11002`. Beide lassen keine falsche Antwort
durch (Urteil 47/51 gegen 46/51), aber Gemma erklärt besser — 20 gegen 17 von 32 ohne
Regelkatalog — und nur Gemma zieht aus dem Regelkatalog reproduzierbar Nutzen (+5 und +9
gute Erklärungen in zwei Läufen). Die Erklärung ist der Grund für den Umbau. Der Preis
ist die Größe: fast doppelt so viel Download, auf einem Rechner mit 8 GB Arbeitsspeicher
eng. Gemma braucht `--reasoning off` am Dienst, sonst denkt es im Klartext und erreicht
das JSON nie.

### 4. Einzelsätze zuerst, Textportionen später

Der Bestand kennt nur Einzelsätze; es gibt kein Feld, das Sätze zu einem Text verbindet.
Der erste Bosskampf stellt deshalb **fünf Einzelsätze** nacheinander. Portionen von zwei bis
drei Sätzen sind gemessen und besser als ein ganzer Text am Stück, brauchen aber ein neues
Satzfeld (Text-Id und Position) im Submodule und damit ein höheres `min_app_version` am
Pack, der die Sätze trägt — das ist eine eigene Entscheidung und nicht Teil dieser.

### 5. Prompts und Regelkatalog stehen im Code, gemessen wird in der Werkstatt

`StageOnePrompts` und `GrammarRules` (beide `src/learning/`) sind GDScript und keine
Datendateien: der Export nimmt nur Ressourcen mit, und ein Prompt gehört mit seiner
Auswertung zusammen — wer ihn ändert, ändert, was `parse_verdict` zu lesen bekommt.

**Die Werkstatt ist der Ort, an dem ein Prompt geändert wird**; hierher kommt er erst, wenn
er dort gemessen ist, und zwar wörtlich. Eine Änderung nur hier ist eine ungemessene.
Der Regelkatalog ist allgemeine Grammatik, geschrieben aus dem Tag und nicht aus Lehrbuch
oder Antwortbogen — er enthält keine Lemmata und gehört deshalb ins öffentliche Repo.

`response_format` wird **nicht** mitgeschickt: gemessen wurde ohne, und beide Modelle
halten die Form aus dem Prompt heraus (ADR 0004, Nachtrag 2026-09-17).

### 6. Der Bosskampf ist vorerst ein eigener Menüpunkt

„👹 Bosskampf" im Startmenü, neben „Spielen". Nicht nach N Wellen und nicht am Ende einer
Unit: solange die Bewertung im Spiel neu ist, soll ein Bosskampf etwas sein, das man
bewusst anfängt, und keine Hürde, die zwischen einem Kind und seiner nächsten Welle steht.

Der Grammatik-Golem stellt fünf Sätze aus seiner `sentence_rule` über der Auswahl des
Profils; jeder Treffer kostet ihn 1 HP, er hat **3 HP**. Kein Zeitdruck, keine Strafe für
eine Niederlage — der Golem zieht ab, sonst nichts.

**Der Kampf verbucht noch nichts**: kein Gold, keine Erfahrung, kein Lernstand. Ein
Modellurteil ist in einem von zehn Fällen falsch; bevor es in `PlayerProgress` schreibt,
soll es im Spiel beobachtet sein. Die Ereignisse gehen über den EventBus in die Spur.

**Der Dienst startet beim Betreten und endet beim Verlassen.** Das Laden von 4,6 GB dauert;
solange ist „Prüfen" gesperrt und beschriftet („Der Golem erwacht …"), der Satz steht schon.
Ist kein Modell installiert oder startet der Dienst nicht, kämpft der Golem nur mit der
Prüfkarte: was sie nicht kennt, ist kein Treffer, und das Spiel sagt das vorher.

### 7. Zeitlimits

`LocalModelBackend.HTTP_TIMEOUT` steigt auf 45 s, `SentenceJudge.DEFAULT_TIMEOUT` auf 47 s
(etwas länger als das Backend — gibt der Richter früher auf, bleibt die Anfrage offen und
jede weitere fällt in die Sperre). Die 4 s aus ADR 0004 stammen aus einer Zeit, in der der
Boss ausholen sollte und Stufe 1 Kür war; ohne Zeitdruck gibt es keinen Grund, eine
Antwort nach zehn Sekunden wegzuwerfen.

## Folgen

- Ein Kind bekommt im Bosskampf zu einer falschen Übersetzung einen Grund auf Deutsch —
  in etwa acht von zehn Fällen treffend, in einem von zehn mit einem schiefen Detail.
- Ohne Modell ist der Golem schwer zu besiegen: nur wenige Sätze tragen einen Schlüssel,
  und ohne Schlüsseltreffer gibt es keinen Treffer. Das ist ehrlich, und es ist der Grund,
  aus dem der Dienst zum Bosskampf gehört.
- Zwei Aufrufe heißen: die Erklärung braucht auf der CPU noch einmal 4–5 s nach dem Urteil.
- `tests/` sprechen weiter mit keinem Dienst; Prompt-Bau, Auswertung und der Ablauf des
  Kampfes sind mit erfundenen Backends geprüft.

## Nicht gebaut

- **Textportionen** (Entscheidung 4): Satzfeld, Aufruf B-abdeckung, „Satz n fehlt" aus dem
  leeren Zitat, Zitat gleich Muster ohne Modell.
- **Belohnung und Lernstand**: was ein Sieg einbringt, als Projektion von `t - c`.
- **Der Boss im Lauf**: nach Wellen oder am Ende einer Unit.
- **Windows-Build mit Gemma**: gemessen ist `b11002` unter Linux. Dass der Windows-Build
  dieselbe GGUF lädt, ist plausibel und ungeprüft — ebenso SmartScreen (ADR 0004).
- **Das Manifest im Release-Kanal**: `tools/model/model.json` zeigt auf Gemma, ist aber
  noch nicht neben `index.json` veröffentlicht.
