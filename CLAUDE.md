# Monster Slam — Hinweise für Claude Code

Godot 4.7, GDScript, Tests mit gdUnit4. Architektur und Begründungen: `docs/ARCHITECTURE.md`
und `docs/adr/`; Inhalte: `docs/ADDING_CONTENT.md`; Tests: `docs/TESTING.md`; was der
Spieler sieht: `docs/handbuch/` (je Kapitel eine Datei, `README.md` ist der Inhalt).

## Befehle

**Godot immer über `tools/godot.sh`, nie direkt** (Grund: siehe „Fallen").

```bash
tools/godot.sh --quit-after 60   # Parse-/Ladeprüfung
tools/godot.sh --import          # nötig nach neuen class_name-Dateien, sonst „Identifier not declared"
tools/godot.sh -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
timeout 14 tools/godot.sh        # längerer Lauf, z. B. um Spawns zu sehen
GODOT_WINDOW=1 tools/godot.sh res://scenes/dev/battle_theme_lab.tscn -- --shoot  # rendert Bilder (headless geht nicht)

# Pack-Zuordnung prüfen (nach jeder neuen Datei unter data/):
python3 tools/packs/build_packs.py --config data/language/packs.yaml \
  --source language=data/language --source game=data --dry-run

# PHP nur im Container:
tools/report/php.sh server/melden/test_endpoint.php

# Windows-EXE → exports/MonsterSlam-<version>.exe, macOS → exports/MonsterSlam-<version>-macos.zip
# (ADR 0015); die Version steht nur in project.godot (config/version), build.sh gleicht
# export_presets.cfg daran an:
./build.sh            # beide; ./build.sh windows | macos für eins
```

- Der Wrapper braucht den **Konsolen**-Build (`GODOT=… tools/godot.sh` überschreibt den
  Pfad) und strippt CRLF schon selbst.
- Physik und `SceneTreeTimer` laufen headless nach Wanduhr — lange genug laufen lassen.
- GDScript-Änderungen end-to-end prüfen, bevor sie als funktionierend gemeldet werden.
- **Editor und EXE haben getrennte `user://`**: jeder Lauf mit dem Editor-Binary (auch
  `tools/godot.sh`, Tests, CI) nutzt `%APPDATA%\Monster Slam (Entwicklung)`, die
  installierte EXE `%APPDATA%\Godot\app_userdata\Monster Slam`
  (`config/use_custom_user_dir.editor` in `project.godot`). Nie auf die Basis-Schlüssel
  ausweiten — sonst zieht die EXE mit und verliert die Profile der Spieler.
- **Ein echter Kampf headless spielt im aktiven Entwicklungsprofil** und schreibt Lernstand,
  Sitzungen und Spur. Nicht tun, oder in einem `zz-`-Profil.
- **Nie eine Datei aus einer Sicherung pauschal nach `user://` zurückspielen.** Der Nutzer
  spielt oft parallel, die Spur ist offen und wird angehängt — ein `cp` hat schon eine
  laufende Sitzung überschrieben (NUL-Bytes in der Spur). Nur eigene Zeilen oder Dateien
  gezielt entfernen, vorher prüfen, ob Godot läuft (`tasklist.exe | grep -i godot`).
- **Löschen nur einzeln benannt**, nie mit Wildcard (`rm dir/*.png`), auch im Scratchpad.

## Was in welches Repo gehört

Das Hauptrepo `pesse/monster-slam` ist **öffentlich**. Vokabel- und Satzdaten stammen aus
urheberrechtlich geschütztem Lehrbuchmaterial und liegen im privaten Submodule
`data/language/` (`pesse/monster-slam-content`).

- Sprachdaten (`lexemes`, `lexeme_forms`, `lexeme_relations`, `sentences`,
  `sentence_lexemes`) → im Submodule committen und pushen, danach den Pointer im Hauptrepo.
- Spielkonfiguration (`monsters`, `bosses`, `waves`, `skills`, `spells`,
  `task_definitions`, `monster_task_rules`) → Hauptrepo.
- `raw/` (Buchscans) gehört in **kein** Repo.
- **Vor jedem Commit im Hauptrepo:** keine Wortlisten, Lexem- oder Satzdaten in Code,
  Docs, Tests oder Reports. Einzelne Vokabeln sind urheberrechtlich frei — Beispiele,
  Konzeptbilder, Screenshots und Test-Prompts mit einzelnen Wörtern sind immer ok;
  geschützt ist die Sammlung (Listen, Unit-Zuordnungen, Sätze).
- Nur lokal, nie committen: `assets/maps/*/drafts/` (steht in `.git/info/exclude`).
- Jeder Content-Generierungslauf (Vokabeln, Formen, Relationen, Sätze) bekommt einen
  Eintrag und eine Tabellenzeile in `docs/CONTENT_GENERATION_RUNS.md` (Ansatz, Modell,
  Agenten, Ergebnis). Kosten werden nicht erfasst: generiert wird über das Abo auf dem
  stärksten Modell, der Qualität wegen.
- Die Spur (`user://logs/*_trace.jsonl`) enthält getippte Kindertexte und Lemmata — sie
  verlässt den Rechner nicht.

## Geheimnisse

- Release-Signierschlüssel: nur im GitHub-Secret `RELEASE_SIGNING_KEY` (`*.pem` ist
  gitignored). Der öffentliche Schlüssel steht absichtlich in `src/update/release_key.gd`.
- HMAC-Geheimnis des Melde-Endpunkts: nur in `ms-secret.php` über dem Docroot — nicht ins
  Repo, kein GitHub-Secret, keine Konstante. Geprägte Token werden nicht committet.

## Release-Notes

Die Beschreibung eines GitHub-Releases ist der Text im Update-Dialog. Der Dialog zeigt
**alle** Releases, die seit der installierten Fassung dazukamen (Manifest trägt die der
letzten 7 Tage, mindestens 3; `tools/release/release_history.sh`) — bei mehreren Releases
am Tag liest ein Kind schnell zehn davon hintereinander. Deshalb kompakt: je Neuerung ein
fetter Titel und ein, zwei Sätze aus Spielersicht, keine technischen Details, keine
Aufzählung von Kleinkram; unter ~600 Zeichen je Release.

## Harte Regeln

**Packs** (`docs/PACK_FORMAT.md`, ADR 0001) — die EXE enthält keine Sprachdaten:
- Kategorien stehen an **vier Stellen** und müssen übereinstimmen: `_by_category` in
  `src/core/content_registry.gd`, `CATEGORIES` in `src/content/pack_installer.gd` und in
  `tools/packs/build_packs.py`, dazu die `roots`/`include`-Blöcke in
  `data/language/packs.yaml` (ADR 0003).
- Jede Datei unter `data/` braucht **genau eine** Zuordnung in `data/language/packs.yaml`
  (der Build bricht sonst ab).
- **Nie ein Glob, der unter `data/language/` greift** — das Submodule liegt in `data/`;
  ein `**/*.json` im `game`-Pack hat schon einmal die geschützten Lexeme eingesammelt.
- Ein Pack, der ein Feld ausliefert, das ältere Clients nicht kennen, hebt sein
  `min_app_version`.

**Laufzeit:**
- `user://` ist der einzige beschreibbare Ort; `res://` ist im Export read-only.
- Gespeichert wird nur der Ursprungswert, alles Abgeleitete wird gerechnet (`total_xp`
  statt Level, gelernte Knoten statt ausgegebener Punkte). Kein zweiter Zähler daneben.
- Schwierigkeit hat **ein** Maß: `t - c` in `WaveGenerator._build_plan`. Tempo, Punkte und
  Erfahrung sind Projektionen davon; kein eigenes Maß daneben bauen.
- `TraceLog` hängt nur am EventBus und wirkt nie zurück. Braucht die Spur ein neues
  Ereignis, bekommt der EventBus ein Signal. Felder der Spur und der Pack-Formate kommen
  dazu, sie werden **nicht umbenannt**.
- `Engine.time_scale` gehört `SlowMotion`; wer das Tempo ändern will, tut es dort.
- Token-Format des Melde-Kanals hat zwei Implementierungen (`tools/report/mint_token.py`,
  `server/melden/token.php`): jede Änderung an beiden, beide `--self-test` müssen passen.
- Marker in den von `tools/report/to_issues.py` angelegten Issues nicht löschen.

**Festung: eine Stufe je Unit** (Issue #21, `src/progression/fortress_tier.gd`):
- Die Stufe misst den Anteil gemeisterter **Wörter** einer Unit (beide Richtungen,
  `PlayerProgress.masterable` im Nenner), Schwellen 10/32/53/75 %, +25 HP je Stufe.
- Ein Verb mit `irregular: true` ist erst mit seinen Formaufgaben gemeistert (ADR 0009,
  `ContentRegistry.form_requirements`), außer Bonus-Formen (ADR 0012) — in jeder Sprache;
  neue unregelmäßige Verben bekommen das Feld beim Erzeugen. Keine Zusatzbedingung für
  Stufe 4.
- Im Kampf gilt die schwächste Unit des Scopes; ein Teil-Scope oder Tag-Filter wertet die
  **ganze** Unit. Gezählt wird nur in `FortressTier.unit_tiers` — `StatsScreen.unit_rows`
  baut darauf auf, keine zweite Zählregel.
- Der HP-Bonus geht in dasselbe `max_health` wie `SkillBook.bonuses()`; ein Anstieg mitten im
  Lauf über `GameState.grow_fortress`. Das Debug-Panel baut nur das Bild um.

**Karte und Laufanfrage** (ADR 0006, `docs/ARCHITECTURE.md` „Karte und Laufanfrage"):
- Kampf und Boss lesen Scope, Tags und Aufgabenpool über `RunRequest`, **nie** direkt aus
  `UserSettings` — sonst spielt ein Level mit alten Expertenmodus-Filtern.
- Kein gespeicherter Level-Abschluss und keine Sperre: die Stufe eines Levels kommt aus
  `FortressTier.part_tiers`/`unit_tiers`. Gespeichert werden nur Boss-Siege (`BossRecord`).
- Kartenbilder und Punkte liegen unter `assets/maps/<book>/` in der EXE (kein Pack);
  gezeichnet wird nur in `MapCanvas`, Punkte setzt `scenes/dev/map_lab.tscn`. Bilder ohne
  Schrift und ohne Vokabeln; Low-Poly-Hex-Brett wie die Kampfmodelle, je Buch ein eigenes
  Thema. Die Bilder entstehen außerhalb dieses Repos.
- Es gibt keinen Grundwortschatz mehr: jedes Lexem trägt `book` und `unit`.
- Jede Unit mit Gebietsbild nennt unter `themes` in `map.json` ein `BattleTheme`
  (`assets/battle_themes/`) — der Kampf steht in der Landschaft der Karte. Ein Stop mit
  anderer Umgebung (Siedlung, Stadtpark) bekommt ein eigenes über
  `{ "default": …, "<key>": … }`; das Licht teilt er über `light_from` mit der Unit. Farben am Bild
  der Werkbank abstimmen (`battle_theme_lab`), nicht an den Zahlen. Deko-Modelle eines
  Themas liegen unter `assets/models/`; eigene baut `src/dev/model_forge.gd` in der Größe
  ihres Platzes (Vergleich: `-- --specimens`). Bodentexturen sind grau und kacheln
  (8 × 8 m); was gemalt wird, steht in `assets/textures/ground/BRIEF.md` — eine neue
  Textur zuerst dort bestellen.

**Satzbewertung und Boss** (ADR 0004, `docs/ARCHITECTURE.md` „Sätze bewerten"):
- Ein Treffer in `accepted` schlägt jede Stolperstelle; ohne Schlüsseltreffer gibt die
  Prüfkarte **kein** Urteil, und die Nähe (`overlap`) ist nie eine Güte.
- Stufe 1 darf nur heben, nie senken, und spricht nur mit `127.0.0.1`. Wo sie nicht hebt,
  erklärt ein zweiter Aufruf ohne Schlüssel; findet er keinen Fehler, gibt es keine
  Erklärung (ADR 0005). Die Begründung des Urteils wird nie gezeigt.
- Prompts (`StageOnePrompts`) und Regelkatalog (`GrammarRules`) werden in der Werkstatt
  `prompt-eval` geändert und gemessen und erst dann wörtlich übernommen.
- Ein Boss trägt keine Sätze, sondern eine `sentence_rule` — Sätze liegen im Submodule.
- Die Normalisierung gibt es einmal (`AnswerEvaluator.tokens()`), das Auswahlmaß ist `t - c`.
- Sätze gibt es je Unit (`sentences/en_<band>_unit<n>.json`), erzeugt nach
  `docs/prompts/sentence_generation.md`: deutscher Satz, `grammar_tags` und Musterlösung
  tragen dieselbe Form, und Tags nur aus `GrammarRules.RULES`.
- Neue Felder am Satz heben `min_app_version` **an den Access-Paketen** (derzeit 0.10.0),
  nicht global. Erst die App veröffentlichen, dann im Content-Repo nach `main`.
- Kein Test startet `llama-server` oder spricht mit einem Dienst.

**Oberfläche:**
- Statische UI als `.tscn` im Editor-Format, nicht im Code. Was zur Laufzeit in
  variabler Zahl entsteht, kommt aus einer `.tscn`-Vorlage für ein Element (`instantiate()`).
- Im Kampf-HUD keine Hinweise (kein `Hints.attach`): gespielt wird meist ohne Maus.
  Erklärungen gehören in den Bestätigungsdialog; XP steht nur als Ring da.
- Raum und Typografie nur aus `scenes/ui/ui_theme.tres` über `theme_type_variation` —
  kein `theme_override_…`, keine `add_theme_*_override`. Abstände nur 0/4/8/16/24. Kein
  MarginContainer in einem PanelContainer; in jeden ScrollContainer ein `Gutter`.
  (`tests/theme_discipline_test.gd`)
- Erklärungen nur über `Hints.attach` / `Hints.attach_live`, **nie `tooltip_text`**;
  am kleinsten Knoten anmelden, nie an einer Screen-Wurzel. (`tests/hint_discipline_test.gd`)
- Dialoge als Overlay (`ConfirmDialog`), kein Godot-`Window` — das skaliert nicht mit.
- Die Bezugsgröße (`content_scale_size`) setzt nur `UiScale.apply` (ADR 0017); wer mehr
  Platz braucht, hebt `UiScale.floor_size`.
- Randlayout gegen **1152×648** prüfen (siehe „Fallen"); die Kopfleiste ist voll
  (`tests/hud_header_test.gd`), Neues gehört woandershin.
- Ein Screen, der in der Bildmitte hängt, ändert seine Größe nicht, solange er sichtbar
  ist: sperren und umbeschriften statt ein-/ausblenden; Inhaltsentscheidungen vor dem
  Anzeigen.
- Entwickler-Werkbänke liegen unter `scenes/dev/`, `src/dev/` (im Export ausgeschlossen),
  nie als Knopf im Startmenü. Jede Taste einer Werkbank hat auch einen Knopf.

## Tests

- `user://` ist für alle Editor-Läufe dasselbe Verzeichnis und enthält das Entwicklungsprofil.
  Tests auf Wallet, PlayerLevel, SkillBook, TraceLog laufen auf eigenen Instanzen mit
  `zz-`-Profil und räumen ihre Dateien weg. Fixture-Packs bekommen eine `zz-`-Id (Packs
  werden nach Id sortiert, der letzte gewinnt).
- Nach einem Test, der Packs installiert, `user://content` aufräumen — ein
  liegengebliebener Pack überschreibt im Entwicklungslauf das Submodule.
- Kein Test fährt eine ganze Welle.
- Neue Fixtures nach `tests/fixtures/` (dort ist jede Zeilenenden-Umwandlung aus).
- Größen je Achse prüfen: `assert_vector(...).is_less_equal(...)` vergleicht lexikografisch.

## Fallen

- **Godot schreibt offene Dateien um.** Jeder Lauf, auch headless, lädt und speichert die
  im Skripteditor offenen Dateien und stellt ihre Einrückung auf Tabs um — auch Markdown,
  JSON und Dateien im Submodule. `tools/godot.sh` setzt reine Einrückungsänderungen danach
  zurück und meldet alles andere. Der offene GUI-Editor des Nutzers schreibt auch
  Sekunden später noch nach — vor jedem Commit `git diff -w --stat` gegen
  `git diff --stat` halten und reine Einrückungsänderungen zurücksetzen.
- **Das Vollbild ist der schmalste Fall.** `canvas_items`/`expand` dehnt die längere Achse;
  ein maximiertes Fenster ist breiter als 1152, das Vollbild auf 16:9 bei großer Menügröße
  nicht. Was im Fenster passt, kann im Vollbild abgeschnitten sein.
- **Ein umbrechendes Label meldet als Mindestgröße 1 px Breite und die Höhe dafür.** Wo
  keine echte Breite ankommt (unsichtbare Seite im `PageStack`, von Hand gesetzte
  Kartengröße), braucht es `custom_minimum_size.x` oder die Breite vor dem Messen.
- **Geladene Ressourcen sind geteilt.** Ein Mesh oder Material aus dem Cache zu ändern
  trifft jede andere Instanz; erst kopieren.
- **Der Renderer ist `gl_compatibility`**: `GeometryInstance3D.transparency` gibt es dort nicht.
- **Der erste Auftritt eines Effekts übersetzt Shader** und hält das Bild an (kalt bis 1,5 s).
  Kampf und Boss zeigen deshalb hinter dem geschlossenen Schleier alles einmal (`FxWarmup`);
  ein neuer Effekt, ein neues Material oder eine neue Schriftgröße im Kampf gehört dort
  hinein. Messen: `battle_theme_lab -- --hitches [--warm]` mit leerem `user://shader_cache`.
- **Kopflos gibt es keine Mausereignisse** — `gui_get_hovered_control()` ist im Test leer;
  dafür gibt es `Hints.probe`.
- **Ein Autoload läuft nach `_initialize()` eines `-s`-Skripts** — eine dort gesetzte
  Test-Id (z. B. `Wallet.player_id`) ist danach wieder überschrieben.
