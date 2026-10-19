# Monster Slam – Controls: Direktableitung aus controls-v1

Revision 4 ersetzt die flache Atlas-Ableitung. Die 19 Laufzeitdateien übernehmen Material, Fasen, Glanz, Eckreflexe, Haken und vertikale Flächenverläufe direkt aus [concept/sources/controls-v1.png](concept/sources/controls-v1.png), 2128 × 739. Quelle und exakte Ausschnitte sind in [preview/checks.json](preview/checks.json) mit SHA-256 dokumentiert. Der alte `sources/controls-atlas.png` bleibt historische Quelle und wird beim aktuellen Export nicht verwendet.

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
