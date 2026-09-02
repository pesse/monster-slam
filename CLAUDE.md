# Monster Slam — Claude Code notes

## Running the game headless (to read logs/errors directly)

Godot 4.7 project. **Immer über `tools/godot.sh` aufrufen, nie direkt.** Der Wrapper
kennt den Godot-Pfad, setzt `--headless` und die Windows-Schreibweise des Projektpfads
und nimmt hinterher zurück, was der Editor an offenen Dateien anrichtet (siehe unten).

```bash
# Parse-/Ladeprüfung (beendet sich nach 60 Frames):
tools/godot.sh --quit-after 60

# Import (nötig, wenn neue class_name-Dateien dazugekommen sind):
tools/godot.sh --import

# Testsuite:
tools/godot.sh -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests

# Längerer Lauf, um Spawns zu beobachten:
timeout 14 tools/godot.sh
```

Notes:
- Godot-Pfad per `GODOT=... tools/godot.sh …` überschreibbar. Der Wrapper besteht auf dem
  **Konsolen**-Build: die schlichte `.exe` ist GUI-only und schreibt nichts auf stdout.
- CRLF strippt der Wrapper bereits, ein eigenes `tr -d '\r'` ist unnötig.
- Physics läuft auch headless in Echtzeit mit 60 Hz, `SceneTreeTimer`-Spawns feuern also
  nach Wanduhr — lange genug laufen lassen, um sie zu sehen.
- Damit GDScript-Änderungen end-to-end prüfen, bevor sie als funktionierend gemeldet werden.

## Sprachdaten liegen in einem privaten Submodule

Das Hauptrepo (`pesse/monster-slam`) ist **public**. Vokabel- und Satzdaten sind
aus urheberrechtlich geschütztem Lehrbuchmaterial (Cornelsen *Access 2* u. a.)
abgeleitet und dürfen **nicht** dorthin — sie liegen im privaten Repo
`pesse/monster-slam-content`, eingehängt als Submodule unter `data/language/`.

- **Sprachdaten** (`lexemes`, `lexeme_forms`, `lexeme_relations`, `sentences`,
  `sentence_lexemes`) → `data/language/…` → Commit/Push **im Submodule**,
  danach den neuen Submodule-Pointer im Hauptrepo committen.
- **Spielkonfiguration** (`monsters`, `bosses`, `waves`, `skills`,
  `task_definitions`, `monster_task_rules`) → `data/…` → Hauptrepo.
- `raw/` (Buchscans/-fotos) ist gitignored und gehört in **kein** Repo.

Vor dem Commit im Hauptrepo prüfen, dass keine Lemmata/Wortlisten in Code, Docs
oder Reports gelandet sind. Schema-Beispiele mit einzelnen Allerweltswörtern sind ok.

## Ausliefern: EXE ohne Sprachdaten, Inhalte als Packs

`data/language/*` steht im `exclude_filter` des Export-Presets — die verteilte EXE
enthält **keine** Vokabeln und holt sie als Content-Packs nach
`user://content/<pack-id>/`. Das ist der Grund, aus dem es die Pack-Mechanik gibt;
Entscheidung und Begründung in `docs/adr/0001-app-und-content-update.md`, Dateiformat
in `docs/PACK_FORMAT.md`.

Beim Arbeiten daran zu beachten:

- **Kategorien stehen an drei Stellen** und müssen übereinstimmen: `_by_category` in
  `src/core/content_registry.gd`, `CATEGORIES` in `src/content/pack_installer.gd`,
  `CATEGORIES` in `tools/packs/build_packs.py`. Eine neue Kategorie in nur einer davon
  heißt: der Pack liefert sie aus, der Installer verwirft sie (oder umgekehrt).
- **Jede Datei unter `data/` braucht eine Zuordnung** in `data/language/packs.yaml`.
  Der Pack-Build ist fail-closed: keine oder mehrere Zuordnungen brechen ab. Nach dem
  Anlegen einer neuen Datei prüfen mit
  `python3 tools/packs/build_packs.py --config data/language/packs.yaml --dry-run`.
- **Nie ein Glob, das `data/**` unter `data/language/` mitnimmt.** Das Submodule liegt
  *innerhalb* von `data/`; ein `**/*.json` im offenen `game`-Pack hat genau deshalb
  einmal die geschützten Lexeme eingesammelt. Kategorien einzeln angeben.
- **`user://` ist der einzige beschreibbare Ort.** `res://` ist im Export read-only:
  Spielerdaten (Fortschritt, Einstellungen, Meldungen via `LexemeFlags`) gehören nach
  `user://`, nicht in die Quell-JSON.
- **Nach einem Test, der Packs installiert, `user://content` aufräumen** — ein
  liegengebliebener Pack überschreibt im Entwicklungslauf das Submodule.
- **Der private Signierschlüssel** gehört ausschließlich in das GitHub-Secret
  `RELEASE_SIGNING_KEY`; `*.pem` ist gitignored. Der öffentliche Schlüssel steht
  bewusst als Konstante in `src/update/release_key.gd`.

## Melde-Rückkanal: das Geheimnis liegt nur auf dem Server

Meldungen („dieses Wort ist falsch") gehen über einen eigenen PHP-Endpunkt zurück
(`server/melden/`, Autoload `ReportService`, ADR `docs/adr/0002-melde-rueckkanal.md`).
Beim Arbeiten daran:

- **Das HMAC-Geheimnis gehört ausschließlich in `ms-secret.php` über dem Docroot** — nicht
  ins Repo, nicht in ein GitHub-Secret, nicht in eine Konstante. Geprägte Token teilt man
  mit, man committet sie nicht (`.gitignore`). Öffentlich ist nur die Endpunkt-URL, so wie
  die Manifest-URL des App-Kanals.
- **Das Token-Format hat zwei Implementierungen**: `tools/report/mint_token.py` prägt,
  `server/melden/token.php` prüft. Eine Änderung ist eine Änderung an beiden Stellen, und
  beide Seiten haben dieselben Vektoren: `mint_token.py --self-test` und
  `php server/melden/verify_token.php --self-test` müssen übereinstimmen.
- **Ohne Token kein „Melden"** — der Knopf im Reveal und die Liste im Einstellungs-Screen
  erscheinen dann nicht. Bedienungsentscheidung, keine Schranke; die sitzt im Endpunkt.
- **Gemeldet wird erst lokal, gesendet danach.** Ein Netzfehler ist ein Zustand: die
  Meldung bleibt in `user://lexeme_flags.json` offen (`sent: false`) und geht beim nächsten
  Start mit.

## Drei Fallen, die schon zugeschlagen haben

**Godot-Läufe schreiben offene Dateien um — dagegen gibt es `tools/godot.sh`.** Welche
Dateien im Skripteditor offen sind, merkt sich `.godot/editor/script_editor_cache.cfg`;
Godot lädt und speichert sie bei jedem Lauf mit, auch headless, und normalisiert dabei
ihre Einrückung auf Tabs (`text_editor/behavior/indent/type=0` plus Godots Standard
`convert_indent_on_save=true`). Für `.gd` ist das gewollt, sonst nirgends: in Markdown
werden aus eingerückten Fortsetzungszeilen Codeblöcke, in Spieldaten-JSON ändern sich
zehn Zeilen ohne Grund. Betroffen waren hier schon `docs/*.md`, `data/bosses/*.json` —
und `data/language/README.md`, also das private Submodule.

`tools/godot.sh` setzt nach dem Lauf genau die Dateien zurück, die vorher sauber waren
**und** sich nur in der Einrückung unterscheiden; alles andere meldet es und lässt es
liegen. Deshalb Godot nie direkt aufrufen. Wer es an der Wurzel abstellen will, setzt in
den Godot-Editor-Einstellungen `text_editor/behavior/files/convert_indent_on_save` auf
`false` — das gilt aber nur für den eigenen Rechner, der Wrapper gilt für alle.

**Fixtures dürfen keine Zeilenenden-Umwandlung sehen.** `tests/fixtures/update/payload.bin`
ist ASCII, aber Prüfsumme *und* Signatur gehen über genau diese Bytes; auf einem
Windows-Runner (`core.autocrlf=true`) machte git aus dem LF ein CRLF und fünf Tests fielen
um. `.gitattributes` nimmt `tests/fixtures/**` deshalb von jeder Umwandlung aus. Neue
Fixtures dort ablegen, nicht daneben.

**Tests müssen neben echten Packs gelten.** `user://` ist projektübergreifend dasselbe
Verzeichnis, und Packs werden nach Id sortiert — der letzte gewinnt. Ein Fixture-Pack
braucht deshalb eine Id, die zuletzt sortiert (`zz-…`), sonst gewinnt auf einem Rechner mit
installierten Inhalten `game` oder `language-*` und der Test wird grundlos rot.
