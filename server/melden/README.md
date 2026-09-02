# Melde-Endpunkt deployen

Der Rückkanal für „Melden": die Spiel-EXE schickt eine Meldung hierher, das Skript
prüft das Melde-Token und hängt eine Zeile an eine JSON-Lines-Datei.
Entscheidung und Begründung: `docs/adr/0002-melde-rueckkanal.md`.

Braucht PHP 7.1 oder neuer (getestet gegen 8.x) und sonst nichts — keine Datenbank,
keine Erweiterung außer den PHP-Standardfunktionen.

## Was wohin gehört

```
<über dem Docroot>/
  ms-secret.php          ← Geheimnis + Ablagepfad. NIE in ein Repo, nie in den Docroot.
  ms-reports/
    reports.jsonl        ← die Meldungen (wird angelegt, Modus 0600)
    revoked.txt          ← gesperrte Labels, eines je Zeile (optional)

<Docroot>/melden/
  melden.php             ← der Endpunkt
  token.php              ← Token-Format, von melden.php eingebunden
```

`verify_token.php` ist ein Kommandozeilen-Werkzeug und gehört **nicht** in den Docroot.

Die beiden `ms-*`-Namen liegen absichtlich **über** dem Webverzeichnis: `reports.jsonl`
sammelt Vokabular aus geschütztem Lehrbuchmaterial und darf über keine URL abrufbar sein.
Ein Konfigurationsfehler serviert PHP-Quelltext, ein Verzeichnis außerhalb des Docroots
serviert er nicht.

Findet dein Paket keinen beschreibbaren Ort über dem Docroot, ist der Rückfall ein
Unterverzeichnis mit einer `.htaccess`:

```apache
Require all denied
```

Das ist die schlechtere Variante — sie schützt nur, solange Apache die `.htaccess` liest.

## Schritte

1. **Geheimnis erzeugen** (auf deinem Rechner, nicht auf dem Server):

   ```bash
   python3 tools/report/mint_token.py --new-secret
   ```

2. **`ms-secret.php` anlegen**, eine Ebene über dem Docroot:

   ```php
   <?php
   const MS_SECRET_HEX  = '…64 Hex-Zeichen aus Schritt 1…';
   const MS_KEY_VERSION = 1;
   const MS_DATA_DIR    = __DIR__ . '/ms-reports';
   // Optional, mit diesen Vorgaben:
   // const MS_RATE_HOUR = 30;
   // const MS_RATE_DAY  = 200;
   // const MS_REQUIRE_HTTPS = true;   // nur für einen lokalen Test auf false
   ```

3. **`melden.php` und `token.php`** in `<Docroot>/melden/` hochladen. Liegt die
   Konfiguration nicht genau eine Ebene über dem Docroot, die Konstante `MS_CONFIG`
   am Kopf von `melden.php` anpassen — sie ist der einzige Pfad, der zu setzen ist.

4. **Gegenprobe des Formats**:

   ```bash
   tools/report/php.sh server/melden/verify_token.php --self-test
   python3 tools/report/mint_token.py --self-test
   ```

   Beide rechnen dieselben Vektoren. Weichen sie ab, ist das Format auseinandergelaufen
   und kein Token stimmt mehr — dann nicht weitermachen.

5. **Token prägen und mitteilen**:

   ```bash
   MONSTER_SLAM_REPORT_SECRET=<hex> python3 tools/report/mint_token.py mia leo
   ```

6. **Die URL in die App eintragen**: `ENDPOINT` in `src/report/report_service.gd`.
   Solange sie leer ist, ist der Rückkanal aus und „Melden" erscheint nirgends.

## Örtlich prüfen, ohne PHP zu installieren

PHP kommt aus dem Container in `.devcontainer/`, nicht vom Rechner. Der Wrapper
`tools/report/php.sh` nimmt, was da ist: eine vorhandene PHP-Installation (so läuft es in
der CI), sonst podman oder docker mit dem Abbild aus dem Dockerfile — beim ersten Aufruf
wird es gebaut, danach kommt es aus dem Cache.

```bash
tools/report/php.sh server/melden/test_endpoint.php
```

Der Prüfstand baut die Ablage aus diesem Dokument in einem Wegwerf-Verzeichnis nach,
startet `php -S` davor und spielt die Fälle durch: Token (gültig, verfälscht, abgetippt,
fehlend), Meldung annehmen, Doppelmeldung, Abweisungen, gesperrtes Label, Rate-Limit,
Rotation, HTTPS-Zwang, und dass die Meldungsdatei über keine URL abrufbar ist. Er braucht
kein Netz und kein Geheimnis; die CI fährt ihn bei jeder Änderung an `server/**`.

Wer den ganzen Container will (VS Code: „Reopen in Container"): dort liegen PHP und
Python nebeneinander, damit beide Hälften des Token-Formats geprüft werden können. Der
Container ist die **PHP-Werkbank**, nicht die Entwicklungsumgebung des Spiels — Godot läuft
als Windows-Binary über `tools/godot.sh` und ist darin nicht enthalten.

**Ganz durch, mit dem echten Spiel**: im Container `php -S 0.0.0.0:8080 -t <docroot>`
starten (Port 8080 ist in `devcontainer.json` weitergegeben), in der Konfiguration
`MS_REQUIRE_HTTPS = false` setzen und Godot im Debug-Build mit
`MONSTER_SLAM_REPORT_URL=http://localhost:8080/melden/melden.php` starten. Dann meldet das
Spiel wirklich, und die Zeile landet wirklich in der JSONL.

## Von Hand durchspielen

```bash
URL=https://<domain>/melden/melden.php
TOKEN=mia.XXXXXXXXXXXXXXXX

# Token prüfen
curl -s -X POST "$URL" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"action":"verify","key_version":1}'
# -> {"ok":true,"label":"mia","key_version":1}

# Meldung
curl -s -X POST "$URL" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"action":"report","key_version":1,"target_type":"lexeme","target_id":"lex.beispiel",
       "comment":"Übersetzung passt nicht","at":"2026-09-02T18:04:11","app_version":"0.3.1"}'
# -> {"ok":true,"stored":true}    (bei Wiederholung: "stored":false)

# Verfälschtes Token
curl -s -X POST "$URL" -H "Authorization: Bearer mia.0000000000000000" \
  -H 'Content-Type: application/json' -d '{"action":"verify","key_version":1}'
# -> {"ok":false,"error":"bad_token"}

# Die Ablage darf nicht abrufbar sein
curl -s -o /dev/null -w '%{http_code}\n' https://<domain>/ms-reports/reports.jsonl
# -> 403 oder 404, niemals 200
```

Diese Runde gegen die echte Domain bleibt Pflicht: der Prüfstand oben deckt die Logik ab,
aber nicht die PHP-Fassung des Hosts, nicht die Schreibrechte über dem Docroot, nicht TLS
— und ausdrücklich nicht die Header-Falle darunter, weil der eingebaute Server den
Authorization-Header einfach durchreicht.

Antwortet `verify` mit `bad_token`, obwohl das Token stimmt, reicht Apache den
`Authorization`-Header nicht durch (CGI/FastCGI). Dann in `<Docroot>/melden/.htaccess`:

```apache
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
```

## Betrieb

- **`reports.jsonl` ist der einzige Ort, an dem Meldungen liegen.** Sichern — und die
  Sicherung gehört so wenig in ein Repo wie `raw/`.
- **Token sperren**: Label in `ms-reports/revoked.txt` schreiben, eines je Zeile. Wirkt
  sofort, ohne neues Geheimnis.
- **Geheimnis wechseln**: neues erzeugen, `MS_KEY_VERSION` hochzählen, Token neu prägen
  und mitteilen. Alte Token antworten danach `stale_key`, und die App sagt „Token ist
  abgelaufen, bitte neu eintragen" statt „ungültig".
- **Auswerten**: Datei herunterladen und lesen, z. B.
  `jq -r '[.received_at,.label,.target_id,.comment] | @tsv' reports.jsonl`.
  Das Bündeln zu GitHub-Issues im privaten Content-Repo ist ein eigener Schritt und
  bewusst nicht Teil des Endpunkts.
