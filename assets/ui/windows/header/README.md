# Titelband und Medaillon

Alle Maße sind logische Pixel, 1:1. Die Laufzeittexturen enthalten keine Schrift oder Symbole und verwenden verlustfreies RGBA-WebP.

| Datei | Leinwand | Slices L / R / O / U | Kachelung |
| --- | --- | --- | --- |
| `title_bar.webp` | 512 × 64 | 32 / 32 / 8 / 8 | Horizontal TILE, vertikal 1:1 / STRETCH bei Höhe 64 |
| `title_medallion.webp` | 64 × 64 | keine | 1:1, keine Kachelung |
| `preview/header.png` | 1152 × 388 | – | Bänder 1152 und 640 breit; freigegebene Kopfzeile auf 1152 px darunter |
| `preview/details.png` | 1152 × 200 | – | Kachelgrenze und Medaillon ohne Icon, 3× nearest |
| `preview/checks.json` | – | – | Maße, Alpha, Gegenkanten und Rahmenvergleich |
| `sources/title_bar-raw.png` | 512 × 64 | wie WebP | Pixel vor Export |
| `sources/title_medallion-raw.png` | 64 × 64 | keine | Pixel vor Export |
| `sources/header-concept-region.png` | 1330 × 128 | – | Unveränderte textfreie Materialprobe aus dem Entwurf |
| `sources/header-tile.png` | 448 × 54 | – | Horizontal periodische Materialprobe |
| `sources/medallion-concept-region.png` | 68 × 68 | – | Ringquelle vor Entfernung des Pokals |
| `sources/concept-1152.png` | 1152 × 384 | – | Vollständiger Entwurf skaliert, Referenz für Vorschau und Ring |
| `sources/export.cjs`, `sources/raster.cjs` | – | – | Reproduzierbarer Export, Vorschauen und Prüfungen |
| `sources/prompt.txt` | – | – | Vollständige Bearbeitungsvorgabe; kein ImageGen-Aufruf für Teil B |
| `sources/.gdignore` | leer | – | Godot ignoriert die Quellen |

Godot: Titelband als `StyleBoxTexture`, Texture Margins 32 / 32 / 8 / 8, horizontal TILE, vertikal STRETCH bei fest 64 px Höhe. `draw_center = true`, Expand Margins 0. Der vorhandene obere Rahmen bleibt in Lage und Stärke erhalten. Medaillon als 64 × 64-Overlay, mittiger Icon-Slot 40 × 40, also 12 px Abstand von der Leinwandkante. Der Außenring liegt bei ungefähr Radius 30; die äußerste weiche Kontur reicht bis Radius 31.5. In der Vorschau liegt das Medaillon bei x = 18, der Pokal bei x = 30 / y = Bandoberkante + 12. Schrift: Fira Sans SemiBold 36, ausschließlich Vorschau. Verlustfrei importieren, Mipmaps aus, ganze Pixelpositionen.

Die Metallfläche und der Fasenring werden direkt aus `../folder_tabs/sources/concept-v1.png` abgeleitet. Kein gemalter Pokal bleibt in der finalen Medaillontextur: Die Innenfläche wird vollständig dunkel ersetzt. Die Materialprobe enthält keine Titelbuchstaben. Das vorhandene `../title_bar.webp` liefert obere und seitliche Rahmen sowie die Trennkante. Kein Original wird verändert.

Prüfung: Beide Zielmaße, vier Kanäle, Alpha 0–255 und VP8L bestanden. PNG/WebP-Roundtrip für alle sichtbaren RGBA-Werte und sämtliches Alpha exakt; RGB bei Alpha 0 ist technisch nicht festgelegt. Sämtliche 64 RGBA-Pixel der Spalte 479 stimmen exakt mit Spalte 32 überein. Die oberen acht Zeilen und Trennzeilen 62/63 stimmen einschließlich Alpha mit dem Original überein (unsichtbares RGB ausgenommen). Breiten 480 bis 1100 wurden mit dem TILE-Kompositor durchlaufen; die 1152-px-Vorschau liegt zusätzlich außerhalb dieses vorgesehenen Laufzeitbereichs. Beide Vorschau-Bänder und das Medaillon stammen aus den erneut dekodierten endgültigen WebP; Pokal und Titel sind reine Overlays.

Abweichungen zum Entwurf: Die freigegebene Kopfzeile misst bei 1152 px ungefähr 86 px einschließlich Rahmen, das austauschbare Band hier nur 64 px. Risse sind deshalb in der Höhe komprimiert; Ring und Icon stehen enger zwischen Oberkante und Trenner. Die Materialmitte wiederholt sich nach 448 px und enthält weniger einzigartige großflächige Glanzstellen. Die silberne obere Rahmenkante stammt aus dem bisherigen Fensterteil; die gemalte Konzeptkante hat andere Einzelreflexe. Der Innenkreis des Medaillons ist sauberer und dunkler als die gemalte Vorlage, der Ring behält deren kleine Kerben. Der Vorschautitel hat keine gemalte silberblaue Verlaufsfüllung oder Schattenextrusion. Dies ist ein Rasteraufbau, kein Godot-Screenshot.

Reproduktion ab `assets/`: `node ui/windows/header/sources/export.cjs`, Node.js und `sharp` erforderlich (getestet 0.35.5). Modulauflösung siehe `sources/raster.cjs`: reguläres `sharp`, dann `MONSTER_SHARP`, dann sitzungsspezifische Codex-Runtime. Bestehendes Konzept, Titelband, `assets/ui/statistics/icons/records_trophy.webp` und `assets/fonts/fira_sans/FiraSans-SemiBold.ttf` werden nur gelesen. Ausgaben ausschließlich in `header/`.
