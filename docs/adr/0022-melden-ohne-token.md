# ADR 0022 — Melden ohne Token: jeder Spieler meldet mit dem App-Schlüssel

Status: **angenommen** · Datum: 2026-10-08 · Ändert: ADR 0002 (Berechtigung) · Baut auf: ADR 0021

## Kontext

ADR 0002 hat Melden an ein Token je Person gebunden: `<label>.<mac>`, von Hand geprägt,
vom Spieler im Reiter „Melden“ eingetragen. Ohne Token gab es den Knopf nicht.

Im Testbetrieb ist jeder Spieler ein Testspieler. Ein Token je Kind zu prägen, zu
verschicken und eintippen zu lassen, kostet mehr, als der Name in der Meldung bringt —
und die meisten Meldungen gehen so gar nicht erst raus. Seit ADR 0021 trägt jede Fassung
ohnehin einen App-Schlüssel (`app-<n>`), mit dem der Endpunkt nebenan rechnet.

## Entscheidung

1. **Gemeldet wird mit dem App-Schlüssel aus `stats_key.cfg`.** Die Melde-URL steht dort in
   einer eigenen Sektion `[report]`, geschrieben von `tools/stats/write_key.sh` aus der
   Repo-Variablen `REPORT_URL`. Fehlen URL oder Schlüssel, ist Melden aus wie bisher.
2. **Kein Token-Eintrag mehr.** `ReportToken`, das Eingabefeld und „Vergessen“ fallen weg;
   ein früher eingetragenes Token in `user://codes.cfg` bleibt liegen und wird nicht
   gelesen.
3. **Debug-Fassungen melden nur mit `MONSTER_SLAM_REPORT_URL` und
   `MONSTER_SLAM_REPORT_KEY`**, wie der Statistik-Kanal — der Editor spielt im
   Entwicklungsprofil.
4. **Der Endpunkt bleibt unverändert.** `melden.php` nimmt jedes gültige Token an, also
   auch `app-*`. `statistik.php` nimmt weiterhin **nur** `app-*` an (ADR 0021).

## Folgen

- Jede Meldung trägt das Label `app-<n>`; wer gemeldet hat, ist nicht mehr zu sehen. Für
  die Korrektur eines Wortes zählt das Wort, nicht der Melder.
- Die Rate des Endpunkts gilt je Label, also für **alle Spieler zusammen** (Vorgabe 30 je
  Stunde, 200 je Tag). Wird es eng, `MS_RATE_HOUR`/`MS_RATE_DAY` in `ms-secret.php`
  anheben.
- Der Schlüssel ist aus der EXE lesbar (ADR 0021); wer ihn herausholt, kann melden. Die
  Grenzen des Endpunkts deckeln das, gesperrt wird über `revoked.txt` und eine neue
  Fassung mit `app-<n+1>`.
- Zurück zu Personen-Tokens ginge ohne Serveränderung: der Endpunkt kann beides. Die
  entfernte Client-Seite steht in der Git-Geschichte (`src/report/report_token.gd`).
