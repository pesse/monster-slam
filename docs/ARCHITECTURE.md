# Architektur

Leitziel: **Modularität durch Daten + Entkopplung durch Signale.** Neue Inhalte
und Mechaniken sollen sich ergänzen lassen, ohne bestehende Systeme zu ändern.

## Zwei Autoload-Säulen

### 1. ContentRegistry (`src/core/content_registry.gd`)
Datengetriebener Katalog. Scannt beim Start rekursiv `<root>/<kategorie>/`
und lädt jede `.json`-Datei. Kategorien: `lexemes`, `lexeme_forms`,
`lexeme_relations`, `sentences`, `sentence_lexemes`, `task_definitions`,
`monster_task_rules`, `monsters`, `bosses`, `skills`, `waves`.

**Drei Roots, in Vorrangfolge** (`_roots()`): bei gleicher `id` gewinnt der spätere.

| # | Root | Inhalt | im Export? |
|---|---|---|---|
| 1 | `res://data/` | Spielkonfiguration (Monster, Wellen, Skills, Aufgaben-Regeln) | ja |
| 2 | `res://data/language/` | Sprachdaten — privates Submodule, nur in der Entwicklung | **nein** |
| 3 | `user://content/<pack-id>/` | installierte Content-Packs | — |

Root 2 ist ein separates **privates** Repo, weil die Daten aus urheberrechtlich
geschütztem Lehrbuchmaterial abgeleitet sind. Es wird per `exclude_filter` **aus dem
Export ausgeschlossen** — die verteilte EXE enthält keine Vokabeln und holt sie über
Content-Packs (Root 3). Root 3 ist damit kein Sonderfall, sondern der Normalweg beim
Spieler; dass ein Pack einen eingebauten Eintrag überschreiben *kann*, ist gewollt.

Fehlen Sprachdaten in allen Roots, startet das Spiel mit leeren Sprachkatalogen und
einer Warnung, die beide Wege nennt (Pack installieren / Submodule auschecken).

Kollisionen werden pro Root beurteilt (`_origins`): zwei Dateien **desselben** Roots
mit gleicher `id` sind ein Fehler und werden gemeldet; ein Pack, der einen eingebauten
Eintrag ersetzt, ist der Zweck der Übung und bleibt still.

- Jede JSON-Datei enthält ein Objekt **oder** ein Array von Objekten.
- Jedes Objekt braucht eine eindeutige `id` (String).
- Zugriff: `ContentRegistry.monsters`, `.get_entry("lexemes", "lex.en.house")`,
  `.all("waves")`, `.lexemes_by_tags(["basics"])`, `.forms_for(id, form_type)`,
  `.relations_of(id, "opposite")`, `.monster_rule_for(task_type, direction)`.
- Auswahl-Filter fürs Session-Setup: `.lexemes_scoped(scope, tags)` (Schnitt aus
  Curriculum-Scope UND Themen, siehe unten), plus `.all_books()` / `.units_for(book)`
  für den Buch▸Unit-Picker.
- `reload()` scannt zur Laufzeit neu.

**Folge:** Content hinzufügen = Datei ablegen. Kein Code-Edit.

### Datenmodell (ERM): Sprache / Aufgabe / Darstellung getrennt
Der Lernstoff ist normalisiert, damit Sprachdaten, Aufgaben, Fortschritt und
Darstellung unabhängig wachsen können (siehe `docs/ADDING_CONTENT.md`):

- **lexemes / lexeme_forms / lexeme_relations** — *Was* ist das Wort, welche Formen
  (Konjugation/Zeit) und Relationen (opposite/synonym/…) hat es. **Keine** `difficulty`
  am Lexem: wie schwer ein Wort ist, ergibt sich aus dem Lernstand (Confidence), nicht
  aus dem Wort selbst.
  - **Zwei getrennte Klassifikations-Achsen** am Lexem (für die Session-Auswahl):
	*Curriculum* über die Felder `book` (z.B. `"access2"`) + `unit` (int) — woher das
	Wort stammt; *Themen* über `tags` (z.B. `body`, `animals`) — worum es geht. Die
	Wortart steckt in `type`, **nicht** in `tags`. `.lexemes_scoped(scope, tags)`
	schneidet beide Achsen (Scope UND Themen; innerhalb der Tags ODER), leer = keine
	Einschränkung. So ist z.B. „Körperteile aus Access 2 / Unit 6" ausdrückbar. Lexeme
    ohne `book`/`unit` (Grundwortschatz) sind keinem Curriculum zugeordnet und erscheinen
    nur, wenn kein Scope gewählt ist.
- **task_definitions** — *Regeln*, was abgefragt wird (translate/opposite/synonym/
  conjugation/… + `direction`, `allowed_types`, `requires_relation`/`requires_form`,
  `difficulty`). Wenige, statische Einträge (Größenordnung ~10–20) — **unabhängig von
  der Wortanzahl**. Die konkrete Aufgabe entsteht erst zur Laufzeit aus
  *Definition × Lexeme (× Form/Relation)*; es gibt keine per-Wort-Aufgaben mehr.
- **monster_task_rules** — *Wie* eine Aufgabe dargestellt wird: `(task_type, direction)
  → monster_type` + `base_damage/weight`. **Kein** Tempo und **keine** Punkte —
  beide sind Projektionen der Schwierigkeit (siehe unten), keine Darstellungswerte.
- **player_progress** — *Wie gut* der Spieler eine konkrete Aufgabe kann, adressiert über
  einen kanonischen **`learnable_id`** (Task-Typ + Richtung + Lexeme/Form/Relation; Schema
  in `TaskResolver.learnable_id()`). Nicht im Content, sondern beschreibbar in `user://`.
- **sentences / sentence_lexemes** — für Boss-/Satzübungen; Schema vorhanden, Feature
  (task_type `sentence`/`fill_gap`, Boss-Runner) noch zurückgestellt.

Die Auflösung Definition × Lexeme → spielbare Aufgabe `{prompt, accepted_answers, …}`
macht `src/learning/task_resolver.gd`; die Enumeration der Kandidaten (Definition × Lexeme)
und die Auswahl fälliger/neuer Aufgaben + Monster-Mapping `src/battle/wave_generator.gd`.

### Tempo = Schwierigkeit (Monster-Geschwindigkeit)
Geschwindigkeit ist **kein eigenständiges Attribut**, sondern die sichtbare Projektion der
Schwierigkeit. Es gibt genau eine Achse — Schwierigkeit — und Tempo ist ihre Ausgabe.
Daraus zwei Regeln: (1) Tempo entsteht **ausschließlich** aus Schwierigkeits-Quellen
(Grundschwierigkeit der Aufgaben-Art, Confidence, Wellen-Schwierigkeit) — kein Monster und
keine Regel trägt ein eigenes Tempo; (2) jede Tempo-Änderung ist eine Schwierigkeits-Änderung
und daher monoton und begrenzt zu behandeln.

Formel (`src/battle/wave_generator.gd`), mit `c` = Confidence (0..1) und `t` =
normalisierte `task_definition.difficulty` (0..1):

```
e = c − t                                    # Netto-Können
speed = REFERENCE_SPEED · clamp(1 + K·e) · speed_scale
```

- `e < 0` (Confidence unter Grundschwierigkeit) → **langsamer** (Zeit zum Abrufen).
- `e = 0` → **Referenztempo**. `REFERENCE_SPEED` ist der Nullpunkt der Skala, kein Deko-Wert;
  es zu ändern verschiebt die Schwierigkeit **aller** Aufgaben.
- `e > 0` (Confidence übersteigt die Grundschwierigkeit) → **schneller** (mehr Druck).

Die Differenzierung „opposite/synonym sind schwerer als translate" lebt damit allein in
`task_definition.difficulty` — nicht in per-Monster- oder per-Regel-Geschwindigkeiten.

**Punkte folgen derselben Schwierigkeit, invers zum Tempo:** je schwerer das Monster
(hohe Grundschwierigkeit, niedrige Confidence, härtere Welle), desto **mehr** Punkte —
`reward = REFERENCE_REWARD · clamp(1 + K_r·(t − c)) · speed_scale`. Ein hartes Monster ist
also langsam *und* wertvoll; das Abrufen unsicherer/schwerer Aufgaben lohnt sich. Auch die
Punkte kommen damit ausschließlich aus der Schwierigkeit, nicht aus per-Regel-Werten.

### 2. EventBus (`src/core/event_bus.gd`)
Globaler Signal-Hub. Systeme kommunizieren über Signale statt direkter
Referenzen. Ein neues System abonniert relevante Signale, ohne dass ein
bestehendes System davon wissen muss.

`GameState` (`src/core/game_state.gd`) hält die Laufzeit-Session (Festungs-HP,
Score, aktive Welle) und reagiert selbst nur über EventBus-Signale.

## Lern-Module (`src/learning/`)

- **`spaced_repetition.gd`** — SM-2-artiger Scheduler. Bestimmt, wann ein Item
  wieder fällig ist. Persistierbar via `to_dict()`/`from_dict()`.
- **`answer_evaluator.gd`** — zwei Modi:
  - `evaluate_vocab()`: normalisierter Exakt-/Alternativabgleich für schnellen Recall (offline).
  - `evaluate_sentence()`: semantische Qualität für Boss-Sätze. Standard ist eine
	Offline-Heuristik; ein lokales LLM lässt sich über `sentence_backend`
	(Callable) einstecken — **ohne** Aufrufer zu ändern.

## Wirtschaft: Gold und Schatzkisten (`src/economy/`)

Gold ist die erste Währung. Verdient wird es als **Schatzkiste am Wellenende**, gehalten
wird es im **Profil** — nicht im Lauf: eine gefallene Festung kostet den Lauf, nicht das
Erspielte.

| Baustein | Wo | Aufgabe |
|---|---|---|
| `ChestReward` | `src/economy/chest_reward.gd` | reine Rechnung: Güte der Kiste + Goldmenge |
| `Wallet` (Autoload) | `src/economy/wallet.gd` | Goldstand des Profils, verdienen/ausgeben, Persistenz |
| `TreasureChest` | `src/ui/treasure_chest.gd` + `scenes/ui/treasure_chest.tscn` | die Kiste zum Aufdrücken (2 s halten, Wackeln, Platzen, Münzflug) — ein 3D-Modell in eigener Welt |
| `WaveStats` | `src/ui/wave_stats.gd` | Wellenabschluss in zwei Stufen: Ergebnis (Statistik + Kiste) → nächste Welle |
| `PageStack` | `src/ui/page_stack.gd` | Seitenstapel mit fester Größe (Mindestgröße = größte Seite, auch unsichtbar) |
| Werkbank | `scenes/dev/chest_lab.tscn` | die Kiste ohne Spiel ausprobieren (Güte, Gold, Münzen, Haltezeit, Modell/Zeichnung); im Export ausgeschlossen |

- **Die Menge Gold kommt aus den PUNKTEN der Welle**, nicht aus der Zahl der Monster: die
  Punkte je Monster tragen die Schwierigkeit schon in sich (`WaveGenerator.reward` steigt
  mit der Grundschwierigkeit der Aufgabe, fällt mit der Confidence des Spielers, wächst
  mit dem Wellentempo). Ein zweites Schwierigkeitsmaß daneben liefe auseinander, sobald
  eines von beiden justiert wird.
- **Die Güte kommt aus der Genauigkeit** (`WOOD`/`BRONZE`/`SILVER`/`GOLD`, perfekt = Gold)
  und wirkt als Faktor auf die Menge. Sie ist das, was in DIESER Welle besser zu machen
  war, und unabhängig davon, wie lang die Welle war.
- **Verbucht wird im `WaveRunner`, nicht im Screen** (`_on_reward_collected` →
  `Wallet.earn`). Die Kiste meldet per `opened` nur, dass sie offen ist; so ist dieselbe
  Kiste später auch am Tagesziel oder nach einem Boss zu haben, ohne dass sie weiß, wem
  sie etwas gutschreibt.
- **Die Kiste ist ein 3D-Modell in einem eigenen SubViewport**, keine Zeichnung
  (`chest.gltf` aus dem KayKit-Dungeon-Satz, Nachweis in `assets/models/CREDITS.md`).
  Eigene Welt und durchsichtiger Hintergrund halten sie vom Kampf getrennt, über dem der
  Abschluss-Screen hängt. Der Deckel ist ein eigener Knoten mit dem Scharnier als
  Ursprung, Aufklappen also eine Drehung um X. Die gezeichnete Fassung bleibt erreichbar
  (`use_model = false`): als Vergleich in der Werkbank und als Rückfall, wenn das Modell
  fehlt.
- **Die Güte sitzt im Beschlag und kommt aus dem Texturatlas**, nicht aus einem
  Farbfilter: der Atlas ist ein Raster aus 8×4 Verlaufsfeldern, die Kiste benutzt genau
  zwei (Beschlag, Holz), und ein Feldsprung in den UV-Koordinaten der Beschlag-Vertices
  macht aus Stahl Kupfer, Silber oder Gold (`TIER_METAL`). Das Gold ist dasselbe Feld, aus
  dem die Münze ihre Farbe nimmt.
- **Aus der Kiste fliegt eine Münze je Goldstück** (`TreasureChest.coin_count`), als
  Modell (`coin.gltf`) in derselben 3D-Welt, taumelnd und unten aus dem Bild. Gedeckelt
  ist nur der zeitliche Versatz zwischen den Münzen, damit 200 Gold nicht tröpfeln. Weil
  die Münzen mehr Platz brauchen als die Kiste, ist der gerenderte Ausschnitt größer als
  das Widget (`STAGE_PAD`) — die Kiste selbst bleibt in ihrem Platz im Layout, geprüft
  gegen das Widget-Rechteck.
- **Die Größe des Abschluss-Screens steht fest**, solange er sichtbar ist: er hängt in
  der Bildmitte, und eine Größenänderung beim Weiterblättern verschiebt die Knöpfe unter
  dem Zeiger. Dafür der `PageStack` plus die Regel, innerhalb einer Seite nur zu sperren
  und umzubeschriften statt ein- und auszublenden.
- **Die Münzen der Tages-Leiste sind keine Währung.** Sie markieren geübte TAGE
  (`CoinStrip`, `DayCoin`, Vorrat aus `SessionLog.played_day_count()`); Gold zählt in
  Beträgen. Deshalb redet die Leiste von Tagen — zwei Dinge, die „Goldstück" heißen,
  wären eines zu viel.

## Erweiterungspunkte für den KI-Agenten

| Erweiterung | Wie | Bestehender Code betroffen? |
|---|---|---|
| Neues Wort | JSON in `data/language/lexemes/` (Aufgaben entstehen automatisch aus Definitions) | nein |
| Neuer Aufgaben-*Typ* | JSON in `data/task_definitions/` (+ ggf. Resolver-Zweig) | ggf. Resolver |
| Neues Monster | JSON in `data/monsters/` | nein |
| Neuer Boss | JSON in `data/bosses/` | nein |
| Neue Welle | JSON in `data/waves/` | nein |
| Neue Fähigkeit (Daten) | JSON in `data/skills/` | nein |
| Neuer Fähigkeits-*Effekt* (Verhalten) | Effect-Handler ergänzen (siehe unten) | nur additiv |
| Neue Mechanik | Neues System, das EventBus-Signale abonniert | nein |

### Fähigkeits-Effekte
Eine Fähigkeit trägt in den Daten ein `effect`-Feld (z. B. `slow_monsters`).
Die reine Definition ist datengetrieben; Verhalten, das Code braucht, wird über
ein Effekt-Handler-Muster ergänzt: jeder Effekt registriert sich selbst unter
seinem `effect`-Schlüssel. Ein neuer Effekt = neuer Handler, keine Änderung an
vorhandenen Handlern. (Noch zu implementieren — siehe `docs/ADDING_CONTENT.md`.)

## Datenpersistenz

- **Content** (Aufgaben, Monster, Wellen, …): JSON unter `data/` — versioniert, agent-editierbar.
- **Sprachdaten** (Lexeme, Formen, Relationen, Sätze): JSON unter `data/language/`
  — eigenes privates Repo (Submodule), Änderungen werden dort committet.
- **Nutzer-Meldungen** („dieses Wort ist falsch", `LexemeFlags`,
  `src/core/lexeme_flags.gd`): JSON unter `user://lexeme_flags.json`, lexeme_id → Meldung.
  Bewusst **nicht** in der Quell-JSON: `res://` ist im Export read-only, und eine
  veränderte Pack-Datei würde beim nächsten Pack-Update übersprungen. `ContentRegistry`
  legt die Meldungen nach jedem Laden über die Lexeme (`_apply_flags()`), sodass
  `flagged_lexemes()` unverändert funktioniert. Jede Meldung trägt ein Feld `sent`: das
  ist die Warteschlange des Melde-Kanals (siehe unten) — was noch nicht abgehakt ist,
  geht beim nächsten Start mit.
- **Gold** (`Wallet`, `src/economy/wallet.gd`): JSON unter
  `user://progress/<player>_wallet.json` — Stand, Lebensleistung und Zahl geöffneter
  Kisten. Gesichert wird **sofort** bei jeder Änderung und nicht erst am Laufende:
  verdientes Gold darf ein Absturz nicht kosten.
- **Spielerfortschritt** (`player_task_progress`): der Autoload `PlayerProgress`
  (`src/learning/player_progress.gd`) hält je Aufgabe Confidence/Streak/Fälligkeit und
  kapselt den SM-2-Scheduler. Persistenz: JSON unter `user://progress/<player>.json`
  (schreibintensiv, wächst → bewusst nicht in `data/`). SQLite ist die vorgesehene
  Ausbaustufe für größere Historien.

## Ausliefern: zwei getrennte Update-Kanäle

Entscheidung und Begründung: `docs/adr/0001-app-und-content-update.md`;
Pack-Dateiformat: `docs/PACK_FORMAT.md`.

| | App-Kanal | Content-Kanal |
|---|---|---|
| Was | die ganze EXE (~120 MB) | Content-Packs (KB) |
| Wie oft | selten | oft |
| Quelle | `latest.json` am GitHub-Release des Hauptrepos | `index.json` im Transport-Repo |
| Autoload | `UpdateService` (`src/update/`) | `ContentService` (`src/content/`) |
| UI | `scenes/ui/update_dialog.tscn` | `scenes/ui/content_manager.tscn` |
| Prüfung | SHA-256 **und** RSA-Signatur (`ReleaseKey`) | SHA-256; geschützte Packs zusätzlich AES-CBC + HMAC |
| Einbau | EXE umbenennen, ersetzen, neu starten (Rollback bei Fehler) | nach `user://content/<pack-id>/` auspacken |

Zwei Kanäle, weil die beiden Dinge unterschiedlich groß und unterschiedlich häufig sind:
neue Vokabeln dürfen nicht 120 MB kosten, und ein Fehler im Content-Kanal darf die
installierte App nicht beschädigen.

**Versions-Tor in beide Richtungen** (`SemVer`, `PackStatus`): ein Pack nennt
`minVersion` — ist die App älter, wird der Pack als `APP_OUTDATED` blockiert (kein
Zugangscode hebt das auf), und der App-Kanal wird zum Update gedrängt. Umgekehrt nervt ein
veralteter Pack (`UPDATE`, vorausgewählt), blockiert aber nichts. In Debug-Builds gibt es
kein Tor, damit die Entwicklung nicht an ihren eigenen Versionsnummern hängt.

**Geschützte Packs.** Ein Pack aus Lehrbuchmaterial wird verschlüsselt ausgeliefert und
braucht einen Zugangscode (`AccessCodes`, `PackCrypto`). Der Code steht in
`user://codes.cfg` und ist ausdrücklich **kein** Geheimnisspeicher — er hält den Inhalt
aus dem öffentlichen Netz heraus, nicht vor dem Besitzer des Rechners.

**Bauen und Veröffentlichen.** Die Packs baut `tools/packs/build_packs.py` nach der
Zuordnung in `packs.yaml` (im privaten Content-Repo, weil sie entscheidet, was geschützt
bleibt) — fail-closed: eine Datei ohne eindeutige Zuordnung bricht den Build ab. Drei
unabhängige Sicherungen halten geschütztes Material aus offenen Packs heraus: die
Pfadregeln, ein Blick in die Lexeme (`protected_books`) und
`tools/packs/check_open_packs.py` am fertigen ZIP. Es gibt genau ein `index.json`, also
auch nur einen Veröffentlicher: der Workflow im Content-Repo, den eine Änderung an
`data/**` im Hauptrepo per `repository_dispatch` mit anstößt.

## Der Melde-Kanal: der Weg zurück

Entscheidung und Begründung: `docs/adr/0002-melde-rueckkanal.md`.

Die beiden Kanäle oben liefern **zum** Spieler. Der dritte geht nach oben: eine Meldung
(„dieses Wort ist falsch") wird zu einer Korrektur im privaten Content-Repo und kommt über
den Content-Kanal als Pack-Update zurück.

| | Melde-Kanal |
|---|---|
| Was | eine Meldung: Ziel-Id, Kommentar, App- und Pack-Fassung (wenige Bytes) |
| Autoload | `ReportService` (`src/report/`) |
| Ziel | eigener PHP-Endpunkt, `server/melden/melden.php`; Ablage als JSON Lines **über** dem Docroot |
| Berechtigung | Melde-Token je Person, `<label>.<mac>` mit HMAC — geprägt von `tools/report/mint_token.py`, geprüft vom Endpunkt |
| Ablage des Tokens | `user://codes.cfg`, Sektion `report` (`ReportToken`) — wie die Zugangscodes **kein** Geheimnisspeicher |
| UI | Reiter „Melden" in `scenes/ui/settings_menu.tscn`; „⚑ Melden" im Reveal |

**Ohne hinterlegtes Token gibt es „Melden" nicht** — der Knopf im Reveal und die
Meldungsliste erscheinen nicht. Das ist eine Bedienungsentscheidung, keine Schranke: eine
Meldung, die nirgends ankommt, ist ärgerlicher als ein fehlender Knopf. Die Schranke sitzt
im Endpunkt, der das Token prüft, Größe und Rate deckelt und ein zurückgezogenes Label
sperrt.

Gemeldet wird **immer erst lokal**, gesendet danach: ein Netzfehler lässt die Meldung offen
stehen (`sent` bleibt false), sie geht beim nächsten Start mit, und eine doppelt gesendete
erkennt der Endpunkt. Das Bündeln zu GitHub-Issues liegt bewusst hinter dem Endpunkt und
nicht in ihm — eine Störung dort darf keine Meldung verschlucken.

Gearbeitet wird nicht an der Ablage, sondern an Issues im privaten Content-Repo:
`tools/report/to_issues.py` macht aus den JSON Lines **ein Issue je gemeldetem Wort** mit
allen Meldungen dazu als Belege. Es läuft **lokal** — `gh` ist dort angemeldet (kein Token
auf dem Webhost), und das Lemma zu einer Id steht nur im Checkout des Submodules, der
Endpunkt kennt bloß Ids. Zustand hält es keinen: es liest per `gh issue list`, was schon
dort steht, erkennt Vorhandenes an unsichtbaren Markern im Issue-Text und trägt nur
Fehlendes nach, also beliebig oft wiederholbar (`server/melden/README.md`).

Das HMAC-Geheimnis liegt **ausschließlich** auf dem Server (`server/melden/README.md`). Die
Endpunkt-URL ist dagegen eine Konstante im öffentlichen Repo (`ReportService.ENDPOINT`) —
kein Geheimnis, und genau deshalb muss der Endpunkt seine Grenzen selbst setzen. Ist sie
leer, ist der Kanal aus.

## Sprachwahl: GDScript (C# nur bei Bedarf punktuell)

Das Projekt ist bewusst in **GDScript** geschrieben. Ein Wechsel auf C# ist
**nicht** geplant.

- **Shader und 3D sind kein Argument für C#.** Shader werden in der Godot Shading
  Language geschrieben (unabhängig von der Skriptsprache); die 3D-Engine läuft im
  C++-Kern und wird aus GDScript und C# über dieselbe API angesprochen. Beides lässt
  sich ohne Sprachwechsel ergänzen.
- **C# lohnt nur bei CPU-lastiger Eigenlogik** (große Simulationen, prozedurale
  Generierung, schweres Pathfinding) oder aus Tooling-/Ökosystem-Gründen (.NET/NuGet,
  Rider). Für ein Vokabel-Lernspiel trifft das nicht zu.
- **Kosten von C#:** weniger ausgereifter Web-Export, .NET-SDK-Abhängigkeit,
  langsamere Iteration, überwiegend GDScript-lastige Doku/Beispiele.
- **Strategie:** GDScript als Basis. Taucht später ein echter Performance-Hotspot
  auf, wird gezielt *diese* Klasse in C# neu geschrieben (Godot erlaubt Mischbetrieb).
  Für extreme native Performance ist **GDExtension** (C++/Rust) der Weg — nicht C#.

## Konventionen

- IDs: `kategorie.name`, z. B. `monster.slime`, `vocab.en.house`, `skill.freeze`.
- GDScript mit statischen Typen und `##`-Doc-Kommentaren.
- UI-Texte und Feedback auf Deutsch (Zielgruppe DE→EN-Lernende).
