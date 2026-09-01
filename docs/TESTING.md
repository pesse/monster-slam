# Testing

Framework: **gdUnit4** (vendored unter `addons/gdUnit4/`, aktiviert in `project.godot`).
Testdateien liegen in `tests/` und enden auf `_test.gd` (`extends GdUnitTestSuite`).

## Ausführen (headless)

```bash
GODOT="/mnt/c/dev/_tools/godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path "C:/dev/privat/monster-slam" \
    -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
```

Exit-Code 0 = grün, ≠0 = Fehler (CI-tauglich). Report unter `reports/` (git-ignoriert).
`--ignoreHeadlessMode` ist nötig, weil gdUnit4 sonst wegen fehlender Input-Events abbricht —
für Logik-/Datentests ohne UI-Interaktion unproblematisch.

## Strategie

Testbarkeit entsteht durch **Trennung von Logik und Nodes**:

1. **Reine Logik in `RefCounted`-Klassen** (`AnswerEvaluator`, `TaskResolver`,
   `SpacedRepetition`) — direkt mit `.new()` instanziierbar, kein SceneTree nötig.
   Schnelle, deterministische Unit-Tests. Das ist der Standardfall (siehe
   `tests/answer_evaluator_test.gd` als Muster).
2. **Autoloads** (`ContentRegistry`, `PlayerProgress`) sind globaler Zustand. Wo eine
   Logik-Klasse davon abhängt (z. B. `TaskResolver` im `de_to_en`-Pfad für Synonyme),
   im Test die echten Daten laden oder ein Double injizieren. Autoload-freie Pfade
   (`en_to_de`) brauchen nichts davon.
3. **Szenen/Node-Verhalten** nur wo nötig über gdUnit4s `scene_runner()` (Frames
   vorspulen, Signale abwarten) — teurer, für zeitgesteuerte Wellen-Spawns gedacht.
4. **Datenvalidierung**: JSON-Content gegen Konventionen prüfen
   (`tests/lexeme_data_test.gd`), damit Generierungsläufe keine kaputten Daten einschleusen.

## Tests, die Sprachdaten brauchen

`data/language/` ist ein privates Submodule und wird im CI des öffentlichen Hauptrepos
**nicht** ausgecheckt — die verteilte EXE darf das Lehrbuchmaterial nicht enthalten, also
hat der Build es auch nicht. Ein Test, der auf konkreten Vokabeln besteht
(„`access2` ist unter `all_books()`"), kann dort nicht laufen.

Solche Tests überspringen sich selbst, statt rot zu werden:

```gdscript
func test_all_books_contains_access2(
		do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
```

`tests/language_data.gd` prüft dafür das Verzeichnis, nicht `ContentRegistry.lexemes` —
unabhängig davon, ob der Autoload schon geladen hat.

Wichtig ist die Auswahl: markiert wird nicht nur, was **rot** würde, sondern auch, was ohne
Daten **stillschweigend durchläuft** — eine leere Liste, über die eine Schleife nicht
iteriert, ist ein falsches Grün und schlechter als ein sichtbares `skipped`. Ein Test, der
ohne Sprachdaten echte Aussagekraft behält (`lexemes_scoped(["nope/1"], [])` ist leer,
`task_definitions` liegen im öffentlichen `data/`), bleibt unmarkiert.

Sind **alle** Tests einer Suite datenabhängig, die Suite überspringen statt jeden Test
einzeln — bei einer Suite, deren einziger Test übersprungen wird, lässt gdUnit einen
Orphan-Node zurück, und der Lauf endet mit Exit-Code 101 (Warnung):

```gdscript
func before(do_skip := LanguageData.missing(), skip_reason := LanguageData.REASON) -> void:
	pass
```

Lokal mit ausgechecktem Submodule laufen alle 117 Fälle; ohne 99, der Rest als `skipped`.
Nachstellen lässt sich der CI-Zustand mit einem Clone ohne `git submodule update --init`.

## Neuen Test hinzufügen

`tests/<name>_test.gd` anlegen, `extends GdUnitTestSuite`, Testmethoden `test_*`,
Assertions via `assert_bool/assert_int/assert_str/assert_array/assert_that`. Optional
`before_test()` / `after_test()` für Setup pro Testfall.
