# ADR 0002 — Rückkanal für Meldungen über einen eigenen Endpunkt

Status: **umgesetzt** (Endpunkt geprüft, noch nicht deployt) · Datum: 2026-09-02 · Baut auf: ADR 0001

## Kontext

„Melden" gibt es im Spiel schon: im Reveal markiert der Spieler ein Lexem mit
einem Kommentar (`src/ui/leak_reveal.gd:223`), die Meldung landet in
`user://lexeme_flags.json` (`src/core/lexeme_flags.gd`) und ist im
Settings-Menü sichtbar (`src/ui/settings_menu.gd:115`). Warum sie dort und nicht
in der Quell-JSON liegt, steht in ADR 0001, Abweichung 6.

Was fehlt, ist die Richtung nach oben. Eine falsche Übersetzung wird nicht
dadurch besser, dass sie auf dem Rechner des Kindes markiert ist — sie wird
besser, wenn sie beim Content-Autor ankommt und als Pack-Korrektur
zurückkommt. Der Content-Kanal aus ADR 0001 liefert Inhalte **zum** Spieler; der
Weg zurück ist bisher: keiner. Bei einer verteilten EXE heißt das, dass jede
Beobachtung an dem Rechner verfällt, an dem sie gemacht wurde.

Drei Randbedingungen legen das Ergebnis weitgehend fest:

1. **Eine Meldung trägt geschütztes Material.** Payload ist Lexem-Id plus
   Kommentar, faktisch also Lehrbuch-Vokabular — dasselbe Material, für das es
   das private Submodule und den `exclude_filter` gibt. Ein öffentliches
   GitHub-Issue oder ein öffentliches Formular ist damit ausgeschlossen, aus
   demselben Grund wie in ADR 0001.
2. **In der EXE kann kein Geheimnis liegen.** ADR 0001 hat den Satz schon:
   „Ein Token in einer öffentlichen EXE ist kein Token." Was ausgeliefert wird,
   darf höchstens ein reines Schreibrecht gegen einen Endpunkt sein, der nichts
   zurückgibt.
3. **Nicht jeder soll melden können — aus Bedienungsgründen.** Eine Meldung, die
   nirgends ankommt, ist ärgerlicher als ein fehlender Knopf. Wer keinen
   Rückkanal hat, soll „Melden" gar nicht sehen. Das ist ausdrücklich **kein**
   Sicherheitsargument: Sicherheit entscheidet der Endpunkt, nicht die UI.

## Entscheidung

Ein **dritter Kanal**, in der Gegenrichtung der beiden aus ADR 0001, mit einem
eigenen Endpunkt auf dem bereits bezahlten Strato-Webhosting.

```
Spieler-EXE  ──POST /melden.php (Bearer <Token>)──▶  Strato
                                                       │  melden.php prüft Token,
                                                       │  hängt eine Zeile an
                                                       ▼
                                              ../ms-reports/reports.jsonl
                                              (außerhalb des Docroots)
                                                       │  entkoppelt, per Hand oder Cron
                                                       ▼
                                    Issues in pesse/monster-slam-content (privat)
                                                       │  Korrektur
                                                       ▼
                                     Content-Kanal aus ADR 0001 ──▶ Spieler
```

Damit schließt sich der Kreis über den Kanal, der schon existiert: eine Meldung
wird zu einer Korrektur im privaten Content-Repo und kommt als Pack-Update
zurück. Der Rückkanal transportiert nur die Beobachtung, nichts sonst.

### 1. Melde-Token: `<label>.<mac>`, offline geprägt

Ein Token nennt die Person und beweist sich selbst:

```
label      = kurzer Name des Melders, klein, [a-z0-9-], z.B. "mia"
mac        = Crockford-Base32( HMAC-SHA256(secret, "<keyVersion>:<label>")[0..9] )
Token      = "<label>.<mac>"          z.B.  mia.K7Q2-9FTX-3M5R-8W1E
```

- **Ein Geheimnis, beliebig viele Token.** `secret` liegt ausschließlich auf dem
  Server. Geprägt wird offline mit `tools/report/mint_token.py` — es gibt keine
  Liste gültiger Token, die der Endpunkt pflegen müsste; die Signatur ist der
  Beweis. Dasselbe Muster wie beim Release-Schlüssel: der geheime Teil lebt an
  genau einer Stelle.
- **Das Label ist die Zuordnung.** Du siehst an jeder Meldung, von wem sie kommt,
  ohne dass die App einen Profil- oder Klarnamen mitsendet. Es ist gleichzeitig
  der Schlüssel für Rate-Limit und Sperrung.
- **80 Bit MAC, auf 16 Base32-Zeichen gekürzt.** Crockford-Alphabet (kein `0`/`O`,
  kein `1`/`I`/`L`), in Vierergruppen, Groß-/Kleinschreibung egal — das tippt ein
  Kind ab. 80 Bit sind gegen Raten reichlich, zusammen mit dem Rate-Limit
  erst recht; die Alternative „vollständige 256 Bit" kostet 52 Zeichen und kauft
  nichts, was hier gebraucht wird.
- **Kein Ablaufdatum im Token.** Zurückziehen geschieht über eine Sperrliste,
  Rotation über `keyVersion`. Ein Ablauf würde bedeuten, dass ein Melder ohne
  Zutun eines Tages stumm wird — der schlechtere Fehlerfall.
- **Sperrliste**: `../ms-reports/revoked.txt`, ein Label je Zeile. Ein Eintrag
  wirkt sofort, ohne neues Geheimnis und ohne die anderen Token zu berühren.
- **Rotation**: neues `secret`, `keyVersion` hochzählen. Alte Token scheitern
  danach mit einer benannten Antwort (`stale_key`), nicht mit „ungültig" — die
  App kann dann „Token ist abgelaufen, bitte neu eintragen" sagen, statt den
  Spieler ratlos zu lassen. Dieselbe Begründung wie `keyVersion` in ADR 0001,
  Abschnitt 7.

### 2. Ablage in `user://codes.cfg`, Sektion `[report]`

Das Token landet als `<keyVersion>:<token>` in `user://codes.cfg`, in einer
eigenen Sektion `report` neben den Pack-Zugangscodes in `codes`. Gleiche Datei,
weil es für den Spieler dasselbe ist („was ich hier eingetragen habe"); eigene
Sektion, weil `codes` nach `pack_id` geschlüsselt ist und ein Melde-Token kein
Pack ist.

**Das ist keine Geheimnis-Ablage.** Godot hat keinen Zugriff auf einen
OS-Keystore; wer die Datei lesen kann, liest auch die entpackten Vokabeln
daneben. Das Token schützt den öffentlichen Endpunkt, nicht den lokalen Rechner
— wörtlich dieselbe Zusicherung wie bei den Zugangscodes.

Der Träger kann es weitergeben. Das ist hingenommen: die Bedrohung, gegen die
hier gebaut wird, ist „jemand findet die URL und flutet sie", nicht „ein Kind
gibt seinen Melde-Zugang weiter".

### 3. Endpunkt: eine PHP-Datei

`POST https://<domain>/melden.php`, `Authorization: Bearer <label>.<mac>`,
JSON im Body. Zwei Aktionen im selben Skript — ein zweiter Endpunkt für die
Token-Prüfung wäre eine zweite Datei mit derselben Logik:

| `action` | Wirkung | Antwort |
|---|---|---|
| `verify` | prüft nur das Token | `{"ok":true,"label":"mia"}` |
| `report` | prüft, dedupliziert, hängt an | `{"ok":true,"stored":true}` |

Fehlerfälle antworten mit benanntem Grund, nicht nur mit einem Status:
`bad_token`, `stale_key`, `revoked`, `too_large`, `rate_limited`, `bad_payload`.
Die App zeigt bei einem Klick genau diesen Grund; bei einem stillen
Hintergrundversand zeigt sie nichts.

```php
// Skizze, verbindlich ist server/melden/melden.php
require __DIR__ . '/../../ms-secret.php';       // außerhalb des Docroots
$raw = file_get_contents('php://input');
if (strlen($raw) > 4096)            fail('too_large');
[$label, $mac] = explode('.', bearer(), 2);
$want = b32(substr(hash_hmac('sha256', KEY_VERSION.":".$label, SECRET, true), 0, 10));
if (!hash_equals($want, normalize($mac))) fail('bad_token');   // nicht ==
if (revoked($label))                fail('revoked');
if (rate_exceeded($label))          fail('rate_limited');
append(REPORTS, json_encode($entry) . "\n");   // fopen('a') + flock(LOCK_EX)
```

Vier Dinge, die auf Shared Hosting anders liegen als bei einem Anbieter mit
eingebauten Deckeln:

- **Geheimnis und Daten liegen über dem Docroot.** `ms-secret.php` und
  `ms-reports/` eine Ebene höher. Sonst ist die Meldungsdatei per URL abrufbar —
  und das ist die Datei, in der sich geschütztes Vokabular ansammelt. Ein
  `.htaccess` mit `Require all denied` ist der Rückfall, wenn das Paket kein
  Verzeichnis über dem Docroot erlaubt, aber der schlechtere: ein
  Konfigurationsfehler serviert PHP-Quelltext, ein Verzeichnis außerhalb nicht.
- **Schreiben braucht ein Lock.** `fopen('a')` plus `flock(LOCK_EX)`; zwei
  gleichzeitige Meldungen zerschneiden sonst eine Zeile.
- **Die Deckel setzt das Skript.** Body hart auf 4 KB, Rate je Label (Vorschlag:
  30/Stunde, 200/Tag) über die letzten Zeilen der JSONL — kein zweiter Speicher
  nötig. Nur `POST`, nur bekannte `target_type`-Werte, alles andere abgewiesen.
- **HTTPS ist Pflicht**, nicht Option: ohne TLS reist das Token im Klartext.
  Ein Request ohne `HTTPS` wird abgewiesen, statt bedient.

**JSON Lines statt Datenbank.** Anhängen ist atomar genug, es gibt kein Schema zu
migrieren, und die Auswertung ist ein `scp` und ein `jq`. MySQL wäre hier
Aufwand ohne Gegenwert.

### 4. Payload

```json
{
  "action": "report",
  "target_type": "lexeme",
  "target_id": "lex.beispiel",
  "learnable_id": "task.translate.de_en|lex.beispiel",
  "comment": "Übersetzung passt nicht",
  "at": "2026-09-02T18:04:11",
  "app_version": "0.3.1",
  "pack": {"id": "language-access2", "version": "v7"}
}
```

- **`target_type` von Anfang an.** Heute ist nur ein Lexem meldbar; Sätze sind in
  `ContentRegistry` schon vorgesehen. `{lexeme_id: …}` wäre in einem halben Jahr
  ein Formatbruch, `{target_type, target_id}` nicht.
- **Herkunft mitsenden.** `app_version` und der Pack, aus dem der Eintrag stammt
  — `ContentRegistry` weiß beides (`_origins`, `source_file()`, der lokale
  Pack-Zustand aus ADR 0001). Ohne das steht eine Meldung zu einem Wort im Raum,
  das in der Zwischenzeit längst korrigiert wurde.
- **Kein Personenbezug über das Label hinaus.** Kein Profilname, keine
  Installations-Id, keine Fortschrittsdaten. Der Kommentar ist Freitext von einem
  Kind — er ist das einzige, was mitfährt, und genau darum steht beim
  Token-Eintragen ein Satz, was übertragen wird.
- **Idempotenz** über `<label>|<target_id>|<at>`: geht die Antwort verloren und
  die App schickt erneut, erkennt der Endpunkt die Wiederholung in den letzten
  Zeilen und antwortet `{"ok":true,"stored":false}`.

### 5. Verhalten in der App

- **Ohne hinterlegtes Token kein „Melden".** Der Knopf im Reveal erscheint nicht,
  und die Flag-Liste im Settings-Menü bleibt aus. Kein ausgegrautes Element, kein
  Erklärungsbedarf. Bedienungsentscheidung, keine Schranke.
- **Token eintragen im Settings-Menü**, nicht im Content-Manager — es hat mit
  Packs nichts zu tun. Eingabe → `verify` → Rückmeldung mit dem Label („Token
  gilt für Mia"). Erst bei `ok` wird gespeichert, damit ein Tippfehler sofort
  auffällt und nicht bei der ersten echten Meldung.
- **Melden bleibt lokal wirksam.** Die Meldung wird wie heute in
  `lexeme_flags.json` geschrieben; der Versand ist ein zweiter Schritt. Jeder
  Eintrag bekommt dafür ein `sent`-Feld. Kein Netz heißt: liegt in der
  Warteschlange und geht beim nächsten Start mit.
- **Jeder Netzfehler ist ein Zustand, kein Abbruch** — das Muster aus
  `update_service.gd`: `ReportService` als Autoload mit `State`-Enum und
  `changed`-Signal, still im Hintergrund, benannt nur nach einem Klick. Eine
  klemmende Meldung darf das Spiel nicht aufhalten.

### 6. GitHub bleibt außerhalb des Request-Pfads

Das PHP-Skript legt **kein** Issue an. Es hängt die Zeile an, fertig. Das
Übersetzen in Issues im privaten Content-Repo ist ein eigener Schritt — lokal
oder per Cron. Zwei Gründe: eine GitHub-Störung darf keine Meldung verschlucken,
und erst getrennt lässt sich bündeln („dasselbe Lexem von drei Spielern" ist ein
Issue, nicht drei). Solange das Aufkommen klein ist, reicht es, die JSONL
herunterzuladen und zu lesen; der Endpunkt bleibt davon unberührt.

## Verworfene Alternativen

**GitHub-PAT an die Melder.** Zwei Varianten, beide schlecht. *Eigenes Konto je
Melder*: jede Collaborator-Rolle bei GitHub schließt Leserecht ein — du gäbest
jedem Melder das Recht, den geschützten Korpus zu klonen, um ihm das Melden eines
Tippfehlers zu erlauben. *PATs aus dem eigenen Konto*: jedes Token ist ein Stück
der eigenen Identität; auf `Issues: write` beschränkt darf es immer noch alle
Issues lesen, ändern und schließen — und die Issues sind der Ort, an dem sich das
geschützte Vokabular sammelt. Dazu: alle Issues erscheinen als von dir verfasst
(Zuordnung weg), es gibt keine Bremse dazwischen, und die Issue-Form läge für
immer im Client, also kostet jede Änderung daran eine neue EXE. Dass Secrets in
die CI gehören und nicht auf Spielerrechner, hält das Projekt an anderer Stelle
schon ein (`RELEASE_SIGNING_KEY`, `.github/workflows/release.yml`).

**Ein gemeinsames Token für alle.** Ein Leck beendet den Kanal, Zurückziehen
heißt „allen ein neues mitteilen", und es gibt keine Zuordnung. Die signierte
Einzelvariante kostet ein Skript in `tools/` mehr.

**Cloudflare Worker.** Sachlich einwandfrei — serverlos, nichts läuft permanent,
Rate-Limit und KV eingebaut, im Freikontingent kostenlos. Verworfen, weil das
Strato-Paket bezahlt ist und der Worker dafür einen zweiten Anbieter samt
CLI-Toolchain in ein Projekt bringt, das mit zwei Repos und einem Submodule schon
genug Orte hat. Bleibt die Rückfalloption, falls Strato zu enge Grenzen setzt
(kein Verzeichnis über dem Docroot, kein HTTPS) oder das Aufkommen wächst — am
Token-Format und am Payload ändert ein Umzug nichts.

**Fertiges Backend (Supabase, Airtable, Google Forms).** Funktioniert technisch,
verlagert aber geschütztes Lehrbuchmaterial in eine fremde Datenbank. Das ist der
Punkt, den ADR 0001 überall sonst vermeidet.

**`mailto:` mit vorbefülltem Body.** Keine Infrastruktur, kein Geheimnis — aber
es setzt einen konfigurierten Mailclient voraus, den auf einem Kinder-Rechner
niemand hat, und begrenzt die Länge.

**Export-Datei als Hauptweg.** War der naheliegende erste Schritt und ist mit
„ohne Token kein Melden" hinfällig: wer melden darf, hat ein Token und braucht
keinen Umweg über eine Datei. Bleibt als Entwickler-Werkzeug denkbar, nicht als
Rückkanal.

## Konsequenzen

- **Die Endpunkt-URL steht im öffentlichen Repo**, als Konstante in
  `report_service.gd` — so wie `MANIFEST_URL` in `update_service.gd:25`. Kein
  Geheimnisverlust, aber eine Einladung zum Anklopfen. Deshalb sind die Deckel im
  PHP nicht optional, sondern der Ersatz für das, was ein Anbieter mitbrächte.
- **Betrieb liegt jetzt bei dir.** PHP-Version im Strato-Panel aktuell halten,
  und die JSONL sichern — sie ist der einzige Ort, an dem Meldungen liegen.
- **Auf dem Webhost sammelt sich geschütztes Material.** Verzeichnis über dem
  Docroot, und die Backups dieser Datei gehören genauso wenig in ein öffentliches
  Repo wie `raw/`.
- **Token-Verteilung ist Handarbeit.** Prägen, mitteilen, bei Bedarf sperren. Bei
  einer Handvoll Meldern richtig, bei fünfzig nicht mehr — dann wird der
  Verteilweg das nächste Thema, nicht der Endpunkt.
- **Von Fremden kommt nichts zurück.** Wer kein Token hat, hat keinen Rückkanal
  und sieht das Melden nicht. Bewusst so: eine Rückmeldung, die niemand liest,
  ist schlechter als keine.
- **Struktur bleibt, wie sie ist.** Rein additiv: `src/report/` (dritter Kanal
  neben `src/update/` und `src/content/`), `server/melden/`, `tools/report/`,
  zwei Tests, diese ADR. Dazu vier Einzeiler: Autoload in `project.godot`,
  `server/*` in den `exclude_filter`, Geheimnis und geprägte Token in die
  `.gitignore` (analog zur `*.pem`-Regel), `*.php text eol=lf` in die
  `.gitattributes`.
- **Der Pack-Weg ist nicht betroffen.** Keine neue Content-Kategorie, kein
  Eintrag in `packs.yaml`, kein Anfassen des Submodules — Meldungen liegen in
  `user://` und auf dem Server, nie unter `data/`.

## Umsetzungsplan

Vier Phasen, jede für sich prüfbar.

### Phase 1 — Endpunkt und Token-Prägung

1. Strato prüfen: PHP-Version, HTTPS, und ob ein Verzeichnis über dem Docroot
   beschreibbar ist. Fällt letzteres aus, `.htaccess`-Rückfall dokumentieren.
2. `tools/report/mint_token.py`: Geheimnis erzeugen, Token prägen, Crockford-Base32.
3. `server/melden/melden.php` mit beiden Aktionen, Deckeln, Sperrliste, `flock`.
4. `server/melden/README.md`: welche Datei wohin, was über den Docroot gehört,
   wie die JSONL gesichert wird.
5. Von Hand mit `curl` durchspielen: gültig, verfälscht, gesperrt, zu groß,
   Rate-Limit, Wiederholung.

*Fertig, wenn* ein gültiges Token eine Zeile schreibt, ein um ein Zeichen
verändertes `bad_token` liefert und die Meldungsdatei über keine URL abrufbar ist
(auch nicht über einen geratenen Pfad unter dem Docroot).

### Phase 2 — Token in der App, „Melden" am Token

6. `src/report/report_token.gd`: lesen/schreiben/vergessen in `user://codes.cfg`
   Sektion `report`, mit `keyVersion` (Muster: `access_codes.gd`).
7. `src/report/report_service.gd` als Autoload: `verify()`, `State`-Enum,
   `changed`-Signal, still/laut wie `update_service.gd`.
8. Settings-Menü: Eingabefeld, `verify`, Rückmeldung mit Label, „vergessen".
9. Reveal-Melden-Knopf und Flag-Liste an das Vorhandensein des Tokens binden.

*Fertig, wenn* eine EXE ohne Token kein „Melden" zeigt, ein Tippfehler beim
Eintragen benannt wird und ein gültiges Token das Melden freischaltet.

### Phase 3 — Senden

10. `sent`-Feld in `LexemeFlags`, Warteschlange über nicht gesendete Einträge.
11. Versand beim Melden und beim Start; Fehler bleiben Zustand, nie Abbruch.
12. Herkunft anreichern (`app_version`, Pack-Id/-Version aus `_origins` und dem
    Pack-Zustand).

*Fertig, wenn* eine Meldung ohne Netz liegen bleibt, beim nächsten Start
angekommen ist und ein doppelter Versand `stored:false` erzeugt.

### Phase 4 — Auswertung, Tests, Doku

13. Kleines Skript, das neue JSONL-Zeilen zu Issues im Content-Repo bündelt —
    getrennt vom Request-Pfad.
14. Tests (gdUnit4, `docs/TESTING.md`): Token-Ablage inkl. `keyVersion`-Wechsel,
    Warteschlange und `sent`-Übergänge, Payload-Aufbau, UI-Gate ohne Token.
    Fixtures mit MAC gehören unter `tests/fixtures/` — dort greift die
    `-text`-Regel der `.gitattributes`, und ein HMAC über *genau diese Bytes* ist
    exakt die Falle, die schon einmal fünf Tests umgeworfen hat. Neue
    `class_name`-Dateien brauchen `--import` vor dem Testlauf.
15. `docs/ARCHITECTURE.md` um den dritten Kanal ergänzen; in `CLAUDE.md` einen
    Satz, dass das Melde-Geheimnis ausschließlich auf dem Server liegt.

## Abweichungen in der Umsetzung

Umgesetzt am 2026-09-02. Was anders kam als oben geplant, und warum:

1. **`key_version` wird beim Prüfen NICHT mitgesendet, beim Melden schon.** Der Plan sagte
   nur „Rotation über `keyVersion`" und ließ offen, woher die App die Zahl kennt — das
   Token trägt sie nicht. Also: `verify` schickt sie nicht mit, der Endpunkt antwortet mit
   seiner, und die App legt sie neben dem Token ab. `report` schickt sie dann mit, und
   genau daran erkennt der Endpunkt nach einer Rotation ein altes Token (`stale_key`).

2. **Der Melder-Name ist abgeleitet, nicht gespeichert.** Erst hielt `ReportService` ihn in
   einem Feld, gefüllt aus der `verify`-Antwort. Der UI-Test hat das als Zustandsmüll
   entlarvt: ein direkt hinterlegtes Token ließ das Feld leer zurück. Der Name steht im
   Token, und der Endpunkt leitet ihn genauso ab — ein Feld daneben kann nur falsch werden.

3. **Rate-Limit und Doppelerkennung teilen einen Lesevorgang.** Geplant waren sie als zwei
   Prüfungen; sie brauchen beide dasselbe Ende der Datei, also durchläuft der Endpunkt es
   einmal. Kein zweiter Speicher, keine zweite Datei.

4. **PHP 7.1 als Untergrenze.** Der Rückgabetyp `never` (erst 8.1) ist wieder `void`
   geworden — welche Fassung auf dem Strato-Paket läuft, steht noch nicht fest, und der
   Endpunkt braucht kein einziges 8.x-Merkmal.

5. **`_apply_report_gate()` als eigene Funktion im Reveal.** Eine Zeile in `play()` wäre
   nicht prüfbar gewesen, ohne den ganzen Auto-Durchlauf samt Timern anzustoßen. Die
   Entscheidung „ohne Token kein Knopf" ist der Kern der Anforderung und gehört unter Test.

6. **Der Reiter heißt jetzt „Melden", nicht „Markiert".** Er trägt beides — die
   Token-Eingabe und die eigenen Meldungen —, und „markiert" beschrieb nur den lokalen
   Teil.

7. **Meldungen ohne Feld `sent` gelten als offen.** In der ADR nicht bedacht: in
   `lexeme_flags.json` liegen schon Meldungen aus der Zeit vor dem Rückkanal. Sie sollen
   mitgehen, nicht stillschweigend verfallen.

8. **PHP kommt aus einem Container, nicht vom Rechner.** Der Plan sagte nichts dazu, wie
   der Endpunkt geprüft wird. Er wird es jetzt: `.devcontainer/` ist eine PHP-Werkbank
   (PHP 8.3 plus python3, damit beide Hälften des Token-Formats darin rechnen können),
   `tools/report/php.sh` zieht sie für einen einzelnen Aufruf hoch — dieselbe Regel wie
   bei `tools/godot.sh`, und aus demselben Grund: der Aufruf soll überall gleich aussehen.
   `server/melden/test_endpoint.php` startet `php -S` gegen ein Wegwerf-Docroot, das die
   Ablage aus der README nachbaut, und spielt 48 Prüfungen durch. Die CI
   (`.github/workflows/endpoint.yml`) fährt das plus beide `--self-test` bei jeder Änderung
   an `server/**` — das ist die eigentliche Absicherung gegen das Auseinanderlaufen der
   zwei Formatimplementierungen.

**Noch offen:** `ReportService.ENDPOINT` ist leer, damit ist der Kanal aus — die URL kommt
mit dem Deployment.

Der Endpunkt selbst ist inzwischen gelaufen: 48 Prüfungen im Prüfstand, und das
Token-Format stimmt zwischen `mint_token.py` und `token.php` nicht mehr nur nachgerechnet,
sondern gemessen. Was der Prüfstand **nicht** abdeckt, bleibt die PHP-Fassung des Hosts,
die Schreibrechte über dem Docroot, TLS und die Authorization-Header-Falle von Apache (der
eingebaute Server reicht den Header durch). Die `curl`-Runde aus der README gegen die echte
Domain ist deshalb vor dem ersten echten Token weiter Pflicht.
