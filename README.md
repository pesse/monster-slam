# Monster Slam

Offline-Singleplayer-Lernspiel in einer isometrischen Fantasy-Welt. Der Spieler
verteidigt seine Festung gegen Monsterhorden, indem er deutsche und englische
Sprachaufgaben löst. Fokus: motivierendes Gameplay, das evidenzbasiertes Lernen
(Recall, Spaced Repetition) unterstützt.

## Kernidee

- **Normale Monster** tragen einzelne Vokabeln → per Tastatur übersetzen → Zeitdruck fördert schnellen Recall.
- **Bosse** stellen ganze Sätze → wenig/kein Zeitdruck → Übersetzungsqualität bestimmt den Schaden (semantische Bewertung, optional per LLM).
- **Lernprinzipien**: neue Inhalte ohne Zeitdruck, bekannte Vokabeln in schnelleren Wellen, Fehler werden per Spaced Repetition wiederholt.
- **Fähigkeiten** erleichtern das Lernen, ohne die Lösung vorzugeben.

## Technik

- Engine: **Godot 4.7** (GDScript, GL-Compatibility-Renderer)
- **Offline-first**, datengetrieben (JSON; SQLite optional für persistenten Lernfortschritt)
- Modulare, entkoppelte Architektur (siehe [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md))

## Loslegen

1. Sprachdaten auschecken: `git submodule update --init`
   (siehe [Sprachdaten](#sprachdaten-privates-submodule) — ohne diesen Schritt
   startet das Spiel, hat aber keine Vokabeln).
2. Projekt in Godot 4.7 öffnen (`project.godot`).
3. Starten (F5). Die Konsole listet den geladenen Content — bestätigt, dass die
   `ContentRegistry` die JSON-Daten unter `data/` und `data/language/` findet.

## Sprachdaten (privates Submodule)

Die Vokabel- und Satzdaten sind aus urheberrechtlich geschütztem
Lehrbuchmaterial abgeleitet und liegen deshalb **nicht in diesem Repo**, sondern
in einem separaten privaten Repo, eingehängt als Submodule unter
`data/language/`. Ohne Zugriff darauf ist das Spiel lauffähig, aber ohne
Sprachinhalte — eigene Lexeme können nach
[`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md) selbst angelegt werden.

## Content erweitern

Neue Monster, Fähigkeiten, Vokabelpakete, Bosse oder Wellen werden durch das
**Ablegen einer JSON-Datei** im passenden `data/`- bzw. `data/language/`-Ordner
ergänzt — ohne bestehenden Code anzufassen. Anleitung: [`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md).

## Projektstruktur

```
monster-slam/
├── project.godot          Godot-Projektkonfiguration (Autoloads, Main-Szene)
├── data/                  Datengetriebener Content (JSON) — hier wird erweitert
│   ├── language/          Sprachdaten — privates Submodule (Lexeme, Formen,
│   │                      Relationen, Sätze)
│   ├── monsters/          Normale Gegner
│   ├── bosses/            Bossgegner mit Sätzen
│   ├── task_definitions/  Aufgaben-Regeln
│   ├── monster_task_rules/ Zuordnung Aufgabe ↔ Monster
│   ├── skills/            Fähigkeiten
│   └── waves/             Wellen- & Level-Definitionen
├── src/                   GDScript-Code
│   ├── core/              Autoloads: EventBus, ContentRegistry, GameState
│   ├── learning/          Spaced Repetition, Antwort-Bewertung
│   └── main/              Einstiegspunkt
├── scenes/                Godot-Szenen (.tscn)
├── assets/                Grafik, Audio, Fonts
└── docs/                  Vision & Architektur
```
