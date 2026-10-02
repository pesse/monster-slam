# Auftrag: drei Icons für den ruhigen Ast des Zeitwandlers

Die Knoten `skill.time.heavy`, `skill.time.mire` und `skill.time.lull` sind im Spiel und
tragen vorerst Platzhalter (`time_web`, `time_web`, `time_hourglass` in
`skill_icons.json`). Gebraucht werden drei eigene Icons im Stil der übrigen
Zeitwandler-Icons.

| Skill-Id | Name | Wirkung | Prompt | Ziel |
|---|---|---|---|---|
| `skill.time.heavy` | Schwere Schritte | alle Monster 15 % langsamer | `sources/time_heavy.prompt.txt` | `icons/time_heavy.webp` |
| `skill.time.mire` | Zäher Boden | nochmal 15 % langsamer | `sources/time_mire.prompt.txt` | `icons/time_mire.webp` |
| `skill.time.lull` | Späte Horde | 30 % mehr Abstand zwischen den Monstern | `sources/time_lull.prompt.txt` | `icons/time_lull.webp` |

## Ablauf (wie bei `bulwark_builder`)

1. Je Prompt ein Bild mit dem eingebauten `image_gen.imagegen` erzeugen, Stilreferenz
   `icons/time_hourglass.webp` und `icons/time_web.webp`. Original als
   `sources/time_<name>.png` ablegen.
2. Freistellen und auf 256 × 256 px bringen, Motiv mittig und höchstens 208 px groß, echtes
   Alpha, als verlustfreies WebP (RGBA) nach `icons/time_<name>.webp`.
3. `skill_icons.json`: die drei Platzhalter auf die neuen Dateien umstellen.
4. `manifest.json`: je Icon einen Eintrag unter `assets` (`icons/time_<name>`: path,
   width, height, notes mit „Source: sources/time_<name>.png", sha256) und unter
   `skill_icons` (name, tree `tree.timeweaver`, path), Vorbild `icons/bulwark_builder`.
5. `tools/godot.sh --import`, dann `tests/skill_icons_test.gd` und ein Bild der Werkbank:
   `GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/skill_tree_lab.tscn -- --shoot`.
   Die drei Knoten stehen unten links im Zeitwandler-Fächer; die Icons müssen sich bei
   40 px voneinander und von Spinnennetz/Sanduhr unterscheiden.

Keine Schrift, keine Zahlen, kein Medaillon hinter dem Motiv (das zeichnet das Spiel).
Nichts an Code, Daten oder Layout ändern.
