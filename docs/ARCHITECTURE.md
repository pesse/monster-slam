# Architektur

Leitziel: **Modularität durch Daten + Entkopplung durch Signale.** Neue Inhalte
und Mechaniken sollen sich ergänzen lassen, ohne bestehende Systeme zu ändern.

## Zwei Autoload-Säulen

### 1. ContentRegistry (`src/core/content_registry.gd`)
Datengetriebener Katalog. Scannt beim Start rekursiv `<root>/<kategorie>/`
und lädt jede `.json`-Datei. Kategorien: `lexemes`, `lexeme_forms`,
`lexeme_relations`, `sentences`, `sentence_lexemes`, `task_definitions`,
`monster_task_rules`, `monsters`, `bosses`, `spells`, `skills`, `waves`.

`spells` und `skills` sind **zwei Dinge**: Spells sind die aktiven Fähigkeiten mit
Abklingzeit, Skills die Knoten der Fähigkeitsbäume. Warum sie so heißen und was das für
`min_app_version` bedeutet, steht in `docs/adr/0003-skills-und-spells.md`.

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
  `.all("waves")`, `.lexemes_by_tags(["basics"])`, `.forms_for(id, form_type)`,
  `.relations_of(id, "opposite")`, `.monster_rule_for(task_type, direction)`.
- Auswahl-Filter fürs Session-Setup: `.lexemes_scoped(scope, tags)` (Schnitt aus
  Curriculum-Scope UND Themen, siehe unten), plus `.all_books()` / `.units_for(book)` /
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
	Einschränkung. So ist z.B. „Körperteile aus Access 2 / Unit 6" ausdrückbar. Lexeme
    ohne `book`/`unit` (Grundwortschatz) sind keinem Curriculum zugeordnet und erscheinen
    nur, wenn kein Scope gewählt ist.
	Der Scope hat DREI Stufen: `"access2"`, `"access2/6"` und `"access2/6/2"` — das
	zweite Viertel der Unit. Die Teile stehen NICHT in den Daten, sondern werden aus der
	**Position** in der Unit gerechnet (`ContentRegistry._index_parts`, gleich große
	Viertel, Rest nach vorn): die Lexeme stehen in Seitenreihenfolge in der Quelldatei,
	damit ist Teil 1 der Anfang der Unit. Ein Teil ist damit ungefähr eine Woche
	Unterricht — die Einheit, in der vor einer Arbeit tatsächlich geübt wird.
- **task_definitions** — *Regeln*, was abgefragt wird (translate/opposite/synonym/
  conjugation/… + `direction`, `allowed_types`, `requires_relation`/`requires_form`,
  `difficulty`). Wenige, statische Einträge (Größenordnung ~10–20) — **unabhängig von
  der Wortanzahl**. Die konkrete Aufgabe entsteht erst zur Laufzeit aus
  *Definition × Lexeme (× Form/Relation)*; es gibt keine per-Wort-Aufgaben mehr.
- **monster_task_rules** — *Wie* eine Aufgabe dargestellt wird: `(task_type, direction)
  → monster_type` + `base_damage/weight`. **Kein** Tempo und **keine** Punkte —
  beide sind Projektionen der Schwierigkeit (siehe unten), keine Darstellungswerte.
- **player_progress** — *Wie gut* der Spieler eine konkrete Aufgabe kann, adressiert über
  einen kanonischen **`learnable_id`** (Task-Typ + Richtung + Lexeme/Form/Relation; Schema
  in `TaskResolver.learnable_id()`). Nicht im Content, sondern beschreibbar in `user://`.
- **sentences / sentence_lexemes** — für Boss-/Satzübungen. Ein Satz trägt neben der
  `reference_translation` seinen Lösungsschlüssel (`accepted`, `must_contain`,
  `pitfalls`); bewertet und ausgewählt wird damit offline (siehe „Sätze bewerten" unten
  und `docs/adr/0004-satzbewertung-ohne-modell.md`). Der Bosskampf startet wie der
  Wellenkampf aus „Runde vorbereiten“ (`scenes/battle/boss_fight.tscn`, ADR 0005).

Die Auflösung Definition × Lexeme → spielbare Aufgabe `{prompt, accepted_answers, …}`
macht `src/learning/task_resolver.gd`; die Enumeration der Kandidaten (Definition × Lexeme)
und die Auswahl fälliger/neuer Aufgaben + Monster-Mapping `src/battle/wave_generator.gd`.

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

- **`spaced_repetition.gd`** — SM-2-artiger Scheduler. Bestimmt, wann ein Item
  wieder fällig ist. Persistierbar via `to_dict()`/`from_dict()`.
- **`answer_evaluator.gd`** — normalisierter Exakt-/Alternativabgleich für schnellen
  Recall (offline, deterministisch). Hier wohnt die Normalisierung (Artikel,
  Platzhalter, Klammergruppen, Typografie); die Satzbewertung nimmt sie über `tokens()`.

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

Der Fortschrittsbalken je Unit und Thema (Statistik, Reiter „Fortschritt") zählt WÖRTER:
`PlayerProgress.mastered_lexemes` nimmt ein Lexem erst auf, wenn `translate:de_to_en:<id>`
UND `translate:en_to_de:<id>` über der Schwelle liegen (`LEXEME_MASTERY_DIRECTIONS`). Der
Reiter „Aufgaben" daneben zählt learnable_ids — zwei Maße, zwei Reiter, mit Absicht.

Die Kopplung macht den Balken **empfindlich gegen alles, was EINE Richtung stört**: fällt
en→de aus, steht die Unit dauerhaft auf „0 von N", während „Gemeisterte Aufgaben" weiter
steigt. Das sieht aus wie ein Rechenfehler der Statistik und war noch nie einer (die
Rechnung hält `tests/mastered_lexemes_test.gd`). Gesucht wird deshalb im Weg der Richtung
in den Pool:

- **Der Schwierigkeitsriegel** (`difficulty_max`) darf keine Lernrichtung wegnehmen —
  `translate` steht in `WaveGenerator.CORE_TASK_TYPES` und ist ausgenommen
  (`definition_allowed()`); der Riegel staffelt nur die Zusatzaufgaben.
- **Geteilte deutsche Prompts** in einer Unit machen de→en zur Ratefrage
  (Regel und Ausnahmen: `docs/ADDING_CONTENT.md`).
- **`excluded_task_types`** muss den Nenner mitnehmen (`PlayerProgress.masterable()`),
  sonst steht der Balken auf „N-1 von N".
- **Dubletten**: dasselbe Wort unter zwei Ids hat zwei Fortschrittsstände, die vier nötigen
  Treffer verteilen sich, und keine Id wird gemeistert. Unter den buchgebundenen Lexemen
  ein Einzelfall, im ungebundenen Grundwortschatz die Regel — wer den Balken einer Unit
  beurteilt, prüft erst, ob der Scope gesetzt ist.

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
- **Die Münzen der Tages-Leiste sind keine Währung.** Sie markieren geübte TAGE
  (`CoinStrip`, `DayCoin`, Vorrat aus `SessionLog.played_day_count()`); Gold zählt in
  Beträgen. Deshalb redet die Leiste von Tagen — zwei Dinge, die „Goldstück" heißen,
  wären eines zu viel.

## Erfahrung und Level (`src/progression/`)

Erfahrung ist die zweite Größe, die über den Lauf hinaus bleibt — neben dem Gold, und mit
der umgekehrten Absicht: Gold ist Beute, Erfahrung ist Lernfortschritt.

| Baustein | Wo | Aufgabe |
|---|---|---|
| `Experience` | `src/progression/experience.gd` | reine Rechnung: XP je Monster, Stufenkosten, Skillpunkte |
| `PlayerLevel` (Autoload) | `src/progression/player_level.gd` | Gesamt-Erfahrung des Profils, Aufstieg, Persistenz |
| Anzeige | `hud.tscn` (Level + Balken beim Namen), `wave_stats.gd` (Zuwachs der Welle), `profile_menu.gd` / `stats_screen.gd` (Stand + offene Skillpunkte) | — |

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
  genau wie beim Gold — und SOFORT: Erfahrung fällt mitten in der Welle an, und ein
  Absturz auf dem Weg zum Wellenende darf sie nicht kosten. Der Abschluss-Screen bekommt
  nur den Zuwachs der Welle und liest den Stand bei `PlayerLevel`.
- **`PlayerLevel.skill_points()` ist der VERDIENTE Stand**, die offenen Punkte rechnet
  `SkillBook.available()` aus den gelernten Knoten — auch dort kein zweiter Zähler.
- **Level und Balken stehen im HUD beim Namen**, nicht in einer fünften Tafel: die
  Kopfleiste passt bei 1152 Pixeln nur knapp (`tests/hud_header_test.gd` misst mit einem
  späten Spielstand). Was dort dazukommt, muss anderswo eingespart werden.

## Fähigkeitsbäume: wofür die Punkte da sind

Die Skillpunkte aus den Levelups werden in Bäumen ausgegeben. Der Screen hängt am
Start-Screen (`🌳 Fähigkeiten`), nicht am Kampf: gelernt wird zwischen den Läufen.

| Baustein | Wo | Aufgabe |
|---|---|---|
| Daten | `data/skills/{healing,bulwark,timeweaver}.json` | Baum-Köpfe (`kind: "tree"`) und Knoten (`kind: "skill"`) |
| `SkillTree` | `src/progression/skill_tree.gd` | reine Regeln: Stufen, Äste, Voraussetzungen, Kosten, Summe der Boni |
| `SkillBook` (Autoload) | `src/progression/skill_book.gd` | das Gelernte des Profils, Kauf, Umlernen, Persistenz |
| Wirkung | `GameState.apply_skills`, `SlowMotion.apply_skills` | Boni auf die Grundwerte des Laufs |
| Anzeige | `skill_tree.tscn` + `skill_graph.gd` (gezeichnetes Netz), `Hints` (Auskunft am Zeiger, spielweit), `confirm_dialog.tscn` (Rückfrage), `hud.tscn` (Rüstungsleiste) | — |

- **Ein Knoten hat `tier` (Abstand) und `branch` (Stelle im Fächer)** — zwei Felder statt
  einer aus `requires` gerechneten Position, und statt fertiger Koordinaten in den Daten.
  `SkillTree.layout()` macht daraus das Netz: jeder Baum bekommt seinen eigenen
  Anfangspunkt in seinem Sektor, `tier` wird zum Radius, `branch` zum Winkel; der NAME
  des Baums steht außen, jenseits seines äußersten Knotens, wo nichts liegt. Ein dritter
  Ast ist damit ein Eintrag in der JSON, ein vierter Baum eine Datei — die drei
  vorhandenen rücken von selbst zusammen (`tests/skill_graph_layout_test.gd` prüft das bis
  sechs Bäume).
- **Gezeichnet statt gebaut** (`SkillGraph`, `_draw()`): drei Bäume mal vier Zuständen
  wären zwölf Theme-Variationen, und die Farbe eines Baums soll aus seiner JSON kommen
  (`color`) und nicht aus dem Theme. Der Screen zoomt mit dem Mausrad und lässt sich
  ziehen; ein Kauf verschiebt den Ausschnitt nicht. Einpassen und Umlernen sitzen als
  Zeichen (⛶, ↺) in der unteren rechten Ecke der Fläche und erklären sich über ihre Karte
  am Zeiger (`Hints.attach`).
- **Die Auskunft steht am Zeiger, die Entscheidung in einem Dialog.** Der Screen ist nur
  das Netz; eine Tafel am Bildrand gibt es nicht. Erklärt wird über `Hints` — dieselbe
  Karte wie im ganzen Spiel, sofort und am Bildrand auf die andere Seite geklappt. Weil
  der Graph seine Treffer selbst sucht, hängt er dort als *lebende* Auskunft
  (`attach_live`) und antwortet über `SkillTree._hint_at(local)`, statt jede Mausbewegung
  zu melden.
  Über einem Knoten trägt sie Zeichen, Name, Wirkung und Zustandszeile
  (`SkillTree.state_label`), über dem NAMEN eines Baums dessen Stand
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
  heilt. Im HUD steht die Rüstung als Leiste über dem Lebensbalken und **ohne Zahl** — eine
  Zahl am HP-Text sprengte die Kopfleiste (`tests/hud_armor_test.gd`), und die Beträge
  sollen in der JSON justierbar bleiben.
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
  nennt seine Vorstufe beim Namen (`state_label`), weil an einem Knoten mehrere Linien
  hängen; der Dialog fokussiert ABBRECHEN; `SkillGraph.select()` meldet jeden Klick, auch
  auf den gewählten Knoten, damit ein abgebrochener Antrag neu gestellt werden kann.
  Schriftgrößen liest `_draw()` aus dem Theme (`SkillIcon`, `SectionTitle`, `Hint`,
  `Caption`), Farbe und Zeichen kommen aus den Daten.

## Erweiterungspunkte für den KI-Agenten

| Erweiterung | Wie | Bestehender Code betroffen? |
|---|---|---|
| Neues Wort | JSON in `data/language/lexemes/` (Aufgaben entstehen automatisch aus Definitions) | nein |
| Neuer Aufgaben-*Typ* | JSON in `data/task_definitions/` (+ ggf. Resolver-Zweig) | ggf. Resolver |
| Neues Monster | JSON in `data/monsters/` | nein |
| Neuer Boss | JSON in `data/bosses/` | nein |
| Neue Welle | JSON in `data/waves/` | nein |
| Neuer Zauber (Daten) | JSON in `data/spells/` | nein |
| Neuer Zauber-*Effekt* (Verhalten) | Effect-Handler ergänzen (siehe unten) | nur additiv |
| Neuer Skill-Knoten oder ganzer Ast | JSON in `data/skills/` (`tier`/`branch`/`requires`/`effects`) | nein |
| Neuer Baum | JSON in `data/skills/` (ein `kind: "tree"`-Kopf plus Knoten) | nein |
| Neuer Skill-*Effekt-Schlüssel* | `SkillTree.EFFECT_KEYS` + ein `apply_skills`, das ihn liest | nur additiv |
| Neue Mechanik | Neues System, das EventBus-Signale abonniert | nein |

### Zauber-Effekte
Ein Zauber trägt in den Daten ein `effect`-Feld (z. B. `slow_monsters`).
Die reine Definition ist datengetrieben; Verhalten, das Code braucht, wird über
ein Effekt-Handler-Muster ergänzt: jeder Effekt registriert sich selbst unter
seinem `effect`-Schlüssel. Ein neuer Effekt = neuer Handler, keine Änderung an
vorhandenen Handlern. (Noch zu implementieren — siehe `docs/ADDING_CONTENT.md`.)

## Datenpersistenz

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
  Kisten. Gesichert wird **sofort** bei jeder Änderung und nicht erst am Laufende:
  verdientes Gold darf ein Absturz nicht kosten.
- **Erfahrung und Level** (`PlayerLevel`, `src/progression/player_level.gd`): JSON unter
  `user://progress/<player>_level.json`. Gelesen wird daraus nur `total_xp` — Level und
  Skillpunkte stehen zum Mitlesen in der Datei, kommen aber aus der Rechnung. Gesichert
  wird **sofort** bei jeder Änderung, also mitten in der Welle.
- **Ereignis-Protokoll** (`TraceLog`, `src/learning/trace_log.gd`): JSON Lines unter
  `user://logs/<player>_trace.jsonl`, eine Zeile je Ereignis. Siehe „Die Spur eines Laufs"
  unten.
- **Spielerfortschritt** (`player_task_progress`): der Autoload `PlayerProgress`
  (`src/learning/player_progress.gd`) hält je Aufgabe Confidence/Streak/Fälligkeit und
  kapselt den SM-2-Scheduler. Persistenz: JSON unter `user://progress/<player>.json`
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
  Der Zugang ist der Reiter „Protokoll" im Einstellungs-Screen: Pfad, Ordner öffnen, leeren.
  Eine Aufzeichnung, die man erst einschalten muss, ist beim Fehler von gestern leer.
- **Die Spur bleibt auf dem Rechner.** Sie enthält getippte Kindertexte und Lemmata aus
  geschütztem Material — anders als der Melde-Rückkanal, der nur Ids kennt. Das ist der
  Unterschied und keine Nachlässigkeit. Sie geht deshalb in kein Repo.
- **Felder kommen dazu, sie werden nicht umbenannt** — eine Zeile von gestern muss lesbar
  bleiben (dieselbe Regel wie bei den Packs). `JSON.stringify` läuft mit
  `sort_keys = false`, damit Zeit und Art vorn stehen: eine Spur wird gelesen.
- **Wer eine Zeile braucht, die es nicht gibt, gibt dem EventBus ein Signal** — das Spiel
  ruft das Protokoll nie direkt. Ein Fehler darin darf kein Spiel kosten
  (`push_warning` und Stille, kein `push_error`).
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

Entscheidung und Begründung: `docs/adr/0002-melde-rueckkanal.md`.

Die beiden Kanäle oben liefern **zum** Spieler. Der dritte geht nach oben: eine Meldung
(„dieses Wort ist falsch") wird zu einer Korrektur im privaten Content-Repo und kommt über
den Content-Kanal als Pack-Update zurück.

| | Melde-Kanal |
|---|---|
| Was | eine Meldung: Ziel-Id, Kommentar, App- und Pack-Fassung (wenige Bytes) |
| Autoload | `ReportService` (`src/report/`) |
| Ziel | eigener PHP-Endpunkt, `server/melden/melden.php`; Ablage als JSON Lines **über** dem Docroot |
| Berechtigung | Melde-Token je Person, `<label>.<mac>` mit HMAC — geprägt von `tools/report/mint_token.py`, geprüft vom Endpunkt |
| Ablage des Tokens | `user://codes.cfg`, Sektion `report` (`ReportToken`) — wie die Zugangscodes **kein** Geheimnisspeicher |
| UI | Reiter „Melden" in `scenes/ui/settings_menu.tscn`; „⚑ Melden" im Reveal |

**Ohne hinterlegtes Token gibt es „Melden" nicht** — der Knopf im Reveal und die
Meldungsliste erscheinen nicht. Das ist eine Bedienungsentscheidung, keine Schranke: eine
Meldung, die nirgends ankommt, ist ärgerlicher als ein fehlender Knopf. Die Schranke sitzt
im Endpunkt, der das Token prüft, Größe und Rate deckelt und ein zurückgezogenes Label
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

Das HMAC-Geheimnis liegt **ausschließlich** auf dem Server (`server/melden/README.md`). Die
Endpunkt-URL ist dagegen eine Konstante im öffentlichen Repo (`ReportService.ENDPOINT`) —
kein Geheimnis, und genau deshalb muss der Endpunkt seine Grenzen selbst setzen. Ist sie
leer, ist der Kanal aus.

## Auskunft am Zeiger (`Hints`, `src/ui/hints.gd`)

| | |
|---|---|
| Autoload | `Hints` — eine `CanvasLayer` (layer 128) mit genau einer `HintCard` |
| Anmelden | `Hints.attach(control, titel, text, nachsatz)`; leer = abmelden |
| Eigene Trefferprüfung | `Hints.attach_live(control, callable)` → Karte oder `{}` je Punkt |
| Wächter | `tests/hint_discipline_test.gd` (kein `tooltip_text` mehr im Projekt) |

Godots eigener Tooltip ist im ganzen Spiel abgelöst: er erscheint verzögert, bleibt stehen,
wo er aufgegangen ist, und bringt die Typografie der Engine mit. Die Karte hängt am
Mauszeiger, kommt aus dem Theme und trägt vier Teile — Überschrift, Text, Liste, Nachsatz —,
von denen leere nicht erscheinen. Die Liste ist eine Tabelle (Zeichen | Bezeichnung | Wert),
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
| `Accent` | Gold, Nachdruck | `HudPanel` | Tafel der Kopfleiste, 8/4 statt 16 |
| `SectionButton` | 20, klappbare Abschnitte | | |

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

**Werkbänke haben mehr Platz als das Spiel.** Ein Fenster lässt sich wegen `canvas_items`
nicht am Rand größer ziehen, das Bild skaliert bloß mit. `LabRoom` (`src/dev/lab_room.gd`)
hebt deshalb Fenster und `content_scale_size` auf 1600×900 und stellt in `_exit_tree()`
wieder her, was dem Spiel gehört. Werkbänke sind die eine Stelle, an der 1152 nicht gilt;
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
