# ADR 0003 — Skills sind Bäume, die alten Fähigkeiten heißen Spells

Status: **umgesetzt** · Datum: 2026-09-15 · Berührt: ADR 0001 (Pack-Kanal, `min_app_version`)

## Kontext

Seit dem Erfahrungs-System (`Experience`/`PlayerLevel`) sammelt jedes Levelup einen
Skillpunkt an, für den es nichts zu kaufen gibt. Der Start-Screen schrieb ihn hin, der
Statistik-Screen sagte wörtlich „noch nichts zum Ausgeben", und `player_level.gd` hielt im
Kopfkommentar fest, dass der Zähler für ausgegebene Punkte erst mit den Fähigkeiten kommt.
Der Lernfortschritt zahlte damit auf nichts ein.

Die Fähigkeitsbäume sind die Antwort darauf — und sie stießen sofort auf einen
Namenskonflikt. Unter `data/skills/` lag bereits etwas: die **aktiven Fähigkeiten mit
Abklingzeit** („Ersten Buchstaben zeigen", „Monster verlangsamen"), aus der Vision von
Anfang an vorgesehen, als Daten vorhanden und im Code über `ContentRegistry.skills`,
`GameState.active_skills` und die Signale `skill_activated`/`skill_ready` angelegt.
Umgesetzt war davon noch nichts: die Signale hatten keinen Emitter, `active_skills` keinen
Leser, und `ContentRegistry.skills` wurde ausschließlich in `main.gd` gezählt.

Zwei Dinge, ein Name. Beide sollen bleiben, und ein Skill soll später einen Spell
freischalten können — die Kollision ist also nicht vorübergehend.

## Entscheidung

**Die aktiven Fähigkeiten mit Abklingzeit heißen ab jetzt Spells** (`data/spells/`,
`ContentRegistry.spells`, `GameState.active_spells`, `spell_activated`/`spell_ready`,
Ids `spell.*`). **Der Name `skills` gehört dem Baum** (`data/skills/` mit dem neuen
Baum-Schema, `ContentRegistry.skills`, Ids `skill.*` und `tree.*`).

Es sind **zwei Content-Kategorien nebeneinander**, nicht eine mit einem Unterscheidungs-
feld. Sie haben nichts gemeinsam außer dem früheren Namen: ein Spell wird im Kampf
ausgelöst und hat eine Abklingzeit, ein Skill wird einmal gekauft und wirkt dauerhaft über
`SkillBook.bonuses()` auf den Lauf. Eine gemeinsame Kategorie hieße, jeden Leser mit einer
Fallunterscheidung zu belasten, die ihn nichts angeht.

Der Name der *Punkte* bleibt `skill` (`Experience.SKILL_POINTS_PER_LEVEL`,
`PlayerLevel.skill_points()`, alle Anzeigetexte): sie gehören jetzt erst recht zum Baum.

## Folgen

**Die Kategorienliste steht an vier Stellen** und alle vier mussten mit:
`_by_category` in `src/core/content_registry.gd`, `CATEGORIES` in
`src/content/pack_installer.gd`, `CATEGORIES` in `tools/packs/build_packs.py` und die
`roots`/`include`-Blöcke in `data/language/packs.yaml` (privates Submodule). Zwei Wächter
halten sie zusammen: `build_packs.py:check_categories_match_installer()` und
`tests/content_registry_roots_test.gd`.

**`min_app_version` musste steigen** (0.2.0 → 0.7.0). Das ist der eigentliche Grund, aus
dem diese Umbenennung ein ADR ist: eine App vor der Umbenennung kennt `spells/` nicht und
verwürfe den Ordner still — **und** sie läse die neuen `skills/`-Dateien als Zauber, also
Baum-Köpfe und Knoten als Fähigkeiten mit Abklingzeit. Genau dafür gibt es das Feld aus
ADR 0001; ohne das Hochzählen verlöre ein alter Client die Zauber und bekäme dafür Unsinn.

**Ein installierter Pack von vorher wird zur Waise.** Auf einem Rechner, auf dem der
`game`-Pack vor der Umbenennung installiert wurde, liegt unter
`user://content/game/skills/basic_skills.json` noch die alte Zauber-Datei — und sie landet
beim Start in der Kategorie `skills`, also zwischen den Bäumen. Zur Laufzeit ist das
folgenlos: `SkillTree.trees()` und `tiers_of()` filtern über `kind`, ein Eintrag ohne
`kind` ist weder Baum noch Knoten. `tests/skill_data_test.gd` prüft deshalb nur, was aus
`ContentRegistry.DATA_ROOT` kommt, und hält die Gleichgültigkeit gegenüber dem Rest mit
`test_foreign_entries_are_ignored` fest. Mit dem nächsten Pack-Update verschwindet die
Waise von selbst.

**ADR 0001 bleibt unverändert.** Es hält den Stand seiner Zeit fest — dass dort noch von
`skills` als Fähigkeitskategorie die Rede ist, ist kein Fehler, sondern Chronologie.
