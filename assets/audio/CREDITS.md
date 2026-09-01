# Audio-Credits

Dieses Repo ist öffentlich. Jede Datei unter `assets/audio/` braucht deshalb einen Eintrag
mit belegter Herkunft und Lizenz — auch „Public Domain"/CC0 muss auf eine Quelle zeigen,
sonst lässt sich später nicht mehr nachweisen, dass die Datei hier stehen darf. Neue Datei
und Eintrag gehören in denselben Commit.

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `monster_kill.wav` | https://freesound.org/people/modusmogulus/sounds/792520/ | CC0 | modusmogulus |
| `slow_mo_in.wav` | https://freesound.org/people/Leszek_Szary/sounds/146733/ | CC0 | Leszek_Szary |
| `slow_mo_out.wav` | aus `slow_mo_in.wav` erzeugt (rückwärts, sonst unverändert) | wie `slow_mo_in.wav` | s. o. |
| `wrong_answer.wav` | https://freesound.org/people/Sadiquecat/sounds/818960/ | CC0 | Sadiquecat |
| `fortress_hit.mp3` | https://freesound.org/people/canberries4/sounds/868110/ | CC0 | canberries4 |
| `wave_cleared.wav` | https://freesound.org/people/plasterbrain/sounds/397355/ | CC0 | plasterbrain |
| `fortress_destroyed.wav` | https://freesound.org/people/taranp/sounds/362206/ | CC0 | TaranP |

`wave_cleared.wav` ist die verlustfreie WAV-Fassung der dort angebotenen FLAC-Datei —
Godot 4.7 lädt FLAC nicht („No loader found for resource"). Die Quelle ist innen bereits
16-Bit-PCM, die Wandlung ist bitgleich.
