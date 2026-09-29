# Skill-Tree: Einbaupaket

35 verlustfreie WebP-Dateien mit Alpha, passend zum freigegebenen Konzept `concept/skill-tree-v5.webp`.

## Dateien

- `icons/`: 21 Fähigkeitsicons und 3 Zusatzicons (Skillpunkt, Schild, Zurücksetzen), jeweils 256 × 256 px.
- `medallions/`: locked, available, learned und separater goldener focus_ring; jeweils 256 × 256 px, sichtbarer Durchmesser ca. 224 px.
- `status/`: Schloss und Haken, jeweils 64 × 64 px.
- `tooltip/`: skalierbarer Rahmen, vier Richtungszeiger, zwei StyleBoxTexture-Ressourcen und `tooltip_shell.tscn`.
- `skill_icons.json`: direkte Zuordnung aller 21 vorhandenen Skill-IDs zu `res://`-Texturpfaden.
- `manifest.json`: Maße, Prüfsummen, Namen und Zweigfarben aus `data/skills/*.json`.
- `preview/assets.png`: Übersicht aller Einzelteile auf dunklem Hintergrund.

## Wie das Spiel die Teile benutzt

Die Regeln des Entwurfs stehen in `concept/README.md`, dort gehen die „Entscheidungen zur
Umsetzung" dem Bild vor. Eingebaut ist:

- **Medaillons** zeichnet `src/ui/skill_graph.gd`. Benutzt wird nur `available.webp`,
  moduliert mit der Baumfarbe (hell: lernbar oder gelernt; gedämpft: zu teuer oder
  gesperrt). Gelernt tönt eine gezeichnete Scheibe die Mitte, dazu der Haken; gesperrt
  steht das Schloss statt des Icons. `locked.webp` und `learned.webp` bleiben ungenutzt.
  Den Ring misst `scenes/dev/skill_tree_lab.tscn -- --medallion` (innen 90, außen 111 px
  auf 256).
- **Icons** lädt `src/ui/skill_icons.gd` über `skill_icons.json`;
  `tests/skill_icons_test.gd` prüft, dass jeder ausgelieferte Skill eins hat.
- **Tooltip:** `tooltip/frame.webp` und die Zeiger nach oben und unten stecken im Theme
  (`scenes/ui/ui_theme.tres`, Variation `HintCard`) und gelten für jede Hinweiskarte im
  Spiel. `tooltip_shell.tscn`, `frame_only.tres`, `textured_panel.tres` und die seitlichen
  Zeiger benutzt das Spiel nicht: die Szene setzt Farben und Abstände an sich selbst, und das
  verbieten die Theme-Regeln (CLAUDE.md, `tests/theme_discipline_test.gd`).
- **Fenster:** `scenes/ui/skill_tree.tscn`, aufgebaut aus dem Fensterpaket
  (`assets/ui/windows/`, Revision 2): Rahmen `GameWindow`, Titelband `WindowTitleBar`,
  Schließen-X, Anschlussplatten, Werkzeugrahmen `ToolButton`.

## Herkunft und Prüfung

Mit dem eingebauten `image_gen.imagegen` anhand des freigegebenen Konzepts erzeugt; Prompts in `sources/prompts.json`, Originale in `sources/`. `sources/export-assets.cjs` übernimmt ausschließlich Ausschneiden, Größenanpassung und verlustfreien WebP-Export. Keine Spielimplementierung geändert. `sources/` und `preview/` sind vom Godot-Import ausgeschlossen.

Der Export prüft Alpha, Abmessungen und vollständige Zuordnung der 21 Skills. `preview/verify.gd` prüft im isolierten Godot-Projekt Texturen, Ressourcen und Tooltip-Szene.
