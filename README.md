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

1. Projekt in Godot 4.7 öffnen (`project.godot`).
2. Starten (F5). Die Konsole listet den geladenen Content — bestätigt, dass die
   `ContentRegistry` die JSON-Daten unter `data/` findet.

## Content erweitern

Neue Monster, Fähigkeiten, Vokabelpakete, Bosse oder Wellen werden durch das
**Ablegen einer JSON-Datei** im passenden `data/`-Ordner ergänzt — ohne
bestehenden Code anzufassen. Anleitung: [`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md).

## Projektstruktur

```
monster-slam/
├── project.godot          Godot-Projektkonfiguration (Autoloads, Main-Szene)
├── data/                  Datengetriebener Content (JSON) — hier wird erweitert
│   ├── vocabulary/        Vokabelpakete (Sprach-Unterordner erlaubt)
│   ├── monsters/          Normale Gegner
│   ├── bosses/            Bossgegner mit Sätzen
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
