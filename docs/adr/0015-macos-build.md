# ADR 0015 — macOS-Build: universal, ad hoc signiert, Update über den Browser

Status: **angenommen** · Datum: 2026-10-05 · ergänzt ADR 0001 (App-Kanal)

## Kontext

Bisher gab es nur die Windows-EXE. Godot exportiert auch nach macOS, und zwar von Windows
aus: Templates, Bundle und Signatur erzeugt es selbst. Drei Teile des Spiels setzen aber
Windows voraus: der Updater ersetzt die laufende Programmdatei per Umbenennen, der
Sprachmodell-Zusatz lädt `llama-server.exe`, und die Release-CI baut nur die EXE.

Einen Mac zum Testen gibt es nicht ständig, ein Apple-Developer-Konto gibt es nicht.

## Entscheidung

1. **Ein Preset „macOS“, universal (Intel und Apple Silicon), ad hoc signiert, nicht
   notarisiert** (`codesign/codesign=1`, Godots eingebauter Signierer). Apple Silicon
   startet nur signierte Programme, und ad hoc reicht dafür. Gatekeeper fragt beim ersten
   Start trotzdem nach. Erklärt wird das im Handbuch, weil Notarisierung ein bezahltes
   Konto braucht. Ausgeliefert wird `MonsterSlam-<version>-macos.zip` mit der `.app`.

2. **ETC2/ASTC wird mitimportiert** (`rendering/textures/vram_compression/import_etc2_astc`).
   Ohne diese Einstellung verweigert Godot den Export für arm64. Die `.import`-Dateien tragen
   dafür einen zweiten Pfad. Die Windows-EXE enthält weiter nur S3TC, ihre Größe bleibt.

3. **Gebaut wird auf dem Windows-Runner mit**, im selben Job wie die EXE. Ein Mac-Runner
   brächte nichts, solange nicht notarisiert wird. `latest.json` bekommt einen zweiten
   Block `macos-universal` mit eigener Prüfsumme und Signatur (`make_latest_json.sh` nimmt
   Plattform, Datei und URL in Dreiergruppen). Ältere Clients lesen nur `windows-x86_64`.

4. **Auf dem Mac ersetzt sich das Spiel nicht selbst.** `UpdateService.can_self_install()`
   ist nur unter Windows wahr. Sonst öffnet der Dialog die ZIP im Browser („Im Browser
   laden“) und sagt vorher, was danach zu tun ist. Eine im Bundle ausgetauschte
   Programmdatei bräche die Signatur. Ein Tausch des ganzen Bundles wäre machbar, ist aber
   ohne Mac nicht prüfbar.

5. **Kein Sprachmodell auf dem Mac**, solange der Zusatz experimentell ist.
   `ModelService.refresh()` fragt außerhalb von Windows gar nicht erst nach. Das Manifest
   nennt ein Windows-Programm, ein Mac lüde es sonst und könnte es nicht starten. Der
   Bosskampf bleibt dort bei Stufe 0 (ADR 0004). Für später gilt: llama.cpp liefert macOS
   nur als `.tar.gz` mit Symlink-Ketten für die `.dylib`s, und Godot liest von sich aus
   nur ZIP.

## Folgen

- Vor einem Release muss der Mac-Build einmal auf einem echten Mac gestartet werden; die
  CI prüft nur, dass er entsteht.
- Nach jedem Update fragt Gatekeeper erneut, weil die ZIP aus dem Browser in Quarantäne
  kommt.
- `user://` liegt auf dem Mac unter `~/Library/Application Support/Godot/app_userdata/Monster Slam/`.
