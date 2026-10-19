# Folder Tabs – Revision 4

Laufzeitteile für Monster Slam, 1:1 bei 1152 × 648, verlustfreies RGBA-WebP ohne Schrift. Direkt aus `sources/concept-v1.png` abgeleitet. Revision 4 übernimmt gemessenes Stahlblau statt der grauen Aufhellung von R3, behält senkrechten Verlauf und horizontale Bürstung über die gesamte Höhe und verwendet die hellblaue Grundlinie des Entwurfs. Die Vorschau hat jetzt 2 px Textkontur. Änderungen ausschließlich innerhalb dieses Ordners; Originalkonzept und R2-Spiel-Screenshot bleiben unverändert.

| Datei | Leinwand | Slices L / R / O / U | Verwendung |
| --- | --- | --- | --- |
| `tab_normal.webp` | 128 × 44 | 16 / 16 / 12 / 6 | Stahlblaue Metallfläche mit hellerem Kopf, dunklerem Fuß und Originalfase |
| `tab_hover.webp` | 128 × 44 | 16 / 16 / 12 / 6 | Hellerer blauer Grundton, Silberfase, unterer blauer Reflex |
| `tab_selected.webp` | 128 × 44 | 16 / 16 / 12 / 6 | Goldfase und Außenschein; dunkle offene Innenfläche mit schwachem Höhenverlauf |
| `rail.webp` | 32 × 44 | 0 / 0 / 41 / 3 | Neu exportiert mit identischer Grundlinie aus dem Konzept |
| `preview/folder-tabs-1152.png` | 1152 × 648 | – | Exportierte Teile auf bestehenden Fenstertexturen, Beschriftung nur Overlay |
| `preview/folder-tabs-zoom.png` | 1012 × 224 | – | Zwei Reitergrenzen, 4× nearest |
| `preview/compare-v1.png` | 3456 × 600 | – | Original/Export bei 1152 px, darunter beide Zeilen zusätzlich 3× nearest |
| `preview/compare-v1-1152.png` | 1152 × 164 | – | Nur die beiden unskalierten Vergleichszeilen |
| `preview/checks.json` | – | – | Vertragsprüfung, Farbmessungen, Quellen und Sichtprüfung |
| `sources/export.py` | – | – | Reproduzierbare Extraktion, WebP-Export, Vorschau und Prüfung mit Pillow |
| `sources/*-raw.png` | wie jeweilige WebP | – | Finale RGBA-Pixel vor WebP-Export |
| `sources/*-concept-region.png` | variable | – | Unveränderte Quellregionen aus dem Konzept; Beschriftung wird bei der Texturgewinnung ausgespart |
| `sources/prompt.txt` | – | – | Aktuelle Bearbeitungsvorgabe, kein neuer generativer Modellaufruf |
| `sources/.gdignore` | leer | – | Quellen vom Godot-Import ausgeschlossen |

## Godot

`HBoxContainer`, `separation = 0`, gleiche Oberkante und immer genau 44 px Höhe. Buttons 100–260 px breit, `custom_minimum_size.y = 44`, `toggle_mode = true`, gemeinsame `ButtonGroup`. Pro Zustand eine `StyleBoxTexture`: normal → normal, hover → hover, pressed und hover_pressed → selected. Texture-Margins L/R/O/U 16/16/12/6, STRETCH, `draw_center = true`, Expand-Margins 0. Content-Margins separat, beispielsweise L/R 16, O 10, U 12. Vertikal nicht über 44 px strecken: die mittleren Zeilen sind jetzt ausdrücklich variabel und werden bei 44 px Höhe 1:1 abgebildet.

Rechts ein horizontal expandierendes `Panel` mit Schienen-StyleBoxTexture, Höhe 44, Margins L/R/O/U 0/0/41/3. Die Sprachauswahl darf darüberliegen. Gemeinsame Fensterfläche hinter der ganzen Zeile und dem Inhalt; kein zusätzlicher oberer Inhaltsrahmen unter dem offenen aktiven Reiter. Keine zusätzliche Fokus-Grundlinie zeichnen.

Beschriftung: Fira Sans SemiBold 16 px, Weiß bzw. Gold, dunkle 2-px-Kontur. Nur die Vorschauen enthalten Schrift; Pillow `stroke_width=2` ist eine Rasterannäherung, keine in Godot aufgenommene Darstellung. Ganze Pixelpositionen, Texture Filter Nearest, Mipmaps aus, Import Lossless, Premultiply Alpha und Fix Alpha Border aus.

## Farbmessung und Ableitung

Mittelwerte aus den jeweiligen `*-concept-region.png`, RGBA-Alpha überall 255; die Tabelle zeigt RGB. Textfreie Proben x=40…53, oben y=10…17, Mitte y=40…47, unten y=70…77; Rand x=40…53/y=1…2. Diese Messwerte sind auch in `checks.json` enthalten.

| Bereich | Normal RGB | Hover RGB |
| --- | --- | --- |
| Oberer Körper | 10 / 26 / 46 | 22 / 41 / 69 |
| Mitte | 8 / 23 / 41 | 12 / 30 / 54 |
| Unterer Körper | 7 / 21 / 39 | 10 / 28 / 50 |
| Rand | 120 / 138 / 189 | 215 / 227 / 235 |

RGB und Fasen stammen jetzt ohne Grau-Aufhellung oder Entsättigung aus dem Konzept. Der textfreie vertikale Materialstreifen wird waagerecht wiederholt; in der Höhe bleiben seine Originalschwankungen und der dunklere Fuß erhalten. Bei Füllalpha 200 werden die Farben rechnerisch auf den dunklen Referenzhintergrund RGB 8/20/36 zurückgerechnet. Die zusammengesetzte Innenfläche weicht dort um höchstens 1 RGB-Stufe von der resampelten Quellprobe ab; dies wird für Normal/Hover bei y=4…37 geprüft. Bei abweichendem Fensterhintergrund verändert sich der Eindruck durch die Transparenz leicht. Hover erhält zusätzlich einen aus der lokalen blauen Grundlinienreflexion entnommenen unteren Lichtschein; Selected bleibt offen mit maximal 30 Alpha im Innenraum und einem schwachen Verlauf über die Höhe.

## Neue Grundlinie

Das Konzept wird zuerst per Lanczos mit Faktor `1152/2172` auf 1152 × 384 verkleinert. Die drei logischen Pixelzeilen 172/173/174 werden im textfreien rechten Schienenbereich x=796…1007 gemittelt und unverändert als gleichmäßige Anschlussfarben übernommen:

| Texturzeile | RGBA |
| --- | --- |
| 41 | 0, 5, 24, 255 |
| 42 | 107, 126, 173, 255 |
| 43 | 63, 84, 130, 255 |

Normal, Hover und Schiene über die volle Breite pixelgleich; Selected nur x=0…2 und 125…127, x=3…124 auf allen drei Zeilen transparent. Die Linie hat nun die helle blaue Lichtkante und dunklere Übergänge des Entwurfs. `rail.webp` wurde dafür mit exportiert; maßgeblicher aktueller SHA-256 steht in `checks.json`.

## Vergleich und Prüfstand

`compare-v1.png` zeigt oben den Originalstreifen bei 1152 px, darunter die echte Komposition aus WebP-Texturen mit 16-px-Schrift und 2-px-Kontur. Beide Streifen darunter zusätzlich 3× nearest. Gerundete Reiterzellen 182/180/173/184 px, Beginn x=30. Originalgröße 2172 × 724, kein verändertes oder nachgemaltes Original. Vorschauen nach dem finalen Export visuell kontrolliert.

PASS: Maße, RGBA, VP8L und pixelidentischer PNG/WebP-Roundtrip; Füllalpha Normal/Hover 200, Selected ≤40; Außenschein nur in den erlaubten drei Randspalten, Alpha ≤60. Mittlere Spalten x=16…111 über die gesamte Höhe bytegleich; mittlere Zeilen y=12…37 nachweislich variabel. Jeder ganzzahlige Breitenwert 100…260 bei fester Höhe 44 geprüft, einschließlich pixelgleicher Grundlinie und offener Selected-Mitte. Der neue Vertrag ersetzt ausdrücklich die alte Forderung konstanter Mittelzeilen und einer unveränderten Schiene.

Verbleibende Unterschiede: Die waagerechte Gleichförmigkeit entfernt seitliche Materialvariationen und einzelne Glanzpunkte aus der dehnbaren Mitte; Bürstung und Verlauf in der Höhe bleiben erhalten. Die feste 44-px-Höhe, 6-px-Körperabstände und 16-px-Laufzeitschrift weichen geringfügig von der gemalten Referenz ab; auch Fensterhintergrund und Font-Rasterung sind nicht identisch.

Reproduktion: `python sources/export.py`, benötigt Pillow mit WebP-Unterstützung sowie die gespeicherten Quellen, bestehende Fenstertexturen und `assets/fonts/fira_sans/FiraSans-SemiBold.ttf`. Alle Ausgaben verbleiben in diesem Ordner.