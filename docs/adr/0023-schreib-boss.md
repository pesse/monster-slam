# ADR 0023 — Der Schreib-Boss: ganze Texte, bewertet in der Cloud mit eigenem Schlüssel

Status: **Entwurf** · Datum: 2026-10-09 · Ändert: ADR 0004 („Es gibt keine Stufe 2 in der
Cloud“) für diesen einen Boss · Baut auf: ADR 0004, ADR 0005, ADR 0006

## Kontext

Ab Klasse 10 (Gymnasium BW, Niveau B1+) verschiebt sich der Schwerpunkt im Englischen vom
Satz zum Text. Der Bildungsplan 2016 (Synopse „Schreiben“, Arbeitsfassung 11.05.2015) nennt
für Klasse 10: formelle Korrespondenz, informierende Texte, Argumentieren und Stellung
beziehen, fiktionale Texte, Konnektoren über Textteile hinweg und den Schreibprozess
„Planen, Verfassen, Überarbeiten“; dazu kommt Sprachmittlung. Die Summary steht dort erst in
der Kursstufe, wird aber in Klasse 10 geübt.

Der Satzmeister (ADR 0005) prüft einzelne Sätze gegen einen Schlüssel und lässt ein lokales
Modell nur heben und erklären. Für einen Text von 150–250 Wörtern reichen die lokalen
Modelle nicht: sie müssten Inhalt, Aufbau, Textsortenkonventionen und Sprache zugleich
beurteilen, und schon bei fünf Sätzen am Stück fiel die Güte in der Werkstatt deutlich ab
(ADR 0005, Tabelle). Ein starkes Modell gibt es nur über eine API.

ADR 0004 hat das bewusst ausgeschlossen: „Kindertexte gehen nicht ins Netz.“ Diese
Entscheidung wird hier für den Schreib-Boss **ausdrücklich** geändert, nicht umgangen.

### Welche Textart zuerst

Bewertet wurde, was sich zur Autorenzeit absichern lässt (vgl. ADR 0004: der Schlüssel
entsteht beim Autor, nicht im Kampf):

| Textart | Vorlage | Inhaltsschlüssel | offline prüfbar |
|---|---|---|---|
| **Summary** | englischer Text | Kernpunkte | Länge (alles andere das Modell, §5) |
| Mediation | deutscher Text, Adressat | Kernpunkte | Länge, Konnektoren |
| Bericht aus Faktenblatt | Stichpunkte | Fakten | wenig |
| Comment / Erörterung | Fragestellung | nur Struktur | wenig |
| Short story | Anfang, Schlüsselbegriffe | keiner | kaum |

Die Summary hat den schmalsten Modellauftrag: welche Kernpunkte sind erfasst, steht der
Text im Präsens, wo sind Sprachfehler. Fast alles andere rechnet das Spiel selbst. Die
Mediation nutzt dieselbe Infrastruktur und kommt als Zweites.

## Entscheidung

### 1. Cloud nur mit eigenem Schlüssel (BYOK) und Bestätigung

- Der Spieler trägt **seinen eigenen API-Schlüssel** in den Einstellungen ein. Die EXE
  enthält keinen; anders als der App-Schlüssel des Statistik-Kanals (ADR 0021) kostet ein
  eingebauter Modellschlüssel Geld und wäre aus der EXE lesbar.
- Beim Eintragen muss bestätigt werden, dass die geschriebenen Texte **den Rechner
  verlassen** und an den Anbieter gehen. Ohne Bestätigung wird der Schlüssel nicht
  gespeichert. Der Schlüssel gilt gerätweit und liegt **nicht im Klartext** vor, sondern im
  Schlüsselspeicher des Betriebssystems (`SecretVault`): unter Windows mit DPAPI
  verschlüsselt, sodass nur dasselbe Konto auf demselben Rechner ihn lesen kann, unter
  macOS im Schlüsselbund. In `user://api_keys.cfg` stehen nur Bestätigung, verschlüsselter
  Block und verdeckte Anzeigeform. Ohne Schlüsselspeicher wird nichts gespeichert. Die Grenze:
  Ein Programm unter demselben Konto kommt trotzdem heran, weil das Spiel den Schlüssel selbst
  benutzen muss. Geschützt sind die Datei, Sicherungen und Kopien.
- Ohne Schlüssel gibt es den Schreib-Boss **nicht** — unsichtbar statt gesperrt, wie der
  Abschnitt zum lokalen Modell (ADR 0004).
- Hinaus gehen nur: Aufgabe, Vorlage, Kernpunkte und der Schülertext. **Kein**
  Profilname, keine `player_id`, keine `stats_id`, nichts aus der Spur.
- Der Schlüssel erscheint nie in Spur, Log, Statistik oder Meldung.
- Der Satzmeister bleibt unverändert lokal. Diese Änderung gilt nur für den Schreib-Boss.

### 2. Anbieter und Modell

Erster Anbieter ist **Anthropic**, Modell der Opus-Klasse — stark genug, dass die Arbeit in
die Prompts geht und nicht in die Modellwahl. Die Modell-Id steht an **einer** Stelle im
Backend. Das Backend hat denselben Zuschnitt wie `LocalModelBackend` (Anfrage rein,
Dictionary raus, Zeitlimit), damit ein zweiter Anbieter (OpenAI) dahinter passt, ohne dass
Boss oder Richter davon wissen. Kein Test spricht mit dem Dienst; Tests nutzen ein
Fake-Backend.

Die Antwortform erzwingt `output_config.format` (JSON-Schema); ein erzwungenes Tool
(`tool_choice`) lehnt Opus 5.5 ab. `effort: medium` — `high` war in der Werkstatt nicht
besser. Verweigert das Modell, antwortet ein serverseitiges Ersatzmodell (`fallbacks`);
gebucht wird das Modell, das tatsächlich geantwortet hat.

### 3. Der Boss: „The Rambler“

Ein eigener Boss mit eigener Szene, eigenem Setting und eigenem Modell — der Satzmeister
und seine Bühne bleiben, wie sie sind.

- **Figur:** ein aufgeblähter Bücherwurm-Drache, der eine Geschichte endlos, abschweifend
  und falsch nacherzählt — das Gegenteil einer Summary.
- **Setting:** ein Turm aus Papierstapeln. **Ich-Sicht** wie im Satzmeister.
- **Treffer:** Je Kriterium hängt ein Papierstapel an ihm; ein erfülltes Kriterium wirft
  den Stapel ab, und er schrumpft. Die Stapel sind die Lebensleiste — das Bewertungsraster
  ist direkt lesbar.
- Er **bleibt die ganze Zeit auf der Bühne** und läuft im Hintergrund durch den Raum
  (atmen, blättern, murmeln). Die Texte liegen als Overlay darüber und dürfen ihn verdecken;
  zwischen und neben den Panels taucht er immer wieder auf.
- **Kein Zeitdruck**, wie beim Satzmeister.

### 4. Ablauf in Phasen

Verfassen und Überarbeiten (Bildungsplan, Teilkompetenz 6) sind die Struktur des Kampfes.
Jede Phase hat ihr eigenes Overlay; die Bühne dahinter bleibt.

**Planen ist keine eigene Phase.** Eine bewertete Gliederung vor dem Schreiben schriebe
vor, *wie* geplant wird (Stichworte, Reihenfolge, Umfang) — das ist strenger als jede
Klassenarbeit und bestraft Kinder, die anders planen. Wer plant, tut es im Schreibfeld oder
auf Papier.

| Phase | Overlay | Boss dahinter |
|---|---|---|
| Begegnung | Aufgabe, kurz | spricht, im Vordergrund |
| Lesen | Vorlage groß, scrollbar | im Hintergrund, leise |
| Schreiben | Vorlage schmal links, Schreibfeld breit, Randleiste mit Wortzahl und Länge | läuft im Hintergrund umher |
| Angriff | Kriterium für Kriterium: Stapel fällt oder hält; die Vorlage ist weg | im Vordergrund, reagiert |
| Überarbeiten | eigener Text mit markierten Stellen und Hinweisen | angeschlagen |

Die Wartezeit auf das Modell (Sekunden bis eine halbe Minute) ist das Aufladen des
Angriffs. Statische UI als `.tscn`, Raum nur aus `ui_theme.tres`; Layout gegen 1152×648
prüfen — zwei lange Texte nebeneinander sind dort der enge Fall.

### 5. Bewertung: Offline zählt, das Modell beurteilt

**Offline (deterministisch, live in der Randleiste):** nur die Wortzahl gegen
`target_words` (`SummaryCard`), normalisiert über `AnswerEvaluator.tokens()`.

**Modell (ein Aufruf je Abgabe, strukturierte Ausgabe):**

- ob der erste Satz Titel und Autor nennt, mit Zitat
- welche Kernpunkte (`key_points[].id`) erfasst sind, je Punkt ja/nein mit Zitat als Beleg
- ob der Text im Präsens steht, mit den Stellen in der Vergangenheit
- direkte Rede, wörtlich aus der Vorlage Abgeschriebenes und eigene Meinung, je als Zitate
- Sprachfehler als Liste: wörtliches Zitat, Kategorie, Hinweis

**Nachtrag 2026-10-14: Einleitung, Rede und Meinung ans Modell.** Zuerst prüfte das Spiel
Einleitung, direkte Rede, Übernahmen (fünf Wörter am Stück), Meinung (Signalphrasen) und
Konnektoren selbst. Die Regeln trafen zu oft daneben: Fünf gemeinsame Wörter markieren
auch natürliche Sachangaben („his phone in his bag“), Signalphrasen trennen nicht zwischen
der Meinung des Kindes und der einer Figur („in his opinion“), und ein Titel mit Tippfehler
fiel durch. Das Thema ist für Regeln zu offen. Jetzt urteilt das Modell (Prompt
`summary-v5`, in `prompt-eval` gegen v3 gemessen: in zwei Läufen über 34 Fälle keine falsche
Einleitung, keine erfundene Rede oder Meinung, alle Soll-Stellen gefunden). Die Randleiste
zeigt nur noch die Wortzahl; die Konnektoren sind entfallen (offene Frage 3).

**Regeln dafür:**

- **Jedes Zitat wird lokal im Schülertext gesucht.** Was dort nicht steht, fällt weg —
  Schutz gegen erfundene Fehler.
- **Ein Hinweis verrät nie die Lösung.** Kein korrigierter Satz, keine verbesserte
  Fassung, keine Musterlösung — der Boss ist keine Hausaufgabenmaschine. Ein Hinweis nennt
  die Regel („Summaries stehen im Präsens“), nicht das Ergebnis.
- **Gewertet wird in Stufen, nicht in Punkten.** Ein Kriterium ist erfüllt oder nicht; ob
  das Modell bei zwei Läufen sieben oder acht von zehn Fehlern sieht, ändert den Ausgang
  nicht.
- Die Begründung eines Urteils wird wie in ADR 0005 nicht gezeigt, nur Hinweise an
  markierten Stellen.

**Kriterien der Summary** (je ein Stapel):

| Kriterium | erfüllt, wenn | Quelle |
|---|---|---|
| Einleitung | Titel und Autor im ersten Satz | Modell |
| Inhalt | alle Pflicht-Kernpunkte erfasst | Modell |
| Textsorte | Präsens, keine direkte Rede, nichts abgeschrieben, keine Meinung | Modell |
| Sprache | keine schweren Fehler mehr | Modell |
| Länge | im Zielbereich | offline |

Textsorte und Sprache sind „frei von Fehlern“ — das wäre auch ein Text aus einem Wort.
Beurteilt werden sie deshalb erst ab der Hälfte der unteren Zielwortzahl (ohne Zielbereich
ab 20 Wörtern); darunter halten ihre Stapel ohne Markierung.

### 6. Überarbeiten ist der zweite Angriff

Nach der ersten Abgabe ist The Rambler angeschlagen; was hält, wird am Text markiert.
Das Kind überarbeitet selbst und gibt erneut ab; jede Abgabe bewertet den ganzen Text neu.
Fällt der letzte Stapel, ist der Boss besiegt. **Die Zahl der Überarbeitungen ist vorerst
nicht begrenzt** — erst die gemessenen Kosten (Abschnitt 7) zeigen, ob und wo eine Grenze
nötig ist.

### 7. Kosten werden mitgeschrieben

Jede Antwort des Anbieters trägt ihren Verbrauch (`usage`: Eingabe-, Ausgabe-, Cache-Token).
Gespeichert wird nur dieser Ursprungswert mit Modell-Id und Zeitpunkt, **nicht** der Betrag:
der wird aus einer Preistabelle gerechnet, die an einer Stelle steht und ein Gültig-ab-Datum
je Eintrag trägt — so bleiben alte Abgaben richtig, wenn sich Preise ändern.

- **Spur:** ein neues EventBus-Signal je Abgabe (Boss, Abgabe-Nummer, Modell, Token,
  Dauer, Ergebnis je Kriterium), `TraceLog` hängt daran wie an allen anderen. Auch eine
  Antwort ohne brauchbares Urteil wird gebucht, wenn sie Token gekostet hat (`failed`). Kein Text,
  kein Schlüssel. In `TraceSanitizer.KEEP` darf das Ereignis ohne Einschränkung, denn es
  enthält nichts Getipptes.
- **Statistik:** eine eigene Profildatei `_writing` mit den Abgaben (dieselben Felder), in
  `StatsUploader.SNAPSHOT_FILES` mit Allowlist eingetragen. So lassen sich Kosten je Abgabe,
  je Kampf und je Spieler in `tools/stats/report.py` auswerten.
- **Im Spiel** sieht der Schlüsselinhaber in den Einstellungen den geschätzten Verbrauch
  der letzten 30 Tage — aus derselben Datei gerechnet, kein zweiter Zähler.

### 8. Daten: eine neue Kategorie im Submodule

Vorlagen liegen wie Sätze im privaten Submodule, je Unit eine Datei,
`writing/en_<band>_unit<n>.json`:

```json
{
  "id": "writing.en_access6_unit1.summary_01",
  "kind": "summary",
  "book": "access6",
  "unit": 1,
  "title": "…",
  "author": "…",
  "genre": "short story",
  "text": "…",
  "target_words": [80, 140],
  "key_points": [
    { "id": "kp1", "text": "…", "required": true }
  ]
}
```

- Erzeugt zur Autorenzeit nach einer nicht öffentlichen Generierungsvorgabe (wie Sätze),
  mit Eintrag im Generierungsprotokoll. Lehrbuchtexte werden nicht übernommen.
- Neue Kategorie `writing`: an **allen vier Stellen** eintragen (`ContentRegistry`,
  `PackInstaller`, `build_packs.py`, `packs.yaml`, ADR 0003) und mit ihr
  `min_app_version` der betroffenen Access-Pakete heben.
- Ein Boss trägt keine Vorlage, sondern eine Regel (`writing_rule`), wie der Satzmeister
  seine `sentence_rule`.

### 9. Gemessen wird in der Werkstatt — mit dem Abo

Prompt und Raster entstehen in `prompt-eval` und werden erst dann wörtlich übernommen
(Regel aus ADR 0005). Ziel ist **Prompt-Optimierung**, nicht Modellwahl.

- Übernommen ist die Fassung `summary-v3` (gemessen 2026-10-09: Schaden 0–3 von 28 Fällen,
  13/13 schwere Fehler erkannt, nie eine verratene Lösung; Median 7,9 s über `claude -p`).
  Das Testset ist für Opus noch zu leicht — echte Kindertexte trennen die Fassungen erst.
- Gemessen wird über `claude -p` (Abo, ohne Werkzeuge, eigener Systemprompt,
  `--json-schema`) als promptfoo-`exec`-Provider. Ausprobiert am 2026-10-09: Opus 5.5,
  ~4 s je Aufruf, Ausgabe im Schema. Nicht `--bare` (liest nur API-Schlüssel), kein
  `CLAUDE.md` im Arbeitsverzeichnis.
- `claude -p` ist nicht genau die API (Strukturausgabe über ein Werkzeug, keine
  `temperature`). Vor der Übernahme läuft das finale Testset einmal gegen die API.
- **Schaden** zählt wie in ADR 0005, erweitert um: Kernpunkt fälschlich als erfasst oder
  fehlend, erfundener Fehler, **verratene Lösung**.
- Testfälle: echte und erfundene Summaries zu einer Handvoll Vorlagen, von Hand bewertet.

### 10. Fortschritt

Wie beim Satzmeister wird ein Sieg in `BossRecord` gespeichert. Ob zusätzlich je Abgabe die
Stufen je Kriterium festgehalten werden (Schreibtagebuch), ist offen; gespeichert würde nur
der Ursprungswert.

### 11. Wortschatz-Bonus (Nachtrag 2026-10-15)

Eine Summary mit Wörtern der Unit ist ein eigenes Lernziel, und anders als beim
Satzmeister hat das Kind hier die Wahl der Wörter. Deshalb gibt es einen Bonus, der
**offline** gezählt wird (`UnitWords`): verschiedene Lexeme der Unit der Aufgabe, deren
Kern im Text steht. Das erste Wort darf gebeugt sein, regelmäßig oder aus
`lexeme_forms`; Präpositionen und Konjunktionen zählen nicht. Gezählt wird großzügig, denn
der Bonus urteilt über nichts.

- Ziel: `WritingBoss.UNIT_WORD_GOAL` = 5 verschiedene Wörter. Die Vorlagen von Access 4,
  Unit 1–2 enthalten 10–19 Wörter ihrer Unit; eine Summary von 70–110 Wörtern erreicht 5
  nicht von selbst.
- Der Bonus zählt erst, wenn der Stapel „Inhalt“ gefallen ist. Sonst brächte eine
  Wortliste ohne Zusammenhang etwas.
- Einmal erreicht, bleibt er (wie ein gefallener Stapel). Für den Sieg ist er nicht nötig,
  und er bringt wie der Boss selbst kein Gold und keine Erfahrung.
- Die Randleiste zählt live mit, der Angriff deckt ihn nach den fünf Kriterien auf.
- `WritingLog` speichert je Abgabe `unit_words` (die Zahl, nicht die Wörter). Ob der Bonus
  erreicht ist, wird daraus und aus `met` gerechnet, nicht gespeichert.

Das Modell sieht von der Zählung nichts; der Prompt (summary-v5) bleibt unverändert.

## Folgen

- Zum ersten Mal verlässt ein Kindertext den Rechner — nur mit eigenem Schlüssel und
  Bestätigung, nur für diesen Boss. ADR 0004 bekommt einen Verweis hierher.
- Jede Abgabe kostet den Schlüsselinhaber Geld. Begrenzt wird vorerst nicht; die Kosten
  stehen je Abgabe in Spur und Statistik, und eine Grenze kommt erst, wenn die Zahlen sie
  verlangen.
- Ohne Netz oder bei einem Fehler des Dienstes gibt es kein Urteil; der Text bleibt
  erhalten, und die Abgabe zählt nicht.
- The Rambler braucht ein eigenes Modell, eine eigene Bühne und eigene Effekte; die
  Effekte gehören in `FxWarmup`.
- Neue Spurereignisse des Schreib-Bosses tragen keinen Text und keinen Schlüssel; ob sie
  durch `TraceSanitizer` dürfen, wird dort einzeln entschieden.

## Offene Fragen

1. ~~Wo steht The Rambler auf der Karte?~~ Entschieden 2026-10-14: eine **Wahl am
   bestehenden Boss-Ort**. Hat die Unit Vorlagen und Sätze, fragt „Spielen“ am Boss-Ort,
   welcher Boss (`BossChoice`, eine Karte je Boss); gibt sie nur einen her, startet er
   direkt. Ein Sieg zählt in `BossRecord` wie einer über den Satzmeister.
2. **Schreibtagebuch:** Stufen je Kriterium über die Zeit speichern? Den Text selbst
   lokal aufheben?
3. ~~Konnektoren als Lexem-Gruppe?~~ Entfallen 2026-10-14: die Randleiste zählt keine
   Konnektoren mehr (Nachtrag in §5).
4. **Für welchen Band?** Die ersten Vorlagen gehören zu Access 4, Unit 1–2 (2026-10-14),
   etwas leichter als das Ziel B1+. Klasse 10 braucht eigene Vorlagen unabhängig vom Buch
   oder einen neuen Band.
