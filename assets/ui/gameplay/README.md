# Gameplay-HUD

Letzter abgestimmter Vorschlag: [concept/gameplay-hud-v8.png](concept/gameplay-hud-v8.png).
Ältere Vorschläge, ihre Importbegleiter, Zwischen-Prompts und Revisionsnotizen wurden aus diesem Ordner entfernt.

## Inhalt

25 verlustfreie WebP-Grafiken mit echtem Alphakanal, ohne eingebrannte Texte, Zahlen oder Fortschrittsfüllungen:

| Ordner | Grafiken |
| --- | --- |
| `frames/` | Festungsrahmen, Encounter-Rahmen, Namensplakette, offenes/geschlossenes Antwortfeld, Wortschild mit separatem Zipfel sowie einfärbbare Rahmen-/Basisebenen, Legendenstreifen, runder Knopf in Normal/Hover/Pressed/Disabled |
| `icons/` | Festung, Rüstung, Herz, gekreuzte Schwerter, Schädel, goldenes Meisterungsbuch mit Glanzlicht, Vorspulen, Porträtring, Levelplakette |
| `styles/` | Sieben Godot-StyleBoxTexture-Ressourcen mit Slice-Rändern |
| `preview/` | Asset-Übersicht, zusammengesetztes HUD auf neutralem Hintergrund, transparentes HUD-Overlay und Alpha-Prüfbericht |

[Asset-Übersicht](preview/assets.png) · [Zusammengesetzte Vorschau](preview/hud-composition.png) · [Maße und Ressourcenpfade](manifest.json)

## Aufbau und Informationshierarchie

Links oben stehen Rüstung und HP in der breiten Festungsfläche. Die schmalere Namensplakette sitzt darunter. Ihre Breite richtet sich nach dem Profilnamen, höchstens bis zur verfügbaren Breite der Festungsfläche; längere Namen mit Ellipse und vollständigem Tooltip anzeigen, nicht die Schrift dauerhaft verkleinern.

Das Level steht ausschließlich in der kleinen Plakette am Porträt. XP wird ausschließlich als blauer Füllring dargestellt. Der vorhandene Avatar `res://assets/ui/player_badge/menu/avatar.webp` wird wiederverwendet. Keine neue Profildarstellung oder Goldanzeige einführen.

Rechts oben: Welle mit Fortschritt und darunter besiegte Monster sowie gemeisterte Wörter. Das goldene Buch ist das belohnende Meisterungssymbol. Sein Glanzlicht ist in der Grafik enthalten; es muss nicht dauerhaft animiert werden.

Unten: Antwortfeld, Wortart-Legende und separater Symbolknopf zum schnellen Auflösen. Der Knopf erhält den zugänglichen Namen „Schnell auflösen“, einen Tooltip und den vorhandenen Bestätigungsdialog. Kein dauerhafter Hilfetext. Beim Bestätigen gilt weiterhin: übrige Monster laufen im Zeitraffer durch, treffen die Festung und ihre Wörter zählen als nicht gewusst.

## Skalierung und dynamische Ebenen

Die Grafiken sind stilgetreue generative Rekonstruktionen, keine pixelidentischen Ausschnitte aus dem Konzept. Das Konzept enthält illustrative Füllstände. Fortschritte immer aus Spielwerten berechnen.

- `manifest.json` enthält tatsächliche Texturgrößen, Slice-Ränder in Texturpixeln, Referenzpositionen für 1152 × 648 und die XP-Kreisgeometrie.
- Rahmen über `StyleBoxTexture`/`NinePatchRect` aufbauen. Ecken nicht unabhängig verzerren. Für kompaktere Rahmen zuerst die gesamte Rahmengeometrie einschließlich Slice-Rändern proportional skalieren und erst dann die geraden Mittelstücke verlängern. Die mitgelieferten `.tres` verwenden die natürliche Texturauflösung, nicht automatisch die kompakte Vorschaugröße.
- Der Encounter-Rahmen enthält eine horizontale Trennkante. Seine natürliche Höhe von 98 px beibehalten und nur horizontal strecken; für die Vorschauhöhe 68 px die gesamte Rahmengeometrie mit 68/98 skalieren. Nicht die Trennkante vertikal dehnen.
- Die runden Rahmen, Levelplakette und Symbole immer proportional zeichnen. Typische Symbolgrößen sind 18–28 logische Pixel, Porträtring 80 × 80 und Auflösen-Knopf 58 × 58. Die exportierten Icons haben Reserven für höhere UI-Skalierung.
- Porträtaufbau: Avatar, Metallring, dynamischer XP-Bogen in der inneren Spur, Levelplakette, Leveltext. Die Ringmitte ist tatsächlich transparent. Die Kreisparameter stehen im Manifest; am endgültigen Godot-Rendering prüfen.
- Rüstung, HP und Welle als native ProgressBars mit dunkler Spur und separater farbiger Füllung zeichnen. Keine Werte in Texturen brennen. Beispielwerte: Rüstung 60 %, HP 80 %, Welle 60 %, XP 60 %.
- Wortart-Rauten sind einfache dynamische Formen. Farben und Reihenfolge aus `WordTypePalette` übernehmen: Nomen, Verb, Adjektiv, Adverb, Phrase, Bindewort, Ausdruck.
- Enter-Taste: vorhandenen Werkzeugrahmen `res://assets/ui/windows/tool_button_normal.webp` verwenden; Symbol und Beschriftung separat zeichnen. Der gezeichnete Tastenblock in der Vorschau ist ein Platzhalter.
- Den vier Knopftexturen das separate `icons/fast_forward.webp` überlagern. Tastaturfokus als zusätzliche native Kontur darstellen. Alle Zustände haben identische Maße und Alpha-Silhouette.

## Prüfung und Herkunft

Mit dem eingebauten Imagegen-Tool aus dem letzten HUD-Konzept erzeugt: ein unbeschrifteter Metallrahmen-Atlas und ein Symbol-Atlas, beide mit Transparenz. Mit Sharp in Einzelgrafiken zugeschnitten und verlustfrei exportiert; die Knopfzustände sind Helligkeitsvarianten mit identischem Alphakanal. Die Erzeugungsaufträge waren auf leere Rahmen sowie die neun separaten Symbole beschränkt. Zwischen-Prompts und Atlasdateien sind nicht Teil dieses Pakets.

Alle 25 Dateien auf RGBA, transparente Außenpixel und erhaltene deckende Motivflächen geprüft; Ringmitte zusätzlich auf Alpha 0 geprüft. Die Kontaktübersicht zeigt die ursprünglichen 18 Grafiken; für die Ergänzungen gelten die unten verlinkten Detailvorschauen. Die Kontaktübersicht und die 1152 × 648-Komposition wurden visuell kontrolliert. Vorschau- und Konzeptordner sind durch `.gdignore` vom Spielimport ausgeschlossen.

Dies ist ein Grafikpaket mit StyleBox-Ressourcen. Spielcode und bestehende Szenen wurden nicht geändert. Eine Godot-Laufzeitprüfung mit Projektschrift, langen Namen und verschiedenen UI-Skalierungen gehört zur anschließenden Integration.

## Ergänzung: Monster-Wortschild

| Grafik | Größe | Slice links/oben/rechts/unten |
| --- | --- | --- |
| `frames/word_plate.webp` | 384 × 48 px | 36 / 8 / 36 / 8 |
| `frames/word_plate_pointer.webp` | 24 × 12 px | 0 / 0 / 0 / 0; nicht strecken |

Die ursprüngliche dunkle Plakette bleibt neutral; für die Einfärbung nach Wortart stehen zusätzlich die unten beschriebenen getrennten Ebenen bereit. Die Wortartfarben stammen aus `WordTypePalette`. Kein Text, keine Fortschrittsfüllung und kein Zipfel sind in die Plakette eingebrannt. Die kleine Goldraute sitzt jeweils im festen Endstück. Auf eine zusätzliche Fokusvariante und einen separaten Farbstreifen wurde verzichtet.

Die geraden Mittelstücke sind von Spalte 36 bis 347 pixelgleich und lassen sich horizontal verlängern, ohne Glanzstellen oder Rauschen zu dehnen. Die Endstücke bleiben 36 px breit. Technisches Minimum 96 px; die tatsächlich benötigte Breite aus der gerenderten Textbreite plus 80 px Innenabstand bestimmen. Das ist keine feste Zuordnung zwischen Zeichenanzahl und Breite.

Zipfel vor/hinter der Plakette zeichnen: seine linke obere Ecke sitzt bei `(Plakettenbreite / 2 - 12, Plakettenhöhe - 2)`. Das entspricht dem Versatz `(-12, -2)` relativ zur unteren Plakettenmitte. Die Überlappung von 2 px verdeckt die obere Zipfelkante. Bei einer Anzeigehöhe von 24 px die gesamte bereits zusammengesetzte Plakette inklusive Zipfel und Versatz auf 50 % skalieren.

`Sprite3D` bietet selbst kein Nine-Slice: vorab eine passend breite Textur zusammensetzen oder die neun Teilflächen erzeugen; alternativ UI mit `NinePatchRect` in eine Viewport-Textur rendern. Danach hinter dem `Label3D` anordnen. Ein bloßes Skalieren des gesamten Sprites in X würde die Endrauten verzerren. `styles/word_plate.tres` dient dem UI-/Viewport-Aufbau.

[Wortschild-Vorschau](preview/word-plate-lengths.png): links dunkler, rechts heller Waldgrund. Von oben nach unten 116, 260 und 480 px Plakettenbreite bei 48 px Höhe, jeweils darunter dieselbe Kombination halbiert auf 24 px Höhe. Sämtliche Textstellen sind ausschließlich Platzhalterbalken; der Hintergrund ist ein HUD-freier Ausschnitt des vorhandenen Waldkonzepts.

## Ergänzung: Antwortfeld geschlossen

`frames/answer_closed.webp` hat genau 382 × 78 px und dieselben Slice-Ränder 28 / 14 / 28 / 14 wie `frames/answer.webp`. Der goldene Innenrand wurde durch einen ruhigen silberblauen Einsatz ersetzt. Die innere Fläche bleibt dunkelblau und ausreichend hell für weißen Hinweistext. Die goldenen äußeren Endrauten und der äußere Metallrahmen bleiben erhalten. Keine Schloss-/Pausezeichen oder Texte eingebrannt.

Beim Export wurde der Alphakanal bytegenau vom offenen Feld übernommen. Prüfung nach verlustfreiem WebP-Export: 0 unterschiedliche Alpha-Pixel, maximale Alpha-Abweichung 0, identische Alpha-SHA-256. Auch RGB-Pixel des äußeren Rahmens außerhalb des inneren Einsatzes sind unverändert. Die Messwerte stehen in `preview/checks.json` unter `answer_closed`; die gleichmäßigen Wortschild-Mittelstücke unter `word_plate`.

[Antwortfeld-Vergleich](preview/answer-open-closed.png): links offen, rechts geschlossen, gleiche Abmessungen und ausschließlich Platzhalterbalken. Die kleinere rechte Platzhalterfläche repräsentiert den später vom Spiel gezeichneten Enter-Hinweis. Beim Umschalten nur Textur/StyleBox tauschen; Position, Größe und Textlayout bleiben identisch.

Herkunft der Ergänzungen: eingebautes Imagegen, Aufträge für eine vereinfachte unbeschriftete Metallplakette, ein separates nach unten gerichtetes Dreieck und einen ruhigen Antwortfeld-Einsatz ohne Goldinnenrand. Export mit Sharp: Zuschnitt, verlustfreies WebP, konstantes Wortschild-Mittelstück und Übernahme des Original-Alphas sowie des äußeren Antwortfeldrahmens. Bestehende Grafiken wurden nicht überschrieben. Keine Zwischen-Prompts oder generierten Ausgangsbilder im Asset-Paket.

## Einfärbbares Wortschild in zwei Ebenen

| Neue Grafik | Größe | Slice links/oben/rechts/unten |
| --- | --- | --- |
| `frames/word_plate_rim.webp` | 384 × 48 | 36 / 8 / 36 / 8 |
| `frames/word_plate_base.webp` | 384 × 48 | 36 / 8 / 36 / 8 |
| `frames/word_plate_pointer_rim.webp` | 24 × 12 | 0 / 0 / 0 / 0 |
| `frames/word_plate_pointer_base.webp` | 24 × 12 | 0 / 0 / 0 / 0 |

Beide Ebenen haben denselben Ursprung und dieselbe vollständige Leinwand. Nicht einzeln trimmen oder unterschiedlich skalieren. Die Rahmenebenen enthalten ausschließlich Fase und Metallrand; Innenfläche und komplette Rauten sind transparent. Alle sichtbaren Rahmenpixel sind exakt neutral (`R = G = B`), von 102/255 (40 %) bis 250/255 (98 %). Die Basisebenen enthalten die unveränderte dunkle Fläche und bei der Plakette die vollständigen goldenen Endrauten samt Innenstein. Die beiden bisherigen Gesamtgrafiken bleiben bytegenau erhalten.

Zipfelposition unverändert: `(-12, -2)` relativ zur unteren Mitte der Plakette, 2 px Überlappung. Erst Zipfelbasis und Zipfelrand, darüber Plakettenbasis und Plakettenrand zusammensetzen; Text zuletzt. Beide Plakettenebenen mit denselben Nine-Slice-Grenzen und derselben Zielbreite zusammensetzen. Für eine geteilte Sprite-Darstellung identische Position, Größe und Sampling verwenden.

### Multiplikation und Schutz der Goldrauten

- Rand: `rim.rgb * word_type_color.rgb`, Alpha unverändert.
- Innenfläche: `base.rgb * mix(vec3(1.0), word_type_color.rgb, 0.12)` als zurückhaltende Tönung; Stärke bei Bedarf anpassen.
- Goldschutz: **Die Plakettenbasis nicht pauschal mit Sprite-modulate einfärben**, denn das würde auch Gold verändern. In einem Shader die ersten und letzten 30 px von der Basistönung ausnehmen. Für eine horizontal zusammengesetzte Plakette der Breite `W` gilt: unveränderte Basis bei `x < 30` oder `x >= W - 30`. Diese Maße liegen vor der einheitlichen Skalierung; bei halber Anzeigegröße entsprechend 15 px. Der Zipfel benötigt keine Goldausnahme.
- Alternativ die gesamte Basis unverändert lassen und nur den Metallrand modulieren; das erhält ebenfalls alle Goldanteile.

Für garantiert nahtlose Darstellung bei Verkleinerung beide Ebenen **vor dem gemeinsamen Filtern** kombinieren. Am Ursprung haben sie disjunkte Alphamasken; daher die vormultiplizierten Farben addieren: `rgb_p = base.rgb * base.a + rim.rgb * rim.a`, `a = base.a + rim.a`. Dann gegebenenfalls nach Straight-Alpha zurückwandeln und die zusammengesetzte Textur skalieren. Zwei separat linear gefilterte und anschließend per Source-over gemischte Sprites können sonst an der Trennlinie eine schwach transparente Naht erzeugen. Die Vorschau verwendet die gemeinsame Komposition.

[Ebenenübersicht](preview/word-plate-layers.png): links Rand, rechts Basis; darunter der Zipfel vergrößert. [Farbprobe](preview/word-plate-tints.png): oben neutrales Grau, Mitte Blau `#3B82F5`, unten Gelb `#F5D12E`; jeweils 48 und 24 px Plakettenhöhe auf dunklem und hellem Waldgrund. Die Innenfläche wird mit 12 % Farbmischung multipliziert, die Endrauten bleiben unverändert. Nur Platzhalterbalken, keine Wörter.

Die Prüfungen in `preview/checks.json` unter `word_plate_layers` bestätigen für beide Paare: keine überlappenden Alpha-Pixel am Ursprung, keine Alpha-Abweichung zur ursprünglichen Gesamtgrafik, keine farbstichigen Rahmenpixel, unveränderte Basisfarben und unveränderte Quelldateien anhand SHA-256. Beleuchtung und Kontur stammen aus den bestehenden Grafiken; der Metallton wurde nach einer mit Imagegen erzeugten neutralen Materialstudie pixelgenau auf Grau 102–250 normalisiert. Die Studie wurde nicht als zusätzliche Asset-Datei abgelegt.
