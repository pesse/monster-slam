# ADR 0021 — Statistik-Rückkanal: Spieldaten der Testspieler

Status: **angenommen** · Datum: 2026-10-07

## Kontext

Balancing, Schwierigkeit und die Frage, welche Wörter schwer sind, brauchen echte Daten
der Testspieler. Bisher bleibt alles auf deren Rechnern: das Sitzungsjournal, Gold, XP,
Fähigkeiten, Lernstand je Aufgabe (`user://progress/`) und die Spur
(`user://logs/*_trace.jsonl`).

Der Melde-Kanal (ADR 0002) zeigt schon, wie ein Weg nach oben aussehen kann: PHP auf dem
vorhandenen Strato-Hosting, keine Datenbank, Ablage über dem Docroot, Token im Format von
`server/melden/token.php`. ADR 0002 schließt Fortschrittsdaten für **diesen** Kanal aus,
weil eine Meldung eine Person nennt (Label).

Zwei Dinge sind beim Melden anders und gelten hier nicht:

- **Ein Token je Person ist eine Hürde.** Statistik soll von jedem Tester kommen, ohne
  dass jemand etwas abtippt.
- **Die Spur ist das Wertvollste.** Zögern, Fehlerarten und der Verlauf von Spawns und
  Leaks stehen nur dort. Sie enthält aber getippte Kindertexte, Lemmata und den
  Profilnamen.

## Entscheidung

1. **Ein eigener Endpunkt neben dem Melde-Endpunkt**, `server/statistik/statistik.php`.
   Er nutzt dasselbe `ms-secret.php` und dasselbe `token.php`. Die Ablage liegt in
   `ms-stats/` über dem Docroot: je Profil ein Verzeichnis, darin ein Snapshot je Tag
   (`snapshot-YYYY-MM-DD.json.gz`, am selben Tag überschrieben) und die Spur je Monat
   (`trace-YYYY-MM.jsonl.gz`, angehängte gzip-Glieder).

2. **Ein App-Schlüssel statt eines Personen-Tokens.** Das ist ein Token mit Label `app-<n>`,
   geprägt mit `tools/report/mint_token.py`. Der Export setzt ihn als `stats_key.cfg` in
   die EXE: aus dem GitHub-Secret `STATS_APP_KEY` und der Variablen `STATS_URL`, über
   `tools/stats/write_key.sh`. Im öffentlichen Repo steht er nicht.
   - Er ist aus der EXE herauslesbar. Damit ist er **kein Geheimnis**, sondern ein
     Spamschutz.
   - Gesperrt wird er wie ein Melde-Token über `revoked.txt`. Danach baut man eine neue
     Fassung mit `app-<n+1>`.
   - Was die Ablage schützt, sind die Grenzen des Endpunkts: gepackt 256 KB und entpackt
     2 MB je Sendung, 60 Sendungen je Profil und Tag, 400 je IP und Tag (gezählt wird ein
     HMAC der IP), höchstens 1000 Profile und 20 MB Spur je Profil und Monat.
   - Der Endpunkt nimmt **nur** `app-*` an. Mit einem Personen-Token lägen Statistik und
     Name doch wieder zusammen.

3. **Zuordnung über eine zufällige `stats_id` je Profil** (128 Bit,
   `UserSettings.stats_id`). Die player_id ist der Name des Kindes und taugt dafür nicht.
   Die `stats_id` bleibt beim Umbenennen stehen.

4. **Snapshot statt Deltas.** Gesendet wird der ganze Stand eines Profils, frisch aus den
   Dateien unter `user://progress/`. Jede Datei hat eine Allowlist (`StatsUploader.SNAPSHOT_FILES`).
   `player_id` fehlt überall, Abgeleitetes wie Level und Punkte ebenfalls.
   - Das ist idempotent und braucht weder Zähler noch Warteschlange, entsprechend der
     Regel „nur Ursprungswerte, alles andere wird gerechnet“.
   - Der Lernstand geht **je learnable_id**, also mit Lexem-Ids. Das war beim Melde-Kanal
     schon so: Ids liegen über dem Docroot und werden nur lokal mit dem Submodule zu
     Wörtern aufgelöst.

5. **Die Spur geht bereinigt hinaus, nie roh.** `TraceSanitizer` liest die Rohspur und
   lässt je Ereignistyp nur eingetragene Felder durch (`KEEP`, eine Allowlist).
   - Getipptes wird zu Zahlen: Länge, Wortzahl und der Editierabstand zur nächsten
     akzeptierten Lösung der Monster auf dem Feld (`dist`, bei Fehlversuchen dazu `near`).
   - `prompt`, `answers`, `canonical`, `text`, die Boss-Erklärung und der Profilname
     fallen weg.
   - Ein neues Spurereignis bleibt draußen, bis es eingetragen ist. Das erzwingt
     `tests/trace_sanitizer_test.gd`.
   - Der Endpunkt entfernt dieselben Felder ein zweites Mal (`MS_STATS_FORBIDDEN`). Den
     Auswahlgrund (`why` in der Rohspur) sendet die App deshalb als `pick`.
   - Ist die Spur abgeschaltet, geht keine Spur hinaus; der Snapshot geht weiter.

6. **Die Spur geht in Stücken mit Cursor, und der Stand gehört dem Server.**
   - Ein Stück trägt `from`, also den Cursor der App, und `to`, die Marke `[at, ms]` der
     letzten Zeile. Der Server antwortet mit `have`, und die App setzt ihren Cursor darauf.
   - Ein Stück, das vor `have` beginnt (verlorene Antwort, zurückgesetzter Cursor), schreibt
     nichts und liefert nur `have`.
   - `[at, ms]` ist nicht eindeutig, weil mehrere Zeilen in derselben Millisekunde
     entstehen. Ein Stück endet deshalb nie mitten in einer Gruppe gleicher Marken
     (`StatsUploader.chunk_end`).

7. **Wann gesendet wird.** Am Laufende und am Ende eines Bosskampfs für das aktive Profil.
   Beim Start für jedes Profil, dessen Dateien jünger sind als der letzte angenommene
   Snapshot. Gelesen, bereinigt und gepackt wird auf einem Arbeitsthread. Netzfehler
   bleiben still, der nächste Anlass versucht es erneut.

8. **Informieren statt fragen, für die Testphase.** Beim ersten Start erscheint einmal je
   Rechner ein Hinweis im Startmenü (`ConfirmDialog.inform`); vorher geht nichts hinaus.
   Das Handbuch hat ein Kapitel dazu (`21-spieldaten.md`). Ein Opt-in-Schalter kann
   später kommen, ohne am Format etwas zu ändern.

9. **Nie gesendet wird:** aus Debug-Fassungen (Editor, Tests; ausgenommen mit
   `MONSTER_SLAM_STATS_URL` und `MONSTER_SLAM_STATS_KEY`), von `zz-`-Profilen und aus
   einer Fassung ohne `stats_key.cfg`.

10. **Ausgewertet wird lokal.** `tools/stats/fetch.sh` holt die Ablage per SFTP nach
    `stats-data/` (gitignored), `tools/stats/report.py` baut daraus eine HTML-Seite. Die
    Seite enthält aufgelöste Wörter und verlässt den Rechner deshalb nicht.

## Bewusst nicht

- **Keine Rohspur, auch nicht „nur für Tester“.** Kinder tippen gelegentlich Namen,
  Beleidigungen oder ganze Sätze. Was sich aus getipptem Text lernen lässt (verschrieben
  oder nicht gewusst, wie lang, wie schnell), steht schon in den abgeleiteten Zahlen.
- **Keine Datenbank, kein Dashboard auf dem Server.** Die Ablage ist über keine URL
  erreichbar (wie beim Melde-Kanal), und ein Login auf dem Webhost wäre eine weitere
  Angriffsfläche für eine Handvoll Tester.
- **Kein Löschen auf Zuruf über die App.** Wer seine Daten entfernt haben will, nennt die
  `stats_id` (steht in `settings.cfg`), und das Verzeichnis wird von Hand gelöscht. Bei der
  Größe der Testgruppe ist das angemessen.

## Folgen

- `CONVENTIONS.md`: Die Spur-Regel lautet jetzt „die **Rohspur** verlässt den Rechner
  nicht“. `STATS_APP_KEY` steht unter „Geheimnisse“.
- Ein neues Feld in einer Datei unter `user://progress/` oder in der Spur geht erst hinaus,
  wenn es in `SNAPSHOT_FILES` bzw. `TraceSanitizer.KEEP` eingetragen ist.
- Strato schreibt IPs in seine Zugriffslogs. Wo der Kundenbereich es anbietet, wird die
  Anonymisierung der Logs eingeschaltet (`server/statistik/README.md`).
- Rotiert das HMAC-Geheimnis (neue `MS_KEY_VERSION`), senden ältere Fassungen nicht mehr
  (`stale_key`), bis sie aktualisiert sind.
