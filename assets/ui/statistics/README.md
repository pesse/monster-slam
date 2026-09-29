# Statistik-Icons

Sechs transparente, verlustfreie WebP-Einzeldateien in `icons/`, jeweils 256 × 256 px mit maximal 208 × 208 px Motiv. Alpha und Maße beim Export geprüft; Vorschau auf dunklem Hintergrund visuell geprüft.

| Datei | Verwendung |
| --- | --- |
| streak_flame.webp | Übungsserie |
| correct_check.webp | Richtige Antworten / letzte Sitzung |
| records_trophy.webp | Titel und Rekorde |
| gold_coins.webp | Goldbestand |
| treasure_chest.webp | Geöffnete Schatzkisten |
| activity_coin.webp | Tag mit Übung |

`manifest.json` enthält alle res://-Pfade und Verweise auf wiederverwendete Skill-Tree-Assets: Stern, silbernes Medaillon, goldener Hover-Ring und Tooltip-Szene. Keine Duplikate dieser Assets nötig.

Icons mittig über die Medaillon-Basis legen; bei 80 px Medaillon das Icon etwa 52 px groß anzeigen. Für kleine Zeilen 32–40 px verwenden, Seitenverhältnis erhalten, linear filtern. Die Grafik enthält keine Beschriftung und keinen Medaillon-Hintergrund. Kalender: dunkles Medaillon als leerer Tag, Münze darüber für geübt, vorhandenen goldenen Fokusring bei Hover darüber; Datum und Zahlen nativ rendern. Dunkle Basis für die Kalenderreihe: `res://assets/ui/skill_tree/medallions/locked.webp` (ohne Schloss-Overlay).

Quelle: eingebautes `image_gen.imagegen`, Stilreferenz `concept/statistics-v2.webp`. Vollständiger Prompt in `sources/prompt.txt`, Originalatlas in `sources/icons-atlas.png`. `sources/export-icons.cjs` schneidet die Motive aus und exportiert sie ohne gestalterische Nachbearbeitung. `sources/` und `preview/` sind vom Godot-Import ausgeschlossen. Vorschau: `preview/icons.png`.

## Wie das Spiel die Teile benutzt

- **Fenster:** `scenes/ui/stats_screen.tscn`, dieselben Schichten wie die Fähigkeiten
  (Rahmen, Fläche, Titelband mit Pokal, Schließen-X, Anschlussplatten). Öffnet über dem
  Hauptmenü, Esc schließt.
- **Reiter:** `tabs/tab_normal.webp` und `tabs/tab_highlighted.webp` sind die Reiter aus
  `../windows/` auf zwei Drittel verkleinert (347 × 64, `src/dev/shrink_image.gd`): ihr
  28-px-Rand passte in keinen 40 px hohen Reiter. Im Theme als `WindowTab` mit 19 px Rand.
- **Medaillons:** 80 px, `skill_tree/medallions/available.webp` als Basis, Icon mit 14 px
  Rand darüber (Stern 18 px). Mipmaps an, die Icons stehen bei 1152 × 648 auf gut einem
  Viertel.
- **Monatsreihe:** `scenes/ui/stats_day.tscn` je Tag, 28 px: `locked.webp`, darauf
  `activity_coin.webp` an geübten Tagen, `focus_ring.webp` bei Zeiger oder Fokus (heute
  halb). Die Tage 1–n kommen aus dem Datum (`CoinStrip`).
- **Zeilen:** Gold, Kiste und Stern mit 32 px vor Wert und Text.
- Nicht übernommen aus dem Entwurf: die schmale Anordnung „Abschnitte untereinander,
  Monat als Raster". Die Bezugsbreite ist immer 1152 px (`canvas_items`/`expand` dehnt nur
  die längere Achse), die Reihe mit 31 Tagen passt dort.
