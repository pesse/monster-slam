# Auftrag: acht Icons für die Zauber (ADR 0014)

Die Zauber in `data/spells/basic_spells.json` tragen vorerst ein Emoji im Feld `icon`. Es
steht als Schrift in der Ladenkachel (`scenes/ui/spell_tile.tscn`, 128 × 128) und im
Zaubervorrat im Kampf (`scenes/ui/spell_slot.tscn`, 72 × 72, unten links). Gebraucht
werden acht gemalte Icons. Die Prompts stehen in `prompts.json`.

| Zauber-Id | Name | Wirkung | Motiv | Ziel |
|---|---|---|---|---|
| `spell.glimpse` | Drittes Auge | Alternativen, Monster auf dem Feld | violetter Edelstein als Auge in einem Bronze-Amulett | `icons/glimpse.webp` |
| `spell.insight` | Orakelblick | Alternativen, ganze Welle | Kristallkugel auf Bronzefuß, violett-goldener Nebel | `icons/insight.webp` |
| `spell.mire` | Sumpf | halbes Tempo, Feld | Schnecke mit moosgrün leuchtendem Haus | `icons/mire.webp` |
| `spell.lull` | Schwere Luft | halbes Tempo, ganze Welle | schwere Nebelwolke mit eisernem Gewicht | `icons/lull.webp` |
| `spell.frost` | Frost | friert zehn Sekunden ein | drei Eiskristalle aus einem Fuß | `icons/frost.webp` |
| `spell.thunder` | Donnerschlag | fegt das Feld | Gewitterwolke mit einem großen Blitz | `icons/thunder.webp` |
| `spell.mend` | Lebensquell | +25 Leben | Rubinherz, aus dem Quellwasser perlt | `icons/mend.webp` |
| `spell.plate` | Eisenhaut | +25 Rüstung | genieteter Stahlbrustpanzer mit Glanz | `icons/plate.webp` |

## Abgrenzung

- **Zu den Fähigkeiten:** Zauber verbrauchen sich, Fähigkeiten bleiben. Deshalb leuchtet
  jedes Zauber-Icon aus sich heraus in seiner Akzentfarbe (die Fähigkeiten-Icons tun das
  nicht). Der Schein bleibt eng am Objekt, keine Scheibe dahinter. Die Kachel hat schon
  einen Silber-Gold-Rahmen.
- **Bewusst andere Motive als im Fähigkeitenbaum:** kein natürliches Auge (`scout_eye`),
  keine Schlammpfütze mit Fußabdruck (`time_mire`), kein schwerer Stiefel (`time_heavy`),
  kein Verband, Stab oder Zelt (`healing_*`), kein Schild (`defense_shield`).
- **Zum Menü-Icon „Zauber"** (`../../main_menu/sources/spells-icon-brief.md`): Das ist ein
  Zauberfläschchen. Deshalb ist hier keiner der acht ein Trank oder eine Flasche.
- **Paare unterscheidbar:** Orakelblick wirkt stärker als Drittes Auge, Schwere Luft
  stärker als Sumpf. Das stärkere Icon ist reicher, aber die Silhouetten müssen sich
  auch bei 48 px klar unterscheiden.
- Die Akzentfarben sind auch die Farben, in denen die Effekte im Kampf erscheinen sollen
  (Frost eisblau, Donner blauweiß, Lebensquell rot-grün, Eisenhaut silbern).

## Ablauf (wie bei `skill_tree/sources/time_calm_BRIEF.md`)

1. Erst den Atlas (`atlas` in `prompts.json`, 4 × 2 Felder) erzeugen, damit alle acht
   gleich aussehen. Ein Icon, das nicht passt, einzeln mit seinem Prompt unter `icons`
   neu machen. Stilreferenz: die Dateien unter `reference`. Originale nach `sources/`
   (`spells_atlas.png`, einzelne als `<name>.png`).
2. Freistellen und auf 256 × 256 px bringen, Motiv mittig und höchstens 208 px groß, echtes
   Alpha, als verlustfreies WebP (RGBA) nach `icons/<name>.webp`.
3. `manifest.json` in `assets/ui/spells/` anlegen, Aufbau wie
   `assets/ui/skill_tree/manifest.json`: je Icon ein Eintrag unter `assets` (`icons/<name>`:
   path, width, height, notes mit „Source: sources/<name>.png", sha256).
4. Prüfen: die acht Icons nebeneinander bei 128 px und bei 48 px. Sie müssen sich
   voneinander und von den Fähigkeiten-Icons unterscheiden.

Keine Schrift, keine Zahlen, kein Medaillon hinter dem Motiv. Nichts an Code, Daten,
Szenen oder Layout ändern. Den Einbau (Icon statt Emoji in Kachel und Vorrat) macht der
Code danach.
