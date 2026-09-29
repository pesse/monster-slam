# Skill-Tree: Einbaupaket

30 verlustfreie WebP-Dateien mit Alpha, passend zum freigegebenen Konzept `concept/skill-tree-v5.webp`.

## Dateien

- `icons/`: 21 Fähigkeitsicons und 3 Zusatzicons (Skillpunkt, Schild, Zurücksetzen), jeweils 256 × 256 px.
- `medallions/`: locked, available, learned und separater goldener focus_ring; jeweils 256 × 256 px, sichtbarer Durchmesser ca. 224 px.
- `status/`: Schloss und Haken, jeweils 64 × 64 px.
- Allgemeines Tooltip-Paket: `../tooltip/`, mit eigenem Manifest, Quellen und Vorschauen.
- `skill_icons.json`: direkte Zuordnung aller 21 vorhandenen Skill-IDs zu `res://`-Texturpfaden.
- `manifest.json`: Maße, Prüfsummen, Namen und Zweigfarben aus `data/skills/*.json`.
- `preview/assets.png`: Übersicht aller Einzelteile auf dunklem Hintergrund.

## Wie das Spiel die Teile benutzt

Die Regeln des Entwurfs stehen in `concept/README.md`, dort gehen die „Entscheidungen zur
Umsetzung" dem Bild vor. Eingebaut ist:

- **Medaillons** zeichnet `src/ui/skill_graph.gd`. Benutzt wird nur `available.webp`,
  moduliert mit der Baumfarbe (hell: lernbar oder gelernt; gedämpft: zu teuer oder
  gesperrt). Gelernt tönt eine gezeichnete Scheibe die Mitte, dazu der Haken; gesperrt
  steht das Schloss statt des Icons. `learned.webp` bleibt ungenutzt; `locked.webp` ist
  die dunkle Basis der Monatsreihe in der Statistik (`scenes/ui/stats_day.tscn`).
  Den Ring misst `scenes/dev/skill_tree_lab.tscn -- --medallion` (innen 90, außen 111 px
  auf 256).
- **Icons** lädt `src/ui/skill_icons.gd` über `skill_icons.json`;
  `tests/skill_icons_test.gd` prüft, dass jeder ausgelieferte Skill eins hat.
- **Tooltip:** Gemeinsame Texturen unter `assets/ui/tooltip/`, eingebunden im zentralen Theme als `HintCard`. Dokumentation und Transparenzprüfung stehen im dortigen README.
- **Fenster:** `scenes/ui/skill_tree.tscn`, aufgebaut aus dem Fensterpaket
  (`assets/ui/windows/`, Revision 2): Rahmen `GameWindow`, Titelband `WindowTitleBar`,
  Schließen-X, Anschlussplatten, Werkzeugrahmen `ToolButton`.

## Herkunft und Prüfung

Mit dem eingebauten `image_gen.imagegen` anhand des freigegebenen Konzepts erzeugt; Prompts in `sources/prompts.json`, Originale in `sources/`. `sources/export-assets.cjs` übernimmt ausschließlich Ausschneiden, Größenanpassung und verlustfreien WebP-Export. Keine Spielimplementierung geändert. `sources/` und `preview/` sind vom Godot-Import ausgeschlossen.

Der Export prüft Alpha, Abmessungen und vollständige Zuordnung der 21 Skills. `preview/verify.gd` prüft im isolierten Godot-Projekt die 30 Texturen und 21 Skill-Zuordnungen; das allgemeine Tooltip-Paket hat eine eigene Prüfung.
