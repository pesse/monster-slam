# ADR 0001 — App-Update und Content-Update als getrennte Kanäle

Status: **vorgeschlagen** · Datum: 2026-08-31 · Vorbild: `dnd-planner`

## Kontext

Monster Slam wird als **eine self-contained Windows-EXE** ausgeliefert
(`build.sh`, `binary_format/embed_pck=true`, ~122 MB). Alles, was das Spiel
braucht, steckt darin — Engine, Assets, Skripte **und** die JSON-Daten unter
`res://data` inklusive des Sprach-Submodules `res://data/language`.

Daraus folgen heute drei Probleme:

1. **Kein Update-Weg.** Wer die EXE hat, hat sie für immer. Eine neue Fassung
   heißt: neue Datei per Hand besorgen und ersetzen.
2. **Vokabeln kleben an der App.** Der Lernstoff wächst wöchentlich (neue Unit,
   korrigierte Übersetzung), der Code selten. Trotzdem kostet jede
   Vokabel-Korrektur einen 122-MB-Download.
3. **Die EXE trägt geschütztes Material.** `data/language` ist aus
   urheberrechtlich geschütztem Lehrbuchmaterial abgeleitet (siehe `CLAUDE.md`)
   und liegt deshalb in einem privaten Repo. Der Export packt es ungefragt in
   die EXE — eine öffentlich verteilte EXE veröffentlicht damit genau das
   Material, das das private Submodule schützen soll. **Das ist der eigentlich
   drängende Punkt**: er verbietet die Verteilung der heutigen EXE, nicht nur
   ihre Aktualisierung.

`dnd-planner` löst dasselbe Problem mit zwei getrennten Mechanismen und ist als
Vorbild belastbar erprobt:

| | dnd-planner | Quelle |
|---|---|---|
| App-Update | Tauri-Updater: `latest.json` am `releases/latest`-Asset, signiert (minisign), Dialog mit Release-Notes, Download → Installer → Relaunch | `src/lib/stores/update.ts`, `src-tauri/tauri.conf.json` |
| Content-Update | Bibliotheks-**Packs** an einem Release mit *festem* Tag in einem öffentlichen Transport-Repo; `index.json` unverschlüsselt, geschützte Packs AES-256-GCM mit Zugangscode | `src-tauri/src/libraries.rs`, `vault/tools/PACK_FORMAT.md` |
| Verzahnung | `min_app_version` je Library → `minVersion` je Index-Eintrag; **zwei Richtungen**: App zu alt für Inhalt (`appOutdated`, sperrt) und Inhalt zu alt für App (`contentOutdated`, mahnt) | `satisfies_min` / `too_old_for` |

## Entscheidung

Monster Slam bekommt **dieselbe Zweiteilung**: einen App-Kanal und einen
Content-Kanal, jeder mit eigener Version, verbunden über ein
Mindestversions-Gate in beide Richtungen.

```
pesse/monster-slam            (public)   ──Release vX.Y.Z──▶  MonsterSlam-X.Y.Z.exe + latest.json
                                                                     │ App-Kanal
pesse/monster-slam-content    (private)  ──CI baut Packs──▶          ▼
pesse/monster-slam-packs      (public)   ──Release Tag "packs"──▶  index.json + *.zip / *.enc
                                                                     │ Content-Kanal
                                                          user://content/<pack>/…
```

### 1. Die EXE enthält keine Sprachdaten mehr

`exclude_filter` im Export-Preset schließt `data/language/*` aus. Die
ausgelieferte EXE ist damit frei von geschütztem Material und ohne installierten
Pack ein Spiel ohne Vokabeln — genau der Zustand, den `ContentRegistry.reload()`
heute schon mit einer Warnung behandelt, wenn das Submodule fehlt.

Im Editor/Debug-Build bleibt das Submodule die Quelle. Der Content-Kanal ist
dort inert (kein Netz, keine Installation) — die Entwicklung arbeitet weiter
gegen `data/language`, nicht gegen einen heruntergeladenen Pack.

### 2. Dritter Root: `user://content`

`ContentRegistry` bekommt neben `DATA_ROOT` und `LANGUAGE_ROOT` einen dritten
Root `USER_CONTENT_ROOT := "user://content"`, der **nach** den anderen gescannt
wird. Reihenfolge ist Vorrang: eine `id` aus einem installierten Pack
überschreibt dieselbe `id` aus `res://`. Der Scan-Code (`_scan_dir`) ist
pfad-agnostisch und bleibt unverändert.

Ein Pack schreibt **ausschließlich** unter `user://content/`. `user://progress`
und `user://settings.cfg` fasst er nie an — dieselbe Zusicherung wie
`ALLOWED_ROOTS` in `libraries.rs`, hier zusätzlich durch getrennte
Verzeichnisbäume erzwungen.

### 3. Pack-Format (Container v1)

Ein Pack ist ein ZIP mit content-relativen Pfaden (`lexemes/<datei>.json`).
Geschützte Packs liegen in einer Hülle:

```
Offset  Größe  Feld
     0      6  Magic "MSLPK1"
     6      1  Formatversion (= 1)
     7      1  KDF-Kennung (= 1 für PBKDF2-HMAC-SHA256)
     8      4  Iterationen (uint32, big endian)
    12     16  Salt
    28     32  Verifier
    60     16  IV (AES-CBC)
    76     32  HMAC-SHA256 über Kopf ‖ Ciphertext
   108    ...  Ciphertext (AES-256-CBC, PKCS#7)
```

```
master   = PBKDF2-HMAC-SHA256(code, salt, iter, dklen = 32)
enc_key  = HMAC-SHA256(master, "monster-slam:enc")
mac_key  = HMAC-SHA256(master, "monster-slam:mac")
verifier = HMAC-SHA256(master, "monster-slam:verify")
```

Drei Abweichungen von `dnd-planner` — alle erzwungen davon, was Godot ohne
GDExtension anbietet:

- **CBC + HMAC statt GCM.** `AESContext` kennt nur ECB und CBC. Encrypt-then-MAC
  über Kopf ‖ Ciphertext liefert dieselbe Eigenschaft: ein veränderter Kopf
  (etwa herabgesetzte Iterationen) lässt die Prüfung scheitern, statt still
  einen schwächeren Schlüssel zu erzwingen. **Der MAC wird vor dem Entschlüsseln
  geprüft**, nie danach.
- **PBKDF2 statt scrypt.** Kein scrypt in Godot; PBKDF2 ist aus
  `Crypto.hmac_digest` in wenigen Zeilen GDScript gebaut. Es fehlt die
  Speicher-Härte — akzeptiert, weil das Ziel „Lehrbuchmaterial liegt nicht als
  offener Download herum" ist, nicht Widerstand gegen einen finanzierten
  Angreifer. Die Iterationszahl steht im Kopf und ist später erhöhbar, ohne alte
  Packs unlesbar zu machen. **Vor der Festlegung messen** (Zielgröße: ≤ 1 s auf
  dem Zielrechner) — die Zahl wandert in `PACK_FORMAT.md`, nicht in eine
  Konstante ohne Begründung.
- **Verifier-Prüfung vor dem Download.** Wie im Vorbild: die ersten 108 Bytes
  per HTTP-`Range` holen, Code dagegen prüfen, erst danach den ganzen Pack
  laden. Falls GitHub den Range-Header über die Redirect-Kette verliert, ist der
  Rückfall ein voller GET — die Packs sind klein.

`ZIPReader.open()` will einen Pfad, kein Byte-Array: der entschlüsselte ZIP
geht nach `user://tmp/<id>.zip` und wird nach dem Auspacken gelöscht.

### 4. `index.json` und Pack-Zuschnitt

Unverschlüsselt, damit der Update-Check **ohne jeden Zugangscode** funktioniert.
Aufbau wie im Vorbild (`schemaVersion`, `libraries[]` mit `id`, `name`,
`version`, `protected`, `file`, `sha256`, `size`, `fileCount`, `minVersion`).

Drei Packs:

| id | Inhalt | Verteilung |
|---|---|---|
| `game` | `monsters`, `bosses`, `waves`, `skills`, `task_definitions`, `monster_task_rules` | offen |
| `language-basic` | selbst erstellte Lexeme (kein Lehrbuchbezug) | offen |
| `language-access2` | aus Lehrbuchmaterial abgeleitete Lexeme | **geschützt** |

Der Zuschnitt ist **datengetrieben und fail-closed**, wie in
`vault/libraries.yaml`: Grundlage ist ein neues Pflichtfeld `source` am Lexem
(`own` | `access2` | …). Eine Datei ohne eindeutige Zuordnung lässt den
Pack-Build fehlschlagen, statt geschütztes Material in einen offenen Pack
rutschen zu lassen. Die 2118 Bestands-Lexeme brauchen dafür eine einmalige
Migration; `book`/`unit` reichen **nicht** als Ersatz — ein fehlendes `book`
heißt heute „Grundwortschatz" und wäre stillschweigend „offen".

Dass `game` ein eigener, offener Pack ist, kostet fast nichts und macht Balancing
(Wellen, Tempo-Konstanten, Aufgaben-Schwierigkeit) ohne App-Release änderbar.

### 5. `latest.json` und der App-Kanal

An `https://github.com/pesse/monster-slam/releases/latest/download/latest.json`:

```json
{
  "version": "0.2.0",
  "notes": "…Release-Beschreibung…",
  "pub_date": "2026-09-01T10:00:00Z",
  "platforms": {
    "windows-x86_64": {
      "url": "https://…/MonsterSlam-0.2.0.exe",
      "sha256": "…",
      "signature": "base64(RSA-SHA256 über die EXE)"
    }
  }
}
```

Verifiziert wird mit `Crypto.verify(HashingContext.HASH_SHA256, hash, sig, key)`
gegen einen **öffentlichen RSA-Schlüssel im Projekt** (`res://keys/release.pub`).
RSA, weil Godots `Crypto` genau das kann — ed25519/minisign wie im Vorbild gibt
es nicht ohne GDExtension. Der private Schlüssel lebt als GitHub-Secret und
nirgendwo sonst. `sha256` allein ist **keine** Signatur: es schützt gegen den
kaputten Download, nicht gegen einen manipulierten.

Selbstersetzung unter Windows, in dieser Reihenfolge:

1. Nach `user://updates/MonsterSlam-<v>.exe` laden, SHA-256 **und** Signatur
   prüfen. Ein Fehlschlag löscht die Datei und bricht ab.
2. Laufende EXE nach `<name>.old` umbenennen (unter Windows erlaubt, auch
   während sie läuft).
3. Neue EXE an den alten Pfad verschieben.
4. `OS.create_process()` auf den alten Pfad, dann `quit()`.
5. Beim nächsten Start `.old` löschen — nicht vorher, die Datei ist bis zum
   Prozessende gesperrt.

Scheitert Schritt 2 oder 3 (Rechte, Virenscanner, Programme-Verzeichnis), wird
**zurückgerollt** (`.old` zurückbenennen) und der Pfad der geladenen Datei
angezeigt: „Neue Fassung liegt hier, bitte manuell ersetzen." Ein halb
ersetztes Spiel ist der einzige Ausgang, den es nicht geben darf.

### 6. Das Gate in beide Richtungen

Übernommen, weil es genau den stillen Fehler abfängt, der hier sonst entstünde —
ein Lexem mit einem Feld, das erst eine neuere App auswertet, wirkt in einer
älteren App nicht falsch, sondern *unauffällig unvollständig*.

- `min_app_version` je Pack → `minVersion` je Index-Eintrag. Ist die App älter:
  Zustand `appOutdated`, **Installation verweigert**. Kein Zugangscode hebt das
  auf.
- Umgekehrt: `minVersion` des *installierten* Packs gegen die des Index. Kleiner:
  `contentOutdated` — kein Sperrgrund, aber die UI wählt den Pack zum
  Aktualisieren vor.
- Vergleich über das Zahlentripel; Suffixe (`-rc1`) fallen weg.
- Im Debug-Build **kein** Gate: committet steht in `project.godot` immer die
  Version des letzten Releases, eine Deklaration auf die kommende Fassung
  sperrte die Entwicklung an den eigenen Inhalten aus.

### 7. Zugangscode-Ablage

Godot hat keinen Zugriff auf einen OS-Keystore (`keyring` im Vorbild). Der Code
landet als `<keyVersion>:<code>` in `user://codes.cfg`. **Das ist keine
Geheimnis-Ablage**, sondern eine Bequemlichkeit: wer die Datei lesen kann, kann
auch die entpackten Vokabeln lesen, die daneben liegen. Der Code schützt den
öffentlichen Download, nicht den lokalen Rechner. `keyVersion` bleibt trotzdem
dabei — daran erkennt die App eine Passwortrotation (`staleCode`) und kann sie
benennen, statt still zu scheitern.

## Verworfene Alternativen

**Content als Godot-`.pck` per `load_resource_pack()` mounten.** Verlockend: die
Dateien erscheinen unter `res://`, `ContentRegistry` bliebe unangetastet.
Verworfen aus drei Gründen: (a) das Bauen eines `.pck` braucht Godot **im
Content-Repo-CI**, ZIP braucht nur Python; (b) ein Pack ist alles-oder-nichts —
zurückgezogene Einzeldateien und lokal geänderte Dateien (siehe
`flag_lexeme`) sind nicht abbildbar; (c) Godots PCK-Verschlüsselung hängt am
Skript-Schlüssel im Export-Template, für einen Zugangscode also unbrauchbar —
die eigene Hülle bräuchte es trotzdem.

**Pack aus dem privaten Repo mit Token laden.** Ein Token in einer öffentlichen
EXE ist kein Token.

**App-Update als Patch-PCK statt ganzer EXE.** Aktualisiert die Engine nicht und
müsste vor den Autoloads greifen — also genau vor dem Code, der gepatcht werden
soll.

**Nur Content-Kanal, App per Hand.** Trägt zwei Jahre weit und bricht genau
dann, wenn ein Pack ein neues Feld braucht: das Gate meldet dann „App zu alt"
und hat keinen Weg anzubieten.

## Konsequenzen

- **Die 122-MB-EXE ist ein Argument, kein Detail.** Sie rechtfertigt die
  Trennung der Kanäle (Vokabel-Korrektur = einige KB) und ist gleichzeitig der
  Grund, warum App-Updates selten sein sollen.
- **`flag_lexeme` schreibt heute nach `res://`** und ist im Export damit
  wirkungslos (`FileAccess` auf `res://` ist read-only). Das muss mit: Flags
  gehören nach `user://` — als eigene Datei neben dem Fortschritt, nicht als
  Rückschreiben in die Pack-Datei. Sonst wäre jede geflaggte Datei „lokal
  geändert" und würde vom nächsten Update übersprungen.
- **`export_presets.cfg` ist gitignored**, CI braucht es aber. Die Datei enthält
  heute keine absoluten Pfade und keine Geheimnisse (der Skript-Schlüssel kommt
  aus der Umgebung) — sie wird committet, der Grund im `.gitignore` fällt weg.
  `build.sh` synchronisiert die Version darin weiter.
- **Der Release-Tag wird zur einzigen Wahrheit der App-Version** (Vorbild:
  `release.yml`). CI schreibt `vX.Y.Z` nach `project.godot`, baut, signiert,
  hängt EXE + `latest.json` an und committet die Version zurück in `main`.
  `config/version` bleibt die Quelle für `build.sh` — nur eben tag-gespeist.
- **Offline bleibt der Normalfall.** Jeder Netzfehler ist ein Zustand, kein
  Abbruch: Startprüfung schweigt (Konsole), das Spiel startet mit dem, was
  installiert ist.
- **Zwei Repos mehr im Blick.** `monster-slam-packs` (öffentlich, nur Transport,
  Release-Tag `packs`) und der Pack-Build im Content-Repo.

## Umsetzungsplan

Fünf Phasen, jede für sich nutzbar und ausrollbar.

### Phase 1 — Release-Pipeline und App-Update-Hinweis

Ohne Netz-Selbstersetzung; nur „es gibt eine neue Fassung".

1. `export_presets.cfg` committen, `.gitignore`-Eintrag entfernen.
2. RSA-Schlüsselpaar erzeugen; öffentlicher Teil nach `res://keys/release.pub`,
   privater Teil als Secret `RELEASE_SIGNING_KEY`.
3. `.github/workflows/release.yml` (`on: release: published`): Godot + Export-
   Templates holen, Version aus dem Tag nach `project.godot`, `--export-release`,
   SHA-256 + Signatur, `latest.json` erzeugen, beides ans Release hängen;
   Folge-Job committet die Version zurück in `main`.
4. `src/update/update_service.gd` (Autoload): `check()` per `HTTPRequest`,
   Vergleich gegen `ProjectSettings.get_setting("application/config/version")`,
   Zustände `idle | available | downloading | verifying | ready | error`,
   Meldung über `EventBus`. Im Debug-Build inert.
5. `scenes/ui/update_dialog.tscn` + `.gd` (statische UI als `.tscn`, siehe
   Projekt-Konvention): Version, Release-Notes, „Später" / „Herunterladen".
   Badge im `profile_menu`.
6. Version auf `0.2.0` und ein erstes Release durchspielen.

*Fertig, wenn* eine 0.1.0-EXE beim Start ein 0.2.0-Release meldet und ein
manipuliertes `latest.json` mit „Signatur ungültig" abgewiesen wird.

### Phase 2 — Content-Packs, offener Weg

7. `source`-Feld an allen Lexemen ergänzen (Migrationsskript im Content-Repo).
8. `tools/build_packs.py` + `docs/PACK_FORMAT.md` im Content-Repo: Zuordnung
   über `source`, fail-closed, `--dry-run` für die Validierung, `index.json` mit
   `minVersion`, offene Packs als reines ZIP.
9. `.github/workflows/packs.yml` im Content-Repo, zwei Jobs wie im Vorbild:
   `validate` ohne Secrets bei jedem Push/PR, `publish` nur von `main` gegen das
   Release mit festem Tag `packs` in `pesse/monster-slam-packs`.
10. `src/content/pack_index.gd` (Index holen, mit lokalem Stand verschneiden,
    Zustände `installed | update | available | locked | staleCode | appOutdated`
    + Achse `contentOutdated`) und `pack_installer.gd` (Download, SHA-256,
    Auspacken nach `user://content/<id>/`, Zustand nach
    `user://content/.state/<id>.json` mit Dateiliste + SHA je Datei; entfernt
    zurückgezogene Dateien, überspringt lokal geänderte).
11. `ContentRegistry`: `USER_CONTENT_ROOT` als dritter, letzter Root; `reload()`
    nach der Installation.
12. `scenes/ui/content_manager.tscn` + `.gd`: Liste, Zustände, Auswahl,
    „Installieren/Aktualisieren", Ergebnis-Zusammenfassung (geschrieben /
    entfernt / übersprungen). Badge im `profile_menu`.
13. `data/language/*` in den `exclude_filter` des Presets.

*Fertig, wenn* eine frisch gebaute EXE ohne Vokabeln startet, `game` und
`language-basic` zieht und danach spielbar ist.

### Phase 3 — Geschützte Packs

14. `src/content/pack_crypto.gd`: PBKDF2 über `Crypto.hmac_digest`,
    Schlüsseltrennung, HMAC-Prüfung **vor** dem Entschlüsseln, AES-256-CBC.
    Iterationszahl messen und in `PACK_FORMAT.md` begründen.
15. Referenz-Prüfer im Content-Repo (`tools/verify_pack.py`) — dasselbe Format
    aus zwei unabhängigen Implementierungen, wie im Vorbild.
16. Kopf-Abruf per `Range`, Code gegen den Verifier prüfen, Ablage in
    `user://codes.cfg` mit `keyVersion`. Ein Code wird gegen **alle** geschützten
    Packs probiert — wer einen Code bekommt, weiß nicht, wozu er gehört.
17. Passwort als Secret im Content-Repo-CI, `language-access2` verschlüsselt
    veröffentlichen.

*Fertig, wenn* ein falscher Code eine benannte Fehlermeldung erzeugt, ein
richtiger die Vokabeln installiert und ein um ein Byte verändertes `.enc` als
manipuliert abgewiesen wird.

### Phase 4 — Selbstersetzende App-Updates

18. Download + Prüfung + Umbenenn-Tanz + Rückrollpfad aus Abschnitt 5;
    `.old`-Aufräumen beim Start.
19. Beide Fehlerwege von Hand durchspielen: schreibgeschütztes Verzeichnis und
    Abbruch mitten im Download.

### Phase 5 — Nacharbeiten

20. `flag_lexeme` nach `user://` umziehen (siehe Konsequenzen).
21. Tests (gdUnit4, `docs/TESTING.md`): Versionsvergleich inkl. Suffixen und
    unlesbaren Angaben, `too_old_for` in beiden Richtungen, Pfad-Prüfung beim
    Auspacken (Zip-Slip, absolute Pfade, Schreiben außerhalb
    `user://content/`), Zustandsabgleich (zurückgezogen / lokal geändert),
    Krypto gegen Vektoren aus `verify_pack.py`, Root-Vorrang in
    `ContentRegistry`. Neue `class_name`-Dateien brauchen `--import` vor dem
    Testlauf.
22. `docs/ARCHITECTURE.md` um den dritten Root und die zwei Kanäle ergänzen;
    `docs/ADDING_CONTENT.md` um „wie kommt neuer Stoff zum Spieler".

## Abweichungen in der Umsetzung

Umgesetzt am 2026-08-31. Was anders kam als oben geplant, und warum:

1. **Pack-Zuordnung über Pfad-Muster statt eines `source`-Feldes je Eintrag.**
   Der Plan wollte jedem Content-Eintrag ein Feld mitgeben, das seine Herkunft
   nennt. Nicht nötig: die Daten liegen ohnehin eine Datei je Quelle, also
   entscheiden Glob-Muster in `packs.yaml` — ohne Migration der bestehenden
   JSONs. Der Preis ist, dass die Zuordnung an den Dateinamen hängt; abgesichert
   ist das fail-closed (keine oder mehrere Zuordnungen brechen den Build ab) und
   durch `protected_books`, das die Lexeme selbst prüft.

   Dabei ist genau der Fehler passiert, gegen den die Prüfung gebaut ist: ein
   `**/*.json` im offenen `game`-Pack hat die geschützten Lexeme mitgenommen,
   weil das Submodule *innerhalb* von `data/` liegt. Der fail-closed-Abgleich hat
   es gemeldet; `packs.yaml` nennt die Kategorien seither einzeln. Als dritte,
   unabhängige Sicherung sieht `tools/packs/check_open_packs.py` in das fertige
   ZIP — sie fängt auch einen Fehler im Build selbst.

2. **Container-Magic `MSPACK`**, Header 108 Byte, MAC bei Offset 76. Im Plan war
   das Format nur skizziert; verbindlich ist jetzt `docs/PACK_FORMAT.md`.

3. **`MAX_ITERATIONS` (5 000 000) beim Lesen des Headers.** Die
   Iterationszahl steht in einer Datei aus dem Netz — ohne Obergrenze wäre ein
   Header mit 2^31 Runden ein Denial-of-Service gegen das eigene Spiel.

4. **`MONSTER_SLAM_PACKS_BASE`** kann die Pack-Quelle umbiegen, **nur in
   Debug-Builds**. Ohne das ist die Kette nicht end-to-end testbar; in einer
   ausgelieferten EXE wäre es eine Einladung, untergeschobene Packs zu laden.
   Aus demselben Grund gibt es in Debug-Builds kein Versions-Tor.

5. **Nur ein Veröffentlicher.** Es gibt genau ein `index.json`, also baut der
   Workflow im Content-Repo auch den `game`-Pack aus dem Hauptrepo und checkt
   dafür beide Repos aus. Eine Änderung an `data/**` im Hauptrepo stößt ihn per
   `repository_dispatch` an (`.github/workflows/data-changed.yml`).

6. **Meldungen (`flag_lexeme`) in `user://lexeme_flags.json`** statt eines Feldes
   in der Quell-JSON (`LexemeFlags`, `src/core/lexeme_flags.gd`). Der Plan nannte
   nur `res://` read-only als Grund; der zweite ist wichtiger: eine veränderte
   Pack-Datei wird vom Installer beim nächsten Update übersprungen — eine Meldung
   hätte künftige Korrekturen dieses Wortes blockiert. Die Signatur von
   `flag_lexeme()`/`flagged_lexemes()` bleibt unverändert, hinzu kommt
   `unflag_lexeme()`.

7. **Version auf 0.2.0 gezogen.** `min_app_version` der Packs ist `0.2.0`; eine
   0.1.0-EXE würde jeden Pack als `APP_OUTDATED` blockieren.

**Noch offen:** die Repos und Secrets existieren noch nicht (Transport-Repo
`pesse/monster-slam-packs`; Secrets `RELEASE_SIGNING_KEY`, `PACK_PW_ACCESS2`,
`PUBLIC_RELEASE_TOKEN`, `CONTENT_DISPATCH_TOKEN`). Ob `language-basic` wirklich
offen verteilt werden darf, ist eine inhaltliche Entscheidung — Belege in
`docs/CONTENT_GENERATION_RUNS.md` (Lauf #1).
