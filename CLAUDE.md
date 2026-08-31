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
