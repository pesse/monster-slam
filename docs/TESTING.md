# Testing

Framework: **gdUnit4** (vendored unter `addons/gdUnit4/`, aktiviert in `project.godot`).
Testdateien liegen in `tests/` und enden auf `_test.gd` (`extends GdUnitTestSuite`).

## Ausführen (headless)

```bash
tools/godot.sh -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
```

Immer über den Wrapper, nie Godot direkt: er setzt `--headless` und den Projektpfad und
setzt hinterher Dateien zurück, deren Einrückung der Editor-Cache umgeschrieben hat. Neue
`class_name`-Dateien brauchen vorher `tools/godot.sh --import`.

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

## Hygiene: `user://` ist geteilt

`user://` ist für jeden Lauf mit dem Editor-Binary — Editor, `tools/godot.sh`, Tests —
dasselbe Verzeichnis, `%APPDATA%\Monster Slam (Entwicklung)`. Die installierte EXE hat ein
eigenes (`%APPDATA%\Godot\app_userdata\Monster Slam`); das stellen die `.editor`-Schlüssel
in `project.godot` ein. Die Dateien des aktiven Entwicklungsprofils sind trotzdem das Gold,
die Erfahrung und die Spur dessen, der im Editor spielt.

- **Autoloads mit Profildateien werden auf einer eigenen Instanz mit `zz-`Profil geprüft**,
  und der Test räumt seine Datei weg: `Wallet` (`tests/wallet_test.gd`), `PlayerLevel`,
  `SkillBook`, `TraceLog`. `SkillBook` bekommt dazu über eine Unterklasse einen erfundenen
  Baum (`entries()` überschrieben), sonst hinge der Test an der Balance der ausgelieferten
  Bäume. Weil `respec()`/`available()` an die Autoloads `Wallet` und `PlayerLevel` gehen,
  bekommen auch die für die Dauer des Tests ein `zz-`Profil. Ein Screen, der ein Autoload
  benutzt, nimmt dafür ein Feld entgegen, das vor dem Einhängen gesetzt wird (`book`).
- **Ein `-s`-Skript, das die Geldbörse umbiegt**, muss wissen: `Wallet._ready()` setzt
  `player_id` aus `UserSettings` und läuft NACH `_initialize()` — eine früher gesetzte
  Test-Id ist danach wieder weg.
- **`TraceLog` schweigt unter gdUnit** (`_under_test()`): andere Suiten feuern
  EventBus-Signale und schrieben sonst erfundene Wellen in die echte Spur.
- **Kein Test fährt eine ganze Welle**, um das Verbuchen von Gold oder Erfahrung zu prüfen —
  geprüft werden die Regeln (`ChestReward`, `Experience`) und die Instanzen.
- **Fixture-Packs brauchen eine Id, die zuletzt sortiert** (`zz-…`): Packs werden nach Id
  sortiert, der letzte gewinnt, und auf einem Rechner mit installierten Inhalten gewönne
  sonst `game` oder `language-*`.
- **Nach einem Test, der Packs installiert, `user://content` aufräumen** — ein liegen
  gebliebener Pack überschreibt im Entwicklungslauf das Submodule.
- **Fixtures liegen unter `tests/fixtures/`**, das `.gitattributes` von jeder
  Zeilenenden-Umwandlung ausnimmt: Prüfsummen und Signaturen gehen über die exakten Bytes.

## Kopflose Grenzen

- **Godot befördert headless keine Mausereignisse**, `gui_get_hovered_control()` ist im
  Test immer leer. Die Naht ist `Hints.probe(control, at)`; sie zeigt die Karte nur bis zum
  nächsten Frame, Tests dazu stehen deshalb ohne `await`.
- **Vektoren achsenweise vergleichen.** `assert_vector(...).is_less_equal(...)` vergleicht
  lexikografisch — eine zu hohe Seite rutscht über eine passende Breite durch.
- **Randlayout gegen die Grundauflösung 1152×648 prüfen**, nicht gegen das eigene Fenster:
  das Vollbild auf 16:9 ist der schmalste Fall (`tests/hud_header_test.gd`).

## Neuen Test hinzufügen

`tests/<name>_test.gd` anlegen, `extends GdUnitTestSuite`, Testmethoden `test_*`,
Assertions via `assert_bool/assert_int/assert_str/assert_array/assert_that`. Optional
`before_test()` / `after_test()` für Setup pro Testfall.
