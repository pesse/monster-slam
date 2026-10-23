# Monster Slam – Controls: Direktableitung aus controls-v1

Revision 4 ersetzt die flache Atlas-Ableitung. Die 19 Laufzeitdateien übernehmen Material, Fasen, Glanz, Eckreflexe, Haken und vertikale Flächenverläufe direkt aus [concept/sources/controls-v1.png](concept/sources/controls-v1.png), 2128 × 739. Quelle und exakte Ausschnitte sind in [preview/checks.json](preview/checks.json) mit SHA-256 dokumentiert. Der alte `sources/controls-atlas.png` bleibt historische Quelle und wird beim aktuellen Export nicht verwendet.

HUD-Ergänzung: neun weitere Texturen, insgesamt 28 Laufzeitdateien; neue Einbau- und Prüfangaben stehen am Ende dieser README.

| Datei | Leinwand | Slices L/T/R/B | Verwendung |
| --- | --- | --- | --- |
| `field_normal.webp` | 128 × 44 | 16 / 16 / 16 / 16 | Vertieftes LineEdit/TextEdit, dunkle ruhige Mitte |
| `field_focus.webp` | 128 × 44 | 16 / 16 / 16 / 16 | Transparente Goldfassung mit warmem innerem Saum; **über normal zeichnen** |
| `field_read_only.webp` | 128 × 44 | 16 / 16 / 16 / 16 | Gesperrtes Feld, gedämpfte silberblaue Fassung |
| `seg_first_normal.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Linke Endkappe, rechts halbe Fuge |
| `seg_first_hover.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Linkes Segment, heller und erhaben |
| `seg_first_selected.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Linkes Segment, goldene vertiefte Auswahl |
| `seg_first_disabled.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Linkes Segment, gedämpft und entsättigt |
| `seg_mid_normal.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Mittelsegment, beidseitig halbe Fuge |
| `seg_mid_hover.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Mittelsegment, heller und erhaben |
| `seg_mid_selected.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Mittelsegment, goldene vertiefte Auswahl |
| `seg_mid_disabled.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Mittelsegment, gedämpft und entsättigt |
| `seg_last_normal.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Links halbe Fuge, rechte Endkappe |
| `seg_last_hover.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Rechtes Segment, heller und erhaben |
| `seg_last_selected.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Rechtes Segment, goldene vertiefte Auswahl |
| `seg_last_disabled.webp` | 96 × 44 | 16 / 16 / 16 / 16 | Rechtes Segment, gedämpft und entsättigt |
| `check_off.webp` | 32 × 32 | keine | CheckBox-Icon `unchecked` |
| `check_on.webp` | 32 × 32 | keine | CheckBox-Icon `checked`, Goldfassung und goldener Haken |
| `check_off_disabled.webp` | 32 × 32 | keine | CheckBox-Icon `unchecked_disabled` |
| `check_on_disabled.webp` | 32 × 32 | keine | CheckBox-Icon `checked_disabled` |
| `hud_plate.webp` | 96 × 64 | 16 / 16 / 16 / 16 | Erhabene Kampfplatte; ruhige Mitte, Alpha 235 |
| `bar_track.webp` | 64 × 16 | 8 / 6 / 8 / 6 | Vertiefte Metallrinne für Balken und HSlider |
| `bar_fill.webp` | 64 × 16 | 8 / 6 / 8 / 6 | Neutral hellgraue, gewölbte Füllung; 2 px transparenter Rand bereits enthalten |
| `slider_knob.svg` | 24 × 24 | keine | Runder Goldknopf mit silberblauem Ring (Vektor, siehe unten) |
| `slider_knob_hover.svg` | 24 × 24 | keine | Hellerer Knopf, gleiche Geometrie |
| `scroll_track.webp` | 12 × 48 | 0 / 6 / 0 / 6 | Senkrecht dehnbare vertiefte Bildlaufrinne |
| `scroll_grabber.webp` | 12 × 48 | 0 / 6 / 0 / 6 | Erhabener stahlblauer Bildlaufgriff |
| `scroll_grabber_hover.webp` | 12 × 48 | 0 / 6 / 0 / 6 | Heller silberblauer Bildlaufgriff |
| `scroll_grabber_pressed.webp` | 12 × 48 | 0 / 6 / 0 / 6 | Goldener gedrückter Bildlaufgriff |

## Aufbau und Einbau

**Alle Felder und Segmente: Slices L/T/R/B = 16/16/16/16.** Leinwände und Dateinamen bleiben gleich, Segment-/Feldhöhe 44 px. Die breiten Metallränder mit etwa 5–6 px sichtbarer Fase werden als feste Quellzonen übernommen. Nur die textfreien Dehnspalten werden zu einer gemeinsamen Spalte zusammengefasst; vertikale Glanz- und Farbverläufe der Segmente bleiben erhalten. Es werden keine Metallfarben oder Fasen nachgezeichnet.

Die Fuge ist eine **6 px breite plastische Metallrippe**, je 3 px pro Nachbar. Ihre obere/untere Schulter stammt aus der ursprünglichen Segmentfuge, die breite Licht-/Schattenfläche aus der tatsächlichen linken Metallfassung des Konzepts. Die Übergänge mischen ausschließlich diese Quellpixel. Die Rippe ist in allen Zuständen identisch, auch zwischen Gold, Hover und Disabled. Die erste transparente Außenzeile hält auch die Mittelsegmente nativ im RGBA-Format.

Godot: `StyleBoxTexture`, vier `texture_margin_*` auf 16, beide Achsen `STRETCH`, keine Expand-Margins. Felder dürfen in beiden Achsen wachsen; Segmente bleiben 44 px hoch und sind von 44 bis 220 px Breite geprüft. Filter Linear, Mipmaps aus, Lossless-Import. Die UI-Skalierung bis 5/3 kommt nach dem Layout.

Feld: `normal` bzw. `read_only` verwenden, `focus` zusätzlich darüberzeichnen. Fokus enthält nur die aus dem Originalfeld übernommene Goldfassung und deren warmen Saum; x=16…111, y=16…27 ist vollständig transparent. Die normale Innenfläche übernimmt die ruhige blaue Eingabefläche ohne goldenen Fokus-Saum. Die mittleren Feldzeilen sind für TextEdit absichtlich gleichförmig. Innenabstände weiterhin L/R 12, T/B 8, Schrift 20 px hell; Content-Margins **explizit** setzen, da sie von den Texture-Margins 16 abweichen.

Segmentleiste: `HBoxContainer.separation = 0`, Buttons mit `toggle_mode = true`, gemeinsame `ButtonGroup`, `allow_unpress = false`. Pro Position first/mid/last: normal, hover, pressed = selected, hover_pressed = selected, disabled zuweisen. Keine zusätzliche Trennlinie hinzufügen. Content-Margins explizit L/R 12, T/B 4; Fira Sans SemiBold 20 px, Weiß bzw. Gold, dunkle Kontur 4 px. Damit bleibt bei 44 × 44 ausreichend Platz für die mittige Ziffer.

CheckBox-Icons ungesliced in `unchecked`, `checked`, `unchecked_disabled`, `checked_disabled` einsetzen. Die stärkeren Rahmen werden mit festen Eck-/Randzonen aus den Originalkästchen abgeleitet; der ausgeschaltete Innenraum bleibt vertieft.

## Vergleich und Sichtprüfung

- [preview/controls-1152.png](preview/controls-1152.png): 1152 × 648, ausschließlich aus den dekodierten Laufzeittexturen sowie vorhandenem `window_panel_compact.webp` und `window_surface.webp` zusammengesetzt. Schrift und Cursor sind Vorschau-Overlays.
- [preview/compare-v1.png](preview/compare-v1.png): **oben unveränderte Originalregionen**, auf Kontrollhöhe 44 px bzw. Kästchenhöhe 32 px verkleinert; **darunter Laufzeitkomposition bei identischen Positionen, Breiten und Höhen**. Feld, Knopf, beide Segmentgruppen und Kästchen werden einzeln gegenübergestellt. Diese ausdrücklich beschriftete Regionenmontage vermeidet einen Größenvergleich von 59-px-Konzeptsegmenten mit 44-px-Laufzeitsegmenten.
- [preview/controls-zoom.png](preview/controls-zoom.png): zwei tatsächlich zusammengesetzte Fugen selected|hover und hover|normal, 4× Nearest.

Die Sichtprüfung erfolgt an diesem Vergleich bei gleicher Größe: breite silberblaue Eckflächen und Licht-/Schattenseiten, kräftige eingesetzte Metallrippen, glanzvolle Goldfassung mit warmer Vertiefung, heller erhabener Hover und deutlich erkennbare Kästchen. Gegenüber der verworfenen Lieferung werden diese Merkmale aus dem freigegebenen Bild übernommen; zusätzlich wurde die Rippenfläche verbreitert.

Verbleibende Unterschiede: Dehnbare Spalten sind identisch und enthalten keine wandernden horizontalen Glanzflecken; die Feldmitte ist auch senkrecht konstant. Die rechte goldene Endkappe spiegelt die originale linke Goldkappe; Hover-Endkappen verwenden die originalen silberblauen Eckfacetten. Gemeinsame Rippen bleiben neutral silberblau. Die vorhandene lokale Fira Sans SemiBold dient auch als Vorschau-Feldschrift; die angeforderte 4-px-Kontur ist kräftiger als die Originalbeschriftung. Eine pixelidentische Kopie ist wegen der festen Laufzeitgeometrie und Dehnverträge nicht beabsichtigt.

## Prüfbericht

**19/19 RGBA-Dateien, 48/48 Nahtpaare und 39/39 Dehnfälle bestanden.** [checks.json](preview/checks.json) enthält pro Datei Maße, Format, Alpha, SHA-256, Verlustfreiheitsvergleich, die tatsächlich geprüften 6×44-RGBA-Anschlussprofile und Materialstichproben pro Höhe.

| Prüfung | Ergebnis |
| --- | --- |
| Maße | 3 × 128 × 44; 12 × 96 × 44; 4 × 32 × 32, alle exakt |
| Format | Alle 19 nativ RGBA8, VP8L; transparente Außenbereiche und geglättete Kanten |
| Verlustfrei | Nach Export erneut geladen, sämtliche RGBA-Bytes identisch |
| Dehnbare Spalten | x=16 bis Breite−17 über alle 44 Zeilen identisch, 0 Abweichungen |
| Vertikaler Verlauf | Segmentzeilen dürfen und sollen variieren; Quellverläufe in `material_samples` dokumentiert |
| Feld senkrecht | y=16…27 über die volle Breite identisch, 0 Abweichungen |
| Fokus | Mitte vollständig transparent, auch bei 1000 × 300 |
| Slice-Lage | Seitliche Fasen, Eckreflexe und vollständige 3-px-Fugenhälften in fixen 16-px-Zonen; Feld auch senkrecht |
| Nähte | first\|mid, mid\|mid, mid\|last jeweils 16 Zustandspaare: alle 6×44 Pixel entsprechen der gemeinsamen Rippe, kein Höhenversatz |
| Dehnfälle | Felder 128 × 44, 360 × 44, 1000 × 300; alle 12 Segmentvarianten bei Breite 44/96/220 und Höhe 44 |

Prüfung mit Godot 4.7 headless in einem isolierten temporären Projekt. Keine vorhandenen Dateien außerhalb von `assets/ui/windows/controls/` wurden geändert. Der Bericht unterscheidet automatische Technikprüfung und manuelle Sichtprüfung.

## Quellen und Reproduktion

Aktuelle Rohregionen: `sources/normal-concept-region.png`, `hover-concept-region.png`, `selected-concept-region.png`, `rib-concept-region.png`, `check-on-concept-region.png`, `check-off-concept-region.png`. Vollständige Quellkoordinaten und Originalhash stehen im Prüfbericht. Die Normalisierung 2128 → 1152 bewahrt die logischen Materialmaße; feste obere/untere Quellstreifen verhindern ein Zusammendrücken der Fasen auf 2–3 px.

`sources/build_controls.gd` exportiert und prüft die Texturen und erzeugt alle drei Vorschaugrundbilder. `sources/preview_text.ps1` setzt lokale Fira-Sans-Beschriftung und Cursor darüber. Beide `.gdignore` bleiben leer. `sources/prompt.txt` dokumentiert die aktuelle direkte Ableitung und den historischen Atlas-Prompt.

```powershell
$controlsDir = 'C:\dev\privat\monster-slam\assets\ui\windows\controls'
$taskDir = Join-Path $env:TEMP 'monster-controls-runtime-build'
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
& 'C:\dev\_tools\godot\Godot_v4.7-stable_win64_console.exe' --headless --path $taskDir --script (Join-Path $controlsDir 'sources\build_controls.gd')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $controlsDir 'sources\preview_text.ps1')
```

Das Textskript direkt nach dem Builder ausführen, damit das Overlay nur einmal aufgetragen wird. Der Builder setzt die manuelle Sichtprüfung bei jedem Neuaufbau auf `pending`; ihr abschließendes Ergebnis im gelieferten `checks.json` wurde nach Sichtung der tatsächlichen PNGs gesetzt und ist kein automatischer Ähnlichkeitswert.

## HUD-Ergänzung

Neun zusätzliche Texturen für Kampfplatten, Fortschrittsbalken, HSlider und VScrollBar; zusammen mit den bisherigen Controls **28 Laufzeitdateien**. Die Originaldateien der 19 Controls, deren Quellen, Skripte, Importdateien und Vorschauen bleiben unverändert. Nur diese README und `preview/checks.json` wurden ergänzt. Der Prüfbericht enthält die neuen Ergebnisse unter `hud`; die bisherigen Kontrollprüfungen bleiben erhalten.

[preview/hud-1152.png](preview/hud-1152.png) zeigt die Komposition auf RGB **40/36/70**: Bossplatte mit Herz-Platzhalter und 70 % roter Füllung, Satzplatte, Schieberegler bei 50 %, goldener Erfahrungsbalken bei 30 % und die drei Bildlaufgriffzustände. Zusätzliche Farbproben zeigen Grün/Gelb/Blau, eine 16 px breite Füllung und beide Schieberknöpfe. Text und Herz sind ausschließlich Vorschau-Overlays, keine Laufzeitgrafiken.

### Material und Dehnverhalten

- Die HUD-Platte übernimmt die breiten Fasen und abgeschrägten Eckreflexe aus den fertigen first/last-Normal-Texturen. Verlauf und Wölbung liegen in den festen Randzonen; die Mitte ist in beiden Achsen pixelgleich, mit Alpha **235/255**. So bleiben auch große Kampfpanels ruhig, ohne gezogene Glanzflecken.
- Die Rinne stammt aus dem vorhandenen vertieften Feld. Bei nur 16 px Höhe werden die Metallfasen proportional verkleinert. Die Füllung übernimmt den erhabenen Hover-Look und seine Glanzstellen, wird neutral hellgrau umgerechnet und erhält unten einen kräftigeren Schatten. **R=G=B** ist für alle sichtbaren Pixel geprüft; Godot kann sie ohne Blaustich einfärben.
- Der Sliderknopf kombiniert die originale silberne Kästchenfassung ohne Haken mit einem goldgetönten Kern aus demselben Metallmaterial. Die Hover-Variante ist heller und verwendet exakt dieselbe Alphamaske.
- Die Scroll-Texturen werden aus Rinne und Hover-/Gold-Metall abgeleitet und transponiert, damit Licht weiter von oben/links kommt. Die mittleren Zeilen y=6…41 sind identisch; sie dehnen ohne wandernde Glanzpunkte. Hover ist messbar heller als Normal.

### Godot-Zuordnung

| Element | Theme-Zuordnung / Einstellungen |
| --- | --- |
| Kampfplatte | `Panel/styles/panel` oder entsprechende PanelContainer-StyleBoxTexture, Slices 16/16/16/16, beide Achsen STRETCH |
| ProgressBar | `background = bar_track`, `fill = bar_fill`, Slices 8/6/8/6, feste Höhe 16 |
| HSlider | `slider = bar_track`, `grabber_area` und `grabber_area_highlight = bar_fill` goldgetönt; Icons `grabber` und `grabber_highlight` aus den 24-px-Knöpfen |
| VScrollBar | `scroll = scroll_track`; `grabber`, `grabber_highlight`, `grabber_pressed` aus den drei Grifftexturen; Breite explizit 12; Slices 0/6/0/6, senkrecht STRETCH |

Filter Linear, Lossless-Import, Mipmaps aus. Die Knöpfe werden bei 24 × 24 nicht gesliced und sitzen mittig auf der 16-px-Rinne, also 4 px Überstand oben/unten.

Bei Balken ist der **2-px-Abstand bereits in bar_fill enthalten**. Track und Fill erhalten dieselbe äußere Position und Höhe; keine weiteren 2 px versetzen und nicht um zusätzliche Innenabstände verkleinern. StyleBox-Content-Margins für die Balken auf 0 setzen. Die Vorschau berechnet die sichtbare Fülllänge über die innere Breite `W−4`: `Fill-Leinwandbreite = 4 + round((W−4) × Anteil)`. Unter 16 px Füllbreite eine 16-px-Füllung passend clippen; bei 0 % die Füllung ausblenden. Die Texturen selbst sind ab 16 px Breite geprüft.

`bar_fill` bleibt neutral. Über `StyleBoxTexture.modulate_color` z. B. Rot `(1, 0.20, 0.23, 1)`, Gold `(1, 0.76, 0.19, 1)`, Grün `(0.28, 1, 0.39, 1)` oder Blau `(0.25, 0.58, 1, 1)` zuweisen. Nur die Füllung färben, die Rinne behält ihre silberblaue Fassung.

### HUD-Prüfergebnis

**9/9 neue Dateien und 17/17 Dehnfälle bestanden.**

| Prüfung | Ergebnis |
| --- | --- |
| Maße / Format | Alle Leinwände exakt gemäß Dateitabelle, nativ RGBA8 und VP8L |
| Verlustfreiheit | Erneut dekodierte WebP-RGBA-Bytes stimmen exakt mit dem Exportbild und der jeweiligen Roh-PNG überein |
| Alpha | Transparente Außenbereiche, geglättete Ränder; HUD-Flächenmitte genau 235/255 |
| Dehnzonen | HUD in beiden Achsen, Balken waagerecht, Scroll-Texturen senkrecht: 0 Pixelabweichungen |
| Platte | 120 × 44, 400 × 64, 1100 × 400; Ecken und Fasen bleiben fest |
| Balken | Beide Texturen bei 16, 200 und 600 px Breite, Höhe 16 |
| Füllungsrand | Ringsum exakt 2 transparente Pixel, auch in allen drei Dehnfällen |
| Neutrale Füllung | 0 farbige sichtbare Pixel, exaktes R=G=B vor Modulation |
| Bildlauf | Alle vier Texturen bei 48 und 600 px Höhe, Breite 12 |
| Hover | Knopf und Scrollgriff heller als Normal, Alphamasken pixelgleich |

Die finale HUD-Vorschau wurde mit `concept/controls-v1.webp` und `preview/compare-v1.png` verglichen: die originalen Metallfacetten, Eckreflexe und die Silberblau-/Gold-Farbwelt bleiben erhalten. Unterschiede ergeben sich aus den geforderten Abmessungen: 16-px-Balken und 12-px-Scrollleisten haben proportional kleinere Fasen; die große Plattenmitte bleibt absichtlich homogen. Die neutrale Füllung und der goldene Knopfkern sind Tonwert-/Farbableitungen des Originals. Es sind keine offenen Maß-, Alpha-, Dehn- oder Anschlussfehler bekannt.

### HUD-Quellen und Reproduktion

`sources/hud-source-notes.txt` dokumentiert die Ableitung. Jede neue Textur besitzt ein gleichnamiges `sources/<Name>-raw.png`. Quelltexturen und SHA-256 stehen unter `hud.sources` im Prüfbericht.

Für diese Ergänzung ausschließlich den separaten Builder verwenden; er ruft den früheren Controls-Builder nicht auf und erhält dessen Prüfdatensätze:

```powershell
$controlsDir = 'C:\dev\privat\monster-slam\assets\ui\windows\controls'
$taskDir = Join-Path $env:TEMP 'monster-controls-hud-build'
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
& 'C:\dev\_tools\godot\Godot_v4.7-stable_win64_console.exe' --headless --path $taskDir --script (Join-Path $controlsDir 'sources\build_hud.gd')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $controlsDir 'sources\hud_preview_text.ps1')
```

Der HUD-Builder überschreibt bei Wiederholung ausschließlich die neun HUD-Dateien, ihre neun Roh-PNGs, `preview/hud-1152.png` und den HUD-Abschnitt in `checks.json`. Das Textskript direkt danach ausführen. Die manuelle Sichtprüfung wird beim Neuaufbau zunächst auf `pending` gesetzt und ist im gelieferten Bericht nach Prüfung der tatsächlichen Vorschau dokumentiert.

## HSlider: Vektor statt Textur

Rinne und Füllung des HSlider sind `StyleBoxFlat` im Theme (8 px hoch, Radius 4), der Knopf ist `slider_knob.svg` / `slider_knob_hover.svg` (24 × 24) in denselben Farben. Die gemalten 16-px-Texturen wirkten bei Skalierung schmutzig; `slider_grabber*.webp` sind entfernt und `build_hud.gd` erzeugt sie nicht mehr. `bar_track`/`bar_fill` bleiben für die Balken.
