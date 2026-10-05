# Bestellung: Töne der Zauber

Die Zauber (ADR 0014) klingen bisher nach dem Bestand (`slow_mo_in`/`_out`, beim Donner
`fortress_hit` und `monster_kill`). Jede Wirkung soll ihren eigenen Ton bekommen, passend zum
Bild in `SpellFx` (Werkbank: `battle_theme_lab`, Reiter „Zauber").

**Stand 2026-10-05:** alle neun Töne sind eingebaut (Credits in `../CREDITS.md`). Gewählt
wurde nach Gehör aus den Kandidaten unten: `spell_haze` = „So slimy!", `spell_thunder_windup`
= „Laser Charge Up (Stronger)" (1,1 s — der Anlauf des Donnerschlags wurde darauf verlängert),
`spell_thunder` = „thunder.wav" (SGAK), `spell_heal` = „Vocal_chord.wav" (cellokratzer).
Die Tabelle darunter ist die ursprüngliche Bestellung.

**Herkunft:** nur Dateien mit belegter Quelle und Lizenz (CC0 bevorzugt, z. B. freesound.org).
Jede Datei bekommt im selben Commit eine Zeile in `assets/audio/CREDITS.md`. Keine selbst
synthetisierten Töne ohne Quelle.

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

## Kandidaten (recherchiert 2026-10-05)

Alle auf freesound.org, Lizenz auf der Seite geprüft: CC0. Gesucht mit Filter CC0 und
kurzer Dauer, sortiert nach Downloads; gehört ist noch keiner. Die Originale lädt nur, wer
angemeldet ist. Je Ton die erste Wahl zuerst.

| Datei | Kandidat | Dauer | Anmerkung |
| ----- | -------- | ----- | --------- |
| `spell_reveal` | [SFX Magic](https://freesound.org/people/renatalmar/sounds/264981/) (renatalmar) | 1,95 s | Tags „reveal, chimes, magic", sehr verbreitet |
| | [Cliche Magic Spell Sound](https://freesound.org/people/qubodup/sounds/817466/) (qubodup) | 2,16 s | Feen-Glöckchen |
| | [ShiningRinging](https://freesound.org/people/NoisyRedFox/sounds/759840/) (NoisyRedFox) | 0,65 s | kurz, hell |
| `spell_slow` | [Cartoon - Splat!](https://freesound.org/people/Breviceps/sounds/445118/) (Breviceps) | 0,79 s | komisch statt eklig |
| | [Mud Splat](https://freesound.org/people/Breviceps/sounds/445109/) (Breviceps) | 0,36 s | trockener |
| | [So slimy!](https://freesound.org/people/Breviceps/sounds/445968/) (Breviceps) | 2,32 s | eher für Schwere Luft |
| `spell_haze` | [Woosh_Low_Short_01](https://freesound.org/people/moogy73/sounds/425704/) (moogy73) | 2,34 s | tiefer Woosh |
| | [whoosh bass 1](https://freesound.org/people/Logicogonist/sounds/807446/) (Logicogonist) | 1,73 s | Windstoß |
| | [Deep Inhale & Exhale 1](https://freesound.org/people/EverydayEldritch/sounds/615047/) (EverydayEldritch) | 2,93 s | nur das Ausatmen nehmen |
| `spell_freeze` | [iceSpell](https://freesound.org/people/Relenzo2/sounds/160420/) (Relenzo2) | 0,62 s | Kristall, Glas, Hall |
| | [Ice Magic Arrow_type 01](https://freesound.org/people/lotteria001/sounds/709888/) (lotteria001) | 2,4 s | Spiel-Zauber |
| | [Chill Hit](https://freesound.org/people/JustInvoke/sounds/138484/) (JustInvoke) | 0,55 s | Treffer |
| `spell_shatter` | [Breaking ice - small 3](https://freesound.org/people/Aurelon/sounds/422620/) (Aurelon) | 1,83 s | echtes Eis, klein |
| | [Break something (ice/glass/...)](https://freesound.org/people/Aurelon/sounds/422633/) (Aurelon) | 1,14 s | |
| | [Ice Break With Hand](https://freesound.org/people/Lynx_5969/sounds/422669/) (Lynx_5969) | 0,39 s | sehr kurz, passt zum Sechsfach |
| `spell_thunder_windup` | [Charge up](https://freesound.org/people/SamsterBirdies/sounds/483883/) (SamsterBirdies) | 0,47 s | passt zu den 0,35 s |
| | [High Pitched Charging Noise](https://freesound.org/people/Milky0519/sounds/579004/) (Milky0519) | 1,76 s | kürzen |
| `spell_thunder` | [strike 3 sec](https://freesound.org/people/Littlebrojay/sounds/195439/) (Littlebrojay) | 3,68 s | Einschlag mit Grollen |
| | [thunder3](https://freesound.org/people/Josh74000MC/sounds/475094/) (Josh74000MC) | 3,53 s | Original OGG (lädt Godot) |
| | [Closeup Thunder Strike 01](https://freesound.org/people/loganzsound/sounds/840628/) (loganzsound) | 14 s | nah und laut, auf den Krach kürzen |
| `spell_heal` | [Heal Up](https://freesound.org/people/Rickplayer/sounds/530488/) (Rickplayer) | 0,56 s | |
| | [harp glissando](https://freesound.org/people/PhonosUPF/sounds/490831/) (PhonosUPF) | 0,63 s | echte Harfe |
| `spell_armor` | [shield guard](https://freesound.org/people/nekoninja/sounds/370203/) (nekoninja) | 0,82 s | Stahlschild, Treffer |
| | [Metallic Sound Pack 4](https://freesound.org/people/soniktec/sounds/164265/) (soniktec) | 1,24 s | Klang, Schmiede |
| | [unsheath_sword](https://freesound.org/people/Qat/sounds/107589/) (Qat) | 1,01 s | hell, metallisch |

Bewusst nicht genommen: „Heal - Rpg" (colorsCrimsonTears) — ist schon `task_mastered.wav`;
Dateien von gelöschten Konten (kein Autor für die Credits); „thunder-crack 3"
(Logicogonist) wegen anstößiger Tags in einem Kinderspiel; 8-Bit-Töne passen nicht zum Bild.
Was gekürzt oder umgewandelt wird, steht so in `CREDITS.md` (wie bei `slow_mo_out.wav`).

## Zweite Runde (2026-10-05) für die offenen vier

Wieder alle CC0 laut ihrer Seite, Autoren mit bestehendem Konto; ungehört. ★ = Bewertung
auf freesound (Anzahl). Kurzer Donner und kurzes Aufladen sind unter CC0 knapp — fast alles
muss gekürzt werden.

| Datei | Kandidat | Dauer | Anmerkung |
| ----- | -------- | ----- | --------- |
| `spell_haze` | [SFX Reverse time](https://freesound.org/people/xkeril/sounds/715070/) (xkeril) | 2,74 s | „Zeit verlangsamt sich", ★4,8 (28); auf ~1,8 s |
| | [Energy Drain](https://freesound.org/people/qubodup/sounds/742835/) (qubodup) | 3,0 s | Tags slow/slowdown/spell, FLAC; Hall kürzen |
| | [Power down - Rpg](https://freesound.org/people/colorsCrimsonTears/sounds/577960/) (colorsCrimsonTears) | 0,91 s | als „Debuff-Zauber" gemacht, ★4,9 |
| | [Power down 2 - Rpg](https://freesound.org/people/colorsCrimsonTears/sounds/609025/) (colorsCrimsonTears) | 1,67 s | länger, etwas Sci-Fi |
| `spell_thunder_windup` | [Laser Charge Up (Stronger)](https://freesound.org/people/magnuswaker/sounds/592573/) (magnuswaker) | 1,1 s | letzte 0,5 s nehmen; eher Sci-Fi |
| | [Energy Riser 3](https://freesound.org/people/magnuswaker/sounds/531729/) (magnuswaker) | 1,09 s | musikalischer Riser |
| | [Power Up Charge](https://freesound.org/people/qubodup/sounds/172631/) (qubodup) | 1,0 s | steigende Tonhöhe, FLAC |
| | [Long Crackle 04](https://freesound.org/people/ironcross32/sounds/582631/) (ironcross32) | 1,26 s | Lichtbogen; rückwärts ein steigendes Knistern |
| `spell_thunder` | [Electro_Hit_04](https://freesound.org/people/doudar41/sounds/535952/) (doudar41) | 3,0 s | als „Lightning Spell" fürs Spiel gemacht, ★4,8 (34); auf ~2 s |
| | [Electro_Hit_02](https://freesound.org/people/doudar41/sounds/535954/) / [_03](https://freesound.org/people/doudar41/sounds/535953/) (doudar41) | 3,86 s | dieselbe Reihe |
| | [thunder.wav](https://freesound.org/people/SGAK/sounds/467777/) (SGAK) | 2,61 s | sauber, ohne Regen; eher Grollen |
| | [Thunder.wav](https://freesound.org/people/Puerta118m/sounds/471691/) (Puerta118m) | 2,05 s | Foley, passende Länge |
| `spell_heal` | [Level Up](https://freesound.org/people/qubodup/sounds/442943/) (qubodup) | 1,67 s | „chime dreamy fantasy", ★4,8 (75); klingt evtl. nach Aufstieg |
| | [Powerup 10](https://freesound.org/people/LilMati/sounds/523654/) (LilMati) | 1,81 s | Tags Heal/RPG/Extra-life, ★5,0 (55) |
| | [Magic chorus](https://freesound.org/people/punisherdan/sounds/444455/) (punisherdan) | 1,01 s | Engelschor, OGG |
| | [achievement-sparkle](https://freesound.org/people/SkySpeira/sounds/715067/) (SkySpeira) | 1,76 s | funkelnd, evtl. zu sehr „Erfolg" |
| | [Spell Cast / Buff / High Tone](https://freesound.org/people/SypherZent/sounds/420676/) (SypherZent) | 1,69 s | Bearbeitung eines Tons eines gelöschten Kontos — Herkunft schwächer |
