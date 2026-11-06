# ADR 0030 — Linux-Build: eine Datei, Selbst-Update, Sprachmodell aus `.tar.gz`

Status: **angenommen** · Datum: 2026-11-06 · ergänzt ADR 0001 (App-Kanal) und ADR 0015

## Kontext

Nach Windows und macOS (ADR 0015) soll das Spiel auch unter Linux laufen. Godot exportiert
nach Linux auch von Windows aus. Fünf Stellen gingen bisher nur von Windows oder macOS aus:
der Plattformschlüssel des Updaters, das Selbstersetzen, der Sprachmodell-Zusatz (ein
Windows-Programm im Manifest), der Schlüsselspeicher und die Systemskalierung.

## Entscheidung

1. **Ein Preset „Linux“, x86_64, PCK eingebettet.** Ausgeliefert wird eine einzelne Datei
   `MonsterSlam-<version>-linux.x86_64`. Exportiert wird wie macOS auf dem Windows-Runner.
   `latest.json` bekommt den Block `linux-x86_64`. Die Texturen bleiben S3TC/BPTC wie
   unter Windows.

2. **Unter Linux ersetzt sich das Spiel selbst**, wie unter Windows. Eine laufende Datei
   darf dort umbenannt und ersetzt werden. Ein Download kommt ohne Ausführungsrecht an,
   deshalb setzt `UpdateService._swap` danach `rwxr-xr-x`. Liegt das Spiel in einem
   Ordner ohne Schreibrecht, scheitert das Umbenennen. Die Meldung nennt dann den Pfad der
   neuen Fassung.

3. **Das Modell-Manifest bekommt `platforms`.** `parts` bleibt der Windows-Block, den
   auch ältere Fassungen lesen. Unter `platforms.<schlüssel>` steht je weitere Plattform
   eine eigene Teilliste. Wer keinen Block hat (macOS), bekommt nichts angeboten.
   `tools/model/make_manifest.py --program-linux` misst die Gewichte nur einmal.

4. **llama.cpp für Linux kommt als `.tar.gz`, Godot liest nur ZIP.** `TarGz` entpackt
   im Speicher (gzip über `decompress_dynamic`, tar von Hand). Ein Archiv von gut 40 MB
   ist dafür klein genug. Die Bibliotheken liegen dort als Link-Ketten (`libllama.so ->
   .so.0 -> .so.0.4.1`), gesucht werden sie unter dem `.so.0`-Namen. Godot legt keine
   Links an, deshalb wird jeder Link zu einer Kopie seines Ziels. Das Programm trägt
   `RUNPATH $ORIGIN` und findet seine Bibliotheken im eigenen Ordner. Es braucht
   OpenSSL 3, also etwa Ubuntu 22.04 oder neuer. Weiterhin gilt: aus dem Archiv kommt nur
   der Dateiname, nie der Pfad (ADR 0004).

5. **Schlüsselspeicher über `secret-tool`** (libsecret, Secret Service: GNOME-Schlüsselbund,
   KWallet). Das Geheimnis geht über die Standardeingabe, beim Aufrufer bleibt nur eine
   Marke wie unter macOS. Fehlt `secret-tool`, gilt Linux als nicht unterstützt, und es
   wird kein Schlüssel gespeichert. Einen Klartext-Notbehelf gibt es weiter nicht.

6. **Skalierung:** Unter Wayland liefert `screen_get_scale` den Faktor des Systems, unter
   X11 gilt wie unter Windows die DPI ÷ 96.

## Folgen

- Vor einem Release muss die Linux-Datei einmal tatsächlich starten; WSLg reicht dafür.
  Die CI prüft nur, dass die Datei entsteht.
- Nach dem ersten Download muss die Datei ausführbar gemacht werden. Das Handbuch erklärt
  es, spätere Updates erledigen es selbst.
- `user://` liegt unter Linux in `~/.local/share/godot/app_userdata/Monster Slam/`.
- Ein Linux-Modell gibt es erst, wenn `tools/model/model.json` mit dem `platforms`-Block
  im Release-Kanal liegt.
