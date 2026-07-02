# Architektur

Leitziel: **Modularität durch Daten + Entkopplung durch Signale.** Neue Inhalte
und Mechaniken sollen sich ergänzen lassen, ohne bestehende Systeme zu ändern.

## Zwei Autoload-Säulen

### 1. ContentRegistry (`src/core/content_registry.gd`)
Datengetriebener Katalog. Scannt beim Start rekursiv `res://data/<kategorie>/`
und lädt jede `.json`-Datei. Kategorien: `vocabulary`, `monsters`, `bosses`,
`skills`, `waves`.

- Jede JSON-Datei enthält ein Objekt **oder** ein Array von Objekten.
- Jedes Objekt braucht eine eindeutige `id` (String).
- Zugriff: `ContentRegistry.monsters`, `.get_entry("skills", "skill.freeze")`,
  `.all("waves")`, `.vocabulary_by_tags(["basics"])`.
- `reload()` scannt zur Laufzeit neu.

**Folge:** Content hinzufügen = Datei ablegen. Kein Code-Edit.

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
| Neue Vokabeln | JSON in `data/vocabulary/**` | nein |
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

- **Content** (Vokabeln, Monster, …): JSON unter `data/` — versioniert, agent-editierbar.
- **Spielerfortschritt** (Lernhistorie, Unlocks): offline persistent. JSON reicht
  zum Start; SQLite ist die vorgesehene Ausbaustufe für größere Historien.

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
