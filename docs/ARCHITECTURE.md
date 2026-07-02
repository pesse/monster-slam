# Architektur

Leitziel: **Modularität durch Daten + Entkopplung durch Signale.** Neue Inhalte
und Mechaniken sollen sich ergänzen lassen, ohne bestehende Systeme zu ändern.

## Zwei Autoload-Säulen

### 1. ContentRegistry (`src/core/content_registry.gd`)
Datengetriebener Katalog. Scannt beim Start rekursiv `res://data/<kategorie>/`
und lädt jede `.json`-Datei. Kategorien: `lexemes`, `lexeme_forms`,
`lexeme_relations`, `sentences`, `sentence_lexemes`, `task_templates`,
`monster_task_rules`, `monsters`, `bosses`, `skills`, `waves`.

- Jede JSON-Datei enthält ein Objekt **oder** ein Array von Objekten.
- Jedes Objekt braucht eine eindeutige `id` (String).
- Zugriff: `ContentRegistry.monsters`, `.get_entry("lexemes", "lex.en.house")`,
  `.all("waves")`, `.lexemes_by_tags(["basics"])`, `.forms_for(id, form_type)`,
  `.relations_of(id, "opposite")`, `.monster_rule_for(task_type, direction)`.
- `reload()` scannt zur Laufzeit neu.

**Folge:** Content hinzufügen = Datei ablegen. Kein Code-Edit.

### Datenmodell (ERM): Sprache / Aufgabe / Darstellung getrennt
Der Lernstoff ist normalisiert, damit Sprachdaten, Aufgaben, Fortschritt und
Darstellung unabhängig wachsen können (siehe `docs/ADDING_CONTENT.md`):

- **lexemes / lexeme_forms / lexeme_relations** — *Was* ist das Wort, welche Formen
  (Konjugation/Zeit) und Relationen (opposite/synonym/…) hat es.
- **task_templates** — *Was wird abgefragt* (translate/opposite/synonym/conjugation/…
  + `direction`). Referenziert Lexeme/Formen/Relationen, ist aber noch kein Monster.
- **monster_task_rules** — *Wie* eine Aufgabe dargestellt wird: `(task_type, direction)
  → monster_type` + `base_speed/base_damage/base_reward`.
- **player_task_progress** — *Wie gut* der Spieler die konkrete Aufgabe kann
  (nicht im Content, sondern beschreibbar in `user://`, siehe unten).
- **sentences / sentence_lexemes** — für Boss-/Satzübungen; Schema vorhanden, Feature
  (task_type `sentence`/`fill_gap`, Boss-Runner) noch zurückgestellt.

Die Auflösung Template → spielbare Aufgabe `{prompt, accepted_answers, …}` macht
`src/learning/task_resolver.gd`; die Auswahl fälliger/neuer Aufgaben + Monster-Mapping
`src/battle/wave_generator.gd`.

### 2. EventBus (`src/core/event_bus.gd`)
Globaler Signal-Hub. Systeme kommunizieren über Signale statt direkter
Referenzen. Ein neues System abonniert relevante Signale, ohne dass ein
bestehendes System davon wissen muss.

`GameState` (`src/core/game_state.gd`) hält die Laufzeit-Session (Festungs-HP,
Score, aktive Welle) und reagiert selbst nur über EventBus-Signale.

## Lern-Module (`src/learning/`)

- **`spaced_repetition.gd`** — SM-2-artiger Scheduler. Bestimmt, wann ein Item
  wieder fällig ist. Persistierbar via `to_dict()`/`from_dict()`.
- **`answer_evaluator.gd`** — zwei Modi:
  - `evaluate_vocab()`: normalisierter Exakt-/Alternativabgleich für schnellen Recall (offline).
  - `evaluate_sentence()`: semantische Qualität für Boss-Sätze. Standard ist eine
	Offline-Heuristik; ein lokales LLM lässt sich über `sentence_backend`
	(Callable) einstecken — **ohne** Aufrufer zu ändern.

## Erweiterungspunkte für den KI-Agenten

| Erweiterung | Wie | Bestehender Code betroffen? |
|---|---|---|
| Neues Wort/Aufgabe | JSON in `data/lexemes/` + `data/task_templates/` | nein |
| Neues Monster | JSON in `data/monsters/` | nein |
| Neuer Boss | JSON in `data/bosses/` | nein |
| Neue Welle | JSON in `data/waves/` | nein |
| Neue Fähigkeit (Daten) | JSON in `data/skills/` | nein |
| Neuer Fähigkeits-*Effekt* (Verhalten) | Effect-Handler ergänzen (siehe unten) | nur additiv |
| Neue Mechanik | Neues System, das EventBus-Signale abonniert | nein |

### Fähigkeits-Effekte
Eine Fähigkeit trägt in den Daten ein `effect`-Feld (z. B. `slow_monsters`).
Die reine Definition ist datengetrieben; Verhalten, das Code braucht, wird über
ein Effekt-Handler-Muster ergänzt: jeder Effekt registriert sich selbst unter
seinem `effect`-Schlüssel. Ein neuer Effekt = neuer Handler, keine Änderung an
vorhandenen Handlern. (Noch zu implementieren — siehe `docs/ADDING_CONTENT.md`.)

## Datenpersistenz

- **Content** (Lexeme, Aufgaben, Monster, …): JSON unter `data/` — versioniert, agent-editierbar.
- **Spielerfortschritt** (`player_task_progress`): der Autoload `PlayerProgress`
  (`src/learning/player_progress.gd`) hält je Aufgabe Confidence/Streak/Fälligkeit und
  kapselt den SM-2-Scheduler. Persistenz: JSON unter `user://progress/<player>.json`
  (schreibintensiv, wächst → bewusst nicht in `data/`). SQLite ist die vorgesehene
  Ausbaustufe für größere Historien.

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

- IDs: `kategorie.name`, z. B. `monster.slime`, `vocab.en.house`, `skill.freeze`.
- GDScript mit statischen Typen und `##`-Doc-Kommentaren.
- UI-Texte und Feedback auf Deutsch (Zielgruppe DE→EN-Lernende).
