# Allgemeines Tooltip-Paket

Gemeinsame Tooltip-Texturen für alle Spielbereiche. Aus `assets/ui/skill_tree/` nach `assets/ui/tooltip/` ausgelagert; keine Abhängigkeit vom Fähigkeitenbaum. Das zentrale Theme verwendet den Rahmen sowie die Zeiger nach oben und unten für `HintCard`.

| Datei | Größe | Slice L/T/R/B |
| --- | --- | --- |
| `frame.webp` | 256 × 256 | 24 / 24 / 24 / 24 |
| `pointer_up.webp`, `pointer_down.webp` | 64 × 36 | keine |
| `pointer_left.webp`, `pointer_right.webp` | 36 × 64 | keine |

Alle fünf Texturen sind verlustfreie WebP mit Alpha. Nur die goldene Kontur ist sichtbar; Innen- und Außenflächen sind echt transparent. Gewünschte Füllfarben zeichnet das Spiel separat. Antialiasing liegt ausschließlich an der Goldkontur.

`frame_only.tres` und `textured_panel.tres` sind vorhandene StyleBoxTexture-Beispiele mit denselben 24-px-Slices. `tooltip_shell.tscn` ist ein separates Beispiel mit eigener dunkler Füllung; das Spiel benutzt stattdessen seine zentrale `HintCard` und das Theme. Die Beispielszene ist kein Einstiegspunkt für neue Spiel-Tooltips.

## Quellen, Export und Prüfung

- `manifest.json`: Maße, Pfade und SHA-256 der fünf allgemeinen Texturen.
- `sources/tooltip-alpha.cjs`: eigenständiger Export aus `sources/tooltip-before-alpha/`; Node.js und Sharp erforderlich, optional `SHARP_MODULE` setzen. Aufruf: `node sources/tooltip-alpha.cjs`.
- `sources/prompts.json`, `sources/tooltip-transparency-notes.md`: ursprüngliche Erzeugung und Transparenzkorrektur. Quellen unter `sources/` sind vom Godot-Import ausgeschlossen.
- `preview/tooltip-transparency.png`: Rahmen und alle Zeiger auf Weiß, Creme und Hellblau.
- `preview/tooltip-alpha-check.json`: Alpha-/Maß-/Formatprüfung.
- `preview/verify.gd`: prüft die fünf Texturen, beide Ressourcen und die Beispielszene in Godot.

Die Verschiebung erhält Texturinhalt, Maße, Slice-Ränder und Import-UIDs. Zentraler Theme-Verweis, Ressourcen, Statistik-Paket und Exportwerkzeuge verwenden den allgemeinen Pfad. Der Skill-Tree-Export erzeugt nur noch seine eigenen 30 Assets.

Geprüft mit Godot 4.7 über den Projekt-Wrapper: Import erfolgreich; `preview/verify.gd` lädt alle fünf Texturen, beide StyleBoxTexture-Ressourcen und die Beispielszene erfolgreich. Die Transparenzprüfung besteht nach dem eigenständigen Reexport weiterhin.
