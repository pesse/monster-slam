# ADR 0025 — Der Satzmeister wahlweise in der Cloud

Status: **angenommen** · Datum: 2026-10-14 · Ändert: ADR 0004/0005 („Stufe 1 spricht nur
mit `127.0.0.1`“) als Wahl unter „Inhalte“ · Baut auf: ADR 0005, ADR 0023

## Kontext

Stufe 1 des Satzmeisters ist Gemma 4 E4B auf diesem Rechner (ADR 0005), in zwei Aufrufen:
Urteil mit Schlüssel, Erklärung ohne. Am Einzelsatz reicht das, an Texten aus mehreren
Sätzen fällt es deutlich ab, und auf dem Mac gibt es den Dienst gar nicht. Seit dem
Schreib-Boss (ADR 0023) kann ein Spieler einen eigenen API-Schlüssel für Anthropic
eintragen. Ob ein großes Modell auch den Satzmeister besser bewertet, wurde in der Werkstatt
`prompt-eval` gemessen (Nachtrag „Satzmeister über die API“ in deren `STAND.md`).

### Gemessen

Ein Aufruf je Antwort liefert Urteil und Erklärung zusammen (Schema `{parts, mistake,
explanation}`), `effort: medium`, Bewertung durch Opus gegen das Urteil der Lehrkraft.
„Schaden“ heißt: falsche Antwort durchgelassen, richtige abgewiesen, oder eine Erklärung,
die etwas Falsches behauptet. Werte: gut / Schaden.

| Set | Gemma (2 Aufrufe, ADR 0005) | v1 Opus | v2 Opus | v2 Sonnet | v3 Opus | **v3 Sonnet** |
|---|---|---|---|---|---|---|
| Einzelsätze (51, davon 32 falsch) | Urteil: 2 abgewiesen | – | 32 / 5 | 32 / 2 | 32 / 3 | **32 / 0** |
| Texte aus 2–3 Sätzen (66, 42) | 33 / 4 | 42 / 4 | 42 / 0 | 41 / 2 | 42 / 0 | **42 / 0** |
| Texte aus 5 Sätzen (60, 42) | 21–23 / 5–7 | 42 / 0 | 42 / 0 | 42 / 0 | 42 / 0 | **42 / 0** |
| 5 Sätze, mehrere Fehler (35, 35) | 18–23 / 10 | 33 / 2 | 35 / 0 | 33 / 2 | 35 / 0 | **35 / 0** |

satz-v1 hatte die geübte Struktur zur Pflicht gemacht und wies deshalb richtige freie
Fassungen ab („will“ statt „going to“, „a lot“ statt „often“, umgedrehter Vergleich).
satz-v2 verlangt die geübte Struktur nur, wo das Deutsche sie klar fordert (Passiv), und
lässt jede andere richtige Form stehen. An Texten ist Opus damit fehlerfrei, Sonnet
bemängelt noch richtige Wörter („sunny“ für „schön“). **Am Einzelsatz, und den stellt der
Golem, ist es umgekehrt:** Opus weist fünf richtige freie Fassungen ab („really“ ohne
„wirklich“, „your bike“ für „das Fahrrad“, „can't wait“, „there is no need“), Sonnet zwei —
so viele wie Gemmas Urteil. Durchgelassen hat keins der Modelle etwas, und keine Erklärung
zu einer falschen Antwort behauptete etwas Falsches (Gemmas Erklärungen: etwa jede zehnte
schief, ADR 0005).

satz-v3 sagt dazu allgemein, dass die Bedeutung zählt und nicht die Nähe zum deutschen
Wortlaut (idiomatische Wendung, Füllwort, Possessiv nach englischem Gebrauch, andere
Konstruktion), und dass eine Übersetzung nur falsch ist, wenn sich etwas ändert. Die
abgewiesenen Testsätze stehen bewusst nicht als Beispiele im Prompt. Sonnet ist damit auf
allen vier Sets ohne Schaden (212 Antworten), Opus weist am Einzelsatz noch drei ab
(„that one“, „can't wait“, „there is no need“). Je ein Lauf; die Grundsätze stammen aus
den Fehlern auf denselben Sets, ein frisches Set steht aus.

Dauer im Median: Opus ~5 s, Sonnet ~4 s; je Aufruf ~1.400 Token hinein (fast alles Systemprompt, cachebar) und ~300
heraus.

Vorbehalt: Claude bewertet Claude. Die Schadensfälle sind von Hand gelesen, die guten nur
in Stichproben.

## Entscheidung

### 1. Eine Wahl, keine Pflicht

Der lokale Weg bleibt und bleibt die Vorgabe. Mit eingetragenem Schlüssel gibt es unter
„Inhalte“ ein eigenes Kreuz „Auch den Satzmeister in der Cloud bewerten“
(`UserSettings.sentence_cloud`, geräteweit wie der Schlüssel). Es fragt eigens nach, weil
die Zustimmung zum Schlüssel nur die Texte des Schreib-Bosses nennt. Wird der Schlüssel
entfernt, fällt das Kreuz mit; ein neuer Schlüssel fragt wieder.

Gilt das Kreuz und ist ein Schlüssel da (`BossFight.uses_cloud`), startet der Bosskampf
keinen lokalen Dienst, sondern hängt `CloudModelBackend` als Stufe 1 ein.

### 2. Ein Aufruf statt zwei

`CloudModelBackend.judge` urteilt und hält die Erklärung derselben Antwort bereit;
`explain` gibt sie ohne zweiten Aufruf zurück. Der Vertrag von `SentenceJudge` bleibt
unverändert: Stufe 0 zuerst, Stufe 1 nur bei Zweifel, sie hebt nur und senkt nie.

Damit fällt für die Cloud der zweite, unabhängige Blick aus ADR 0005 weg, der abgewiesene
richtige Antworten auffing. Am Einzelsatz weist Sonnet so selten ab wie Gemmas Urteil
allein, und mit v3 in der Messung gar nicht mehr; ein zweiter Aufruf kostete Zeit und Geld
für einen Fehler, den es dort nicht gab.

### 3. Prompt und Modell

Systemprompt, Nutzerteil und Schema stehen wörtlich als `StageOnePrompts.CLOUD_*` im
Spiel (Fassung `satz-v3`). Der deutsche Text geht Satz für Satz nummeriert hinaus, so wie
gemessen. Das Modell ist `CloudModelBackend.SENTENCE_MODEL` = Claude Sonnet 5.5: am Einzelsatz das
bessere, schneller und halb so teuer wie Opus.

### 4. Daten und Kosten

Hinaus gehen deutscher Satz, Musterlösung, `accepted`, die Grammatikregeln und die
Übersetzung — kein Profil, keine Spieler-Id. Gefragt wird nur bei Zweifel der Prüfkarte,
also nie für eine hinterlegte Lösung. Jeder bezahlte Aufruf landet mit `kind: "sentence"`
im `WritingLog` (ADR 0023, §7), damit die Kosten eines Schlüssels an einer Stelle stehen
und unter „Inhalte“ zusammen erscheinen.

## Folgen

- Der Satzmeister wird mit Schlüssel auch auf dem Mac genau bewertet.
- Ohne Netz gibt Stufe 1 auf (`gave_up`); es zählt, was als Lösung hinterlegt ist — wie
  ohne lokales Modell.
- Ein Aufruf kostet unter einem Cent; ein Kampf mit wenigen Zweifeln wenige Cent.
- Tests sprechen mit keinem Dienst: Anfrage-Bau, Auswertung und der Fall ohne Schlüssel
  sind ohne Netz geprüft (`tests/cloud_sentence_test.gd`).

## Nicht gebaut

- Ganze Texte in einem Aufruf: gemessen und gut, aber der Golem stellt Einzelsätze.
- Eine Wahl des Modells in den Einstellungen.
- Ein frisches Einzelsatz-Set, an dem v3 nicht entwickelt wurde — bevor der Prompt weiter
  geändert wird.
