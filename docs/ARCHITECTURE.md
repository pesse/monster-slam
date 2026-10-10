# Architektur

Leitziel: **Modularität durch Daten + Entkopplung durch Signale.** Neue Inhalte
und Mechaniken sollen sich ergänzen lassen, ohne bestehende Systeme zu ändern.

## Zwei Autoload-Säulen

### 1. ContentRegistry (`src/core/content_registry.gd`)
Datengetriebener Katalog. Scannt beim Start rekursiv `<root>/<kategorie>/`
und lädt jede `.json`-Datei. Kategorien: `lexemes`, `lexeme_forms`,
`lexeme_relations`, `sentences`, `sentence_lexemes`, `task_definitions`,
`monster_task_rules`, `monsters`, `bosses`, `spells`, `skills`, `waves`.

`spells` und `skills` sind **zwei Dinge**: Spells sind Zauber zum Verbrauchen, mit Gold
gekauft und im Kampf eingesetzt (`docs/adr/0014-zauber-zum-verbrauchen.md`), Skills die
Knoten der Fähigkeitsbäume. Warum sie so heißen und was das für `min_app_version` bedeutet,
steht in `docs/adr/0003-skills-und-spells.md`.

**Drei Roots, in Vorrangfolge** (`_roots()`): bei gleicher `id` gewinnt der spätere.

| # | Root | Inhalt | im Export? |
|---|---|---|---|
| 1 | `res://data/` | Spielkonfiguration (Monster, Wellen, Zauber, Fähigkeitsbäume, Aufgaben-Regeln) | ja |
| 2 | `res://data/language/` | Sprachdaten — privates Submodule, nur in der Entwicklung | **nein** |
| 3 | `user://content/<pack-id>/` | installierte Content-Packs | — |

Root 2 ist ein separates **privates** Repo, weil die Daten aus urheberrechtlich
geschütztem Lehrbuchmaterial abgeleitet sind. Es wird per `exclude_filter` **aus dem
Export ausgeschlossen** — die verteilte EXE enthält keine Vokabeln und holt sie über
Content-Packs (Root 3). Root 3 ist damit kein Sonderfall, sondern der Normalweg beim
Spieler; dass ein Pack einen eingebauten Eintrag überschreiben *kann*, ist gewollt.

Fehlen Sprachdaten in allen Roots, startet das Spiel mit leeren Sprachkatalogen und
einer Warnung, die beide Wege nennt (Pack installieren / Submodule auschecken).

Kollisionen werden pro Root beurteilt (`_origins`): zwei Dateien **desselben** Roots
mit gleicher `id` sind ein Fehler und werden gemeldet; ein Pack, der einen eingebauten
Eintrag ersetzt, ist der Zweck der Übung und bleibt still.

- Jede JSON-Datei enthält ein Objekt **oder** ein Array von Objekten.
- Jedes Objekt braucht eine eindeutige `id` (String).
- Zugriff: `ContentRegistry.monsters`, `.get_entry("lexemes", "lex.en.house")`,
  `.all("waves")`, `.lexemes_by_tags(["school"])`, `.forms_for(id, form_type)`,
  `.relations_of(id, "opposite")`, `.monster_rule_for(task_type, direction)`.
- Auswahl-Filter fürs Session-Setup: `.lexemes_scoped(scope, tags)` (Schnitt aus
  Curriculum-Scope UND Themen, siehe unten). Der Aufgabenpool nimmt
  `.lexemes_for_run(scope, tags)`: dazu die Lexeme der Boni, die der Scope mitspielt
  (`.bonuses_of(book, unit)`, `.bonus_in_scope`, ADR 0012) — von ihnen fragt der Kampf nur
  die Bonus-Formen. Dazu `.all_books()` / `.units_for(book)` /
  `.parts_for(book, unit)` für den Buch▸Unit▸Teil-Picker.
- `reload()` scannt zur Laufzeit neu.

**Folge:** Content hinzufügen = Datei ablegen. Kein Code-Edit.

### Datenmodell (ERM): Sprache / Aufgabe / Darstellung getrennt
Der Lernstoff ist normalisiert, damit Sprachdaten, Aufgaben, Fortschritt und
Darstellung unabhängig wachsen können (siehe `docs/ADDING_CONTENT.md`):

- **lexemes / lexeme_forms / lexeme_relations** — *Was* ist das Wort, welche Formen
  (Konjugation/Zeit) und Relationen (opposite/synonym/…) hat es. **Keine** `difficulty`
  am Lexem: wie schwer ein Wort ist, ergibt sich aus dem Lernstand (Confidence), nicht
  aus dem Wort selbst.
  - **Zwei getrennte Klassifikations-Achsen** am Lexem (für die Session-Auswahl):
	*Curriculum* über die Felder `book` (z.B. `"access2"`) + `unit` (int) — woher das
	Wort stammt; *Themen* über `tags` (z.B. `body`, `animals`) — worum es geht. Die
	Wortart steckt in `type`, **nicht** in `tags`. `.lexemes_scoped(scope, tags)`
	schneidet beide Achsen (Scope UND Themen; innerhalb der Tags ODER), leer = keine
	Einschränkung. So ist z.B. „Körperteile aus Access 2 / Unit 6" ausdrückbar. Seit
	ADR 0006 gibt es keinen Grundwortschatz mehr; ein Lexem ohne `book`/`unit` ist ein
	Datenfehler und erschiene nur ohne Scope.
	Der Scope hat DREI Stufen: `"access2"`, `"access2/6"` und `"access2/6/2"` — das
	zweite Viertel der Unit. Die Teile stehen NICHT in den Daten, sondern werden aus der
	**Position** in der Unit gerechnet (`ContentRegistry._index_parts`, gleich große
	Viertel, Rest nach vorn): die Lexeme stehen in Seitenreihenfolge in der Quelldatei,
	damit ist Teil 1 der Anfang der Unit. Ein Teil ist damit ungefähr eine Woche
	Unterricht — die Einheit, in der vor einer Arbeit tatsächlich geübt wird.
	Ausnahme Latein: das Buch zählt 36 Lektionen, je sechs sind eine Unit, und die
	Lektion ist der Teil — als Feld `part` am Lexem. Trägt ein Lexem einer Unit `part`,
	gilt das Feld für die ganze Unit. Wie viele Teil-Level die Gebietskarte zeigt, legt
	`AreaMap.part_count` fest: so viele, wie Inhalt oder Kartenpunkte (`t1`…`t6`) es
	verlangen; ein Teil ohne Wörter steht gesperrt da.
- **task_definitions** — *Regeln*, was abgefragt wird (translate/opposite/synonym/
  conjugation/… + `direction`, `allowed_types`, `requires_relation`/`requires_form`,
  `difficulty`). Wenige, statische Einträge (Größenordnung ~10–20) — **unabhängig von
  der Wortanzahl**. Die konkrete Aufgabe entsteht erst zur Laufzeit aus
  *Definition × Lexeme (× Form/Relation)*; es gibt keine per-Wort-Aufgaben mehr.
- **monster_task_rules** — *Wie* eine Aufgabe dargestellt wird: `(task_type, direction)
  → monster_type` + `base_damage/weight`. **Kein** Tempo und **keine** Punkte —
  beide sind Projektionen der Schwierigkeit (siehe unten), keine Darstellungswerte.
  `base_damage` gilt in Welle 3; davor und danach skaliert ihn
  `WaveGenerator.wave_damage_scale` (0,6 · 0,8 · 1,0 · +0,15 je Welle, Issue #51).
- **player_progress** — *Wie gut* der Spieler eine konkrete Aufgabe kann, adressiert über
  einen kanonischen **`learnable_id`** (Task-Typ + Richtung + Lexeme/Form/Relation; Schema
  in `TaskResolver.learnable_id()`). Nicht im Content, sondern beschreibbar in `user://`.
- **sentences / sentence_lexemes** — für Boss-/Satzübungen. Ein Satz trägt neben der
  `reference_translation` seinen Lösungsschlüssel (`accepted`, `must_contain`,
  `pitfalls`); bewertet und ausgewählt wird damit offline (siehe „Sätze bewerten" unten
  und `docs/adr/0004-satzbewertung-ohne-modell.md`). Der Bosskampf startet vom Boss-Ort der
  Gebietskarte oder aus dem Expertenmodus (`scenes/battle/boss_fight.tscn`, ADR 0005/0006).

Die Auflösung Definition × Lexeme → spielbare Aufgabe `{prompt, accepted_answers, …}`
macht `src/learning/task_resolver.gd`; die Enumeration der Kandidaten (Definition × Lexeme)
und die Auswahl fälliger/neuer Aufgaben + Monster-Mapping `src/battle/wave_generator.gd`.
Oberste Stufe der Auswahl ist „in dieser Welle schon gezeigt“ (am Grundwort, nicht am
`learnable_id`): Wiederholungen erst, wenn der Pool erschöpft ist, dann das am längsten
nicht gezeigte Wort zuerst (`WaveGenerator.ordered`). Die Menge führt der `WaveRunner`
je Welle, gespeichert wird sie nicht. Darunter wird gewichtet gezogen, ohne Zurücklegen
(ADR 0018): Gewicht = Bedarf (1 − c, mindestens 0,05) × Dringlichkeit (verstrichener
Anteil des Intervalls seit der letzten Antwort auf das Grundwort, gedeckelt bei 2), ein
neues Wort 1. Die neuen tragen zusammen mindestens 30 % des Gewichts. Gemeistertes kommt
so selten, aber nicht nie; ein Fehler (c halbiert, nach 10 min fällig) bald wieder. Die
Gruppen fällig/neu/Rest stehen nur noch zur Erklärung in der Spur.

### Tempo = Schwierigkeit (Monster-Geschwindigkeit)
Geschwindigkeit ist **kein eigenständiges Attribut**, sondern die sichtbare Projektion der
Schwierigkeit. Es gibt genau eine Achse — Schwierigkeit — und Tempo ist ihre Ausgabe.
Daraus zwei Regeln: (1) Tempo entsteht **ausschließlich** aus Schwierigkeits-Quellen
(Grundschwierigkeit der Aufgaben-Art, Confidence, Wellen-Schwierigkeit) — kein Monster und
keine Regel trägt ein eigenes Tempo; (2) jede Tempo-Änderung ist eine Schwierigkeits-Änderung
und daher monoton und begrenzt zu behandeln.

Formel (`src/battle/wave_generator.gd`), mit `c` = Confidence (0..1) und `t` =
normalisierte `task_definition.difficulty` (0..1):

```
e = c − t                                    # Netto-Können
speed = REFERENCE_SPEED · clamp(1 + K·e) · speed_scale
```

- `e < 0` (Confidence unter Grundschwierigkeit) → **langsamer** (Zeit zum Abrufen).
- `e = 0` → **Referenztempo**. `REFERENCE_SPEED` ist der Nullpunkt der Skala, kein Deko-Wert;
  es zu ändern verschiebt die Schwierigkeit **aller** Aufgaben.
- `e > 0` (Confidence übersteigt die Grundschwierigkeit) → **schneller** (mehr Druck).

Die Differenzierung „opposite/synonym sind schwerer als translate" lebt damit allein in
`task_definition.difficulty` — nicht in per-Monster- oder per-Regel-Geschwindigkeiten.

**Punkte folgen derselben Schwierigkeit, invers zum Tempo:** je schwerer das Monster
(hohe Grundschwierigkeit, niedrige Confidence, härtere Welle), desto **mehr** Punkte —
`reward = REFERENCE_REWARD · clamp(1 + K_r·(t − c)) · speed_scale`. Ein hartes Monster ist
also langsam *und* wertvoll; das Abrufen unsicherer/schwerer Aufgaben lohnt sich. Auch die
Punkte kommen damit ausschließlich aus der Schwierigkeit, nicht aus per-Regel-Werten.

### 2. EventBus (`src/core/event_bus.gd`)
Globaler Signal-Hub. Systeme kommunizieren über Signale statt direkter
Referenzen. Ein neues System abonniert relevante Signale, ohne dass ein
bestehendes System davon wissen muss.

`GameState` (`src/core/game_state.gd`) hält die Laufzeit-Session (Festungs-HP,
Score, aktive Welle) und reagiert selbst nur über EventBus-Signale.

## Lern-Module (`src/learning/`)

- **`spaced_repetition.gd`** — Wiederholung mit Abstand, ohne eigenen Zustand (ADR 0018).
  `spacing_gain`: wie viel ein Treffer die Confidence hebt, 10–40 % der Lücke zu 1, je
  nach Abstand zur letzten Antwort (logarithmisch, voll ab einem Tag bzw. dem Intervall).
  `due_at`: Fälligkeit aus Confidence und letzter Antwort — nach einem Fehler in 10
  Minuten, sonst 1 / 3 / 7 / 14 / 30 / 45 Tage ab lokaler Mitternacht. Es gibt nur einen
  Lernstand, die Confidence; die Fälligkeit wird gerechnet.
- **`answer_evaluator.gd`** — normalisierter Exakt-/Alternativabgleich für schnellen
  Recall (offline, deterministisch). Hier wohnt die Normalisierung (Artikel,
  Platzhalter, Klammergruppen, Typografie); die Satzbewertung nimmt sie über `tokens()`.
  Der Wellenkampf fragt zusätzlich nachsichtig (`lenient`): Akzente, Bindestrich und
  Apostroph dürfen fehlen, das Urteil trägt dann `exact: false`, und die richtige
  Schreibweise wird eingeblendet (ADR 0008).

### Sätze bewerten (`docs/adr/0004-satzbewertung-ohne-modell.md`, `docs/adr/0005-bosskampf-mit-erklaerung.md`)

Ausgeliefert wird **kein** Sprachmodell. Der Lösungsschlüssel entsteht zur Autorenzeit und
steht in den Daten (`accepted`, `must_contain`, `pitfalls` am Satz); bewertet wird in
Stufen, und Stufe 0 trägt das Spiel allein.

| Baustein | Aufgabe |
|---|---|
| `sentence_card.gd` | Stufe 0, die „Prüfkarte": Abgleich gegen `accepted`, `must_contain`, `pitfalls`. Reine Rechnung, deterministisch, ohne Netz. Ein Treffer schlägt jede Stolperstelle. |
| `sentence_judge.gd` | Der Vertrag `{quality, feedback, matched}` für ALLE Stufen. `judge()` gibt Stufe 0 sofort zurück; Stufe 1 kommt als `refined` (Treffer) oder `denied` (kein Treffer) nach — oder gar nicht. Nach `denied` folgt `explained` mit der Erklärung oder leer. Stufe 1 darf nur **heben**, nie senken, und erklärt, wo sie nicht hebt. |
| `local_model_backend.gd` | Stufe 1: HTTP an einen Dienst auf `127.0.0.1`, zwei Aufrufe: `judge()` urteilt mit Schlüssel, `explain()` erklärt ohne. Ohne Dienst existiert sie für das Spiel nicht. Keine Stufe 2 in der Cloud. |
| `stage_one_prompts.gd`, `grammar_rules.gd` | Die beiden Aufträge und der Regelkatalog je `grammar_tag`, wörtlich aus der Werkstatt `prompt-eval`, wo sie gemessen werden. Geändert wird dort, nicht hier. |
| `sentence_selector.gd` | Welcher Satz drankommt: `sentence_lexemes` → Lexem → Scope, gewichtet nach dem Netto-Maß `t - c` — demselben, das Tempo, Punkte und XP tragen. |

Ein Boss trägt deshalb **keine Sätze mehr selbst**, sondern eine `sentence_rule`
(`data/bosses/grammar_golem.json`). Ausprobieren lässt sich das Ganze in der Werkbank
`scenes/dev/boss_lab.tscn`; gespielt wird es im Bosskampf (`scenes/battle/boss_fight.tscn`),
der neben dem Wellenkampf aus „Runde vorbereiten“ startet, dieselbe Auswahl liest (nur
Scope und Tags) und nichts verbucht (ADR 0005). Seine Bühne
(`scenes/battle/boss_stage.tscn`, `BossStage`) ist ein Gewölbe aus der Ich-Sicht mit dem
Skelett-Magier darin; sie spielt nur vor (`hurt`, `gloat`, `fall`, `leave`) und weiß nichts
von Sätzen und Urteilen. Die Oberfläche darüber sind Sprechblasen (`SpeechBubble`), deren
Spitzen dem Kopf des Skeletts folgen. Die Animationen teilen sich Boss und Monster über
`RigAnimations`.

**Die Wörter, die hier gelten.** Die meisten Begriffe sind für dieses Projekt erfunden und
stehen so im Code, in den ADRs und in den Commit-Texten:

| Wort | Was es meint | Wo es steht |
|---|---|---|
| **Prüfkarte** | Stufe 0: der deterministische Abgleich gegen den Schlüssel, ohne Modell | `SentenceCard` |
| **Schlüssel** (Lösungsschlüssel) | die Bewertungsgrundlage AM Satz: `accepted`, `must_contain`, `pitfalls` | im Satz-JSON |
| **Stolperstelle** | ein vorweggenommener Fehler samt eigener Rückmeldung; passt nur, wenn ALLE Bestandteile dastehen | `pitfalls` |
| **ohne Urteil** | die Karte hat weder Lösung noch bekannten Fehler gefunden — ein DRITTER Ausgang, nicht „falsch" | `SentenceCard.NO_VERDICT`, `sure == false` |
| **Nähe** | Überschneidung der Wortmengen, 0 bis 1. Wählt nur die Rückmeldung und ist NIE ein Urteil | `SentenceCard.overlap()` |
| **Antwortbogen** | 10 erfundene Sätze mit 63 getippten Antworten, jede mit dem Urteil einer Lehrkraft — der Maßstab, gegen den gemessen wird | `src/dev/answer_sheet.json` |
| **Falsch-Negativ / -Positiv** | richtige Antwort abgewiesen / falsche durchgewinkt. Im Bosskampf beide teuer, weil er Satzbau prüft | Messung |
| **Stufe 0 / Stufe 1** | Prüfkarte (immer da) / lokales Modell über HTTP (darf nur heben) | `SentenceJudge` |
| **Urteil / Erklärung** | die zwei Aufrufe von Stufe 1: binär mit Schlüssel, dann — nur bei „falsch" — der Grund, ohne Schlüssel und mit den Grammatikregeln des Satzes | `StageOnePrompts`, ADR 0005 |
| **Modellkarte** | die Selbstauskunft eines Modells auf Hugging Face — eine Behauptung, kein Befund über UNSERE Aufgabe | `docs/SATZBEWERTUNG_MODELLE.md` |

**Die Prüfkarte.**
- **Ein Treffer schlägt jede Stolperstelle.** Der teuerste Fehler ist der Tadel für eine
  richtige Antwort. Die Karte prüft erst `accepted`, dann `pitfalls`; ein Datentest hält,
  dass keine Stolperstelle auf eine akzeptierte Lösung passt (`tests/sentence_data_test.gd`).
- **Eine Stolperstelle ist eine Liste von Bestandteilen, kein regulärer Ausdruck.**
  Verglichen wird wortweise (`contains_phrase`), nicht als Teilzeichenkette.
- **Ohne Schlüsseltreffer gibt die Karte KEIN Urteil**, und ohne Urteil ist eine Antwort
  kein Treffer. Vorher stand die Wort-Überschneidung als Güte da — sie sieht weder
  Reihenfolge noch Beugung, und am Antwortbogen stammten ALLE Fehlurteile aus diesem Zweig.
  Die Nähe wählt seitdem nur noch die Rückmeldung („nah dran" gegen „anderer Satz").
  Der Kampf sollte „ohne Urteil" als eigenen Ausgang zeigen (Musterlösung, kein Schaden,
  keine Gutschrift).
- **`must_contain`-Formen müssen im Bestand stehen** (Lemma, `lemma_en_alt`,
  `lexeme_forms`); eine fehlende Form gehört in `lexeme_forms`, nicht als Sonderfall in den
  Satz. Jede akzeptierte Lösung muss die geforderten Wörter enthalten.
- Der Lernstand eines Satzes ist das Mittel über seine Lexeme in der Richtung, die er übt.

**Stufe 1.**
- **Sie darf nur heben, nie senken**, und gefragt wird sie nur, wo die Karte nichts
  Belastendes gefunden hat. Seit „ohne Urteil kein Treffer" ist sie für Bosskämpfe
  **tragend**: nur sie macht aus einem Zweifel einen Treffer.
- **Nur `127.0.0.1`** — keine Einstellung, sondern die Entscheidung: Kindertexte gehen
  nicht ins Netz.
- **Den Dienst stellt das Spiel selbst hin** (`LocalModelServer`, Nachtrag „Stufe 1 auf
  eigenen Beinen"): `llama-server.exe` plus GGUF aus `user://model/`, gestartet mit
  ausdrücklichem `--host 127.0.0.1`, auf `/health` gewartet, beendet auch in
  `_exit_tree()`. An der Bewertung ändert das nichts, `LocalModelBackend` bekommt nur eine
  andere `url`. Das Modell ist Gemma 4 E4B (ADR 0005); der Bosskampf startet den Dienst
  beim Betreten und beendet ihn beim Verlassen. Offen ist SmartScreen.
- **Zwei Aufrufe** (ADR 0005): das Urteil wird sofort gezeigt, die Erklärung kommt nach.
  Findet der Erklärer — ohne Schlüssel, unabhängig vom Urteil — keinen Fehler, gibt es
  keine Erklärung, nur die Musterlösung. Die Begründung des Urteils selbst wird nie
  gezeigt.
- **Geholt wird das Modell über `ModelService`** (Autoload, Knopf in der
  Inhalte-Verwaltung). Wir spiegeln nichts; geliefert wird die Zusicherung, WELCHE Datei
  gemeint ist — alles hängt an `sha256`, und `tools/model/make_manifest.py` rechnet die
  Prüfsummen selbst aus. Aus einem Archiv kommt nur der Dateiname mit (`get_file()`), und
  nur `llama-server.exe`, die `.dll` und die Lizenztexte; ohne Server wird das Archiv
  verworfen.
- **Das Manifest liegt im Release-Kanal** (`model.json` neben `index.json`): ein anderes
  Modell ist eine Datei, kein Release. `tools/model/model.json` ist der **Kandidat**, nicht
  das Veröffentlichte. Gewichts-URLs immer auf einen HF-Commit festnageln
  (`/resolve/<commit>/`), nie auf `main`. Veröffentlicht wird von Hand und nicht vom
  Pack-Workflow (der lädt nur hoch und lässt `model.json` liegen):
  `gh release upload packs tools/model/model.json --repo pesse/monster-slam-packs --clobber`.
- **Gemessen gilt Qwen3-4B-Instruct-2507 Q4_K_M** (90–92 % am Antwortbogen); EuroLLM-1.7B
  blieb auf der Basislinie. `model.json` nennt noch EuroLLM, weil nur der Linux-Build des
  Tauschkandidaten geprüft ist (Nachtrag vom 2026-09-17 im ADR).
- **Eine Anfrage zur Zeit, und das sagt sie auch** (`busy()`, `last_note`, `BUSY_NOTE`).
  `last_note` unterscheidet „kein Dienst" von „Modell hält sich nicht an die Form".
- **`LocalModelBackend.http_timeout`** ist verstellbar, `HTTP_TIMEOUT` (3,5 s) die Vorgabe
  aus der Zeit, als Stufe 1 Kür war. Ein 4-B-Modell braucht rund 6 s je Urteil; der Wert
  gehört für den Kampf hochgezogen und die Haltedauer des Bosses daran angepasst. Gelesen
  wird er in `_ready()`, also vor dem Einhängen setzen.

**Messen und ausprobieren.**
- **Beurteilt wird in der Werkbank, ENTSCHIEDEN am Antwortbogen**:
  `tools/godot.sh res://scenes/dev/measure_sentences.tscn [-- --model | --serve --timeout=60]`.
  Die Sätze darin sind erfunden und nennen ihre `must_contain`-Formen selbst, damit die
  Messung nicht am Submodule hängt; `tests/answer_sheet_test.gd` hält den Bogen in sich
  stimmig. **Die Bezugsgröße ist 37/63**, nicht 0 — so gut ist ein Modell, das stur
  „richtig" sagt.
- Prompt-Varianten werden nebenan gemessen (`C:\dev\prompt-eval`). Unabhängig vom Modell
  gilt: `response_format` repariert die Form, nicht das Urteil, und eine leere Antwort geht
  gar nicht erst an ein Modell.
- **Die Werkbank** startet den Dienst selbst (Port `LocalModelServer.DEFAULT_PORT`, 11435,
  nicht Ollamas 11434), hat eigene Zeitlimits (`LAB_HTTP_TIMEOUT`, 60 s; `http_timeout`
  vor `add_child`), ändert den Schlüssel, ohne ihn zu speichern, und sagt an jedem Satz, ob
  er aus einem Pack oder dem Submodule kommt — ein Pack verdeckt das Submodule auch in der
  Entwicklung. `LocalModelServer` und `LocalModelBackend._report` schreiben Aufruf, Pid,
  Gründe und die volle Modellantwort ins Log; die Konsole von llama-server gibt es nur über
  `show_console`.
- **Kein Test braucht einen laufenden Dienst oder drückt den Startknopf.** Stufe 1 spielt
  im Test ein erfundenes Backend (`tests/sentence_judge_test.gd`). Der Datentest liest die
  Dateien (`LanguageData.entries`), nicht die Registry, und behauptet am Ende, dass
  überhaupt etwas geprüft wurde (`test_the_stock_carries_keyed_sentences`).

### Meisterung: ein Wort braucht beide Richtungen

Der Fortschrittsbalken je Unit (Statistik, Reiter „Fortschritt") zählt WÖRTER:
`PlayerProgress.mastered_lexemes` nimmt ein Lexem erst auf, wenn `translate:de_to_en:<id>`
UND `translate:en_to_de:<id>` über der Schwelle liegen — allgemein beide Richtungen seiner
Sprache (`Lexeme.mastery_directions`: `de_to_<sprache>`/`<sprache>_to_de`, ADR 0007). Der
Reiter „Aufgaben" daneben zählt learnable_ids — zwei Maße, zwei Reiter, mit Absicht.

Ein Verb mit `irregular: true` braucht dazu seine Formaufgaben (ADR 0009): die
learnable_ids, die es braucht, sammelt `ContentRegistry.form_requirements()` beim Laden
(Definitionen mit `requires_form`, deren Form das Lexem hat), und `mastered_lexemes_in`
und `mastered_lexeme_in` bekommen sie übergeben, damit die Regel statisch prüfbar bleibt.
Der Ring auf der Karte (`MapCanvas`, stetig bis 100 %, Füllfarbe nach
`MapCanvas.FILL_PERCENT`) rechnet aus denselben `done`/`total` wie `FortressTier` — mit
eigenen Schwellen, aber ohne eigenen Zähler (ADR 0009, Nachtrag).

Die Kopplung macht den Balken **empfindlich gegen alles, was EINE Richtung stört**: fällt
en→de aus, steht die Unit dauerhaft auf „0 von N", während „Gemeisterte Aufgaben" weiter
steigt. Das sieht aus wie ein Rechenfehler der Statistik und war noch nie einer (die
Rechnung hält `tests/mastered_lexemes_test.gd`). Gesucht wird deshalb im Weg der Richtung
in den Pool:

- **Ein Filter nach Schwierigkeit** darf keine Lernrichtung wegnehmen. Der frühere Riegel
  (`difficulty_max`) nahm auf Stufe 1 en→de heraus; er ist inzwischen ganz entfallen,
  `definition_allowed()` filtert nur noch nach Auswahl und Richtung.
- **Geteilte deutsche Prompts** in einer Unit machen de→en zur Ratefrage
  (Regel und Ausnahmen: `docs/ADDING_CONTENT.md`).
- **`excluded_task_types`** muss den Nenner mitnehmen (`PlayerProgress.masterable()`),
  sonst steht der Balken auf „N-1 von N".
- **Dubletten**: dasselbe Wort unter zwei Ids hat zwei Fortschrittsstände, die vier nötigen
  Treffer verteilen sich, und keine Id wird gemeistert. Unter den buchgebundenen Lexemen
  ein Einzelfall; der ungebundene Grundwortschatz, in dem es die Regel war, ist entfallen
  (ADR 0006).

### Die Feier beim Meistern (Issue #23)

Der Anlass ist der Übergang von `mastered_at` 0 auf einen Zeitstempel: `PlayerProgress.record()`
liefert dann `true` (nur wenn die Confidence vorher unter der Schwelle lag, sonst würde
Altbestand ohne Zeitstempel gefeiert). Der WaveRunner meldet danach `EventBus.task_mastered`
und, wenn `mastered_lexeme_of()` ein Lexem nennt, `lexeme_mastered`. Kein neues Speicherfeld.

- **Anzeige** `MasteryCelebration` (`scenes/ui/mastery_celebration.tscn`) hängt nur am
  EventBus. Sie sammelt bis zum Frame-Ende und nimmt die größere Feier; jede weitere stellt
  sich an. Solange eine ansteht (`is_busy`), hält `WaveRunner._check_end` das Wellenende
  zurück — auch das letzte Monster wird gefeiert. Die Spur schreibt `mastered` und
  `word_mastered`; das Debug-Panel feiert über `celebrate()` an beidem vorbei.
- **Anhalten** über die Baum-Pause (`get_tree().paused`), nicht über `time_scale`: die
  Effekte sind `GPUParticles2D` in der Szene, und die hängen an `delta` — bei time_scale 0
  stünden sie mit. Weiter laufen nur Knoten auf `process_mode = ALWAYS`: die Feier, die
  Antwort-Eingabe (in `battle.tscn`) und `Sfx`. Wer einen Timer im Kampf anlegt, der in
  der Pause stehen soll, braucht `create_timer(t, false)` — der Standard läuft weiter
  (Spawn-Timer, Explosion). Nur die Blitze sind ein eigener Knoten (`src/fx/lightning.gd`).
- **Antwortzeit**: der WaveRunner schiebt `spawned_at_ms` jedes Monsters auf dem Feld um die
  Dauer der Feier. Während der Feier abgeschickte Antworten werden aufgehoben und danach
  ausgewertet (`_held_answers`).

### Standbild bei Schreibfehlern (ADR 0010)

Ein Treffer, der nicht exakt oder nicht vollständig war (`verdict.exact`/`complete`),
merkt sich in `WaveRunner._score_hit` Form und Markierungen — Schreibfehler rot
(`AnswerEvaluator.spelling_marks`), fehlende Klammergruppen und Platzhalter blau
(`AnswerEvaluator.missing_marks`) — und hält die Feier an (`MasteryCelebration.hold()`).
Nach der Explosion spielt `SpellingFreeze` (`scenes/ui/spelling_freeze.tscn`): kurzer
Vorlauf, dann `started(ms)` → dieselbe Baum-Pause und Verschiebung von `spawned_at_ms`
wie bei der Feier, Kamerafahrt über `WaveRunner.spelling_zoom(camera, ziel)` (k von 0
nach 1 und zurück, bei 0 exakt der Ausgangszustand), `finished` → Pause aus,
`release()`, aufgehobene Antworten. Mehrere Standbilder stellen sich an; solange eines
ansteht (`is_busy`), wartet auch das Wellenende. Ein Formschild über dem Monster gibt es
nicht mehr.

## Wirtschaft: Gold und Schatzkisten (`src/economy/`)

Gold ist die erste Währung. Verdient wird es als **Schatzkiste am Wellenende**, gehalten
wird es im **Profil** — nicht im Lauf: eine gefallene Festung kostet den Lauf, nicht das
Erspielte.

| Baustein | Wo | Aufgabe |
|---|---|---|
| `ChestReward` | `src/economy/chest_reward.gd` | reine Rechnung: Güte der Kiste + Goldmenge |
| `Wallet` (Autoload) | `src/economy/wallet.gd` | Goldstand des Profils, verdienen/ausgeben, Persistenz |
| `TreasureChest` | `src/ui/treasure_chest.gd` + `scenes/ui/treasure_chest.tscn` | die Kiste zum Aufdrücken (2 s halten, Wackeln, Platzen, Münzflug) — ein 3D-Modell in eigener Welt |
| `WaveStats` | `src/ui/wave_stats.gd` | Wellenabschluss in zwei Stufen: Ergebnis (Statistik + Kiste) → nächste Welle |
| `PageStack` | `src/ui/page_stack.gd` | Seitenstapel mit fester Größe (Mindestgröße = größte Seite, auch unsichtbar) |
| Werkbank | `scenes/dev/chest_lab.tscn` | die Kiste ohne Spiel ausprobieren (Güte, Gold, Münzen, Haltezeit, Modell/Zeichnung); im Export ausgeschlossen |

- **Die Menge Gold kommt aus den PUNKTEN der Welle**, nicht aus der Zahl der Monster: die
  Punkte je Monster tragen die Schwierigkeit schon in sich (`WaveGenerator.reward` steigt
  mit der Grundschwierigkeit der Aufgabe, fällt mit der Confidence des Spielers, wächst
  mit dem Wellentempo). Ein zweites Schwierigkeitsmaß daneben liefe auseinander, sobald
  eines von beiden justiert wird.
- **Die Güte kommt aus der Genauigkeit** (`WOOD`/`BRONZE`/`SILVER`/`GOLD`, perfekt = Gold)
  und wirkt als Faktor auf die Menge. Sie ist das, was in DIESER Welle besser zu machen
  war, und unabhängig davon, wie lang die Welle war.
- **Verbucht wird im `WaveRunner`, nicht im Screen** (`_on_reward_collected` →
  `Wallet.earn`). Die Kiste meldet per `opened` nur, dass sie offen ist; so ist dieselbe
  Kiste später auch am Tagesziel oder nach einem Boss zu haben, ohne dass sie weiß, wem
  sie etwas gutschreibt. Einen Gesamtstand zeigt der Abschluss bewusst nicht.
- **Justiert wird an zwei Konstanten** in `chest_reward.gd`: `GOLD_PER_SCORE` (Menge) und
  `TIER_FACTOR` (Zuschlag der Güte). Kein eigenes Schwierigkeitsmaß daneben bauen.
- **Die Kiste gibt es auch nach einer Niederlage** — verdient ist verdient. Ohne besiegtes
  Monster gibt es keine Kiste, sondern Trostgold (`ChestReward.CONSOLATION_GOLD`), das ohne
  Öffnen über ein eigenes Signal (`consolation_collected`) verbucht wird: `Wallet` zählt
  geöffnete Kisten mit, und dies ist keine.
- **An einer ungeöffneten Kiste führt kein Weg vorbei**: Weiter und Menü sind `disabled`,
  bis sie offen ist (nicht ausgeblendet, siehe feste Größe unten). Zwei Sekunden Drücken
  sind kein Hindernis, ein weggeklickter Fund ist einer.
- **Stufe 2 trägt die Sitzungsbilanz** (`RunBalance.build`) — nach einem Sieg über der
  Wahl, nach einer Niederlage als Abschluss; Escape zeigt keine. Gebaut wird sie beim
  Wellenende, weil `SessionLog.end()` die laufende Sitzung leert, und mit den Regeln des
  Statistik-Screens (`fresh_rows`, `comeback_rows`). Weil sie über den `PageStack` auch
  Stufe 1 größer macht, sind ihre Zeilen einzeilig mit fester Breite und die Wortliste auf
  `BALANCE_WORDS` gedeckelt („und N weitere").
- **Die Kiste ist ein 3D-Modell in einem eigenen SubViewport**, keine Zeichnung
  (`chest.gltf` aus dem KayKit-Dungeon-Satz, Nachweis in `assets/models/CREDITS.md`).
  Eigene Welt und durchsichtiger Hintergrund halten sie vom Kampf getrennt, über dem der
  Abschluss-Screen hängt. Der Deckel ist ein eigener Knoten mit dem Scharnier als
  Ursprung, Aufklappen also eine Drehung um X. Die gezeichnete Fassung bleibt erreichbar
  (`use_model = false`): als Vergleich in der Werkbank und als Rückfall, wenn das Modell
  fehlt.
- **Die Güte sitzt im Beschlag und kommt aus dem Texturatlas**, nicht aus einem
  Farbfilter: der Atlas ist ein Raster aus 8×4 Verlaufsfeldern, die Kiste benutzt genau
  zwei (Beschlag, Holz), und ein Feldsprung in den UV-Koordinaten der Beschlag-Vertices
  macht aus Stahl Kupfer, Silber oder Gold (`TIER_METAL`). Das Gold ist dasselbe Feld, aus
  dem die Münze ihre Farbe nimmt.
- **Aus der Kiste fliegt eine Münze je Goldstück** (`TreasureChest.coin_count`), als
  Modell (`coin.gltf`) in derselben 3D-Welt, taumelnd und unten aus dem Bild. Gedeckelt
  ist nur der zeitliche Versatz zwischen den Münzen, damit 200 Gold nicht tröpfeln. Weil
  die Münzen mehr Platz brauchen als die Kiste, ist der gerenderte Ausschnitt größer als
  das Widget (`STAGE_PAD`) — die Kiste selbst bleibt in ihrem Platz im Layout, geprüft
  gegen das Widget-Rechteck. Verblasst wird keine Münze: `GeometryInstance3D.transparency`
  gibt es im `gl_compatibility`-Renderer nicht, deshalb fallen sie unter die Bildkante.
  Die Einzelheiten zu Atlas, Mesh-Kopie, Kamera und Polster stehen im Kopf von
  `treasure_chest.gd`.
- **Die Größe des Abschluss-Screens steht fest**, solange er sichtbar ist: er hängt in
  der Bildmitte, und eine Größenänderung beim Weiterblättern verschiebt die Knöpfe unter
  dem Zeiger. Dafür der `PageStack` plus die Regel, innerhalb einer Seite nur zu sperren
  und umzubeschriften statt ein- und auszublenden.
- **Die Münzen der Monatsreihe sind keine Währung.** Sie markieren geübte TAGE
  (`CoinStrip` rechnet die Zustände, `StatsDay` zeigt einen Tag; Vorrat aus
  `SessionLog.played_day_count()`); Gold zählt in Beträgen. Deshalb redet die Reihe von
  Tagen — zwei Dinge, die „Goldstück" heißen, wären eines zu viel. `DayCoin` ist nur noch
  die gezeichnete Münze, die aus der Schatzkiste fliegt; ihr `State` bleibt das Maß für
  beide.
- **Die Statistik ist ein Fenster wie die Fähigkeiten** (`stats_screen.tscn`): dieselben
  Schichten (Rahmen `GameWindow`, gekachelte Fläche, Titelband, Gelenke), dasselbe
  Schließen-X, `closed` an `profile_menu._open_window`, das den Fokus an den Knopf
  zurückgibt. Die Reiter sind drei Knöpfe `WindowTab` in einer `ButtonGroup` statt eines
  `TabContainer` — dessen Reiter nähmen die Bilder des Fensterpakets nur über das ganze
  Theme an. Alle Seiten liegen übereinander in `Pages`, das Fenster ändert beim Umschalten
  seine Größe nicht. Den Tag unter dem Tastaturfokus erklärt `Hints.show_for`. Werkbank:
  `scenes/dev/stats_lab.tscn -- --shoot [--tab=N] [--day=N] [--scroll=N] [--language=fr,la] [--sizes]`.
- **Der Sprachfilter der Statistik rechnet, er speichert nicht** (Issue #45, `LanguageBar`):
  die Sprache einer Aufgabe kommt aus ihrer Richtung, bei Formen und Relationen aus dem Buch
  ihres Lexems (`Lexeme.language_of_learnable`, `ContentRegistry.book_language`); die Zähler
  in `PlayerProgress` nehmen optional eine Liste von Sprachen (`_records_in`). Zur Wahl steht
  je Sprache eines Buchs eine Flagge (`assets/ui/flags/<sprache>.svg`, Variation
  `FlagChoice`), in der Reihenfolge des Regals (`BookSelect.shelf_rows`), mehrere zugleich;
  sind alle an, wird nicht gefiltert. Profilwerte
  und `SessionLog` bleiben sprachübergreifend — Sitzungen tragen keine Sprache. Die Wahl
  ist ein `static var` wie die Sortierung: Ansicht, kein Zustand neben dem Scope.
- **Inhalte und Einstellungen sind dasselbe Fenster** (`content_manager.tscn`,
  `settings_menu.tscn`), die Einstellungen mit denselben Reitern. Knöpfe mit Text tragen
  `WindowButton` (die Rahmen der Hauptmenü-Knöpfe, klein), eine Auswahl wie die
  Standard-Schwierigkeit `ToolChoice` (Werkzeugrahmen, gedrückt golden) in einer
  `ButtonGroup`. Abschnitte trennt `StatRule`, eine Pack-Zeile ist kein Kasten mehr. Die
  Rückfrage zum Zurücksetzen ist ein `ConfirmDialog` im Fenster. Geöffnet wird jedes über
  `ProfileBadge.open_window` — auch aus Bibliothek und Karten, wo die kompakte Plakette
  Fähigkeiten und Statistik anbietet; solange eines offen ist, fängt sie die Tasten ab, die
  das Fenster nicht nimmt. Nach dem Schließen liest die Plakette sich neu, das Menü die
  Spielbarkeit (`window_closed`) — Umbenennen und Installieren melden kein Signal.
  Werkbank: `menu_lab -- --shoot --content | --settings[=1..3]`.
- **Karten im Kampf sind kleine Fenster** (Wellenabschluss, Vokabel-Auflösung,
  `ConfirmDialog`): derselbe Rahmen, dasselbe Titelband, aber so groß wie ihr Inhalt. Die
  Wurzel ist ein `PanelContainer` mit `GameCard` (Fensterrahmen als `StyleBoxTexture`,
  Innenabstand 0). Fläche und Gelenke kann er nicht als verankerte Kinder tragen — ein
  `PanelContainer` zieht jedes Kind auf volle Größe —, deshalb zeichnet sie `WindowChrome`
  selbst: `SURFACE` als erstes Kind der Karte (gekachelt, auf das Achteck innerhalb des
  Rahmens beschnitten), `JOINTS` als erstes Kind des Titelbands. Knöpfe darin tragen
  `WindowButton`, der eine Weg nach vorn `WindowPrimary` (dieselbe Größe, goldener Rahmen)
  — `MainMenuPlay` ist für das Hauptmenü gemacht und in einer Karte viel zu groß. Ein
  Symbol-Schalter (Ich-Sicht) ist `WindowToggle`: gewählt golden, nicht blasser. Alle drei
  sind 9-Slice-Rahmen aus `assets/ui/main_menu/buttons/small/` (der Hauptmenü-Rahmen auf ¼,
  `shrink_image.gd`), damit der Rand auf jeder Breite gleich dick bleibt — auch im Quadrat. Werkbank:
  `wave_card_lab` schaltet mit ◀/▶ (Bild↑/Bild↓) durch alle Karten;
  `-- --snap --card=result|opened|levelup|consolation|next|defeat|reveal|confirm [--size=WxH]`
  speichert eine als Bild (`--snap`, weil der eingebettete `battle_theme_lab` auf `--shoot` hört).
- **Bilder in der Größe, in der sie stehen.** Ein 9-Slice-Rahmen zeichnet seine Ränder in
  Texturpixeln, ein stark verkleinertes Bild flimmert an feinen Kanten. Reiter
  (`statistics/tabs/`) und Spieler-Medaillon (`player_badge/menu/`) liegen deshalb vorab
  verkleinert vor, so dass sie bei 1920 × 1080 Pixel für Pixel stehen, mit Mipmaps für
  die Bezugsgröße. Erzeugt mit `src/dev/shrink_image.gd` aus den Paketbildern.
- **Festungsanzeige der Gebietskarte** nach `assets/ui/fortress/` (README dort): Namens-
  und Fortschrittsrahmen, Medaillon, Stufenplakette, verkleinert unter `fortress/small/`
  (Variationen `FortressName`, `FortressProgress`, `FortressBar`). Die Rahmen greifen
  ineinander — `OverlapRow` schiebt jedes Teil um seinen Rand in das vorige, vorn liegt der
  Namensrahmen (Baumreihenfolge; die Plätze nennt `order`, kein `z_index` — der hob ihn über
  die Fenster der Plakette). Statt des Burg-Bildes der Vorlage zeigt das Medaillon die Festung
  der Stufe aus dem Kampf: `FortressModel` baut sie für `WaveRunner` und für
  `src/dev/fortress_icons.gd`, das daraus `fortress/tiers/tier_<n>.webp` rendert
  (`GODOT_WINDOW=1`). Ändert sich die Festung im Kampf, die Bilder neu rendern.
  Schrift der Anzeige ist Fira Sans (OFL, `assets/fonts/`, Variationen `Fortress*`), näher am
  Konzept als die Standardschrift.

## Erfahrung und Level (`src/progression/`)

Erfahrung ist die zweite Größe, die über den Lauf hinaus bleibt — neben dem Gold, und mit
der umgekehrten Absicht: Gold ist Beute, Erfahrung ist Lernfortschritt.

| Baustein | Wo | Aufgabe |
|---|---|---|
| `Experience` | `src/progression/experience.gd` | reine Rechnung: XP je Monster, Stufenkosten, Skillpunkte |
| `PlayerLevel` (Autoload) | `src/progression/player_level.gd` | Gesamt-Erfahrung des Profils, Aufstieg, Persistenz |
| Anzeige | `hud.tscn` (Level + Erfahrungsring am Porträt), `wave_stats.gd` (Zuwachs der Welle), `profile_badge.gd` (Level, Bogen im Level, Gold; Menü, Bibliothek und Karten) / `stats_screen.gd` (Stand + offene Skillpunkte) | — |

- **10..15 XP je besiegtem Monster, aus seiner Schwierigkeit** — und zwar aus DERSELBEN,
  aus der auch Tempo und Punkte entstehen (`WaveGenerator`, das Netto-Maß `t - c` aus
  Aufgaben-Grundschwierigkeit und Confidence). Ein zweites Schwierigkeitsmaß daneben liefe
  auseinander, sobald eines von beiden justiert wird.
- **Eine schon gemeisterte Aufgabe bringt 1 XP** (`Experience.MASTERED_XP`). Erfahrung
  kommt aus dem Lernen, nicht aus dem Wiederholen des Gekonnten; ganz auf 0 wäre eine
  Strafe für die Wiederholung, und die wählt der Scheduler, nicht der Spieler. Geprüft
  wird die Meisterung beim SPAWN — nach dem Treffer hat `PlayerProgress` die Confidence
  schon angehoben, und das Monster, das die Meisterung bringt, soll noch voll zählen.
- **Der Wellenfaktor (`speed_scale`) hebt die Punkte, nicht die Erfahrung.** Eine härtere
  Welle bringt mehr Monster und mehr Beute; das einzelne Wort wird davon nicht schwerer.
  Ohne diese Trennung wäre die schnellste Welle auch der schnellste Weg zum Levelup.
- **Aufstieg bei Level × 100 XP** (Level 2 ab 100, Level 3 ab 300, Level 4 ab 600): die
  Stufenkosten sind linear, die Summe damit quadratisch. **Jeder Aufstieg gibt einen
  Skillpunkt** (`SKILL_POINTS_PER_LEVEL`), ausgegeben wird er im Fähigkeitsbaum (siehe
  unten).
- **Gespeichert wird EINE Zahl: die Gesamt-Erfahrung.** Level, Levelfortschritt und
  Skillpunkte sind daraus gerechnet (`Experience`). Ein zweiter gespeicherter Zähler
  daneben könnte abweichen, und dann wäre nicht zu sagen, welcher stimmt — ein von Hand
  hochgesetztes Level in der Datei wird beim Laden verworfen.
- **Verbucht wird im `WaveRunner`, nicht im Screen** (`_defeat` → `PlayerLevel.gain`),
  genau wie beim Gold. Auf die Platte kommt sie erst am Wellenende (`SaveCoordinator`,
  ADR 0024): bricht die Welle ab, zählt ihre Erfahrung nicht. Der Abschluss-Screen bekommt
  nur den Zuwachs der Welle und liest den Stand bei `PlayerLevel`.
- **`PlayerLevel.skill_points()` ist der VERDIENTE Stand**, die offenen Punkte rechnet
  `SkillBook.available()` aus den gelernten Knoten — auch dort kein zweiter Zähler.
- **Level und Erfahrung stehen im HUD am Porträt**: das Level in der Plakette, die
  Erfahrung nur als Ring (`XpRing`), ohne Zahl. Die Kopfleiste hat zwei Tafeln fester
  Breite (Festung links, Welle rechts; Grafiken `assets/ui/gameplay/`),
  `tests/hud_header_test.gd` misst mit einem späten Spielstand, dass keine wächst.

## Karte und Laufanfrage (ADR 0006)

Der Hauptweg ins Spiel: **Bibliothek → Buchkarte → Gebietskarte → Kampf**. Das alte
Runden-Setup (`session_setup.tscn`) ist der Expertenmodus.

| Baustein | Wo | Aufgabe |
|---|---|---|
| `RunRequest` | `src/core/run_request.gd` | statisch: was der nächste Lauf spielt — ein Level der Karte oder die Auswahl des Expertenmodus; Scope, Tags, Aufgabenpool, Unit, Rücksprung |
| `MapLevel` | `src/progression/map_level.gd` | die Level einer Unit (T1…T4, Gesamt, Boss) aus `ContentRegistry.parts_for`; Stufe und Zählung je Level |
| `BossRecord` | `src/progression/boss_record.gd` | Boss-Siege je Unit (Ursprungswert), Medaille bei 1/3/5 Siegen |
| `RunSave` | `src/progression/run_save.gd` | begonnene Läufe von der Karte, ein Platz je Buch (ADR 0020) |
| `MapSelection` | `src/ui/map_selection.gd` | welches Buch, welche Unit gerade offen ist (überdauert den Szenenwechsel) |
| `MapLayout` | `src/ui/map_layout.gd` | Bild und Punkte unter `assets/maps/<book>/` (`book.png`, `unit<n>.png`, `map.json`) |
| `BookNaming` | `src/core/book_naming.gd` | Wie das Buch sich und seine Ebenen nennt („Dossier 2 · Partie A", „Abschnitt 2 · Lektion 10"); unter `naming` in `map.json`, ohne Eintrag „Unit"/„Teil" |
| `MapCanvas` | `src/ui/map_canvas.gd` | zeichnet eine Karte: Bild letterboxed in 16:9, Weg, Orte mit Fortschrittsring, Bonus-Sternen, Medaille |
| Screens | `book_select` (die Bibliothek), `book_map`, `area_map` (`src/ui/` + `scenes/ui/`) | die drei Ebenen; die Bibliothek ist kein eigener Screen, sondern die dritte Seite von `profile_menu.tscn` |
| Bibliothek | `scenes/ui/library_room.tscn` in `menu_backdrop.tscn` | der Raum im Turm der Menü-Kulisse: Lesepult, Regale, Kerzen, `%Eye` (Kamerastand), `%Books` (dort stellt `BookSelect` die Bücher auf) |
| `Book3D` | `src/ui/book_3d.gd` + `scenes/ui/book_3d.tscn` | ein gebundenes Buch auf dem Lesepult: leicht schräg (`SLOT_ANGLE`, Rücken links sichtbar), ausgewählt vom Pult genommen — nach vorn, gerade zur Kamera, ein Stück zur Bildmitte (`TOWARD`), mit Glanz (`book_glow.gdshader`) und Stand auf dem Cover —, beim Öffnen schlägt der vordere Deckel am Falz auf. Das Cover ist eine 2D-Szene im SubViewport (Einband `assets/ui/library/`, Karte im `OrnateFrame`, darunter der Stand); die Doppelseite trägt die Buchkarte. `spread_view` liefert den Kamerastand, aus dem die Doppelseite das Bild so füllt wie die Buchkarte — die Bibliothek fliegt die Kamera dorthin und blendet erst am Ende auf das flache Bild über |
| `BookMesh` | `src/ui/book_mesh.gd` | Profile des Einbands (gerundeter Rücken, Deckel mit Falz) und ihre Extrusion zu Meshes, je Buch nach seiner Dicke |
| Werkbank | `scenes/dev/map_lab.tscn` | Punkte und Weg auf die Kartenbilder setzen, schreibt `map.json`; im Export ausgeschlossen |
| `BattleTheme` | `src/battle/battle_theme.gd` + `assets/battle_themes/*.tres` | Farben von Boden und Licht und die Deko im Kampf, je Unit passend zur Gebietskarte; Zuordnung unter `themes` in `map.json` |
| Werkbank | `scenes/dev/battle_theme_lab.tscn` | das Schlachtfeld in jedem Thema, ohne Kampf; `-- --shoot` legt Bilder unter `reports/battle_themes/` ab, `-- --specimens` Nahaufnahmen der Deko (braucht `GODOT_WINDOW=1`) |
| Modellschmiede | `src/dev/model_forge.gd` | baut die eigenen Low-Poly-Modelle unter `assets/models/forge/` aus Grundformen; die `.glb` sind Ergebnis, geändert wird der Generator |

- **Die Bibliothek liegt in der Menü-Kulisse.** `ProfileMenu` hat drei Seiten
  (0 „Wer spielt?", 1 Hauptmenü, 2 Bibliothek); `MenuBackdrop.view_at(page)` führt die
  Kamera von 1 nach 2 in den Turm (`%Library/%Eye`), und `_light_for` blendet Nebel,
  Himmel und Sonne dabei nach innen. Für den Flug ins Buch übernimmt `BookSelect` die
  Kamera (`hold_camera`) und gibt sie am Ende des Rückflugs zurück. Aus der Buchkarte
  zurück (`MapSelection.to_shelf`) startet `profile_menu.tscn` direkt auf Seite 2.
- **Gezielt wird auf den Platz in der Reihe** (`Book3D.hit`), nicht auf das
  herausgenommene Buch — das steht groß vor den Nachbarn. `hit_body` gilt nur, solange
  der Zeiger auf dem herausgenommenen Buch über keinem Platz steht. Nach dem Hereinfahren
  ist kein Buch herausgenommen; erst eine echte Mausbewegung oder ←/→ wählt. Das Pult hat
  `BookSelect.SLOTS` Plätze, mehr Bücher blättern die Pfeile (`slot_x`, jede Seite mittig).
- **Kampf und Boss lesen ihren Bereich aus `RunRequest`, nie aus `UserSettings`.**
  `WaveRunner` (Aufgabenpool, Festungsstufe, Rücksprung), `SentenceSelector.pool_from_settings`
  und `BossFight` fragen dort. Ohne Level fällt `RunRequest` auf die gespeicherte Auswahl
  zurück — das ist der Expertenmodus, der beim Öffnen `start_expert()` ruft. Ein Level
  spielt alle Aufgaben- und Wortarten seines Scopes und keine Tags.
- **Bonus-Level** (ADR 0012): Formen, die das Buch später lehrt als ihr Wort, bilden je
  lehrender Lektion und Formart einen Bonus (`ContentRegistry._index_bonuses`, Scope-
  Schlüssel `bonus:<book>/<unit>/<part>/<form_type>`). Er steht als eigener Ort zwischen
  Gesamt und Boss (`MapLevel.KIND_BONUS`, Punkt `bonus/<part>/<form_type>` mit `title` in
  map.json), zählt Aufgaben statt Wörter (`BonusLevel.counts`), nicht zur Festung und nicht
  zur Meisterung eines Wortes. „Gesamt" und jeder Scope über die ganze Unit spielen ihn mit
  (`form_task_in_scope`); der Bonus-Lauf steht mit der Festung seiner Unit da
  (`bonus_units`). Auf der Buchkarte ein Stern je Bonus, in der Statistik eine Zeile unter
  der Unit.
- **Wort-Bonus** (ADR 0013): Lexeme mit `bonus: "<thema>"` sind Zusatzstoff ihrer Unit
  (Schlüssel `bonus:<book>/<unit>/0/<thema>`, Punkt `bonus/0/<thema>`). Sie stehen nur
  unter diesem Schlüssel (`_scope_keys`), also in keinem Teil, nicht in der Festung
  (`FortressTier.unit_key`) und nicht in den Sätzen; im Bonus und in „Gesamt" kommen sie
  mit allen Aufgaben (`in_word_bonus`). Ein vorhandenes Wort spielt über
  `also_bonus` mit, ohne Dublette.
- **Ein Klick markiert, „Spielen" startet.** `MapLevel.toggle` führt die Auswahl der
  Gebietskarte: Teile und Boni beliebig zusammen, Gesamt und Boss allein. `MapLevel.combine` macht
  daraus EIN Level für `RunRequest` — mehrere Teile mit allen ihren Scopes, `keys` nennt
  die Orte (Zoom hinein und zurück in ihre Mitte, Vorauswahl nach dem Kampf). Markiert
  zeichnet `MapCanvas.set_selected` als wippenden weißen Pfeil über dem Ort — Gold ist
  der Fortschritt; der Knopf `%PlayButton` wird gesperrt statt ausgeblendet.
- **Der Ring ist der Meisterungsstand.** Er füllt sich mit dem Anteil gemeisterter
  Wörter, die Füllung wird bronze, silbern, golden (`MapCanvas.fill_level`). Bei 100 %
  wird er massiv und pulsiert; Schein und Funken zeichnet eine additive Ebene (`_fx`,
  `BLEND_MODE_ADD`), zustandslos aus der Zeit gerechnet. Bonus-Sterne unter einem Ort
  (`node["bonus"]`) leuchten mit denselben Funken, wenn ihr Bonus gemeistert ist. Ein
  weicher Schatten um Ort und Sternreihe hebt beides vom bunten Bild ab. Werkbank:
  `scenes/dev/map_ring_lab.tscn`.
- **Nichts wird gesperrt, nichts als Abschluss gespeichert.** Die Stufe eines Levels ist
  `FortressTier.part_tiers` (Teil) bzw. `unit_tiers` (Gesamt) — dieselbe Zählregel und
  dieselben Schwellen wie die Festung. Gespeichert wird nur, was sich nicht ableiten
  lässt: der Boss-Sieg. Nur ein Sieg mit `RunRequest.unit_key()` zählt; er geht über
  `EventBus.boss_won` auch in die Spur.
- **Rasten** (ADR 0020): ein Lauf von der Karte, dessen Festung steht, wird auf Stufe 2
  gerastet (`RunSave`, ein Platz je Buch). Gespeichert sind die Orte (`keys`), Welle,
  Schwierigkeit und `GameState.run_snapshot()`; Scope und Maxima werden beim Fortsetzen
  neu gerechnet (`RunSave.resumable_level`, `GameState.restore_run`). Die Gebietskarte
  markiert die Orte; eine Auswahl, die sie alle enthält, setzt fort und darf weitere Orte
  der Unit dazunehmen (`RunSave.continues`, Gesamt zählt als alle Teile, der Boss nie).
  „Fortsetzen" trägt den Stand über `RunRequest.start_level(level,
  resume)` in den Kampf, der ihn einmal nimmt und den Platz verwirft.
- **Bilder liegen in der EXE**, nicht im Pack (`export_presets.cfg` nimmt
  `assets/maps/*.json` mit). Punkte stehen in Anteilen des Bildes (0..1). Fehlt Bild oder
  ein Punkt, zeichnet `MapCanvas` eine schlichte Fläche und legt ALLE Orte selbst aus
  (`default_positions`) — eine neue Unit ist so spielbar, bevor ihr Bild existiert.
  Die Bilder entstehen außerhalb dieses Repos.
- **Auf der Gebietskarte bewegt sich das Bild** (`MapAmbience`, `map.json` `ambience`):
  - Wasser schlägt Wellen (Feld) oder Ringe, Wasserfälle laufen, Nebel zieht, aus Glut
    steigt Rauch, Fackeln flackern; jeder Effekt hat eine Intensität.
  - Flächen sind gemalte Graustufen-Masken, je Eintrag eine
    (`unit<n>_<mask>.webp`, `MapLayout.mask_path`; `mask` fehlt beim ersten einer Art und
    heißt sonst `<kind>2` …, so bleibt jedes Feld mit eigenen Einstellungen); Form und Intensität stehen im Eintrag
    in `map.json`. Quellen sind Punkte. Beides setzt man in `map_lab`, Flächen mit dem
    Pinsel. WebP verlustfrei, weil die PNGs unter `assets/maps` nicht exportiert werden.
  - Die Ebene liegt wie das Bild hinter der Zeichnung von `MapCanvas` (`show_behind_parent`):
    Bild, dann Bewegung, dann Weg und Orte, dann `_fx`.
  - Bewegt wird nur im Shader (`TIME`, `assets/shaders/map_*.gdshader`). Neu gezeichnet
    wird nur mit der Karte, ein `_process` gibt es nicht.
  - Eine Fläche zeichnet das ganze Kartenbild; der Shader liest das gemalte Wasser selbst,
    verschoben, und verwirft, was die Maske nicht trifft (`map_ambience.gdshaderinc`).
    Grauwerte schwächen die Bewegung, ein weich gemalter Rand läuft weich aus.
  - Fehlt `ambience`, steht das Bild still da.
- **Der Kampf steht in der Landschaft seiner Gebietskarte** (`BattleTheme`). Ein Thema
  färbt Boden, Hügel, Kuppen und Flecken (Schnee), Hintergrund, Umgebungslicht und
  Sonne und wählt die Deko: je Platz (`trees`, `rocks`, `grass`, `props`, `landmarks`)
  eine Liste von Modellen. Wo die Deko steht, wie viel und wie groß, gehört dem Platz im
  `WaveRunner` — ein Modell wird für seinen Platz bemessen, nicht der Platz fürs Modell.
  Bahn, Hügelform und Festung sind überall dieselben. Dazu kann ein Thema eine graue
  Detailtextur des Bodens nennen (`ground_texture`, Kachel 8 × 8 m unter
  `assets/textures/ground/`, Shader `assets/shaders/battle_ground.gdshader`): sie moduliert
  nur die Helligkeit der Vertexfarben, 50 % Grau lässt sie stehen. Fehlt die Datei, bleibt
  der Boden glatt. Die Texturen malt ein Bild-Agent nach `assets/textures/ground/BRIEF.md`;
  ein Test hält, dass jede genannte Textur dort bestellt ist. Die Vorgaben der Klasse SIND
  das Aussehen ohne Thema (Expertenmodus, Unit ohne Eintrag). Ein Test hält, dass jede
  Unit mit Gebietsbild ein vorhandenes Thema nennt (`tests/battle_theme_test.gd`).
  Liegt auf einer Karte eine Siedlung oder Stadt zwischen Busch und Strand, nennt die Unit
  statt eines Namens `{ "default": …, "t2": … }`: ein Stop mit eigenem Eintrag bekommt
  sein Thema, jeder andere `default` (`BattleTheme.for_level` liest dafür `key` des
  Levels). Das Licht gehört der Unit, nicht dem Ort: ein Thema mit `light_from` nimmt
  Hintergrund, Umgebungslicht und Sonne von dort, so dass eine Unit zu einer Tageszeit
  spielt. Eine Stadt ist im Kampf ein Stadtpark — Rasen, Laternen, Bänke, Türme nur im
  Umland —, denn die Hügel sind in jedem Thema dieselben und gepflastert sähen sie falsch
  aus. Der Bosskampf trägt kein Thema.
  Die Farben kommen im Licht des Kampfes etwa halb so hell an, wie sie in der `.tres`
  stehen — abgestimmt wird am Bild der Werkbank, nicht an den Zahlen.
- **Wind, Wolken und Luft.** Bäume und Gras schwanken (`Wind.sway`): das Modell bekommt statt
  seines StandardMaterial3D den Windshader (`assets/shaders/wind.gdshaderinc`), der es mit
  denselben Werten zeichnet und die Ecken mit der Höhe biegt; nur Modelle aus `Wind.SWAY`
  schwanken, denn im Platz `trees` stehen auch Häuser. Über den Boden ziehen Wolkenschatten
  (gerechnetes Rauschen im Bodenshader, nimmt der Sonne ihren Anteil wie ein Schatten).
  Beide laufen nach `wind_time`, einem globalen Shader-Parameter, den ein `Wind`-Knoten mit
  dem skalierten delta treibt — in der Zeitlupe wehen sie langsamer. In der Luft treibt je
  Thema eine Art `AmbientParticles` (Laub, Schnee, Pollen, Glühwürmchen) über dem
  sichtbaren Boden — nur, wo dort wirklich etwas in der Luft wäre (kein Staub über der
  Wüste, keine Glühwürmchen im Tageslicht des Dschungels). Laub fällt als Blattform aus den
  Kronen der Laubbäume (`LEAF_TREES`, `crown_of`) und kippt im Fallen; Kirschblüten fallen
  genauso aus jedem Blütenbaum (`BLOSSOM_TREES`, `AmbientParticles.blossoms`), unabhängig
  von der Art des Themas. In trockenen Themen (`tumbleweeds`) rollt statt Staub selten
  ein Steppenläufer (`Tumbleweeds`) mit dem Wind durchs Bild und schrumpft vor der Burg
  weg. Beides gehört zu den Teilchen und fällt in „Schnell" weg. Stärke je Thema:
  `wind`, `clouds`, `particles`.
- **Schatten und Licht des Bodens.** Der Bodenshader beleuchtet selbst (`light()`): Grund
  ist das Umgebungslicht des Themas, die Sonne legt nur einen festen Anteil davon dazu
  (`shadow_depth`, nach Neigung zur Sonne). So steht flacher Boden in der Sonne in der Farbe
  des Themas, egal wie hell dessen Sonne ist; im Schatten und an abgewandten Hängen fehlt
  der Anteil. `gl_compatibility` multipliziert den Schatten nach `light()` auf das Ergebnis
  (`ATTENUATION` enthält ihn nicht) — die Sonne muss dort also addieren, nicht abziehen.
  Die Sonne wirft EINE Schattenkarte (`SHADOW_ORTHOGONAL`); bei der Orthogonal-Kamera
  spannt sie sich bis `camera.far`, deshalb setzt `setup_view` `far` auf `SHADOW_DISTANCE`
  — der Wert bestimmt zugleich, wie weich die Schatten sind. Der Boden selbst wirft keinen
  Schatten (`dress_ground`), sonst braucht es einen großen Bias, der Baumschatten schluckt.
- **Weg, Flecken, Hügelfuß.** Jeder Kampf hat einen Weg vom hinteren Bildrand ins
  Festungstor (`BattlePath`): Bildgestaltung, kein Spielfeld — die Monster laufen über die
  ganze Bahn. Der Verlauf (zwei Bögen und eine Schräge) wird je Kampf gewürfelt, die Art
  (`path`: Trampelpfad, Weg, Bohlenweg, Pflaster) und `path_color` nennt das Thema.
  Gezeichnet wird er im Bodenshader, der dieselbe Mittellinie rechnet (`path_centre` =
  `BattlePath.centre_x`, die Zahlen kommen aus `apply_to`); die Streudeko fragt
  `BattlePath.blocks`. Trampelpfad und Weg tragen eine eigene Detailtextur aus
  `assets/textures/ground/` (`BattlePath.TEXTURES`: `dry_earth`, `gravel`; ein Thema kann
  mit `path_texture` eine andere nennen), Bohlen und Pflaster rechnet der Shader. Der Rand
  ist scharf mit feinem Ausfransen — weich sah der Weg verwaschen aus. Ebenfalls im Shader: Flecken in einem dritten Ton (`ground_patch`,
  `ground_patch_amount`). Der Hügelfuß weicht in Bögen nach außen zurück
  (`WaveRunner._foot_shift`) und ist hinter dem Spawn rund — nie nach innen, das Feld
  bleibt flach (`tests/battle_ground_test.gd`).
- **Bewuchs und Haine.** Zwischen der Streudeko wachsen kleine Halmbüschel, Blüten darin
  und Sträucher um die Bäume (`GroundCover`), je Art ein MultiMesh. Die Formen entstehen im
  Code; die Büschel nehmen die Bodenfarbe darunter (oder `cover_color`), Blüten und
  Sträucher ihre aus dem Thema (`cover_flowers`, `bush_color`). Die Dichte ist `cover`
  bzw. `bushes` des Themas mal `GraphicsQuality.cover`; die Büschel stehen in Klumpen mit
  freien Flächen dazwischen, am dichtesten am Wegrand, nie auf dem Weg, in der Burg oder im
  Schnee. `GroundCover.plan` rechnet die Lagen ohne zu bauen (kopflos gibt ein MultiMesh
  sie nicht zurück; `tests/ground_cover_test.gd`). Die Bäume im Umland stehen meist in
  Hainen (`GROVE_RADIUS`), ein paar einzeln.
- **Farbgebung.** Die Kampfszene tonemappt (Filmic) und hebt Kontrast und Sättigung leicht
  (`adjustment_*`). Die Sonne wird tief golden (`SunCycle.tint_at`, von `NOON_TINT` nach
  `GOLDEN`) auf die Farbe des Themas; derselbe Ton geht als `sun_tint` an den Bodenshader.
- **Grafikstufen** (`GraphicsQuality`, geräteweit in `UserSettings.graphics_quality`):
  „Schön" zeigt alles, „Mittel" lässt Glow weg und halbiert MSAA, „Schnell" lässt dazu MSAA,
  Wolken, Teilchen, Bodenflecken und die Farbkorrektur weg. Die Büschel des Bewuchses
  halbiert „Mittel", „Schnell" lässt sie weg; die Sträucher bleiben. Schatten, Wind und der Weg
  bleiben überall. Die Kosten misst `battle_theme_lab -- --fps`. Das alte `graphics_simple`
  wird als „Schnell" gelesen, solange keine Stufe gespeichert ist.

## Fähigkeitsbäume: wofür die Punkte da sind

Die Skillpunkte aus den Levelups werden in Bäumen ausgegeben. Der Screen hängt am
Start-Screen (`🌳 Fähigkeiten`), nicht am Kampf: gelernt wird zwischen den Läufen.

| Baustein | Wo | Aufgabe |
|---|---|---|
| Daten | `data/skills/{healing,bulwark,timeweaver}.json` | Baum-Köpfe (`kind: "tree"`) und Knoten (`kind: "skill"`) |
| `SkillTree` | `src/progression/skill_tree.gd` | reine Regeln: Stufen, Äste, Voraussetzungen, Kosten, Summe der Boni |
| `SkillBook` (Autoload) | `src/progression/skill_book.gd` | das Gelernte des Profils, Kauf, Umlernen, Persistenz |
| Wirkung | `GameState.apply_skills`, `SlowMotion.apply_skills` | Boni auf die Grundwerte des Laufs |
| Anzeige | `skill_tree.tscn` + `skill_graph.gd` (gezeichnetes Netz), `Hints` (Auskunft am Zeiger, spielweit), `confirm_dialog.tscn` (Rückfrage), `hud.tscn` (Rüstungszeile) | — |

- **Ein Knoten hat `tier` (Abstand) und `branch` (Stelle im Fächer)** — zwei Felder statt
  einer aus `requires` gerechneten Position, und statt fertiger Koordinaten in den Daten.
  `SkillTree.layout()` macht daraus das Netz: jeder Baum bekommt seinen eigenen
  Anfangspunkt in seinem Sektor, `tier` wird zum Radius, `branch` zum Winkel; der NAME
  des Baums steht außen, jenseits seines äußersten Knotens, wo nichts liegt. Ein dritter
  Ast ist damit ein Eintrag in der JSON, ein vierter Baum eine Datei — die drei
  vorhandenen rücken von selbst zusammen (`tests/skill_graph_layout_test.gd` prüft das bis
  sechs Bäume).
- **Von Hand gesetzt wird je Id, nicht als Ganzes** (`SkillLayout`,
  `assets/ui/skill_tree/layout.json`). Wo die Rechnung nicht schön ist, zieht man einen
  Knoten oder Baumnamen in der Werkbank `skill_tree_lab` („Knoten verschieben",
  „Speichern") und schreibt so die Datei. Jeder Knoten ohne Eintrag bleibt gerechnet, auch
  ein neuer aus einem Pack. Ein Baumname ohne Eintrag rückt hinter den äußersten Knoten
  seines Baums. Die Datei liegt in der EXE wie die Kartenpunkte: Sie ist Bild, nicht
  Inhalt. Die gesetzten Plätze der ausgelieferten Bäume halten dieselbe Regel wie die
  Rechnung (kein Knoten berührt einen anderen, `skill_graph_layout_test`).
- **Gezeichnet statt gebaut** (`SkillGraph`, `_draw()`): drei Bäume mal vier Zuständen
  wären zwölf Theme-Variationen, und die Farbe eines Baums soll aus seiner JSON kommen
  (`color`) und nicht aus dem Theme. Der Screen zoomt mit dem Mausrad und lässt sich
  ziehen; ein Kauf verschiebt den Ausschnitt nicht. Zoom (−, Prozent, +), Einpassen und
  „Alles umlernen" sitzen als Werkzeugleiste in der unteren rechten Ecke der Fläche und
  erklären sich über ihre Karte am Zeiger (`Hints.attach`); 100 % ist der eingepasste
  Zoom (`SkillGraph.zoom_percent`). Pfeiltasten springen von Knoten zu Knoten, Enter
  wirkt wie ein Klick. Eine Karte zur Tastatur gibt es nicht: sie hängt an der Maus.
- **Fenster statt Seite, Bilder aus `assets/ui/skill_tree/`.** Im Hauptmenü öffnet
  `ProfileMenu` den Screen als Overlay (`closed` → wegnehmen, Fokus zurück auf den
  Knopf); allein gestartet geht Schließen zurück ins Menü. Das Fenster ist geschichtet
  nach `assets/ui/windows/README.md`: Rahmen (`GameWindow`), gekachelte Materialebene,
  Titelband (`WindowTitleBar`) mit Kopfzeile und Schließen-X, Inhalt (`WindowContent`),
  darüber die zwei Anschlussplatten. Die Werkzeugknöpfe tragen `ToolButton`. Jeder Knoten ist ein Medaillon (`medallions/available.webp`, in der
  Baumfarbe moduliert — hell wenn lernbar oder gelernt, gedämpft sonst), darauf das Bild
  aus `SkillIcons` (Zuordnung `skill_icons.json`, fehlt eins, steht das Zeichen aus der
  JSON), gesperrt ein Schloss statt des Bilds, gelernt eine in der Baumfarbe getönte Mitte
  und ein Haken. `SkillIcons` hält die Texturen fest: in `_draw` geladen und von niemandem
  gehalten, würde jede im nächsten Bild neu angelegt und weiß gezeichnet. Das Netz ist
  gestreckt (`SkillTree.STRETCH`), damit es das Breitformat füllt; die Schrift im Netz
  schrumpft nicht unter `SkillGraph.MIN_LABEL_SCALE`. Abgleich mit dem Entwurf:
  `scenes/dev/skill_tree_lab.tscn`.
- **Die Auskunft steht am Zeiger, die Entscheidung in einem Dialog.** Der Screen ist nur
  das Netz; eine Tafel am Bildrand gibt es nicht. Erklärt wird über `Hints` — dieselbe
  Karte wie im ganzen Spiel, sofort und am Bildrand auf die andere Seite geklappt. Weil
  der Graph seine Treffer selbst sucht, hängt er dort als *lebende* Auskunft
  (`attach_live`) und antwortet über `SkillTree._hint_at(local)`, statt jede Mausbewegung
  zu melden.
  Über einem Knoten trägt sie Bild, Name, „Baum · Zustand" (`SkillTree.state_name`), rechts
  im Kopf den Preis eines Klicks als Zeichen (`prices`: Stern und Skillpunkte, gelernt
  Münzen und das Gold fürs Verlernen), die Wirkung und die Voraussetzungen als Tabelle.
  Einen Nachsatz gibt es nur, wenn das Gold fürs Verlernen fehlt. Über dem NAMEN eines Baums steht dessen Stand
  (`SkillTree.tree_status`: „2/5 gelernt · +2 HP je besiegtem Monster"). Ein Klick auf
  einen lernbaren Knoten öffnet `ConfirmDialog`, und erst dessen Bestätigung bucht — ein
  ausgegebener Punkt kommt nur gegen Gold zurück, das soll ein einzelner Klick nicht
  entscheiden. Knoten, an denen es nichts zu entscheiden gibt, öffnen keinen Dialog.
- **`effects` ist ein Dictionary und alle Werte sind ADDITIV** auf den Grundwert. Damit
  gibt es keine Frage „welcher Knoten gewinnt", nur eine Summe — und ein Knoten darf
  später mehreres anheben, ohne dass die Aggregation zur Fallunterscheidung wird. Die
  bekannten Schlüssel stehen in `SkillTree.EFFECT_KEYS`; ein unbekannter wirkt nicht
  (`tests/skill_data_test.gd` fängt den Tippfehler ab, bevor er im Spiel auffällt).
- **Gespeichert wird NUR die Liste der gelernten Knoten.** Ausgegebene Punkte, offene
  Punkte und die Boni sind daraus gerechnet (`SkillTree.spent`/`bonuses`) — dieselbe
  Regel, nach der `PlayerLevel` nur `total_xp` sichert. Eine Id, die die Registry nicht
  (mehr) kennt, zählt weder als Ausgabe noch als Bonus.
- **`apply_skills` gehört unmittelbar hinter `GameState.reset()`** (`wave_runner.gd`):
  der Reset stellt die Grundwerte her, erst danach dürfen die Boni darauf, und der Aufruf
  zieht den HP-Stand auf das neue Maximum nach. Beide Empfänger bekommen DASSELBE
  Dictionary — eine Quelle der Boni, nicht zwei, die auseinanderlaufen können.
- **Rüstung ist ein Vorrat des Laufs, die Instandsetzung kommt je Welle.** `fortress_armor`
  liegt vor dem Leben und wird wie die HP mitgenommen; zu jedem Wellenstart kommt
  `fortress_armor_regen` dazu, gedeckelt an `fortress_armor_max` — die eine Ausnahme von
  „der Wellenstart fasst die Festung nicht an". Eine Vollfüllung je Welle machte den Lauf
  endlos. Ein aufgefangener Treffer zählt trotzdem als durchgelassen — eine aufgefangene
  Welle ist keine saubere; `min_fortress_health` hängt am Leben, nicht an der Rüstung.
  Wer an den Beträgen dreht, vergleicht mit der Genesung, die nur an besiegten Monstern
  heilt. Im HUD steht die Rüstung als eigene Zeile über den HP, nur mit gelerntem Baum; die
  Festungstafel behält ohne sie ihre Höhe (`tests/hud_armor_test.gd`).
- **Das Wachkatapult räumt ab, es beantwortet nicht** (`auto_catapult`, Bollwerk, Stufe 4
  an der Wurzel). Es wirft nur, wenn die Festung des Laufs auf
  `FortressModel.CATAPULT_TIER` (4) steht: es hilft beim letzten Stück einer Unit, nicht
  am Anfang. Steigt die Stufe nach einer Welle, wirft es ab der nächsten. Ein Monster,
  dessen Aufgabe beim Spawn gemeistert ist
  (`PlayerProgress.is_mastered`: gesehen und über `MASTERY_CONFIDENCE`, dieselbe Regel wie
  `mastered_count`), wird nach `CATAPULT_DELAY_MIN..MAX` abgeschossen
  (`WaveRunner._catapult_later`). Bis dahin kann der Spieler es selbst treffen, dann fliegt
  kein Stein. Gebucht wird nur „erledigt": `EventBus.monster_catapulted` statt
  `monster_defeated`. `GameState` zählt `wave_resolved`, sonst nichts, und die Spur
  schreibt `catapult`. Es gibt keinen `PlayerProgress.record`, keine Erfahrung, keine Punkte,
  keine Serie, kein Heilen und keinen Eintrag in der Auflösung: sonst hielte das Katapult
  eine Aufgabe ohne Abruf für gemeistert. Geworfen wird aus dem nächsten Katapultturm
  (`FortressModel.catapults`/`fire`). Das Modell des Packs bringt Drehkranz
  und Wurfarm als eigene Knoten mit: der Kranz dreht sich zum Ziel, der Arm schlägt aus.
  Das Monster läuft dabei weiter. Gezielt wird auf den Ort, an dem es beim Einschlag steht
  (`WaveRunner.catapult_lead`, `Monster.velocity`): Monster laufen geradeaus mit festem
  Tempo, also reicht eine Gerade. Wurf und Stein laufen deshalb in Spielzeit wie die Monster
  und anders als Pfeil und Sturmangriff, sonst stimmte der Vorhalt in der Zeitlupe nicht.
  Kommt der Stein zu spät (Monster schon an der Mauer), wird nicht geworfen. Trifft der
  Spieler vorher, schlägt der Stein ins Leere.
  Die Werkbank wirft mit `battle_theme_lab -- --catapult` oder Taste K. `CatapultStone` ist
  Low-Poly, der Einschlag ist der `Blast` des Explosionspfeils (`WaveRunner._blast_at`).
  Stein und Blast sind im Vorwärmen.
- **Die Zeitlupe hat eine Untergrenze** (`SkillTree.MIN_SLOW_FACTOR`), sonst fröre ein
  tiefer Baum das Spiel ein.
- **Verlernen geht einzeln** (`SkillBook.forget`): mit dem Knoten fällt jeder gelernte
  Knoten, der über ihn hängt (`SkillTree.forget_set`) — ein Knoten ohne Vorstufe ist ein
  Zustand, den das Lernen nie herstellt. Die Rückfrage nennt jeden mitfallenden Knoten beim
  Namen. Bezahlt wird je fallendem KNOTEN (`FORGET_GOLD_PER_NODE`), nicht je Punkt wie beim
  Umlernen des Ganzen (`RESPEC_GOLD_PER_POINT`); der Satz liegt darunter, einzeln ist also
  immer günstiger als alles.
- **Kleinere Regeln des Screens**: der Ausschnitt gehört dem Spieler (`setup()` passt nur
  ein, solange niemand gezoomt oder geschoben hat; zurück über ⛶); ein gesperrter Knoten
  nennt seine Vorstufe beim Namen (Zeile „Voraussetzung" mit Schloss), weil an einem Knoten mehrere Linien
  hängen; der Dialog fokussiert ABBRECHEN; `SkillGraph.select()` meldet jeden Klick, auch
  auf den gewählten Knoten, damit ein abgebrochener Antrag neu gestellt werden kann.
  Schriftgrößen liest `_draw()` aus dem Theme (`SkillIcon`, `SectionTitle`, `Hint`,
  `Caption`), Farbe und Zeichen kommen aus den Daten.

### Eingabe und Zeitlupe (ADR 0016)

Beide Sichten haben dieselbe Eingabe (`AnswerInput`), daran hängen Zeitlupe und
Tasten des Kampfs:

- **Zwei Zustände**: zu, bis Enter sie öffnet; Enter schickt ab und schließt, Escape
  schließt nur (das nächste bricht über `WaveRunner._input` ab). Gesperrt und
  umbeschriftet statt ausgeblendet, das Feld behält seine Größe.
- **Offen gehört jede Taste dem Wort**, auch Ziffern und P. Zu sind die Ziffern Zauber
  (`WaveRunner.spell_key`) und das nackte P die Pause (`WaveRunner._on_pause_key`). Beide
  fragen `AnswerInput.is_typing()` — kein Blick auf den Feldinhalt, keine Sonderregel je
  Sicht, und eine Antwort darf mit einer Ziffer beginnen.
- **Die Zeitlupe hält, solange die Eingabe offen ist**: das öffnende Enter sendet
  `EventBus.typing_started`, SlowMotion hält (`hold_open`), bis `typing_stopped` kommt —
  beim Abschicken, bei Escape und wenn die offene Eingabe verschwindet. Keine Haltedauer
  je Zeichen; der Zeitwandler vertieft nur (`slow_factor`). `typing_activity` (jede
  Zeichenänderung) spannt nur noch den Bogen.

### Ich-Sicht (Späher-Baum)

Der Späherblick (`first_person`, 5 Punkte) schaltet für den **Wellenkampf** eine zweite
Kamera frei; die Äste darunter heben nur das Lauftempo (`walk_speed`, Anteile auf
`FirstPersonView.BASE_SPEED`). Der Bosskampf bleibt, wie er ist.

- **Wahl und Freischaltung sind getrennt.** Der Ich-Sicht-Schalter auf der Gebietskarte (unten rechts vor „Spielen")
  setzt nur einen Wunsch in `RunRequest`; `RunRequest.first_person()` gilt erst mit
  gelerntem Knoten und nur für ein Level. Kein zweiter Merker: wer den Knoten verlernt,
  steht wieder auf der Festung. Der Wunsch hält bis zum Programmende, nicht im Profil.
  Im Debug-Build steht der Schalter immer da und gilt auch ohne Knoten
  (`RunRequest.first_person_selectable`) — zum Ausprobieren ohne fünf Skillpunkte. Dazu hat
  dort das SkillBook des Profils unbegrenzt Punkte (`SkillBook.unlimited_points`, nur das
  Autoload setzt es); gespeichert wird auch dann nur die Liste der Knoten. Ebenso kostet
  dort nichts Gold (`Wallet.unlimited_gold`: `spend` und `can_afford` gehen immer, nichts
  wird abgezogen, verdient und gespeichert wird das echte Gold; angezeigt wird 999.999.999). Tests am Autoload
  schalten beides ab.
- **Der Kampf ist derselbe.** `WaveRunner` baut Boden, Deko und Festung wie immer für die
  Iso-Kamera (die bleibt in der Szene, nur nicht aktiv) und setzt `FirstPersonView`
  darauf: Nebel in der Hintergrundfarbe statt Weltrand, kleineres Gras, die größere Ausführung der
  Wortschilder (`Monster.screen_sized_label`). Wellen, Tempo, `t - c` und Auswertung
  fasst die Ich-Sicht nicht an.
- **Wortschilder sind 2D** (`WordPlates` im Kampf-UI, `WordPlate` je Monster): die Ebene
  holt die Monster aus der Gruppe `Monster.PLATE_GROUP`, projiziert den `PlateAnchor` über
  dem Kopf ins Bild und legt die Schilder so, dass keines ein anderes überdeckt
  (`WordPlates.layout`: das Monster am nächsten zur Festung zuerst, dann der nächste freie
  Platz über/neben/unter einem gelegten Schild, der alte Platz ist billiger). Kopfleiste,
  Antwortfeld, Legende und Knopf stehen in der Gruppe `WordPlates.KEEP_CLEAR_GROUP` und
  zählen wie gelegte Schilder — kein fester Streifen, die Kopfleiste belegt nur die Ecken.
  Rand und Schrift tragen die Farbe der Wortart: der Rand ist eine graue Ebene, die
  `word_plate.gdshader` mit der dunklen Basis zusammensetzt (Farbe über `self_modulate`,
  ein Material für alle Schilder). Ein Schild
  steht genau dann, wenn das Monster treffbar ist (Regel darunter). In 3D ging das nicht:
  ein `Label3D` weiß nichts von den anderen.
- **Die eine neue Regel: eine Antwort trifft nur ein Monster im Bild** (`WaveRunner._hittable`,
  `FirstPersonView.sees` — Körper oder Schild im Sichtkegel, verdeckt zählt als sichtbar).
  Eine richtige Antwort auf ein Monster außerhalb ist eine Falscheingabe; die Spur trägt
  dafür bei der Falscheingabe das Feld `unseen`. Pfeile am Bildrand (`OffscreenMarkers`)
  zeigen, wohin man sich drehen muss.
- **Eingabe mit zwei Zuständen** — dieselbe wie von oben (ADR 0016, „Eingabe und
  Zeitlupe" unten). Solange sie zu ist, gehören WASD/Pfeile dem Laufen, solange sie offen
  ist, den Buchstaben — die Bewegung fragt `AnswerInput.is_typing()` ausdrücklich, weil
  `Input.is_physical_key_pressed` den Fokus nicht kennt. `AnswerInput.first_person`
  beschriftet die geschlossene Eingabe mit Laufen und Maus.
- **Ruhiger Ast des Zeitwandlers** (`monster_speed`, `spawn_gap`): `WaveRunner` nimmt die
  Faktoren aus `SkillTree.monster_pace`/`spawn_gap_scale` und legt sie auf `plan["speed"]`
  beim Spawn und auf den Spawn-Abstand der Welle — **hinter** `WaveGenerator._build_plan`,
  nicht in `speed_scale`. Sonst sänken Punkte und Gold mit, und ein gelernter Skill
  kostete Beute. Schwierigkeit bleibt `t - c`; der Skill ist Können des Spielers wie die
  Rüstung.
- **Sturmangriff** (`charge`): bei einem Treffer rast der Spieler auf das Monster zu
  (`FirstPersonView.charge_at`), erst beim Aufprall platzt es (`WaveRunner._burst`).
  Gebucht wird trotzdem sofort (`_book_defeat`: Lernstand, XP, Punkte, Spur) — das Bild
  wartet, die Zahlen nicht. Das Monster steht (`Monster.halt`) und ist aus `_active`
  heraus, kann also weder die Festung erreichen noch eine zweite Antwort fangen;
  `_check_end` wartet laufende Anläufe und Pfeile ab (`_underway`). Ein zweiter Treffer während eines
  Anlaufs lässt den ersten sofort ankommen. Aufsteigende Texte („+XP") haben in
  der Ich-Sicht eine feste Bildgröße, sonst füllten sie aus der Nähe das Bild.
- **Langbogen** (`bow`): dieselbe Buchung wie beim Sturmangriff, nur fliegt statt des
  Spielers ein Pfeil (`FirstPersonView.shoot_at`, `Arrow`), und das Monster platzt, wenn er
  ankommt. Ein Treffer fliegt schnell und fast gerade (`HIT_SPEED`, `HIT_LIFT`) in den Kopf
  (`Monster.head_height`, aus der Hülle des Modells), der Bogen
  schwenkt davor kurz aufs Ziel (`Bow.swing_to`), und das Blickfeld zuckt beim Abschuss;
  der Fehlschuss behält seinen flacheren Bogen. Gewartet wird auf den Schwenk mit einem
  Timer, nicht auf dessen Tween — den bricht ein Senken ab, und ein nie endendes `await`
  hielte das Wellenende fest. Der Bogen (`Bow`) hängt an der Kamera: gehoben, solange die Eingabe offen ist,
  und jedes `typing_activity` spannt ihn weiter — nur nach getippten Buchstaben, nie nach
  der erwarteten Antwort, sonst verriete er die Wortlänge. Eine falsche Antwort gehört
  weiter zu keinem Monster (Spur unverändert); der Pfeil fliegt nur fürs Bild an dem
  sichtbaren Monster vorbei, das der Bildmitte am nächsten steht
  (`FirstPersonView.nearest_to_view`, `miss_end`), ohne Monster geradeaus. Rot, Wackeln und
  Klang kommen, wenn er steckt. Es gibt kein Fadenkreuz: gezielt wird nicht, die Regel
  bleibt „im Bild". Sind Bogen und Sturmangriff gelernt, wechselt Tab
  (`FirstPersonView.weapons`, `switch_weapon`); die Wahl gilt bis zum Beenden, gespeichert
  wird sie nicht. Pfeil und Spur sind im Vorwärmen (`FxWarmup`).
- **Explosionspfeil** (`explosive_arrow`, `FirstPersonView.explodes_for`/`explosive`) ist
  keine Waffe, sondern ein anderes Bild für den Bogentreffer: `WaveRunner._blast` statt
  `_burst`. `Blast` (`src/fx/blast.gd`) schichtet Blitz, Feuerball, Druckwelle, Funken, Glut
  in der Wortfarbe und Rauch aus eigenen Shadern (`fireball`, `shockwave`, `spark`,
  `smoke`), alles gerechnet und ohne Textur, und weich statt Low-Poly. Nachbarn im Umkreis
  `BLAST_FLINCH_RADIUS` zucken (`Monster.flinch`, nur der Körper). Gebucht, getroffen und
  gespurt wird genau wie ohne. Glühender Pfeil und `Blast` sind im Vorwärmen, sobald der
  Skill gelernt ist.
- **Gelaufen wird nach der Wanduhr**, nicht mit `delta`: weder Zeitlupe noch der Zeitraffer
  von „Schnell auflösen" sollen den Spieler mitnehmen, und `Engine.time_scale` gehört
  SlowMotion. Die Maus ist nur im laufenden Kampf gefangen (`FirstPersonView.set_active`)
  und nicht bei offener Eingabe — die Zeit steht dann, und „Schnell auflösen" ist einen
  Klick entfernt (`mouse_captured`). Alt gibt sie auch beim Laufen frei.

## Erweiterungspunkte für den KI-Agenten

| Erweiterung | Wie | Bestehender Code betroffen? |
|---|---|---|
| Neues Wort | JSON in `data/language/lexemes/` (Aufgaben entstehen automatisch aus Definitions) | nein |
| Neuer Aufgaben-*Typ* | JSON in `data/task_definitions/` (+ ggf. Resolver-Zweig) | ggf. Resolver |
| Neues Monster | JSON in `data/monsters/` | nein |
| Neuer Boss | JSON in `data/bosses/` | nein |
| Neue Welle | JSON in `data/waves/` | nein |
| Neuer Zauber (Daten) | JSON in `data/spells/` | nein |
| Neuer Zauber-*Effekt* (Verhalten) | `SpellCaster.EFFECTS` + je ein Zweig in `can_cast`/`cast` (siehe unten) | nur additiv |
| Neuer Skill-Knoten oder ganzer Ast | JSON in `data/skills/` (`tier`/`branch`/`requires`/`effects`) | nein |
| Neuer Baum | JSON in `data/skills/` (ein `kind: "tree"`-Kopf plus Knoten) | nein |
| Neuer Skill-*Effekt-Schlüssel* | `SkillTree.EFFECT_KEYS` + ein `apply_skills`, das ihn liest | nur additiv |
| Neue Mechanik | Neues System, das EventBus-Signale abonniert | nein |

### Zauber (ADR 0014)
Ein Zauber ist ein Verbrauchsgegenstand: `price` in Gold, `effect` aus
`SpellCaster.EFFECTS`, `params` je Wirkung (Tabelle im ADR). Keine Abklingzeit.

- **Vorrat** (`Inventory`, Autoload, `user://progress/<profil>_inventory.json`): nur die
  Plätze in ihrer Reihenfolge. Die Zahl der Plätze wird gerechnet (`BASE_SLOTS` plus
  `item_slots` aus `SkillBook.bonuses()`), ein leerer Platz rückt nicht nach, damit die
  Taste bleibt. Bezahlt wird über `Inventory.wallet` (das Autoload `Wallet`, im Test eine
  eigene Instanz).
- **Laden** (`SpellShop`, `scenes/ui/spell_shop.tscn`, je Zauber eine quadratische Kachel
  aus `spell_tile.tscn`; Beschreibung und Preis stehen im Hinweis, ein Klick kauft): über
  „Zauber" im Hauptmenü und in der Knopfreihe der kompakten Plakette, nicht im Kampf.
- **Einsatz** (`WaveRunner._use_spell`): Ziffer 1 bis n, aber nur bei geschlossener
  Eingabe (`WaveRunner.spell_key`, `AnswerInput.is_typing`); offen ist die Ziffer ein
  Zeichen (ADR 0016). Im Bosskampf gibt es keine Zauber.
- **Wirkung** (`SpellCaster`, ohne Bild): `can_cast` vor `cast`. Was nichts bewirken
  würde, wird nicht verbraucht, der Platz zittert (`SpellSlots.refuse`). Dazwischen nimmt
  der WaveRunner den Zauber aus dem Vorrat und sendet `spell_activated`, damit er in der
  Spur vor seinen Folgen steht. `scope: wave` merkt sich der SpellCaster
  (`wave_pace`, `wave_alts`) und gibt es über `on_spawn` jedem neuen Monster der Welle mit.
- **Am Monster**: Verlangsamen über `Monster.pace` (der kleinere Faktor gewinnt), nie über
  `Engine.time_scale`. Einfrieren zählt `_frozen_left` in Spielzeit herunter, Umriss
  eisblau, Animation steht. `Monster.velocity()` kennt beides, der Vorhalt des Katapults
  also auch. Die Alternativen (`prompt_alt` der Aufgabe) zeigt das Wortschild als zweite
  Zeile (`WordPlate.alt_line`, Signal `alts_revealed`).
- **Donnerschlag** nimmt jedes Monster auf dem Feld über `WaveRunner._strike` sofort vom
  Feld (aus `_active`, angehalten) und sendet `monster_struck`; das Bild geht erst, wenn
  sein Blitz einschlägt (`SpellFx.bolt`), bis dahin hält `_underway` das Wellenende auf.
  Danach wartet es noch, bis das Bild durch ist (`SpellFx.is_busy`/`settled`, Dauern in
  `SpellFx.SETTLE` und `STRIKE_SETTLE`) — das gilt für jeden Zauber, damit die Abrechnung
  ihn nicht verdeckt. Ebenso jede Explosion eines Treffers (`WaveRunner._settle`,
  `EXPLOSION_SETTLE`, `BLAST_SETTLE`).
  Gezählt wird wie beim Katapult: `GameState` zählt
  `wave_resolved`, die Spur schreibt `struck`, sonst nichts — kein Lernstand, keine
  Erfahrung, kein Gold, kein Eintrag in der Auflösung.
- **Bild** (`SpellFx`, `src/fx/spell_fx.gd`, im Kampf und in der Werkbank dasselbe):
  Schleier über dem ganzen Bild (`SpellVeil`), Banner mit Bild und Name
  (`SpellBanner`), dazu je Wirkung ein Effekt im Feld — Lichtvorhang, nach dem die
  Schilder der Reihe nach aufspringen (`SpellCaster.reveal_delay`), Schlamm-Spritzer,
  Dunst für die ganze Welle, Eisring und Schnee, verdunkeltes Bild mit gestaffelten
  Blitzen (`LightningBolt`, Plasma-`Blast`, Brandfleck), Lichtsäule an der Festung. Am
  Monster hängen `FrostShell` (wächst, reißt in den letzten Sekunden, zerspringt) und
  `SlowAura`. Die Farbe je Wirkung steht in `SpellFx.COLORS`, nicht in den Daten (ein
  neues Feld höbe `min_app_version`). Alles davon zeigt `FxWarmup` vorab
  (`SpellFx.specimens`). Bilder der Zauber: `SpellIcons`
  (`assets/ui/spells/spell_icons.json`), ohne Bild das Emoji. Töne: `SpellFx.SOUNDS` (Ids in
  `Sfx.SOUNDS`, Dateien unter `assets/audio/sfx/spell_*`, Bestellung und Auswahl in
  `assets/audio/sfx/SPELLS_BRIEF.md`). Der Anlauf des Donnerschlags (`STRIKE_WINDUP`) ist so
  lang wie sein Ton, der deshalb ohne Tonhöhen-Streuung spielt (`"spread": 0.0`).
- Kein Zauber verschiebt `spawned_at_ms` oder geht in die Planung einer Welle ein (`t - c`).
- Spur: `{"e":"spell","spell","wave"}` und `{"e":"struck","id","lex","prompt"}`.
- Werkbänke: `battle_theme_lab -- --shoot --hud` (Vorrat), `--plates` (Alternativen),
  `--spells [--spell=<name>]` (jeder Zauber in Schritten; im Fenster Reiter „Zauber"),
  `menu_lab -- --shoot --spells [--stock=…]` (Laden).

## Datenpersistenz

Entscheidung und Begründung: `docs/adr/0024-spielstand-sicher-speichern.md`.

| | Spielstand |
|---|---|
| Schreiben | nur `SaveStore` (`src/core/save_store.gd`): `.tmp`, zurücklesen, umbenennen; Prüfsumme in der Hülle `{"_save":{…},…}` |
| Wann | `SaveCoordinator` (Autoload): Commit an der Wellengrenze, nach Kiste und Boss, in Menüs am Frame-Ende; im Kampf `hold()` |
| Sperre | `SaveGuard.MONOTONIC`: was nur wachsen darf, sinkt nie ohne `allow_drop` |
| Sicherung | `Backups`: Generation des ganzen Profils unter `user://backups/<id>/<stempel>/`, Manifest zuletzt; 3 + 7 Tage + 8 Wochen |
| Schaden | beim Öffnen: Quarantäne `user://quarantine/<id>/…` + neueste Generation zurück, sonst gesperrt |
| Datei | `SaveArchive`: „Sichern…“/„Laden…“ in den Einstellungen, Zip mit Prüfsummen |

- **Ein Speicher meldet nur „geändert“** (`SaveCoordinator.mark_dirty(self)`) und liefert
  `save_path`, `save_suffix`, `save_payload`, `reload`. Wann geschrieben wird, entscheidet
  der Coordinator; ein Abbruch lädt mit `discard_uncommitted` den letzten Stand zurück.
- **Unlesbar ist nie „neu“.** Ein Loader, der eine beschädigte Datei findet, setzt nicht
  auf 0, und über die Datei wird nicht geschrieben.
- **Statische Speicher** (`BossRecord`, `TestLists`, `RunSave`) schreiben über
  `SaveGuard.write` sofort, aber genauso sicher.
- **Testläufe speichern nie ins aktive Profil**: unter gdUnit4 ist der Coordinator still
  (`_under_test`), Tests bauen eigene Instanzen mit eigenen Ordnern.

- **Content** (Aufgaben, Monster, Wellen, …): JSON unter `data/` — versioniert, agent-editierbar.
- **Sprachdaten** (Lexeme, Formen, Relationen, Sätze): JSON unter `data/language/`
  — eigenes privates Repo (Submodule), Änderungen werden dort committet.
- **Nutzer-Meldungen** („dieses Wort ist falsch", `LexemeFlags`,
  `src/core/lexeme_flags.gd`): JSON unter `user://lexeme_flags.json`, lexeme_id → Meldung.
  Bewusst **nicht** in der Quell-JSON: `res://` ist im Export read-only, und eine
  veränderte Pack-Datei würde beim nächsten Pack-Update übersprungen. `ContentRegistry`
  legt die Meldungen nach jedem Laden über die Lexeme (`_apply_flags()`), sodass
  `flagged_lexemes()` unverändert funktioniert. Jede Meldung trägt ein Feld `sent`: das
  ist die Warteschlange des Melde-Kanals (siehe unten) — was noch nicht abgehakt ist,
  geht beim nächsten Start mit.
- **Gold** (`Wallet`, `src/economy/wallet.gd`): JSON unter
  `user://progress/<player>_wallet.json` — Stand, Lebensleistung und Zahl geöffneter
  Kisten. Gespeichert wird nach der geöffneten Kiste.
- **Erfahrung und Level** (`PlayerLevel`, `src/progression/player_level.gd`): JSON unter
  `user://progress/<player>_level.json`. Gelesen wird daraus nur `total_xp` — Level und
  Skillpunkte stehen zum Mitlesen in der Datei, kommen aber aus der Rechnung. Gespeichert
  wird am Wellenende, nie mitten in der Welle (ADR 0024).
- **Boss-Siege** (`BossRecord`, `src/progression/boss_record.gd`): JSON unter
  `user://progress/<player>_bosses.json`, je Sieg ein Eintrag `{unit, won_at}`. Zahl und
  Medaille werden beim Lesen gezählt (ADR 0006).
- **Begonnene Läufe** (`RunSave`, `src/progression/run_save.gd`): JSON unter
  `user://progress/<player>_runs.json`, `{runs: {<book>: <stand>}}`, über eine temporäre
  Datei geschrieben (ADR 0020).
- **Ereignis-Protokoll** (`TraceLog`, `src/learning/trace_log.gd`): JSON Lines unter
  `user://logs/<player>_trace.jsonl`, eine Zeile je Ereignis. Siehe „Die Spur eines Laufs"
  unten.
- **Spielerfortschritt** (`player_task_progress`): der Autoload `PlayerProgress`
  (`src/learning/player_progress.gd`) hält je Aufgabe Confidence/Streak/letzte Antwort;
  die Fälligkeit rechnet `SpacedRepetition` daraus. Persistenz: JSON unter `user://progress/<player>.json`
  (schreibintensiv, wächst → bewusst nicht in `data/`). SQLite ist die vorgesehene
  Ausbaustufe für größere Historien.

## Die Spur eines Laufs: wofür das Protokoll da ist

Vier Ebenen halten fest, was der Spieler tut, und jede beantwortet eine andere Frage:

| Ebene | Wo | Frage |
|---|---|---|
| `GameState` | nur im Speicher | wie steht es GERADE? |
| `PlayerProgress` | `user://progress/<player>.json` | wie gut kann er diese Aufgabe? |
| `SessionLog` | `user://progress/<player>_sessions.json` | wie lief dieser Lauf im Ganzen? |
| `TraceLog` | `user://logs/<player>_trace.jsonl` | **was ist konkret passiert?** |

Die ersten drei sind Summen und Stände — sie beantworten keine Frage, die vorher niemand
gestellt hat. Genau die stellt man aber bei der Fehlersuche („warum wurde *coral* nicht
genommen?", „wie oft kam dieses Wort?"). `TraceLog` schreibt deshalb Rohdaten: je
erschienenem Lexem, je Eingabe, je durchgelassenem Monster und je Wellen-/Lauf-Grenze eine
Zeile JSON.

- **Es hängt ausschließlich am EventBus und wirkt nie zurück.** `monster_spawned` trägt
  seit dieser Änderung die aufgelöste Aufgabe mit, `monster_reached_fortress` zusätzlich
  Aufgabe und Schaden, und `answer_judged` ist neu: es meldet JEDE abgeschickte Antwort
  samt Urteil — auch die, die auf kein Monster passte. Genau die wurde vorher restlos
  verworfen (der `WaveRunner` verbucht sie bewusst nicht, weil sie bei mehreren Monstern
  auf dem Feld keiner Aufgabe zuzuordnen ist); die Zeile nennt sie deshalb mit leerer
  `learnable_id` und dazu die Aufgaben, die im Moment der Abweisung dastanden.
- **Vorher/Nachher steht in zwei Zeilen**, nicht in einem mitgeführten Feld: die
  `spawn`-Zeile trägt die Confidence vor der Antwort, die `answer`-Zeile die danach
  (`PlayerProgress.record()` läuft vor dem Signal). Eine zweite Buchführung daneben liefe
  auseinander.
- **Zwei Generationen à 2 MB je Profil**, mehr nicht: ein Protokoll, das den Rechner
  vollschreibt, schaltet man ab, und dann hilft es niemandem. Geschrieben wird sofort und
  mit `flush()` — der Absturz, den die Spur erklären soll, kündigt sich nicht an.
- **Abschaltbar, Vorgabe an** (`UserSettings.trace_enabled`, geräteweit wie die Lautstärke).
  Der Zugang ist der Reiter „Protokoll" im Einstellungs-Fenster: Pfad, Ordner öffnen, leeren.
  Eine Aufzeichnung, die man erst einschalten muss, ist beim Fehler von gestern leer.
- **Die Rohspur bleibt auf dem Rechner.** Sie enthält getippte Kindertexte und Lemmata aus
  geschütztem Material — anders als der Melde-Rückkanal, der nur Ids kennt. Das ist der
  Unterschied und keine Nachlässigkeit. Sie geht deshalb in kein Repo. Der
  Statistik-Kanal sendet nur ihre bereinigte Fassung (siehe „Der Statistik-Kanal“).
- **Felder kommen dazu, sie werden nicht umbenannt** — eine Zeile von gestern muss lesbar
  bleiben (dieselbe Regel wie bei den Packs). `JSON.stringify` läuft mit
  `sort_keys = false`, damit Zeit und Art vorn stehen: eine Spur wird gelesen.
- **Wer eine Zeile braucht, die es nicht gibt, gibt dem EventBus ein Signal** — das Spiel
  ruft das Protokoll nie direkt. Ein Fehler darin darf kein Spiel kosten
  (`push_warning` und Stille, kein `push_error`).
- **Jede `spawn`-Zeile sagt, warum das Wort kam** (`why`, aus
  `WaveGenerator.pick_reason`): Gruppe (fällig/neu/Rest), ob das Wort in der Welle schon
  dran war, Stelle in der Reihenfolge, Größe des Pools mit Summen je Gruppe, `t − c`,
  Fälligkeit und letzte Antwort des Grundworts (`last_seen`). Die Gruppe kommt aus derselben Sortierung, die auch wählt
  (`WaveGenerator.ordered`), nicht aus einer zweiten Regel. Dieselbe Zeile zeigt im
  Debug-Build das Debug-Panel („Letzte Spawns") und die Konsole; ohne Spiel zeigt
  `scenes/dev/pool_lab.tscn` den ganzen Pool in Wahlreihenfolge, mit verstellbarer Uhr
  und einer simulierten Welle.
- **Die Ansicht im Reiter ist ein Leser, keine Auswertung.** `TraceLog.recent()` liest nur
  das Ende beider Generationen, `TraceView.rows()` übersetzt Zeile für Zeile; verknüpft wird
  nur die learnable_id einer `answer`-Zeile mit dem Prompt der `spawn`-Zeile. Eine
  unbekannte Ereignisart erscheint mit ihrem Namen, statt still zu verschwinden.
- **`clear()` fasst nur die eigenen beiden Dateien an** — `user://logs/` teilt sich das
  Verzeichnis mit Godots `godot.log`.

## Ausliefern: zwei getrennte Update-Kanäle

Entscheidung und Begründung: `docs/adr/0001-app-und-content-update.md`;
Pack-Dateiformat: `docs/PACK_FORMAT.md`.

| | App-Kanal | Content-Kanal |
|---|---|---|
| Was | die ganze EXE (~120 MB) | Content-Packs (KB) |
| Wie oft | selten | oft |
| Quelle | `latest.json` am GitHub-Release des Hauptrepos | `index.json` im Transport-Repo |
| Autoload | `UpdateService` (`src/update/`) | `ContentService` (`src/content/`) |
| UI | `scenes/ui/update_dialog.tscn` | `scenes/ui/content_manager.tscn` |
| Prüfung | SHA-256 **und** RSA-Signatur (`ReleaseKey`) | SHA-256; geschützte Packs zusätzlich AES-CBC + HMAC |
| Einbau | EXE umbenennen, ersetzen, neu starten (Rollback bei Fehler) | nach `user://content/<pack-id>/` auspacken |

Zwei Kanäle, weil die beiden Dinge unterschiedlich groß und unterschiedlich häufig sind:
neue Vokabeln dürfen nicht 120 MB kosten, und ein Fehler im Content-Kanal darf die
installierte App nicht beschädigen.

**Versions-Tor in beide Richtungen** (`SemVer`, `PackStatus`): ein Pack nennt
`minVersion` — ist die App älter, wird der Pack als `APP_OUTDATED` blockiert (kein
Zugangscode hebt das auf), und der App-Kanal wird zum Update gedrängt. Umgekehrt nervt ein
veralteter Pack (`UPDATE`, vorausgewählt), blockiert aber nichts. In Debug-Builds gibt es
kein Tor, damit die Entwicklung nicht an ihren eigenen Versionsnummern hängt.

**`min_app_version` steht am Pack, der das neue Feld trägt**, nicht global über der
`packs.yaml`. Global gesetzt träfe die harte Schranke auch `game` und die Access-Bände, die
von dem Feld nichts wissen, und eine Korrektur dort erreichte den Spieler nicht mehr. Die
Sätze tragen seit ADR 0004 `accepted`/`must_contain`/`pitfalls` und liegen seit Lauf #4
je Unit in den Access-Paketen, also steht dort die 0.10.0 — die Version, mit der die
Bewertung erscheint. Die Reihenfolge
ist deshalb: erst die App-Version veröffentlichen, dann im Content-Repo nach `main`
(gebaut wird beim Merge, nicht beim Push).

**Es gibt keine alten Pack-Fassungen, und das ist entschieden.** Je Id genau eine Datei am
Release-Tag `packs`, bei jedem Build überschrieben. Felder kommen deshalb dazu, sie werden
nicht umbenannt, entfernt oder umgedeutet. Wäre es doch einmal nötig, ist die Pack-**Id**
der einzige versionierte Griff (alte einfrieren, neue daneben).

**Geschützte Packs.** Ein Pack aus Lehrbuchmaterial wird verschlüsselt ausgeliefert und
braucht einen Zugangscode (`AccessCodes`, `PackCrypto`). Der Code steht in
`user://codes.cfg` und ist ausdrücklich **kein** Geheimnisspeicher — er hält den Inhalt
aus dem öffentlichen Netz heraus, nicht vor dem Besitzer des Rechners.

**Bauen und Veröffentlichen.** Die Packs baut `tools/packs/build_packs.py` nach der
Zuordnung in `packs.yaml` (im privaten Content-Repo, weil sie entscheidet, was geschützt
bleibt) — fail-closed: eine Datei ohne eindeutige Zuordnung bricht den Build ab. Drei
unabhängige Sicherungen halten geschütztes Material aus offenen Packs heraus: die
Pfadregeln, ein Blick in die Lexeme (`protected_books`) und
`tools/packs/check_open_packs.py` am fertigen ZIP. Es gibt genau ein `index.json`, also
auch nur einen Veröffentlicher: der Workflow im Content-Repo, den eine Änderung an
`data/**` im Hauptrepo per `repository_dispatch` mit anstößt.

## Der Melde-Kanal: der Weg zurück

Entscheidung und Begründung: `docs/adr/0002-melde-rueckkanal.md`, Berechtigung seit
`docs/adr/0022-melden-ohne-token.md`.

Die beiden Kanäle oben liefern **zum** Spieler. Der dritte geht nach oben: eine Meldung
(„dieses Wort ist falsch") wird zu einer Korrektur im privaten Content-Repo und kommt über
den Content-Kanal als Pack-Update zurück.

| | Melde-Kanal |
|---|---|
| Was | eine Meldung: Ziel-Id, Kommentar, App- und Pack-Fassung, Profilnummer (`stats_id`) (wenige Bytes) |
| Autoload | `ReportService` (`src/report/`) |
| Ziel | eigener PHP-Endpunkt, `server/melden/melden.php`; Ablage als JSON Lines **über** dem Docroot |
| Berechtigung | App-Schlüssel `app-<n>.<mac>` der Fassung, derselbe wie beim Statistik-Kanal — geprägt von `tools/report/mint_token.py`, geprüft vom Endpunkt |
| Konfiguration | `stats_key.cfg` (beim Export geschrieben): Schlüssel in `[stats]`, URL in `[report]` |
| UI | Reiter „Melden" in `scenes/ui/settings_menu.tscn`; „⚑ Melden" im Reveal |

**Ohne Endpunkt und Schlüssel gibt es „Melden" nicht** — der Knopf im Reveal und die
Meldungsliste erscheinen nicht. Das ist eine Bedienungsentscheidung, keine Schranke: eine
Meldung, die nirgends ankommt, ist ärgerlicher als ein fehlender Knopf. Die Schranke sitzt
im Endpunkt, der den Schlüssel prüft, Größe und Rate deckelt und ein zurückgezogenes Label
sperrt.

Gemeldet wird **immer erst lokal**, gesendet danach: ein Netzfehler lässt die Meldung offen
stehen (`sent` bleibt false), sie geht beim nächsten Start mit, und eine doppelt gesendete
erkennt der Endpunkt. Das Bündeln zu GitHub-Issues liegt bewusst hinter dem Endpunkt und
nicht in ihm — eine Störung dort darf keine Meldung verschlucken.

Gearbeitet wird nicht an der Ablage, sondern an Issues im privaten Content-Repo:
`tools/report/to_issues.py` macht aus den JSON Lines **ein Issue je gemeldetem Wort** mit
allen Meldungen dazu als Belege. Es läuft **lokal** — `gh` ist dort angemeldet (kein Token
auf dem Webhost), und das Lemma zu einer Id steht nur im Checkout des Submodules, der
Endpunkt kennt bloß Ids. Zustand hält es keinen: es liest per `gh issue list`, was schon
dort steht, erkennt Vorhandenes an unsichtbaren Markern im Issue-Text und trägt nur
Fehlendes nach, also beliebig oft wiederholbar (`server/melden/README.md`).

Das HMAC-Geheimnis liegt **ausschließlich** auf dem Server (`server/melden/README.md`). URL
und App-Schlüssel kommen beim Export in die EXE und sind kein Geheimnis — genau deshalb
muss der Endpunkt seine Grenzen selbst setzen. Fehlt eins davon, ist der Kanal aus.

## Der Statistik-Kanal: Spieldaten der Testspieler

Entscheidung und Begründung: `docs/adr/0021-statistik-rueckkanal.md`.

| | Statistik-Kanal |
|---|---|
| Was | je Profil ein Snapshot aus der neuesten Sicherung (ADR 0024) und die bereinigte Spur, gzip-gepackt |
| Autoload | `StatsUploader` (`src/stats/`), Bereinigung `TraceSanitizer` |
| Ziel | `server/statistik/statistik.php` neben dem Melde-Endpunkt; Ablage `ms-stats/<stats_id>/` **über** dem Docroot |
| Berechtigung | App-Schlüssel `app-<n>.<mac>` (Format wie Melde-Token), beim Export als `stats_key.cfg` eingesetzt |
| Zuordnung | `UserSettings.stats_id` — zufällig je Profil, nie player_id oder Name |
| Auswertung | lokal: `tools/stats/fetch.sh` (SFTP) → `tools/stats/report.py` → `stats-data/report.html` |

- **Was hinausgeht, steht an genau zwei Stellen**: `StatsUploader.SNAPSHOT_FILES` (je Datei
  einer Sicherung die erlaubten Schlüssel) und `TraceSanitizer.KEEP` (je
  Spurereignis die erlaubten Felder). Beides sind Allowlists; was neu dazukommt, bleibt
  daheim, bis es dort steht.
- **Getipptes wird zu Zahlen.** Eine `answer`-Zeile verliert `text` und `canonical` und
  bekommt `len`, `words` und `dist` — den Levenshtein-Abstand (über `AnswerEvaluator.tokens`)
  zur nächsten Lösung, die die `spawn`-Zeilen davor nennen; bei einem Fehlversuch dazu
  `near`, die Aufgabe dieser Lösung. Deshalb liest die Bereinigung die Spur immer von vorn.
- **Der Cursor gehört dem Server**: die App schickt `from`/`to` als `[at, ms]`, der Server
  antwortet `have`. Ein Stück endet nie mitten in einer Gruppe gleicher Marken.
- **Nie aus den Live-Dateien**: gelesen wird die neueste gültige Generation
  (`Backups.latest`, Prüfsummen geprüft). Ohne sie gibt es keinen Snapshot, die Spur geht
  trotzdem. Speichern wartet nie auf den Versand.
- **Wann**: `run_ended`, `boss_ended` (aktives Profil) und beim Start jedes Profil, das
  seit dem letzten Snapshot neu gesichert wurde. Nur nach dem Hinweis im Startmenü
  (`UserSettings.stats_notice_seen`), nie in Debug-Läufen, nie für `zz-`-Profile.
- **Ohne `stats_key.cfg` ist der Kanal aus** — dort stehen URL und Schlüssel. Für einen
  Versuch gegen einen lokalen Endpunkt in einem Debug-Lauf: `MONSTER_SLAM_STATS_URL` und
  `MONSTER_SLAM_STATS_KEY` (unter WSL über `WSLENV` an Godot durchreichen).

## Auskunft am Zeiger (`Hints`, `src/ui/hints.gd`)

| | |
|---|---|
| Autoload | `Hints` — eine `CanvasLayer` (layer 128) mit genau einer `HintCard` |
| Anmelden | `Hints.attach(control, titel, text, nachsatz)`; leer = abmelden |
| Eigene Trefferprüfung | `Hints.attach_live(control, callable)` → Karte oder `{}` je Punkt |
| Wächter | `tests/hint_discipline_test.gd` (kein `tooltip_text` mehr im Projekt) |

Godots eigener Tooltip ist im ganzen Spiel abgelöst: er erscheint verzögert, bleibt stehen,
wo er aufgegangen ist, und bringt die Typografie der Engine mit. Die Karte hängt am
Mauszeiger, kommt aus dem Theme (Variation `HintCard`: goldener Rahmen und Pfeil aus
`assets/ui/tooltip/` als Theme-Stylebox/-Icon; die Füllung `HintCard/colors/fill` zeichnet
die Karte selbst entlang der Goldkontur, `HintCard.fill_outline`/`pointer_outline` — ein
Rechteck darunter stäche an den abgeschrägten Ecken und neben dem Pfeil dunkelblau heraus) und trägt vier Teile —
Überschrift, Text, Liste, Nachsatz —, von denen leere nicht erscheinen. Dazu kann eine
lebende Auskunft Kopfbild (`icon`), Untertitel (`subtitle`, in `tint` gefärbt) und in der
ersten Listenspalte Texturen statt Zeichen liefern; mit Bild oder Untertitel trennt eine
Linie den Kopf vom Text. Der Pfeil zeigt auf den Zeiger: die Karte steht darunter, am
unteren Rand klappt sie darüber, am rechten rückt sie ein, und der Pfeil wandert auf ihrer
Kante mit (`Hints._place`, `HintCard.point_at`). An einem Knoten ausgerichtet wird sie nie. Die Liste ist eine Tabelle (Zeichen | Bezeichnung | Wert),
kein Text mit „·" dazwischen: eine Aufzählung liest man Zeile für Zeile, und die Werte stehen
rechtsbündig untereinander (die Wortzeilen der Statistik: je Richtung und je Zusatzaufgabe
eine Reihe). Umbrechen darf nur die Bezeichnung.

Gefragt wird jeden Frame `Viewport.gui_get_hovered_control()`, und von dort geht die Suche
nach OBEN, bis ein Knoten eine Auskunft trägt. Das ist der Unterschied zu Godot, das am
ersten Kind mit `MOUSE_FILTER_STOP` abbricht: eine Auskunft an einer Zeile gilt damit auch
für deren Knöpfe und Balken (`ProgressRow` setzte sie vorher zweimal). Gespeichert wird als
Metadatum am Knoten — es gibt keine Liste, die ihre Knoten überleben könnte.

Die eigene Zeichenschicht ist kein Luxus: ein `ScrollContainer` beschneidet seine Kinder,
und die Statistikzeilen liegen in einem. Ein `CanvasLayer` ist kein `CanvasItem`, damit
endet die Beschneidung an seiner Grenze — und auf 128 liegt die Karte zugleich über der
UI-Schicht des Kampfes, in der der Wellenabschluss samt Schatzkiste hängt. Die Karte muss
`MOUSE_FILTER_IGNORE` bleiben: sonst läge sie selbst unter dem Zeiger, versteckte sich und
käme wieder, jeden Frame.

Beim Anmelden gilt: **am kleinsten Ding anhängen, das der Text meint, nie an eine
Screen-Wurzel** — die Suche nach oben erklärte sonst das ganze Bild. Eine `attach_live`-
Fläche, die `{}` liefert, hat geantwortet; dann wird nicht beim Elternknoten weitergefragt.
Die Breite ist eine Regel (so breit wie der Text, zwischen `MIN_WIDTH` und `MAX_WIDTH`),
gemessen in der Reihenfolge, die im Kopf von `HintCard._fit()` steht — dieselbe
Label-Falle wie unter „Oberfläche" unten.

## Das Handbuch im Spiel (`Handbook`, ADR 0019)

| | |
|---|---|
| Quelle | `docs/handbuch/*.md`, per `include_filter` in der EXE; Reihenfolge aus `README.md` „## Inhalt“ |
| Lesen | `Handbook.blocks(markdown)` → Überschrift / Absatz / Listenpunkt / Tabelle; Zeichen über `MarkdownToBbcode.inline` |
| Öffnen | `Handbook.open(datei, überschrift)` — eigene `CanvasLayer` 110 unter der Wurzel, Fenster `scenes/ui/handbook.tscn` |
| Absprung | `HandbookLink` (`scenes/ui/handbook_link.tscn`): `chapter`, `section` (Überschrift wie im Kapitel), `answers_f1` |
| Wächter | `tests/handbook_test.gd` (kein Markdown-Rest, jeder Link und jedes „?“ trifft) |

Das Fenster weiß nichts vom Screen darunter: es hängt in einer eigenen Schicht unter der
Wurzel, schluckt alle Tasten und gibt den Fokus beim Schließen zurück. Die Seite wird je
Kapitel aus vier Vorlagen gebaut (`handbook_heading/_text/_item.tscn`, Kapitelknopf
`handbook_chapter.tscn`); die Typografie steht in den Variationen `Handbook*` im Theme.
Ein Screen mit Reitern setzt `section` seines „?“ beim Umschalten (Statistik,
Einstellungen). Wer eine Überschrift im Handbuch umbenennt, an der ein „?“ hängt, bekommt
das vom Test gesagt.

## Oberfläche: Theme und Layout

`scenes/ui/ui_theme.tres` ist die einzige Quelle für Raum und Typografie. Vorher lagen
beide als `theme_override_…` in den Szenen und hatten sich zu Wildwuchs summiert. Rollen
sind **Type-Variations**, gesetzt über `theme_type_variation`:

| Text | Größe | Container | Abstand |
|---|---|---|---|
| `Display` | 40 | `ScreenMargin` | Screen-Rand 24 |
| `Title` | 28 | `ScreenStack` | 16 |
| `SectionTitle` | 20 | `SectionStack` | 24, zwischen Abschnitten |
| — (Grundgröße) | 18 | `Tight` | 4, Listenzeilen |
| `Hint` | 14, gedämpft | (Klassenvorgabe) | 8 |
| `Caption` | 12, gedämpft | `ScrollGutter` | 8 rechts, in jedem ScrollContainer |
| `Accent` | Gold, Nachdruck | `HudPanel` | schlichte Tafel (Boss), 8/4 statt 16 |
| `HudText`, `HudTitle`, `HudName`, `HudLevel` | 14–18, Kontur | `HudStack` | 0, Zeilen im Encounter-Rahmen |
| `SectionButton` | 20, klappbare Abschnitte | | |

Die Rahmen des Kampf-HUD (`HudFortress`, `HudNamePlate`, `HudEncounter`, `HudLegend`,
`HudAnswer`, `HudRound`) sind `FrameStyle`: ein 9-Slice, der die Grafik aus
`assets/ui/gameplay/frames/` samt Ecken verkleinert zeichnet (`scale`), statt die Ränder in
Texturpixeln wie `StyleBoxTexture`. Die Grafik bleibt in voller Auflösung, damit sie bei
größeren Fenstern nicht hochgerechnet wird. Die Balken wechseln ihre Farbe über die Variation
(`HudHp`/`HudHpWarn`/`HudHpLow`), nicht über einen geänderten Style: der gehört dem Theme
und ist geteilt.

- **Abstände nur in den Stufen 0 / 4 / 8 / 16 / 24.** Der Karten-Innenabstand kommt aus
  `PanelContainer/styles/panel` (16) — **keinen MarginContainer in eine PanelContainer**,
  das addiert sich.
- **In jeden ScrollContainer gehört ein `Gutter`** (MarginContainer mit `ScrollGutter`)
  zwischen Balken und Inhalt. Godot legt den Balken an die Innenkante und gibt dem Kind
  exakt den Rest; ein Rand am ScrollContainer selbst verschiebt Balken und Inhalt gemeinsam.
- **`CheckBox`/`CheckButton` haben eigene Styles** (`StyleBoxEmpty`). Ohne sie fällt die
  Theme-Suche auf `Button/styles/*` zurück, und ein angehaktes Kästchen sah aus wie ein
  gedrückter, rahmenloser Knopf.
- **Der Wächter** `tests/theme_discipline_test.gd` meldet `theme_override_…` in
  `scenes/**.tscn` und `add_theme_*_override` in `src/**.gd`, prüft die Skala und fängt
  Tippfehler in Variationen ab (die Godot still verschluckt). Die Kampf- und
  Effekt-Oberflächen stehen mit Begründung in seiner Liste `ALLOWED` — eigene, lautere
  Typografie, noch nicht umgestellt.
- **Was das Theme nicht kann**: `size_flags_*`, `custom_minimum_size`, `autowrap_mode`,
  Anchors und die Layout-Struktur bleiben Knoten-Eigenschaften in der Szene.

**Ein umbrechendes Label braucht eine Mindestbreite, bevor jemand seine Höhe liest.** Ein
`Label` mit `autowrap_mode` meldet als Mindestbreite 1 Pixel und dazu die Höhe, die der
Text bei EINEM Pixel braucht; das korrigiert sich erst mit einer echten zugeteilten Breite.
Zwei Fälle, in denen die nie kommt: eine unsichtbare Seite im `PageStack` (der sie trotzdem
mitrechnet — ohne `custom_minimum_size.x` wurde der Wellenabschluss höher als das Bild,
und Kiste und Menü-Knopf lagen außerhalb), und jede Karte, deren Größe von Hand gesetzt
wird (`Control.size` wird an der Mindestgröße geklemmt; `RevealCard.set_width()` gibt den
Labels deshalb ihre Breite, BEVOR die Größe gesetzt wird). Gehalten von
`test_the_defeat_screen_fits_into_the_base_resolution` und
`tests/leak_reveal_layout_test.gd`.

**Innerhalb einer sichtbaren, zentrierten Seite wird nichts ein- oder ausgeblendet**,
sondern gesperrt und umbeschriftet — jede Größenänderung verschiebt den Knopf unter dem
Zeiger. Was sich doch ändern muss, wird entschieden, bevor die Seite erscheint
(`WaveStats.show_stats`).

**Die Bezugsgröße wird gerechnet** (ADR 0017, `UiScale`). `canvas_items`/`expand` skaliert
von `Window.content_scale_size` aus, und die ist Fenster ÷ (Systemskalierung × Menügröße),
je Achse mindestens 1152×648. Ein großes Fenster gibt also Platz statt größerer Schrift.
Gesetzt wird sie nur in `UiScale.apply`, beim Start und nach jedem `size_changed`
(`UserSettings`). Kopflos gilt fest 1152×648, damit Tests nicht vom Bildschirm abhängen.

**Werkbänke haben mehr Platz als das Spiel.** `LabRoom` (`src/dev/lab_room.gd`) hebt Fenster
und Untergrenze der Bezugsgröße (`UiScale.floor_size`) auf 1600×900 und gibt sie in
`_exit_tree()` dem Spiel zurück. Werkbänke sind die eine Stelle, an der 1152 nicht gilt;
`tests/lab_room_test.gd` rechnet, dass jede in ihren Platz passt.

## Sprachwahl: GDScript (C# nur bei Bedarf punktuell)

Das Projekt ist bewusst in **GDScript** geschrieben. Ein Wechsel auf C# ist
**nicht** geplant.

- **Shader und 3D sind kein Argument für C#.** Shader werden in der Godot Shading
  Language geschrieben (unabhängig von der Skriptsprache); die 3D-Engine läuft im
  C++-Kern und wird aus GDScript und C# über dieselbe API angesprochen. Beides lässt
  sich ohne Sprachwechsel ergänzen.
- **C# lohnt nur bei CPU-lastiger Eigenlogik** (große Simulationen, prozedurale
  Generierung, schweres Pathfinding) oder aus Tooling-/Ökosystem-Gründen (.NET/NuGet,
  Rider). Für ein Vokabel-Lernspiel trifft das nicht zu.
- **Kosten von C#:** weniger ausgereifter Web-Export, .NET-SDK-Abhängigkeit,
  langsamere Iteration, überwiegend GDScript-lastige Doku/Beispiele.
- **Strategie:** GDScript als Basis. Taucht später ein echter Performance-Hotspot
  auf, wird gezielt *diese* Klasse in C# neu geschrieben (Godot erlaubt Mischbetrieb).
  Für extreme native Performance ist **GDExtension** (C++/Rust) der Weg — nicht C#.

## Konventionen

- IDs: `kategorie.name`, z. B. `monster.slime`, `vocab.en.house`, `spell.freeze`,
  `skill.heal.root`, `tree.healing`.
- GDScript mit statischen Typen und `##`-Doc-Kommentaren.
- UI-Texte und Feedback auf Deutsch (Zielgruppe DE→EN-Lernende).
