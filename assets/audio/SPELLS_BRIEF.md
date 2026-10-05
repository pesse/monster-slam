# Bestellung: Töne der Zauber

Die Zauber (ADR 0014) klingen bisher nach dem Bestand (`slow_mo_in`/`_out`, beim Donner
`fortress_hit` und `monster_kill`). Jede Wirkung soll ihren eigenen Ton bekommen, passend zum
Bild in `SpellFx` (Werkbank: `battle_theme_lab`, Reiter „Zauber").

**Herkunft:** nur Dateien mit belegter Quelle und Lizenz (CC0 bevorzugt, z. B. freesound.org).
Jede Datei bekommt im selben Commit eine Zeile in `CREDITS.md`. Keine selbst synthetisierten
Töne ohne Quelle.

**Format:** WAV (16 Bit, 44,1 oder 48 kHz) oder MP3; kein FLAC (lädt Godot 4.7 nicht). Mono
reicht. Pegel ungefähr wie `monster_kill.wav`, ohne Stille am Anfang — der Ton fällt auf den
Tastendruck.

| Datei | Zauber | Länge | Charakter |
| ----- | ------ | ----- | --------- |
| `spell_reveal.wav` | Drittes Auge, Orakelblick | 0,8–1,2 s | Heller, gläserner Schimmer, der aufsteigt (Glockenspiel, Shimmer-Sweep); der Lichtvorhang fährt 0,9 s übers Feld. |
| `spell_slow.wav` | Sumpf | 0,5–0,9 s | Schmatzender Schlamm, ein, zwei Blasen; eher komisch als eklig. |
| `spell_haze.wav` | Schwere Luft | 1–1,5 s | Dumpfes, tiefes Ausatmen, ein Windstoß, der sich legt. |
| `spell_freeze.wav` | Frost | 0,6–1 s | Eis, das schlagartig zufriert: Knistern, das in ein helles Klirren endet. |
| `spell_shatter.wav` | Frost (Auftauen) | 0,3–0,6 s | Eis zerspringt, kleine Splitter; leiser als der Zauber, er kommt sechsmal zugleich. |
| `spell_thunder_windup.wav` | Donnerschlag | 0,3–0,4 s | Kurzes Aufladen, Knistern in der Luft (das Bild verdunkelt sich 0,35 s). |
| `spell_thunder.wav` | Donnerschlag | 0,8–1,5 s | Ein krachender Einschlag mit Grollen; die Blitze fallen im Abstand von 0,09 s, der Ton für den ersten muss die übrigen tragen. |
| `spell_heal.wav` | Lebensquell | 0,8–1,2 s | Warmer, aufsteigender Akkord, eine Spur Harfe. |
| `spell_armor.wav` | Eisenhaut | 0,6–1 s | Metallisch: ein Schild, das einrastet, mit hellem Nachklang. |

Wenn die Dateien da sind, bekommen sie je einen Eintrag in `Sfx.SOUNDS` (`src/core/sfx.gd`,
mit Pegel) und werden in `SpellFx.SOUNDS` bzw. `SpellFx.bolt` der Wirkung zugeordnet;
`spell_shatter` spielt `FrostShell.shatter`.
