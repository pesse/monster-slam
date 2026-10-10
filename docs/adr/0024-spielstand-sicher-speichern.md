# ADR 0024 — Spielstand sicher speichern

Status: **angenommen** · Datum: 2026-10-10 · Berührt: ADR 0020 (Rasten), ADR 0021 (Statistik)

## Kontext

Ein Spieler fiel von etwa Level 26 auf Level 1, mit −17 Skillpunkten. Die Ursache stand
im Code:

- `PlayerLevel` schrieb `<id>_level.json` **bei jedem Kill** mit `FileAccess.WRITE`, also
  erst leeren, dann schreiben. Ein Absturz oder Stromausfall dazwischen ließ eine leere
  oder mit NUL gefüllte Datei zurück.
- Der Loader behandelte „unlesbar“ wie „neues Profil“: 0 XP. Der nächste Kill schrieb das
  endgültig fest. `_skills.json` wurde selten geschrieben und blieb heil, daher −17.
- Dieselbe Schwäche hatten Geldbörse, Inventar, Lernstand, Lernzeiten, Abzeichen, Boss-Siege
  und Testlisten. Nur `RunSave` schrieb über eine `.tmp`.
- Eine unlesbare `settings.cfg` setzte die Profilliste still zurück.
- Der Statistik-Kanal las die Live-Dateien auf einem Arbeitsthread; ein halber Stand
  konnte den vollständigen des Tages auf dem Server ersetzen.
- Ein Abbruch mitten in der Welle speicherte Teilstände, obwohl der Dialog sagte, die
  Welle zähle nicht.

Ein verlorener Spielstand kann die Arbeit von Jahren kosten. Ziel: er geht nie still
verloren. Beschädigung wird erkannt, nie überschrieben und aus einer stimmigen Sicherung
des ganzen Profils zurückgeholt.

## Entscheidung

1. **Ein Schreibweg für alles (`SaveStore`).** Jede Profildatei und die `settings.cfg`
   werden in eine `.tmp` geschrieben, zurückgelesen und erst dann umbenannt. Jede Datei
   trägt eine SHA-256-Prüfsumme in derselben Datei, als erstes Feld:
   `{"_save":{"format":1,"sha256":"…"},…Daten…}`. Ältere Fassungen lesen die Datei wie
   bisher und übersehen das Feld. Die `settings.cfg` bekommt eine Kommentarzeile
   `; sha256=…`. Lesen kennt vier Ergebnisse: OK, fehlt, beschädigt, neuer. „Beschädigt“
   ist nie „neu“, und über eine beschädigte oder neuere Datei wird nie geschrieben.
2. **Gespeichert wird an der Wellengrenze (`SaveCoordinator`).** Die Speicher melden nur
   noch „geändert“. Im Kampf hält der WaveRunner das Speichern an (`hold`); geschrieben wird
   am Wellenende, nach der Schatzkiste, nach dem Bosskampf, beim Rasten. In Menüs am Ende
   des Frames. Fenster zu, Absturz oder Abbruch mitten in der Welle: die Welle verfällt.
   Beim Abbruch werden die Speicher auf den letzten Stand zurückgeladen
   (`discard_uncommitted`). Nur die Lernzeiten behalten die Antworten, sie zählen echtes
   Lernen.
3. **Ein Commit ist alles oder nichts.** Alle Dateien eines Profils werden gestagt, dann
   folgt ein Journal (`<id>.commit.json`), dann die Umbenennungen, dann wird das Journal
   gelöscht. Ein abgebrochener Commit wird beim nächsten Öffnen aus dem Journal vollendet.
   Eine `.tmp` ohne Journal ist ein nie vollendetes Schreiben und fällt weg. Hat Windows
   beim Umbenennen schon das Ziel gelöscht, gilt die `.tmp`.
4. **Sperre gegen sinkende Werte (`SaveGuard`).** Erfahrung, verdientes Gold, geöffnete
   Kisten, Zahl der Lernstände, Lernzeiten und Boss-Siege wachsen nur. Sinkt einer gegenüber
   der Datei auf der Platte, wird der **ganze** Commit verweigert und gemeldet. Erlaubt ist
   das Sinken nur ausdrücklich: Fortschritt zurücksetzen, leer weiterspielen, Import.
5. **Sicherungen als Generationen des ganzen Profils (`Backups`).** Nach jedem Commit
   werden alle Dateien des Profils mit einer Kopie der `settings.cfg` in
   `user://backups/<id>/<Zeitstempel>/` abgelegt. Das `manifest.json` mit den Prüfsummen
   wird zuletzt geschrieben. Ohne gültiges Manifest zählt eine Generation nicht.
   Zurückgespielt wird immer eine ganze Generation, nie Datei für Datei. Sonst kämen
   Erfahrung und Skills aus verschiedenen Ständen zusammen, und das ergibt wieder negative
   Punkte. Aufbewahrt wird gestaffelt: die 3 neuesten, die neueste je Tag der letzten
   7 Tage und je Woche der letzten 8 Wochen. Ein still falscher Wert soll nicht alle
   Sicherungen erreicht haben, bevor ihn jemand bemerkt. `_runs` gehört nicht dazu: ein
   begonnener Lauf ist mit dem Fortsetzen verbraucht (ADR 0020).
6. **Beim Öffnen eines Profils wird geprüft.** Eine beschädigte Datei oder eine fehlende,
   die die neueste Sicherung hat, führt dazu, dass der ganze bisherige Stand nach
   `user://quarantine/<id>/<Zeitstempel>/` wandert (mit `incident.json`) und die neueste
   gültige Generation zurückgespielt wird; der Spieler bekommt einen Hinweis. Ohne
   Sicherung ist das Profil **gesperrt**: es speichert nicht, bis der Spieler eine Datei
   lädt oder für die beschädigten Teile leer weitermacht. Die Quarantäne wird nie
   automatisch gelöscht.
7. **`settings.cfg`:** Ist die Datei beschädigt, kommt sie in die Quarantäne, und die
   neueste gesicherte Kopie wird geladen. Gibt es keine, wird die Profilliste aus den
   Spielständen gebaut. Fehlt die Datei, obwohl es Spielstände gibt, ist das kein
   Erststart.
8. **Der Statistik-Kanal liest nur fertige Sicherungen.** `StatsUploader` nimmt die
   neueste gültige Generation (Prüfsummen geprüft). Ohne eine solche sendet er keinen
   Snapshot. Speichern wartet nie auf ihn, er schreibt nie unter `progress/`.
   Die Spur bekommt `save_refused`, `save_restored` und `save_damaged`; hinaus gehen davon
   nur Endungen, Zeitpunkte und Werte (`TraceSanitizer.KEEP`). So fällt ein Vorfall wie
   dieser bei der Auswertung auf, ohne dass der Spieler ihn meldet.
9. **Spielstand als Datei.** „Sichern…“ und „Laden…“ in den Einstellungen schreiben bzw.
   lesen ein Zip (`SaveArchive`) über den Dateidialog des Systems. Beim Laden werden nur
   bekannte Einträge gelesen; es gibt eine Größengrenze, eine Prüfsumme je Datei, eine
   Vorschau und eine Rückfrage. Geladen wird nur ins aktive Profil, vorher wird gesichert.
10. **Plausibilität beim Öffnen:** mehr Skillpunkte ausgegeben als verdient wird gemeldet.
    So wäre der Vorfall sofort sichtbar geworden.

## Bewusst nicht

- **Speichern beim Schließen.** Ein Teilstand mitten in der Welle ist genau das, was der
  Dialog verspricht nicht zu tun, und `NOTIFICATION_WM_CLOSE_REQUEST` kommt bei einem
  Absturz ohnehin nicht.
- **Eine einzige Spielstand-Datei.** Getrennte Dateien bleiben; die Generation hält sie
  zusammen. Ein Umbau aller Loader brächte kein Mehr an Sicherheit.
- **Prüfsumme in einer Nebendatei.** Zwei Dateien können auseinanderlaufen; in der Hülle
  gehören Daten und Summe zusammen.
- **fsync.** Godot bietet es nicht an. `flush` und das Zurücklesen fangen das Meiste;
  gegen den Rest helfen die Generationen.
- **Wiederherstellung aus dem Server-Snapshot im Spiel.** Das ist ein Entwicklerwerkzeug
  (`tools/stats/rebuild_save.py`); der Snapshot trägt nicht alle Dateien.

## Folgen

- Eine abgebrochene Welle kostet jetzt auch ihre Erfahrung. Das Handbuch sagt es
  (Kapitel 7, 9, 23).
- Jede neue Profildatei braucht einen Eintrag in `SaveCoordinator.PROFILE_SUFFIXES` und,
  wenn sie nur wachsen darf, in `SaveGuard.MONOTONIC`. Ein neuer Speicher meldet sich mit
  `SaveCoordinator.register` an und liefert `save_path`, `save_suffix`, `save_payload` und
  `reload`.
- Ein Sicherungsordner wiegt so viel wie ein Spielstand; höchstens 18 je Profil.
