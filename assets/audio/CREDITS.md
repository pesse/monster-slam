# Audio-Credits

Dieses Repo ist öffentlich. Jede Datei unter `assets/audio/` (Effekte in `sfx/`, Musik in
einem eigenen Ordner daneben) braucht deshalb einen Eintrag mit belegter Herkunft und
Lizenz — auch „Public Domain"/CC0 muss auf eine Quelle zeigen, sonst lässt sich später
nicht mehr nachweisen, dass die Datei hier stehen darf. Neue Datei und Eintrag gehören in
denselben Commit.

| Datei | Quelle (URL) | Lizenz | Autor |
| ----- | ------------ | ------ | ----- |
| `sfx/monster_kill.wav` | https://freesound.org/people/modusmogulus/sounds/792520/ | CC0 | modusmogulus |
| `sfx/slow_mo_in.wav` | abgeleitet aus einer ElevenLabs-Generierung (`eleven_text_to_sound_v2`), 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, s. u. |
| `sfx/slow_mo_out.wav` | aus derselben Generierung abgeleitet | wie `slow_mo_in.wav` | s. u. |
| `sfx/wrong_answer.wav` | https://freesound.org/people/Sadiquecat/sounds/818960/ | CC0 | Sadiquecat |
| `sfx/fortress_hit.mp3` | https://freesound.org/people/canberries4/sounds/868110/ | CC0 | canberries4 |
| `sfx/wave_cleared.wav` | https://freesound.org/people/plasterbrain/sounds/397355/ | CC0 | plasterbrain |
| `sfx/fortress_destroyed.wav` | https://freesound.org/people/taranp/sounds/362206/ | CC0 | TaranP |
| `sfx/task_mastered.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/word_mastered.wav` | https://freesound.org/people/qubodup/sounds/442774/ | CC0 | qubodup |
| `sfx/spell_reveal.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/spell_slow.wav` | https://freesound.org/people/Breviceps/sounds/445118/ | CC0 | Breviceps |
| `sfx/spell_freeze.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/spell_shatter.wav` | https://freesound.org/people/Aurelon/sounds/422620/ | CC0 | Aurelon |
| `sfx/spell_armor.wav` | https://freesound.org/people/nekoninja/sounds/370203/ | CC0 | nekoninja |
| `sfx/spell_haze.wav` | https://freesound.org/people/Breviceps/sounds/445968/ | CC0 | Breviceps |
| `sfx/spell_thunder_windup.wav` | https://freesound.org/people/magnuswaker/sounds/592573/ | CC0 | magnuswaker |
| `sfx/spell_thunder.wav` | https://freesound.org/people/SGAK/sounds/467777/ | CC0 | SGAK |
| `sfx/spell_heal.wav` | https://freesound.org/people/cellokratzer/sounds/502947/ | CC0 | cellokratzer |
| `sfx/badge_earned.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_gold.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_diamond.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_revenge.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_catch_up.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_comeback.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |
| `sfx/badge_better.wav` | ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), generiert 2026-10-12 | ElevenLabs-Nutzungsbedingungen (Abo des Projekts) | ElevenLabs, Prompt s. u. |

`sfx/wave_cleared.wav` ist die verlustfreie WAV-Fassung der dort angebotenen FLAC-Datei —
Godot 4.7 lädt FLAC nicht („No loader found for resource"). Die Quelle ist innen bereits
16-Bit-PCM, die Wandlung ist bitgleich.

`sfx/spell_shatter.wav` ist die dort angebotene FLAC-Datei (24 Bit) als 16-Bit-WAV, vorn um
0,58 s Stille gekürzt; sonst unverändert. Die übrigen freesound-`spell_*`-Dateien sind die
Originale, nur umbenannt.

`sfx/task_mastered.wav` ist eine KI-Generierung (`tools/sound_eval`, `generate`), keine
freesound-Datei: Prompt „Short soft magic spell: a quick airy whoosh that lands on a warm,
mellow magical shimmer, gentle and friendly, low-mid tones, fantasy game success sound",
1,1 s, `prompt_influence` 0,5; Variante 2 von 3, nach Gehör gewählt. Die gelieferte MP3 ist
als 16-Bit-WAV gespeichert, sonst unverändert. Bis 2026-10-12 stand hier „Heal - Rpg" von
colorsCrimsonTears (https://freesound.org/people/colorsCrimsonTears/sounds/562292/, CC0) —
Spieler fanden ihn auf Dauer nervig.

`sfx/slow_mo_in.wav` und `sfx/slow_mo_out.wav` stammen aus Variante 3 desselben Laufs
(gleicher Prompt). Bearbeitung: zu Mono gemischt, die ersten 50 ms (fast still) entfernt, dann
als Band-Effekt die Abspielrate gleiten lassen – beim Einstieg von 1,0 auf 0,55 (Bandstopp,
0,85 s), beim Ausstieg von 0,6 auf 1,15 (Bandstart, 0,85 s), beide mit natürlichem Ausklang –,
Cosinus-Fades, Pegel wie die Vorgänger (lautestes 50-ms-Fenster −21 dBFS, True Peak ≤ −1 dBTP).
Bis 2026-10-12 stand hier „Slow motion" von Leszek_Szary
(https://freesound.org/people/Leszek_Szary/sounds/146733/, CC0), Ausstieg rückwärts.

Zauber `spell_reveal`, `spell_freeze` und alle Plaketten-Töne sind seit 2026-10-12 ebenfalls
KI-Generierungen (`tools/sound_eval`, `generate`, `prompt_influence` 0,5, je 3 Varianten, nach
Gehör gewählt). Bearbeitung: MP3 als 16-Bit-WAV, Pegel auf −16 dBFS im lautesten 300-ms-Fenster
(True Peak ≤ −1 dBTP; die MP3-Spitzen über 0 dBFS sind damit ohne Verlust abgesenkt), letzte
10 ms ausgeblendet; sonst unverändert. Prompts, Dauer, gewählte Variante und Vorgänger (CC0):

- `sfx/spell_reveal.wav`: „Magic reveal spell: a soft shimmering sweep rising upward like a curtain of light passing over, airy glassy chimes and warm sparkle, mystical and calm, fantasy game sound", 1,2 s, Variante 1; vorher „SFX Magic" von renatalmar (https://freesound.org/people/renatalmar/sounds/264981/).
- `sfx/spell_freeze.wav`: „Magic frost spell: a quick icy whoosh as water freezes solid with crisp crackling ice, ending in one clear glassy crystal clink, fantasy game spell sound", 1,0 s, Variante 3; vorher „iceSpell" von Relenzo2 (https://freesound.org/people/Relenzo2/sounds/160420/).
- `sfx/badge_earned.wav`: „Small reward sound: a short soft whoosh landing on a gentle, warm metallic ting, subtle and pleasant, low-mid tones, fantasy game achievement", 0,8 s, Variante 1; vorher teilten sich Bronze und Silber `spell_armor.wav`.
- `sfx/badge_gold.wav`: „Gold medal reward: a warm shiny chime with a few soft bells and a light jingle of gold coins, festive but gentle, low-mid tones, fantasy game reward sound", 1,0 s, Variante 2; vorher „Shiny Object of Value" von LilMati (https://freesound.org/people/LilMati/sounds/659677/).
- `sfx/badge_diamond.wav`: „Diamond reward: a soft magical whoosh rising into a crystalline glassy sparkle that settles on a clear warm shimmer, precious and special, fantasy game reward sound", 1,2 s, Variante 1; vorher „cartoon_wink_magic_sparkle" von MLaudio (https://freesound.org/people/MLaudio/sounds/511485/).
- `sfx/badge_revenge.wav`: „Cheeky triumphant sting: a quick punchy swoosh into one confident bright ding, playful and sassy, cartoon fantasy game reward", 0,8 s, Variante 3; vorher „Spacey 1up/Power up" von GameAudio (https://freesound.org/people/GameAudio/sounds/220173/).
- `sfx/badge_catch_up.wav`: „A rising swoosh that speeds up and lands on a bright warm tone just in time, playful just-made-it feeling, fantasy game reward sound", 1,0 s, Variante 2; vorher „simple power up" von Tissman (https://freesound.org/people/Tissman/sounds/455857/).
- `sfx/badge_comeback.wav`: „Short heroic comeback sting: a quick snare drum roll into a bold warm brass hit with a cymbal swell, triumphant and brief, fantasy game", 1,2 s, Variante 2; vorher „Fanfare - Rpg" von colorsCrimsonTears (https://freesound.org/people/colorsCrimsonTears/sounds/566203/).
- `sfx/badge_better.wav`: „Two or three gentle friendly rising marimba notes, soft and warm, encouraging, casual fantasy game reward sound", 0,8 s, Variante 3; vorher „Correct Answer / That's Right!" von Beetlemuse (https://freesound.org/people/Beetlemuse/sounds/528957/).
