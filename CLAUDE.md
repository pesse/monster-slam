# Monster Slam — Claude Code notes

## Running the game headless (to read logs/errors directly)

Godot 4.7 project. Godot is installed on Windows at `C:\dev\_tools\godot`.
Always use the **console** build — the plain `.exe` is GUI-only and prints
nothing to stdout/stderr; the `_console.exe` build does, so logs are captured
from WSL.

```bash
GODOT="/mnt/c/dev/_tools/godot/Godot_v4.7-stable_win64_console.exe"

# Quick parse/load check (quits after 60 frames):
"$GODOT" --headless --path "C:/dev/privat/monster-slam" --quit-after 60 2>&1 | tr -d '\r'

# Longer run to exercise runtime/spawns (kill after N seconds):
timeout 14 "$GODOT" --headless --path "C:/dev/privat/monster-slam" 2>&1 | tr -d '\r'
```

Notes:
- Pass the **Windows-style** `--path` (`C:/...`), not the WSL `/mnt/c` path.
- Pipe through `tr -d '\r'` to strip Windows CRLF.
- Physics runs at real-time 60 Hz even when headless, so `SceneTreeTimer`-based
  spawns fire on wall-clock time — run long enough to observe them.
- Use this to verify GDScript changes end-to-end before reporting them as working.

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

## Drei Fallen, die schon zugeschlagen haben

**`--import` schreibt offene Markdown-Dateien um.** Sind `.md`-Dateien im Godot-Skript-
editor offen (gemerkt in `.godot/editor/script_editor_cache.cfg`, `editor_layout.cfg`,
`project_metadata.cfg`), speichert Godot sie beim Import mit — und wandelt dabei führende
Leerzeichen in Tabs. In Markdown macht das aus Fortsetzungszeilen Codeblöcke. Nach jedem
`--import` also `git status` prüfen; unerwartete `.md`-Änderungen sind das, nicht deine.
Dauerhaft weg ist es, wenn keine `.md` im Editor offen ist — `.godot/editor/` löschen
setzt Docklayout und offene Tabs zurück und behebt es (Verzeichnis ist regenerierbar).

**Fixtures dürfen keine Zeilenenden-Umwandlung sehen.** `tests/fixtures/update/payload.bin`
ist ASCII, aber Prüfsumme *und* Signatur gehen über genau diese Bytes; auf einem
Windows-Runner (`core.autocrlf=true`) machte git aus dem LF ein CRLF und fünf Tests fielen
um. `.gitattributes` nimmt `tests/fixtures/**` deshalb von jeder Umwandlung aus. Neue
Fixtures dort ablegen, nicht daneben.

**Tests müssen neben echten Packs gelten.** `user://` ist projektübergreifend dasselbe
Verzeichnis, und Packs werden nach Id sortiert — der letzte gewinnt. Ein Fixture-Pack
braucht deshalb eine Id, die zuletzt sortiert (`zz-…`), sonst gewinnt auf einem Rechner mit
installierten Inhalten `game` oder `language-*` und der Test wird grundlos rot.
