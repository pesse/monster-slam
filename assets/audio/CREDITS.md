# Audio-Credits

Dieses Repo ist öffentlich. Jede Datei unter `assets/audio/` (Effekte in `sfx/`, Musik in
einem eigenen Ordner daneben) braucht deshalb einen Eintrag mit belegter Herkunft und
Lizenz — auch „Public Domain"/CC0 muss auf eine Quelle zeigen, sonst lässt sich später
nicht mehr nachweisen, dass die Datei hier stehen darf. Neue Datei und Eintrag gehören in
denselben Commit.

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `sfx/monster_kill.wav` | https://freesound.org/people/modusmogulus/sounds/792520/ | CC0 | modusmogulus |
| `sfx/slow_mo_in.wav` | https://freesound.org/people/Leszek_Szary/sounds/146733/ | CC0 | Leszek_Szary |
| `sfx/slow_mo_out.wav` | aus `slow_mo_in.wav` erzeugt (rückwärts, sonst unverändert) | wie `slow_mo_in.wav` | s. o. |
| `sfx/wrong_answer.wav` | https://freesound.org/people/Sadiquecat/sounds/818960/ | CC0 | Sadiquecat |
| `sfx/fortress_hit.mp3` | https://freesound.org/people/canberries4/sounds/868110/ | CC0 | canberries4 |
| `sfx/wave_cleared.wav` | https://freesound.org/people/plasterbrain/sounds/397355/ | CC0 | plasterbrain |
| `sfx/fortress_destroyed.wav` | https://freesound.org/people/taranp/sounds/362206/ | CC0 | TaranP |
| `sfx/task_mastered.wav` | https://freesound.org/people/colorsCrimsonTears/sounds/562292/ | CC0 | colorsCrimsonTears |
| `sfx/word_mastered.wav` | https://freesound.org/people/qubodup/sounds/442774/ | CC0 | qubodup |
| `sfx/spell_reveal.wav` | https://freesound.org/people/renatalmar/sounds/264981/ | CC0 | renatalmar |
| `sfx/spell_slow.wav` | https://freesound.org/people/Breviceps/sounds/445118/ | CC0 | Breviceps |
| `sfx/spell_freeze.wav` | https://freesound.org/people/Relenzo2/sounds/160420/ | CC0 | Relenzo2 |
| `sfx/spell_shatter.wav` | https://freesound.org/people/Aurelon/sounds/422620/ | CC0 | Aurelon |
| `sfx/spell_armor.wav` | https://freesound.org/people/nekoninja/sounds/370203/ | CC0 | nekoninja |

`sfx/wave_cleared.wav` ist die verlustfreie WAV-Fassung der dort angebotenen FLAC-Datei —
Godot 4.7 lädt FLAC nicht („No loader found for resource"). Die Quelle ist innen bereits
16-Bit-PCM, die Wandlung ist bitgleich.

`sfx/spell_shatter.wav` ist die dort angebotene FLAC-Datei (24 Bit) als 16-Bit-WAV, vorn um
0,58 s Stille gekürzt; sonst unverändert. Die übrigen `spell_*`-Dateien sind die Originale,
nur umbenannt.
