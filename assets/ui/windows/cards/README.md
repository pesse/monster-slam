# Karten – Revision 2

Logische Pixel, Texturen 1:1 bei 1152 × 648. Alle drei Laufzeitdateien sind verlustfreie RGBA-WebP ohne Text und Symbole.

| Datei | Leinwand | Slices L / R / O / U | Kachelung |
| --- | --- | --- | --- |
| `card_normal.webp` | 192 × 192 | 32 / 32 / 32 / 32 | TILE horizontal + vertikal |
| `card_hover.webp` | 192 × 192 | 32 / 32 / 32 / 32 | TILE horizontal + vertikal |
| `card_selected.webp` | 192 × 192 | 32 / 32 / 32 / 32 | TILE horizontal + vertikal |
| `preview/cards.png` | 1152 × 1000 | – | Drei Zustände jeweils 200 × 224, 240 × 280 und 64 × 96; unten Kachelkreuzung 3× |
| `preview/pair.png` | 1000 × 320 | – | Normal + Selected jeweils 200 × 224 auf hellem und dunklem Hintergrund |
| `preview/tiles-3x3.png` | 1152 × 422 | – | Jede exportierte Mitte 3 × 3 wiederholt |
| `preview/checks.json` | – | – | Maschinenlesbare Prüfwerte |
| `sources/steel-r2-generated.png` | 1254 × 1254 | – | Neue unveränderte ImageGen-Vorlage für senkrecht gebürsteten Stahl |
| `sources/wood-generated.png` | Originalgröße | – | ImageGen-Vorlage der Holzfläche (card_selected) |
| `sources/*-tile.png` | 128 × 128 | – | Periodische Materialien vor Einbau |
| `sources/*-raw.png` | 192 × 192 | – | RGBA-Pixel vor WebP-Export |
| `sources/export.cjs`, `sources/raster.cjs` | – | – | Reproduzierbarer Export, Vorschauen, Prüfungen |
| `sources/prompt.txt` | – | – | Aktueller R2-Prompt und Exportvorgabe, danach historische R1-Prompts |
| `sources/.gdignore` | leer | – | Godot ignoriert die Quellen |

Godot: `StyleBoxTexture`, Texture Margins jeweils 32, `axis_stretch_horizontal = TILE`, `axis_stretch_vertical = TILE`, `draw_center = true`, Expand Margins 0. Keine TILE_FIT-Einstellung. Inhalt separat darüber zeichnen; Content Margins nach Bedarf unabhängig einstellen. Verlustfrei importieren, Mipmaps aus, ganze Pixelpositionen. Bei 64 px Breite sind beide 32-px-Ränder direkt benachbart, die Mitte hat Breite 0. Unter 64 px müssen die Ränder schrumpfen; dafür sind diese Teile nicht ausgelegt.

Normal und Hover werden unmittelbar aus der dekodierten **unveränderten `card_selected.webp`** aufgebaut. Es wird kein separater schmaler Fensterrahmen mehr verwendet. Die Alphamaske wird unverändert kopiert. Jede Fase, jede Niete und jedes Glanzdetail bleibt an derselben Pixelposition. Der Stahlrahmen übernimmt die Helligkeit des Goldrahmens pixelweise und erhält eine silberblaue Färbung; Luminanzabweichungen entstehen ausschließlich durch 8-Bit-Rundung (maximal 0,4894 von 255). Der Hoverrahmen wird aufgehellt, ein zarter blauer Schein sitzt nur am inneren Rand. Die Mitte von Normal und Hover ist pixelgleich.

Die neue Stahlfläche stammt aus `sources/steel-r2-generated.png`, erzeugt mit dem eingebauten ImageGen. Lange senkrechte Bürstung und feine native Linien ersetzen das körnige R1-Material. Eine zirkuläre vertikale Glättung entfernt kurze Partikel; ein nativer 128-px-Ausschnitt erhält feine Bürstspuren beim Verkleinern. Das Material wird periodisiert und auf Mittelwert und Kontrastumfang der bestehenden Holzmitte abgestimmt. Gemessene Luminanz der exportierten Mitten: Stahl Mittelwert 28,247 / Standardabweichung 2,548, Holz 28,239 / 2,605. Die Mitte hat keine Vignette. Beim Materialtausch werden nur die alten Holzbeiträge ersetzt; Rahmen und der vorhandene Innenschatten bleiben in ihrer Geometrie erhalten: 15 px Innenabstand, diagonale Eckgrenze 39, 16 px Schattenauslauf, Stärke 0,42. Die Rundungsreste des ursprünglichen Schattens bleiben erhalten. Die Lichtverläufe im Material selbst kacheln mit.

Prüfung: 192 × 192, vier Kanäle, echtes Alpha 0–255, VP8L, verlustfreier Roundtrip für Alpha und sämtliche RGB-Werte bei Alpha > 0. Unsichtbare RGB-Werte bei Alpha 0 können sich durch den WebP-Codec ändern. Alle sechs Gegenkantenvergleiche pro Zustand sind exakt 0: Mitte horizontal/vertikal sowie vier Kanten in Längsrichtung. Die Alphamasken aller Zustände sind pixelgleich (maximale Differenz 0), die Mitten vollständig deckend. Die Vorschauen werden aus den erneut dekodierten exportierten WebP zusammengesetzt, mit festen Ecken, wiederholten Kanten und abgeschnittenen Restkacheln. Die Ausschnitte unten zeigen die Kreuzung bei x/y = 160 des 460 × 460-Testaufbaus ohne eingezeichnete Hilfslinien.

`card_selected.webp` wird vom Exportskript ausschließlich gelesen. SHA-256 vor und nach R2: `947d20640afba2af2d8365cfa5aa23aa5d73de5a9891c50afc89cc768a7dc58c`. Der Export verweigert die Arbeit, wenn sich diese Eingabe geändert hat. Auch `sources/card_selected-raw.png`, die Holzquellen und die Spielaufnahme bleiben unverändert.

Visuelle Prüfung: Auf beiden Hintergründen in `preview/pair.png` wirken die Karten jetzt wie ein Paar. Breite, Ecken, Nieten, Glanzstellen und Tiefe stimmen überein. Verbleibende Materialunterschiede: Stahlbürstung ist gerader und gleichmäßiger als die organische Holzmaserung; die silberblauen Reflexe wirken kühler und weißer als Gold, trotz gleicher Rahmenluminanz. Der gemessene Materialkontrast liegt durch Periodisierung und Rundung etwa 2,2 % unter dem Holzkontrast. Feine 128-px-Materialdetails sind bei gezieltem Vergleich wiederzufinden; `preview/tiles-3x3.png` zeigt dies offen. Dies sind Rastervorschauen, keine neue Spielaufnahme; die Umsetzung ist noch nicht erneut im Spiel aufgenommen.

Reproduktion: `node ui/windows/cards/sources/export.cjs` ab `assets/`, benötigt Node.js und `sharp` (getestet 0.35.5). Das Skript sucht zuerst ein installiertes `sharp`, alternativ `MONSTER_SHARP` als Modulpfad; der letzte Fallback ist die in dieser Sitzung vorhandene Codex-Runtime. Eingaben sind nur die unveränderte Selected-WebP und die gespeicherte R2-Stahlvorlage; alle Ausgaben bleiben in `cards/`. Die vorhandenen Selected-Prüfwerte werden beim Fortschreiben von `preview/checks.json` übernommen und die Gegenkanten erneut gemessen.
