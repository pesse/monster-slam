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

## Neuen Test hinzufügen

`tests/<name>_test.gd` anlegen, `extends GdUnitTestSuite`, Testmethoden `test_*`,
Assertions via `assert_bool/assert_int/assert_str/assert_array/assert_that`. Optional
`before_test()` / `after_test()` für Setup pro Testfall.
