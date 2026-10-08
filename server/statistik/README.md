# Statistik-Endpunkt deployen

Der Weg der Spieldaten: die Spiel-EXE schickt je Profil einen Snapshot des Spielstands und
die bereinigte Spur hierher. Entscheidung und Begründung:
`docs/adr/0021-statistik-rueckkanal.md`.

Er sitzt **neben** dem Melde-Endpunkt und teilt sich mit ihm Geheimnis, Token-Format und
Sperrliste. Erst `server/melden/README.md` durchgehen (PHP-Fassung, `ms-secret.php` über
dem Docroot, `Authorization`-Header unter CGI/FastCGI), dann das hier.

Braucht zusätzlich zur Melde-Ausstattung **zlib** (`gzdecode`, `gzencode`), das in jeder
üblichen PHP-Installation enthalten ist.

## Was wohin gehört

```
<über dem Docroot>/
  ms-secret.php          ← wie beim Melden; optional MS_STATS_DIR und die Grenzen unten
  ms-reports/
    revoked.txt          ← gemeinsame Sperrliste: hier auch app-1, app-2, …
  ms-stats/              ← wird angelegt (Modus 0700/0600)
    <stats_id>/
      snapshot-YYYY-MM-DD.json.gz
      trace-YYYY-MM.jsonl.gz
      trace-cursor.json
    _rate/               ← Tageszähler je Profil und je IP-HMAC

<Docroot>/melden/token.php        ← schon da, wird mitbenutzt
<Docroot>/statistik/statistik.php ← der Endpunkt
```

`ms-stats/` sammelt Lexem-Ids und Spielverläufe und darf über keine URL abrufbar sein, aus
demselben Grund wie `ms-reports/`.

## Schritte

1. **`statistik.php`** nach `<Docroot>/statistik/` hochladen. Der Endpunkt bindet
   `../melden/token.php` und `../../ms-secret.php` ein, also muss der Melde-Endpunkt in
   `<Docroot>/melden/` liegen.

2. **Optional in `ms-secret.php`**, mit diesen Vorgaben:

   ```php
   // const MS_STATS_DIR = __DIR__ . '/ms-stats';
   // const MS_STATS_RATE_ID = 60;          // Sendungen je Profil und Tag
   // const MS_STATS_RATE_IP = 400;         // Sendungen je IP und Tag
   // const MS_STATS_IDS = 1000;            // Profile insgesamt
   // const MS_STATS_TRACE_BYTES = 20971520; // gepackte Spur je Profil und Monat
   ```

3. **App-Schlüssel prägen**, mit demselben Geheimnis wie die Melde-Token:

   ```bash
   MONSTER_SLAM_REPORT_SECRET=<hex> python3 tools/report/mint_token.py app-1
   ```

4. **In GitHub hinterlegen**: Secret `STATS_APP_KEY` = der Schlüssel aus Schritt 3,
   Repo-Variable `STATS_URL` = `https://<domain>/statistik/statistik.php`, für Melden
   zusätzlich `REPORT_URL` = `https://<domain>/melden/melden.php` (ADR 0022). Der
   Release-Workflow schreibt daraus `stats_key.cfg` (`tools/stats/write_key.sh`), und die
   nächste Fassung sendet. Für einen lokalen `./build.sh` dasselbe Skript einmal von Hand
   aufrufen; die Datei ist gitignored.

5. **Zugriffslogs**: Strato schreibt IP-Adressen in die Logs des Webservers. Im
   Kundenbereich die Anonymisierung der Logs einschalten, wo das Paket sie anbietet.

## Örtlich prüfen

```bash
tools/report/php.sh server/statistik/test_endpoint.php
python3 tools/stats/report.py --self-test
```

Der Prüfstand spielt durch:
- **Zugang**: App-Schlüssel gilt, ein Personen-Token wird abgewiesen, gesperrter Schlüssel.
- **Snapshot**: gepackt und ungepackt, am selben Tag überschrieben.
- **Spur**: Stücke, Wiederholung, zurückgesetzter Cursor, verbotene Felder.
- **Grenzen**: gzip-Grenzen (auch eine Zip-Bombe), Tages- und IP-Grenzen, Zahl der
  Profile, Kontingent der Spur.
- **Ablage**: über keine URL abrufbar.

**Ganz durch, mit dem echten Spiel**:
1. Im Container `php -S 0.0.0.0:8080` vor einem Docroot mit `melden/token.php` und
   `statistik/statistik.php` starten (`MS_REQUIRE_HTTPS = false`). Unter WSL mit podman
   `--network host` verwenden, die Portweiterleitung reicht dort nicht.
2. Godot im Debug-Build starten mit
   `MONSTER_SLAM_STATS_URL=http://127.0.0.1:8080/statistik/statistik.php` und
   `MONSTER_SLAM_STATS_KEY=<app-Schlüssel>`. Unter WSL zusätzlich
   `WSLENV=MONSTER_SLAM_STATS_URL:MONSTER_SLAM_STATS_KEY`, sonst kommen die Variablen in der
   Windows-EXE nicht an. `127.0.0.1` statt `localhost` angeben, weil Windows sonst `::1`
   versucht.

Ein echter Lauf schreibt in das aktive Profil (`CONVENTIONS.md`); also mit einem eigenen,
nicht mit `zz-` beginnenden Wegwerfprofil spielen und es danach entfernen.

## Von Hand durchspielen

```bash
URL=https://<domain>/statistik/statistik.php
KEY=app-1.XXXX-XXXX-XXXX-XXXX
ID=0123456789abcdef0123456789abcdef

curl -s -X POST "$URL" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d "{\"action\":\"snapshot\",\"key_version\":1,\"stats_id\":\"$ID\",\"format\":1}"
# -> {"ok":true,"stored":true}

# Gepackt, wie die App sendet
echo "{\"action\":\"snapshot\",\"key_version\":1,\"stats_id\":\"$ID\",\"format\":1}" | gzip \
  | curl -s -X POST "$URL" -H "Authorization: Bearer $KEY" -H 'Content-Encoding: gzip' \
      --data-binary @-
# -> {"ok":true,"stored":true}

# Personen-Token aus dem Melde-Kanal
curl -s -X POST "$URL" -H "Authorization: Bearer mia.XXXX-XXXX-XXXX-XXXX" \
  -d "{\"action\":\"snapshot\",\"key_version\":1,\"stats_id\":\"$ID\",\"format\":1}"
# -> {"ok":false,"error":"bad_token"}

# Die Ablage darf nicht abrufbar sein
curl -s -o /dev/null -w '%{http_code}\n' https://<domain>/ms-stats/$ID/trace-cursor.json
# -> 403 oder 404, niemals 200
```

Den Test-Snapshot danach auf dem Server löschen: `ms-stats/0123456789abcdef0123456789abcdef/`.

## Abholen und auswerten

```bash
STATS_SFTP=<benutzer>@<sftp-host> tools/stats/fetch.sh   # -> stats-data/ms-stats/
python3 tools/stats/report.py                            # -> stats-data/report.html
```

Die Seite löst Lexem-Ids über das Submodule zu Wörtern auf und bleibt deshalb auf dem
Rechner.

## Daten eines Profils entfernen

Wer seine Daten gelöscht haben will, nennt die `stats_id`. Sie steht in `settings.cfg` im
Benutzerordner des Spiels, Sektion `[stats_id]`. Dann wird das Verzeichnis
`ms-stats/<stats_id>/` auf dem Server gelöscht.
