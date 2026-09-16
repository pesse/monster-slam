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
- **PHP läuft im Container, nicht auf dem Rechner** — immer über `tools/report/php.sh`
  aufrufen. Der Wrapper nimmt eine vorhandene Installation (CI) oder podman/docker mit dem
  Abbild aus `.devcontainer/Dockerfile`; das erste Mal baut er es, danach ist es Cache.
  Den Endpunkt prüfen: `tools/report/php.sh server/melden/test_endpoint.php` — startet
  `php -S` gegen ein Wegwerf-Docroot und spielt die Fälle durch. Der Container ist die
  PHP-Werkbank, nicht die Entwicklungsumgebung des Spiels.
- **Ohne Token kein „Melden"** — der Knopf im Reveal und die Liste im Einstellungs-Screen
  erscheinen dann nicht. Bedienungsentscheidung, keine Schranke; die sitzt im Endpunkt.
- **Gemeldet wird erst lokal, gesendet danach.** Ein Netzfehler ist ein Zustand: die
  Meldung bleibt in `user://lexeme_flags.json` offen (`sent: false`) und geht beim nächsten
  Start mit.
- **Ausgewertet wird lokal, nicht auf dem Server**: `tools/report/to_issues.py` bündelt die
  JSON Lines zu Issues im privaten Content-Repo (ein Issue je gemeldetem Wort). Es braucht
  den Submodule-Checkout, weil nur dort das Lemma zu einer Id steht — der Endpunkt kennt
  keine Wörter, und das soll so bleiben. Es hält keinen Zustand, sondern erkennt schon
  Eingetragenes an Markern im Issue-Text; **die nicht aus Issues löschen**, sonst wird die
  Meldung erneut angelegt.

## Gold: verdient in Kisten, gehalten im Profil

Der Wellenabschluss läuft in **zwei Stufen** (`src/ui/wave_stats.gd`, eine Seite je
Stufe in `wave_stats.tscn`): Ergebnis (Statistik **und** Schatzkiste) → Schwierigkeit der
nächsten Welle. Die Vokabel-Auflösung (`leak_reveal`) gehört zum Ergebnis, liegt aber als
eigenes Overlay davor. Die Wahl bleibt getrennt, weil sie eine Entscheidung will und das
Ergebnis gelesen werden will — zusammen auf einer Seite hieß es: Zahlen überfliegen,
„Nächste Welle" klicken.

Beim Arbeiten daran zu beachten:

- **Gold gehört zum Profil, nicht zum Lauf.** `Wallet` (Autoload, `src/economy/wallet.gd`)
  hält den Stand in `user://progress/<player>_wallet.json` und sichert **sofort** bei
  jeder Änderung. Eine gefallene Festung kostet den Lauf, nicht das Erspielte — deshalb
  gibt es die Kiste auch nach einer Niederlage.
- **Verbucht wird im `WaveRunner`, nicht im Screen.** Die Kiste meldet per `opened(gold)`,
  `WaveStats` reicht das als `reward_collected` weiter, und erst
  `WaveRunner._on_reward_collected` ruft `Wallet.earn`. Der Screen zeigt den neuen Stand
  über `Wallet.changed` — er schreibt nichts, was er nur anzeigt. Das ist der Grund, aus
  dem dieselbe Kiste später am Tagesziel oder nach einem Boss hängen kann.
- **Die Wirtschaft justiert man an zwei Konstanten** in `src/economy/chest_reward.gd`:
  `GOLD_PER_SCORE` (Menge; die Punkte tragen die Schwierigkeit der Monster schon in sich,
  siehe `WaveGenerator.reward` — kein zweites Schwierigkeitsmaß daneben bauen) und
  `TIER_FACTOR` (Zuschlag der Güte, die aus der Genauigkeit kommt).
- **Die Größe des Screens steht fest, solange er sichtbar ist.** Er hängt in der
  Bildmitte, jede Größenänderung verschiebt also auch den Knopf, auf den man gerade
  geklickt hat. Zwei Regeln halten das: die Seiten liegen in einem `PageStack`
  (`src/ui/page_stack.gd`, Mindestgröße = größte Seite, **auch die unsichtbare**), und
  innerhalb einer Seite wird nichts ein- oder ausgeblendet, sondern nur gesperrt und
  umbeschriftet. Deshalb ist bei zugesperrter Kiste der Menü-Knopf `disabled` und nicht
  weg, und die Aufforderung an der Kiste wird zur Quittung („+5 Gold") statt von einer
  zweiten Zeile ersetzt zu werden. Was sich doch ändern muss (ob es überhaupt eine Kiste
  gibt, Sieg/Niederlage), wird in `show_stats` entschieden — vor dem Anzeigen.
- **Ein umbrechendes Label braucht dort eine Mindestbreite.** Ein `Label` mit
  `autowrap_mode` meldet als Mindestbreite 1 Pixel und dazu die Höhe, die der Text bei
  EINEM Pixel Breite braucht; das korrigiert sich erst mit einer echten zugeteilten
  Breite — die eine unsichtbare Seite nie bekommt, während der `PageStack` sie trotzdem
  mitrechnet. Ohne `custom_minimum_size.x` machte das Niederlage-Label den Abschluss 1878
  statt 542 Pixel hoch; er hängt in der Bildmitte, also lagen Kiste und Menü-Knopf
  außerhalb des Bildes und die Niederlage war eine Sackgasse. Gehalten von
  `test_the_defeat_screen_fits_into_the_base_resolution` — und der prüft die Achsen
  einzeln, weil `assert_vector(...).is_less_equal(...)` Vektoren lexikografisch
  vergleicht (zu hoch wäre über die Breite durchgerutscht).
  Dasselbe Label-Verhalten trifft jede Karte, deren Größe von Hand gesetzt wird:
  `Control.size` wird an der Mindestgröße geklemmt, die Reveal-Karte blieb deshalb 5881
  statt 340 Pixel hoch und trug ihren Inhalt aus der abschneidenden Bühne heraus.
  `RevealCard.set_width()` gibt den umbrechenden Labels ihre Breite, BEVOR die Größe
  gesetzt wird (`tests/leak_reveal_layout_test.gd`).
- **Aus der Kiste fliegt eine Münze je Goldstück** (`TreasureChest.coin_count`), nicht
  eine gedeckelte Handvoll: der Haufen in der Luft ist der Fund, und eine Deckelung würde
  lügen, sobald die Wellen größer werden. Gedeckelt ist nur der zeitliche *Versatz*
  zwischen den Münzen (`COIN_STAGGER_TOTAL`) — sonst wird aus dem Platzen ein Rinnsal.
- **Die Münzen sind Modelle (`coin.gltf`) und fliegen IN der 3D-Welt der Kiste**, nicht
  als Zeichnung darüber. Sie fallen nicht auf einen Wert, sondern **unter die Kante des
  Bildfelds** (`_floor_y()`, aus dem Bildfeld gerechnet und nicht als zweite Konstante
  daneben): eine Münze, die im Bild liegen bleibt, ist kein Fund mehr, sondern Müll auf
  dem Tisch. Alle Münzen teilen Mesh und Material des Packs — die Zahl der Münzen kostet
  Knoten und Tweens, nichts weiter. Verblasst wird nicht: `GeometryInstance3D.transparency`
  gibt es im `gl_compatibility`-Renderer nicht.
- **An einer ungeöffneten Kiste führt kein Weg vorbei.** Zwei Sekunden Drücken sind kein
  Hindernis, ein weggeklickter Fund ist einer.
- **Die Münzen der Tages-Leiste sind keine Währung**, sondern Marken für geübte Tage
  (`CoinStrip`/`DayCoin`, Vorrat aus `SessionLog.played_day_count()`). Die Leiste redet
  deshalb von Tagen und nicht von Goldstücken. Dieselbe *Zeichnung* fliegt als Münze aus
  der Kiste — Gold soll überall gleich aussehen.
- **Die Kiste selbst ist ein Modell, keine Zeichnung** (`chest.gltf` aus dem
  KayKit-Dungeon-Satz, Nachweis in `assets/models/CREDITS.md`). Sie steht in einem
  `SubViewport` mit **eigener Welt** und durchsichtigem Hintergrund: der Wellenabschluss
  hängt über dem Kampf, und ohne das stünde die Kiste zwischen den Skeletten und ihr Licht
  in der Schlacht. Kamera- und Lichtdrehungen setzt `_setup_view()` im Code (wie
  `WaveRunner._setup_view`), damit in der `.tscn` keine Transform-Basis-Mathematik steht.
  Es ist EIN Modell für alle Güten (`CHEST_MODEL`); unterschieden wird der Beschlag.
- **Die Güte sitzt im BESCHLAG, und die Farbe kommt aus dem Atlas** — kein Farbfilter.
  Der Atlas des Packs ist ein Raster aus 8×4 Farbfeldern, jedes ein senkrechter Verlauf
  (die eingebackene Beleuchtung). Die Kiste benutzt genau zwei Felder, Beschlag (1,0) und
  Holz (4,0), und **kein Dreieck liegt in beiden** — nachgerechnet, nicht geschätzt.
  Rückt man die UV-Koordinaten der Beschlag-Vertices um ganze Felder weiter, wird aus
  Stahl Kupfer, Silber oder Gold, das Holz bleibt Holz und der Verlauf bleibt erhalten
  (`TIER_METAL`, `_mesh_with_metal_cell`). Ein `material_override` wäre der falsche Weg:
  dasselbe Material trägt Holz UND Beschlag, ein Tint träfe beide.
- **Das Mesh aus dem Pack darf dabei nicht angefasst werden.** Godot hält geladene
  Ressourcen im Cache — eine Änderung daran träfe jede weitere Kiste und jedes andere
  Teil, das dasselbe Mesh benutzt. Deshalb entsteht ein eigenes `ArrayMesh` aus den
  Kopien von `surface_get_arrays` (`test_the_metal_recolour_leaves_the_shared_mesh_alone`).
- **Der Beschlag der Goldkiste hat genau die Farbe der Münzen**, weil er auf deren
  Atlas-Feld landet. Das ist der Grund, aus dem `chest_gold.gltf` NICHT im Repo liegt: es
  ist keine goldene Kiste, sondern dieselbe Kiste mit einem Münzhaufen darin — und der
  Haufen ist bei uns das, was herausfliegt.
- **Der 3D-Ausschnitt ist GRÖSSER als das Widget** (`STAGE_PAD`, `_layout_stage`). Ein
  `Control` beschneidet seine Kinder nicht, ein `SubViewport` schneidet hart an seiner
  Kante ab — ohne dieses Polster wären die Münzen im Kistenfenster gefangen. Verschoben
  wird über die *Offsets* bei Ankern auf Vollbild, damit das Polster jeden Layout-Durchgang
  des übergeordneten Containers überlebt. `CAM_SIZE` bezieht sich weiter auf die Höhe des
  **Widgets**; das Bildfeld der Kamera wächst mit dem Polster (`_cam_size()`), sonst würde
  die Kiste kleiner, sobald man den Münzen mehr Platz gibt.
- **Der Rahmen ist gemessen, nicht geschätzt.** `CAM_SIZE`, `CAM_HEIGHT`, `STAGE_PAD` und
  `LID_OPEN_DEG` hängen zusammen. `test_the_open_chest_stays_inside_the_widget` rechnet die
  **echten Mesh-Eckpunkte** über `Camera3D.unproject_position` in das Widget-Rechteck —
  nicht die AABB, deren Ecken weit außerhalb des Meshes liegen und Fehlalarm melden — und
  prüft beide Größen (220×170 im Abschluss, 340×260 in der Werkbank), alle Güten und das
  Überschwingen des Deckels. Gemessen wird gegen das **Widget**, nicht gegen den
  Ausschnitt: die Kiste soll in ihrem Platz im Layout bleiben, die Münzen dürfen darüber
  hinaus. Aus demselben Grund liegen die großen Varianten des Packs (`chest_large*`) nicht
  im Repo: mit offenem Deckel passen sie nicht ins Widget, und kleingerechnet sind sie von
  der normalen nicht zu unterscheiden.
- **Die gezeichnete Kiste bleibt** (`use_model = false`, Umschalter in der Werkbank): zum
  Vergleich Modell gegen Zeichnung und als Rückfall, wenn das Modell fehlt. Sie behält
  ihre gezeichneten Münzen (`day_coin.tscn`) — ohne 3D-Welt gibt es nichts, worin ein
  Modell fliegen könnte, und die Zeichnung ist dieselbe wie in der Tages-Leiste.
- **Die Kiste hat eine eigene Werkbank:** `scenes/dev/chest_lab.tscn` (im Editor mit F6;
  bewusst **kein Knopf im Startmenü** — das Startmenü ist der Weg des Spielers).
  Güte, Gold, Münzzahl und Haltezeit einstellbar, Modell gegen Zeichnung umschaltbar,
  „Sofort aufspringen lassen" für den Blick auf Deckel und Münzflug, und ein Block, der
  die Belohnung einer erfundenen Welle über `ChestReward` ausrechnet. Zum Beurteilen
  einer Wackel-Amplitude will man die Kiste zwanzigmal sehen, nicht zwanzig Wellen
  spielen. Die Werkbank **verbucht nichts** und ist im Export ausgeschlossen
  (`scenes/dev/*`, `src/dev/*` im `exclude_filter`). Ihre Debug-Nahtstellen an der Kiste
  sind `present(tier, gold, coins)`, `hold_time` und `use_model` — alle drei mit Test,
  damit sie beim nächsten Umbau nicht still verschwinden.
- **Wallet-Tests laufen auf einer eigenen Instanz mit `zz-`Profil** und räumen ihre Datei
  weg: `user://` ist projektübergreifend dasselbe Verzeichnis, und die Datei des aktiven
  Profils ist das echte Gold des Spielers. Dasselbe gilt für ein Skript, das die
  Geldbörse zum Ausprobieren umbiegt: `Wallet._ready()` setzt `player_id` aus
  `UserSettings` und läuft NACH `_initialize()` eines `-s`-Skripts — eine früher gesetzte
  Test-Id ist danach wieder weg.

## Erfahrung: Lernfortschritt, nicht Beute

XP und Spielerlevel liegen in `src/progression/` — `Experience` (reine Regeln, wie
`ChestReward`) und der Autoload `PlayerLevel` (Stand je Profil). Verdient wird an
besiegten Monstern, verbucht in `WaveRunner._defeat`.

Beim Arbeiten daran zu beachten:

- **XP kommt aus DEMSELBEN Schwierigkeitsmaß wie Tempo und Punkte** — dem Netto-Maß
  `t - c` in `WaveGenerator._build_plan` (Grundschwierigkeit der Aufgabe minus Confidence
  des Spielers). Kein zweites Maß daneben bauen; die drei Projektionen justiert man an
  ihren Empfindlichkeiten, nicht an einer eigenen Formel.
- **Der Wellenfaktor `speed_scale` gehört NICHT in die XP-Rechnung.** Er hebt die Punkte,
  weil eine härtere Welle mehr Beute bringt; das einzelne Wort wird davon nicht schwerer.
  Sonst wäre die schnellste Welle der schnellste Weg zum Levelup
  (`test_the_wave_factor_lifts_the_points_but_not_the_experience`).
- **Ob eine Aufgabe gemeistert war, wird beim SPAWN entschieden** (dort steht die
  Confidence im Plan, und dort kostet es nichts). Nach dem Treffer hat `PlayerProgress`
  sie schon angehoben — wer erst dort fragt, nimmt genau dem Monster die volle Erfahrung
  weg, das die Meisterung gebracht hat.
- **Gespeichert wird nur `total_xp`.** Level, Levelfortschritt und Skillpunkte rechnet
  `Experience` daraus; das Level in der Datei ist zum Mitlesen da und wird beim Laden
  verworfen. `PlayerLevel.skill_points()` ist der VERDIENTE Stand; was davon ausgegeben
  ist, weiß nur `SkillBook` — und auch dort nicht als Zähler, sondern gerechnet aus den
  gelernten Knoten. Die offenen Punkte sind `SkillBook.available()`.
- **Die Stufengrenze wird gezählt, nicht gewurzelt.** `Experience.progress_in_level`
  läuft in einer Schleife über die Stufenkosten: die Umkehrung der Summenformel trifft
  den runden Betrag (300 XP = Level 3) nicht zuverlässig, und ein Balken, der bei rundem
  Stand eine Stufe zurückfällt, ist schlimmer als 140 Additionen bei einer Million XP.
- **Level und Balken stehen im HUD beim NAMEN**, nicht in einer eigenen Tafel: sie gehören
  zum Spieler, und die Kopfleiste hat bei 1152 Pixeln keinen Platz für eine fünfte. Die
  vier Tafeln passen dort nur knapp: `tests/hud_header_test.gd` misst die Mindestbreite
  der Reihe gegen die Grundauflösung, mit einem späten Spielstand (Level 27,
  fünfstelliges Gold). Was dazukommt, muss anderswo eingespart werden.
- **`PlayerLevel`-Tests laufen auf einer eigenen Instanz mit `zz-`Profil** und räumen ihre
  Datei weg — dieselbe Regel wie bei der Geldbörse: `user://` ist projektübergreifend
  dasselbe Verzeichnis, und die Datei des aktiven Profils ist die echte Erfahrung des
  Spielers. Aus demselben Grund fährt kein Test eine ganze Welle, um das Verbuchen zu
  prüfen.

## Skills: Bäume aus Punkten, Spells sind etwas anderes

Die Skillpunkte aus den Levelups werden in Fähigkeitsbäumen ausgegeben (`data/skills/`,
`SkillTree`, Autoload `SkillBook`, Screen `skill_tree.tscn` am Start-Screen). Die früheren
„Skills" — die aktiven Fähigkeiten mit Abklingzeit — heißen jetzt **Spells**
(`data/spells/`, `ContentRegistry.spells`, `spell_activated`/`spell_ready`). Warum, und
warum `min_app_version` deshalb auf 0.7.0 stehen musste: `docs/adr/0003-skills-und-spells.md`.

Beim Arbeiten daran zu beachten:

- **Bonus-Werte sind ADDITIV auf den Grundwert**, immer. Es gibt keine Frage „welcher
  Knoten gewinnt", nur eine Summe (`SkillTree.bonuses`). Ein Faktor oder ein „überschreibt"
  wäre ein zweites Rechenmodell daneben. Erlaubt sind nur die Schlüssel aus
  `SkillTree.EFFECT_KEYS`; ein unbekannter wirkt gar nicht, und `tests/skill_data_test.gd`
  fängt ihn ab, bevor ein bezahlter Knoten still wirkungslos bleibt.
- **Gespeichert wird nur die Liste der gelernten Knoten.** Ausgegebene Punkte, offene
  Punkte und die Boni rechnet `SkillTree` daraus — dieselbe Regel wie bei `PlayerLevel`
  (nur `total_xp`) und aus demselben Grund: ein zweiter gespeicherter Zähler könnte
  abweichen, und dann wäre nicht zu sagen, welcher stimmt. `spent_points` steht zum
  Mitlesen in der Datei und wird beim Laden verworfen.
- **`apply_skills` gehört unmittelbar hinter `GameState.reset()`** (`wave_runner.gd`): der
  Reset stellt die Grundwerte her, erst danach dürfen die Boni darauf, und der Aufruf zieht
  `fortress_health`/`min_fortress_health` auf das neue Maximum nach. `GameState` und
  `SlowMotion` bekommen DASSELBE Dictionary — eine Quelle der Boni, nicht zwei. Beide
  `apply_skills` nehmen ein einfaches Dictionary und kein Autoload, damit sie ohne
  `SkillBook` und ohne installierte Inhalte prüfbar sind.
- **Die Rüstung ist per WELLE, das Leben per Lauf.** `_on_wave_started` füllt sie wieder
  auf — die eine Ausnahme von „der Wellenstart fasst die Festung nicht an", und der Grund,
  aus dem das Bollwerk etwas anderes tut als ein höheres Maximum. Ein aufgefangener Treffer
  zählt trotzdem als durchgelassen (Serie hin, `monsters_leaked` hoch); `min_fortress_health`
  hängt am Leben und nicht an der Rüstung.
- **Die Zeitlupe hat eine Untergrenze** (`SkillTree.MIN_SLOW_FACTOR`): `Engine.time_scale`
  auf 0 wäre ein eingefrorenes Spiel, in dem die Haltedauer nach Wanduhr weiterliefe.
- **Die Rüstung steht im HUD ÜBER dem Lebensbalken und OHNE Zahl.** Ein „🛡90" am HP-Text
  brauchte 1153 von 1152 Pixeln, ein dreistelliger Wert 1159 — die Kopfleiste ist in der
  Breite knapp, in der Höhe nicht (`tests/hud_header_test.gd`, `tests/hud_armor_test.gd`).
  Die Beträge der Bäume stehen in JSON und sollen justierbar bleiben, ohne dass die
  Kopfleiste reißt.
- **Der Screen ist ein gezeichnetes Netz, keine Reihe Karten** (`SkillGraph`, `_draw()`).
  Jeder Baum hat seinen EIGENEN Anfangspunkt — es gibt keine gemeinsame Mitte, an der
  alles hängt — und `requires` bleibt vorerst innerhalb eines Baums. Wo ein Knoten liegt,
  rechnet `SkillTree.layout()` aus `tier` und `branch`; **es stehen keine Positionen in
  der JSON**, sonst wäre ein vierter Baum ein Umbau der drei vorhandenen statt einer neuen
  Datei. Dass sich dabei nichts überlappt, ist eine Aussage über Zahlen und wird gerechnet
  (`tests/skill_graph_layout_test.gd`, bis sechs Bäume), nicht am Bildschirm beurteilt.
- **Farbe und Zeichen kommen aus den Daten**, nicht aus dem Theme: `color` am Baum-Kopf,
  `icon` am Knoten. Drei Bäume mal vier Zuständen wären sonst zwölf Theme-Variationen —
  und ein vierter Baum brauchte vier weitere. Aus dem Theme kommen nur die Schriftgrößen
  (`SkillIcon`, `SectionTitle`, `Hint`, `Caption`), gelesen in `_draw()` statt als
  Override gesetzt.
- **Der Name eines Baums steht AUSSEN**, jenseits seines äußersten Knotens auf der Achse
  des Fächers (`SkillTree.layout` gibt dem Baum-Kopf dort seinen Platz, `TITLE_GAP`).
  Nicht am Anfang: dort laufen die Linien zusammen, dort liegen bei mehreren Bäumen auch
  die Namen der Nachbarn, und ein Name über einem Knoten verdeckt genau das, was er
  benennen soll. Dass er keinen Knoten berührt, wird gerechnet und nicht angeschaut
  (`test_a_tree_label_touches_no_node`, bis sechs Bäume).
- **Der Ausschnitt gehört dem Spieler.** `SkillGraph.setup()` passt nur ein, solange
  niemand gezoomt oder geschoben hat: wer hineingezoomt hat, um einen Ast zu lesen, soll
  nach dem Kauf denselben Ast sehen. Zurück kommt man über „Ansicht einpassen".
- **Der Screen ist NUR das Netz — keine Tafel am Rand.** Was ein Knoten tut, steht am
  ZEIGER, in derselben Karte, die im ganzen Spiel erklärt (siehe „Auskunft am Zeiger").
  Der Grund ist nicht Platz, sondern Blickrichtung: wer einen Knoten prüft, sieht ihn an,
  nicht an den anderen Bildrand.
- **Die Fläche antwortet, statt zu melden.** Der Graph sucht seine Treffer selbst, also
  hängt er bei `Hints` als *lebende* Auskunft (`attach_live(_graph, _hint_at)`):
  `SkillTree._hint_at(local)` liefert für einen Punkt Zeichen+Name, Wirkung und
  Zustandszeile — oder nichts, beim Ziehen und über einer offenen Rückfrage. Die Regeln
  bleiben in `SkillTree` (`state_label`, `tree_status`), die Karte kennt nur
  Zeichenketten.
- **Der Stand eines Baums hängt an seinem NAMEN.** Über dem Namen zeigt dieselbe Karte
  „2/5 gelernt · +2 HP je besiegtem Monster" (`SkillTree.tree_status`) — das ist das, was
  früher rechts als „Dein Ausbau" stand. Der Name ist damit anklickbar-ähnlich, aber
  nichts zum Lernen: `_on_node_selected` steigt bei `kind != "skill"` aus.
- **Ein gesperrter Knoten nennt seine Vorstufe beim NAMEN** („🔒 braucht Verband"). Im
  Netz hängt an einem Knoten mehr als eine Linie; ein bloßes „gesperrt" sagt nicht, welche
  zuerst dran ist. Die vier Zustandszeilen rechnet `SkillTree.state_label()` — sie sind
  eine REGEL und keine Frage der Darstellung, und dieselbe Zeile soll später auch anderswo
  stehen können.
- **Ein Klick bucht nicht, er fragt** (`ConfirmDialog`, dasselbe Overlay-Muster wie
  `update_dialog`, **kein `Window`**). Ein ausgegebener Skillpunkt kommt nur gegen Gold
  zurück — das ist keine Entscheidung für einen unbeabsichtigten Klick. Der Fokus liegt
  auf ABBRECHEN, damit die Eingabetaste nichts ausgibt. Gefragt wird nur, wo es etwas zu
  entscheiden gibt: ein gelernter, gesperrter oder unbezahlbarer Knoten öffnet nichts,
  denn warum, steht schon in der Karte. Deshalb meldet `SkillGraph.select()` JEDEN Klick,
  auch den auf den schon gewählten Knoten — sonst ließe sich ein abgebrochener Antrag
  nicht neu stellen.
- **„Ansicht einpassen" und „Umlernen" sind Zeichen am unteren rechten Rand der
  Zeichenfläche** (⛶ und ↺), nicht beschriftete Knöpfe unter dem Netz: sie gehören zur
  Fläche, die sie bedienen. Was sie tun und was sie kosten, steht in ihrer Karte am Zeiger
  (`Hints.attach`) — ein Zeichen ohne Erklärung ist ein Rätsel. Der Umlern-Knopf bleibt
  gesperrt statt zu verschwinden und sagt in seiner Karte, woran es liegt; dass ein
  gesperrter Knopf überhaupt sprechen darf, hängt daran, dass `disabled` die
  Trefferprüfung nicht anfasst.
- **`SkillBook`-Tests laufen auf einer eigenen Instanz mit `zz-`Profil** und schieben ihr
  über eine Unterklasse einen erfundenen Baum unter (`entries()` überschrieben) — sonst
  hängen sie an der Balance der ausgelieferten Bäume. `Wallet` und `PlayerLevel` lassen
  sich nicht ebenso ersetzen (`respec()`/`available()` gehen an die Autoloads): beide
  bekommen für die Dauer des Tests ebenfalls ein `zz-`Profil, sonst schreibt ein
  `Wallet.spend` in die echte Geldbörse des Spielers. Der Screen nimmt dafür ein Feld
  `book` entgegen, das vor dem Einhängen gesetzt wird.

## Auskunft am Zeiger: eine Karte für das ganze Spiel

Erklärt wird über das Autoload `Hints` (`src/ui/hints.gd`, `scenes/ui/hints.tscn`) und die
eine `HintCard` darin. **Godots eigener Tooltip wird nirgends mehr benutzt** — er erscheint
verzögert, bleibt stehen, wo er aufgegangen ist, und bringt die Typografie der Engine mit;
über einem Netz hieß das eine halbe Sekunde je Knoten. `tests/hint_discipline_test.gd`
meldet jedes `tooltip_text` in `scenes/**.tscn` und `src/**.gd`, und
`gui/timers/tooltip_delay_sec` ist damit ersatzlos aus `project.godot` verschwunden.

Beim Arbeiten daran zu beachten:

- **Angemeldet wird am kleinsten Ding, das der Text meint**: `Hints.attach(control, titel,
  text, nachsatz)`. Ein durchweg leerer Hinweis IST das Abmelden — deshalb bleibt eine
  Statistikzeile ohne Hinweis einzeilig und die fliegenden Münzen der Kiste stumm.
  Gespeichert wird als Metadatum AM Knoten, nicht in einer Liste im Autoload: ein Meta
  stirbt mit seinem Knoten, eine Liste könnte ihn überleben.
- **Gefragt wird der Zeiger, nicht das Control.** `_process` liest jeden Frame
  `Viewport.gui_get_hovered_control()` und geht von dort nach OBEN, bis ein Knoten eine
  Auskunft trägt. Keine `mouse_entered`/`mouse_exited`-Verbindungen: jede bräuchte ihr
  Gegenstück, und jede deckte nur einen Weg ab, auf dem eine Auskunft ungültig wird —
  weggescrollt, zugeklappt, freigegeben, Szene gewechselt.
- **Die Suche nach oben ist der Grund, aus dem ein Hinweis einmal statt zweimal dasteht.**
  Godot bricht am ersten Kind mit `MOUSE_FILTER_STOP` ab; genau deshalb musste
  `ProgressRow` seinen Text an der Zeile UND am Kopf-Knopf setzen. Jetzt spricht die Zeile
  auch für ihren Knopf und ihren Balken. Umgekehrt heißt das: **nie an eine Screen-Wurzel
  anhängen**, sonst erklärt sich das ganze Bild.
- **Eine Fläche mit eigener Trefferprüfung hängt als `attach_live(control, callable)`**
  und liefert für einen Punkt IN ihr eine Karte oder `{}`. Leer heißt wirklich nichts —
  es wird dann nicht beim Elternknoten weitergefragt, die Fläche hat ja geantwortet.
- **Die Karte liegt in einer eigenen `CanvasLayer` auf 128.** Ein `ScrollContainer`
  beschneidet seine Kinder, ein `CanvasLayer` ist kein `CanvasItem` — damit endet jede
  Beschneidung an seiner Grenze, und die Karte liegt zugleich über der UI-Schicht des
  Kampfes (`battle.tscn`, layer 1), in der der Wellenabschluss samt Schatzkiste hängt.
  Die Karte MUSS `MOUSE_FILTER_IGNORE` bleiben: sonst läge sie selbst unter dem Zeiger,
  versteckte sich, käme wieder — sechzigmal in der Sekunde.
- **Die Breite ist eine Regel, keine Zahl in der Szene**: so breit wie ihr Text, zwischen
  `MIN_WIDTH` und `MAX_WIDTH`. Gemessen wird mit **abgeschaltetem** Umbruch, danach wird
  die Breite in die Labels gedrückt und ERST DANN die Höhe gelesen — ein umbrechendes
  Label meldet sonst die Höhe für einen Pixel Breite (dieselbe Falle wie
  `RevealCard.set_width()`). Und die Label-Mindestbreite wird vor jedem Messen auf 0
  gesetzt, sonst bliebe jede Karte so breit wie die breiteste, die je zu sehen war
  (`test_the_width_does_not_stick_from_the_last_card`).
- **Godot befördert kopflos keine Mausereignisse**, `gui_get_hovered_control()` ist im Test
  also immer leer. Dafür gibt es `Hints.probe(control, at)` — die Naht, an der die Tests
  hängen. Ungeprüft bleibt damit genau eine Sache: dass die Trefferprüfung der Engine auch
  einen `disabled` Button meldet. Sie tut es (der Umlern-Knopf lebte bis hierher von
  Godots Tooltip), und `probe` zeigt die Karte nur bis zum nächsten Frame — Tests dazu
  stehen deshalb ohne `await`.

## Abstände und Schriftgrößen stehen im Theme, nicht in der Szene

`scenes/ui/ui_theme.tres` ist die einzige Quelle für Raum und Typografie. Vorher lagen
sie als `theme_override_…` in den Szenen und hatten sich auf 14 Schriftgrößen und 12
Abstandswerte summiert — im Statistik-Screen standen sieben Größen auf einem Bildschirm,
darunter 14 neben 15.

Rollen gibt es als **Type-Variations**, gesetzt über `theme_type_variation`:

| Text | | Container | |
|---|---|---|---|
| `Display` | 40 | `ScreenMargin` | Screen-Rand 24 |
| `Title` | 28 | `ScreenStack` | 16 |
| `SectionTitle` | 20 | `SectionStack` | 24, zwischen Abschnitten |
| — (Grundgröße) | 18 | `Tight` | 4, Listenzeilen |
| `Hint` | 14, gedämpft | (Klassenvorgabe) | 8 |
| `Caption` | 12, gedämpft | | |
| `Accent` | Gold, für Hinweise mit Nachdruck | | |
| `SectionButton` | 20, für klappbare Abschnitte | `ScrollGutter` | 8 rechts, in jedem ScrollContainer |
| | | `HudPanel` | Tafel der Kopfleiste, 8/4 statt 16 |

Abstände dürfen nur die Stufen **0 / 4 / 8 / 16 / 24** benutzen. Karten-Innenabstand
kommt aus `PanelContainer/styles/panel` (16) — **keinen MarginContainer in eine
PanelContainer legen**, das addiert sich; genau das war in `content_pack_row` und
`update_dialog` passiert.

**In jeden ScrollContainer gehört ein `Gutter`** (MarginContainer mit `ScrollGutter`)
zwischen Balken und Inhalt. Godot legt den Scrollbalken an die Innenkante des
ScrollContainers und gibt dem Kind exakt den Rest — die Lücke muss also aus dem Inhalt
kommen. Ein Rand am ScrollContainer selbst (`ScrollContainer/styles/panel`) hilft nicht:
der verschiebt Balken und Inhalt gemeinsam, gemessen mit content_margin_right=8 →
Inhalt 386, Balken 386..392.

**`CheckBox` und `CheckButton` brauchen eigene Styles**, sonst greift die Theme-Suche über
die Klassenkette auf `Button/styles/*` zurück — ein Kästchen sah dadurch aus wie ein
Druckknopf, und angehakt nahm es `btn_pressed` (bg 0.09/0.11/0.16, fast die
Hintergrundfarbe), stand also rahmenlos neben den gerahmten nicht angehakten. Jetzt ist
beides `StyleBoxEmpty`; der Unterschied ist das Häkchen, wie es sein soll.

`tests/theme_discipline_test.gd` hält die Regel: er meldet `theme_override_…` in
`scenes/**.tscn` und `add_theme_*_override` in `src/**.gd`, prüft die Skala im Theme und
schlägt bei einem Tippfehler in einer Variation an (den Godot sonst stillschweigend
verschluckt). Die Kampf- und Effekt-Oberflächen (`hud`, `reveal_card`, `leak_reveal`,
`wave_stats`, `battle`, Combo-Zahlen) stehen mit Begründung in der Ausnahmeliste `ALLOWED`
— sie haben eine eigene, lautere Typografie und sind noch nicht umgestellt.

Was das Theme **nicht** kann: `size_flags_*`, `custom_minimum_size`, `autowrap_mode` und
Anchors sind Knoten-Eigenschaften und bleiben in der Szene. Layout-Struktur auch — der
Titel im Header ist deshalb noch um halbe Knopfbreite außermittig (HBox mit Knopf plus
gedehntem Label zentriert im Restplatz, nicht im Screen).

## Vier Fallen, die schon zugeschlagen haben

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

**Das Vollbild ist der SCHMALSTE Fall, nicht der breiteste.** `canvas_items`/`expand`
skaliert mit der knapperen Achse und dehnt die andere — das Bild ist also nie kleiner als
die Grundauflösung (1152×648), aber im Vollbild auf einem 16:9-Schirm genau so groß. Ein
maximiertes Fenster gibt dem Spiel dagegen MEHR Breite (Titelleiste kostet Höhe, die
Skalierung fällt, die Breite wächst auf ~1196). Was am Rand knapp ist, fällt beim
Entwickeln im Fenster deshalb nicht auf und im Vollbild sofort: die Kopfleiste brauchte
1215 Pixel und schnitt die Tafel mit Kills und Gold ab. Randlayout gegen 1152 prüfen,
nicht gegen das eigene Fenster.

**Tests müssen neben echten Packs gelten.** `user://` ist projektübergreifend dasselbe
Verzeichnis, und Packs werden nach Id sortiert — der letzte gewinnt. Ein Fixture-Pack
braucht deshalb eine Id, die zuletzt sortiert (`zz-…`), sonst gewinnt auf einem Rechner mit
installierten Inhalten `game` oder `language-*` und der Test wird grundlos rot.
