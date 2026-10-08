# Bestellung: Töne der Plaketten

Plaketten (Issue #63, `Badges`) halten den Kampf gut eine Sekunde an, kleiner als die
Meister-Feier. Welcher Ton spielt, sagt `Badges.sound_of`: Bronze und Silber kommen oft und
teilen sich `badge_earned` (die Datei von Eisenhaut, `spell_armor.wav`). Die besonderen heißen
wie ihre Palette, `badge_<palette>`. Probehören: `battle_theme_lab`, Reiter
„Feiern".

**Stand 2026-10-08:** alle sechs Töne sind eingebaut (Credits in `../CREDITS.md`), je der
Favorit unten; Revanche ist „Spacey 1up/Power up“ — „Brass Sting 2“ klang nach Fehler. Die
übrigen Kandidaten sind die Reserve.

**Herkunft, Format, Pegel:** wie in `SPELLS_BRIEF.md` (belegte Quelle, CC0 bevorzugt, Zeile in
`../CREDITS.md`, WAV oder MP3, ohne Stille am Anfang).

| Datei | Plakette | Länge | Charakter |
| ----- | -------- | ----- | --------- |
| `badge_gold.wav` | Gold (50 Treffer, 100 Wörter, 10 behalten) | 0,5–1 s | Warmer Medaillen-Glanz, Glöckchen oder Münzen; spürbar festlicher als Bronze/Silber. |
| `badge_diamond.wav` | Diamant (höchste Stufe) | 0,6–1,2 s | Kristallin, gläsern, ein kleiner aufsteigender Glitzer — die größte Plakette, aber kleiner als `task_mastered`. |
| `badge_revenge.wav` | Revanche | 0,4–0,8 s | Keck und triumphierend: ein frecher Akzent, Schwung mit „Ding". |
| `badge_catch_up.wav` | Aufholjagd | 0,5–1 s | Aufsteigender Swoosh, der in einem hellen Ton landet — gerade noch geschafft. |
| `badge_comeback.wav` | Comeback des Tages | 0,6–1,2 s | Heroisch und kurz: kleiner Wirbel mit Becken oder ein Bläser-Akzent. |
| `badge_better.wav` | Besser als sonst | 0,4–0,8 s | Zwei, drei freundliche Töne nach oben, sanft. |

Ein Tausch: Datei ersetzen, Zeile in `../CREDITS.md` anpassen, den Pegel in `Sfx.SOUNDS` am
Gehör neben `badge_earned` und `task_mastered` einstellen.

## Kandidaten (CC0, freesound.org, noch nicht angehört)

Lizenz und Dauer auf der Soundseite geprüft; der Charakter stammt aus Titel und Beschreibung.
Die erste Zeile je Plakette ist der Favorit. Vorschau ohne Anmeldung: der Link der Soundseite.
MP3/FLAC beachten (FLAC nach WAV wandeln, Godot 4.7 lädt kein FLAC).

| Plakette | Kandidat | Autor | Dauer | Format |
| -------- | -------- | ----- | ----- | ------ |
| Gold | [Shiny Object of Value - Rare Loot Find](https://freesound.org/people/LilMati/sounds/659677/) | LilMati | 1,30 s | WAV |
| Gold | [Coin Flip Shimmer](https://freesound.org/people/dpren/sounds/248143/) | dpren | 0,82 s | WAV |
| Gold | [victory chime](https://freesound.org/people/1bob/sounds/717771/) | 1bob | 0,81 s | WAV |
| Diamant | [cartoon_wink_magic_sparkle](https://freesound.org/people/MLaudio/sounds/511485/) | MLaudio | 1,27 s | WAV |
| Diamant | [ShiningRinging](https://freesound.org/people/NoisyRedFox/sounds/759840/) | NoisyRedFox | 0,65 s | OGG |
| Diamant | [Item Sparkle](https://freesound.org/people/Mr._Fritz_/sounds/545238/) | Mr._Fritz_ | 0,57 s | WAV |
| Revanche | [Spacey 1up/Power up](https://freesound.org/people/GameAudio/sounds/220173/) | GameAudio | 1,00 s | WAV |
| Revanche | [8-bit Correct Answer](https://freesound.org/people/JapanYoshiTheGamer/sounds/361263/) | JapanYoshiTheGamer | 0,81 s | WAV |
| Revanche | [Powerup/success](https://freesound.org/people/GabrielAraujo/sounds/242501/) | GabrielAraujo | 0,90 s | WAV |
| Aufholjagd | [simple power up](https://freesound.org/people/Tissman/sounds/455857/) | Tissman | 0,58 s | WAV |
| Aufholjagd | [Ascending pitch tone](https://freesound.org/people/Swedger/sounds/170693/) | Swedger | 0,71 s | MP3 |
| Aufholjagd | [Energy Bounce 1](https://freesound.org/people/magnuswaker/sounds/523088/) | magnuswaker | 1,21 s | WAV |
| Comeback | [Fanfare - Rpg](https://freesound.org/people/colorsCrimsonTears/sounds/566203/) | colorsCrimsonTears | 1,18 s | WAV |
| Comeback | [Win Spacey](https://freesound.org/people/GameAudio/sounds/220184/) | GameAudio | 0,99 s | WAV |
| Comeback | [Eb Orch Hit (Beethoven 5) stab 03](https://freesound.org/people/astro_denticle/sounds/822414/) | astro_denticle | 1,08 s | WAV |
| Besser | [successarpeggio](https://freesound.org/people/djm62/sounds/318968/) | djm62 | 0,38 s | FLAC |
| Besser | [Correct Answer / That's Right!](https://freesound.org/people/Beetlemuse/sounds/528957/) | Beetlemuse | 0,73 s | WAV |
| Besser | [Cmaj Victory Scale](https://freesound.org/people/ConManVD/sounds/742190/) | ConManVD | 1,07 s | MP3 |

`Fanfare - Rpg` stammt vom selben Autor wie `task_mastered.wav` und passt damit im Klang zur
Meister-Feier.
