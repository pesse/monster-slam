# Zusammensetzbare Festungsanzeige

Umsetzungsvorgabe: kompakter Entwurf `concept/fortress-hud-v3.png` mit breitem Bereich für variable Unit-Titel. Sechs transparente, verlustfreie WebP-Dateien; keine eingebrannten Texte oder Zahlen. Generative Rekonstruktionen im Stil des Konzepts, keine pixelidentischen Ausschnitte.

## Teile

| Textur unter textures/ | Größe | Einsatz |
| --- | --- | --- |
| name_panel.webp | 600 × 180 | Verbreiterbarer Buch-/Unit-Rahmen |
| progress_panel.webp | 480 × 180 | Separater Fortschrittsbereich |
| medallion.webp | 320 × 320 | Runde Hintergrundfassung |
| castle.webp | 256 × 256 | Festungs-Icon, separat austauschbar |
| level_plate.webp | 160 × 120 | Leere Plakette für aktuelle Stufe |
| progress_track.webp | 400 × 48 | Leerer Balkenrahmen |

`manifest.json` enthält res://-Pfade, Maße und Nine-Slice-Ränder. Vier StyleBoxTexture-Ressourcen unter `styles/` sind für Panels, Stufenplakette und Balken vorbereitet. Castle und Medaillon ausschließlich proportional skalieren. `preview/parts.png` zeigt alle Einzelteile.

## Aufbau für den Coding-Agenten

Orientierungsmaß für eine sichtbare Anzeige: 900 × 180 px; abhängig von UI-Skalierung anpassen. Alle folgenden Rechtecke sind Layoutwerte dieses Beispiels, keine Texturausschnitte:

1. Fortschrittsrahmen hinten bei (440, 28), Größe (340, 126).
2. Namensrahmen davor bei (0, 28), Größe (480, 126). Überlappung verdeckt die doppelte Verbindungskante. Für längere Titel diesen Bereich verbreitern und die folgenden Teile entsprechend nach rechts verschieben.
3. Medaillon bei (735, 0), Größe (165, 165), vor rechtem Ende des Fortschrittsrahmens.
4. Festung mittig auf Medaillon, etwa (762, 20), Größe (112, 112).
5. Stufenplakette ganz vorn bei (787, 123), Größe (62, 47); Zahl als zentriertes Label darüber. Platz auch für zwei Ziffern halten.
6. Texte nativ: Buchname klein und Unit-Titel größer im Namensbereich; Festung, Balken und Restwörter im Fortschrittsbereich. Beispielpositionen: Buch (36,48), Titel (36,82), Festung (490,44), Balken (490,76,225,16), Restwörter (490,102), bei Bedarf zweizeilig.

Die StyleBox-Ränder beziehen sich auf Quellpixel. Für das Beispiel mit verkleinerten Elementen Ränder und Content-Margins proportional reduzieren oder die gesamte Baugruppe in Designgröße über eine gemeinsame Transform skalieren. Standardmäßig werden Nine-Slice-Ränder nicht automatisch passend zur Zielhöhe kleiner. Das Medaillon niemals als NinePatch darstellen.

## Dynamischer Balken

`progress_track.webp` ist die leere Bahn. Darüber innerhalb der dunklen Vertiefung eine native blaue Füllung zeichnen, an den Innenbereich maskiert; sichtbare Breite = Innenbreite × clamp(Fortschritt, 0, 1). Alternativ ProgressBar mit dem Track als Hintergrund-Style und abgerundetem StyleBoxFlat als Fill. Füllung darf den Metallrand nicht überdecken. Füllfarbe etwa #43BAFA. Es ist keine zusätzliche generierte Fülltextur nötig.

Fortschritt und Restwörter aus vorhandenen Spieldaten beziehen. Stufe 0 bedeutet nicht automatisch 0 % Fortschritt. Maximalstufe und fehlende nächste Schwelle entsprechend der bestehenden Spiellogik behandeln, Division durch null vermeiden. Texte, Stufenzahl und Icon sind keine neue Spiellogik.

## Variable Texte und Bedienung

Breite nicht auf „Unit 1“ festlegen. „The world around us“ ist ein Layoutbeispiel. Unit-Titel darf bei Bedarf zweizeilig sein, danach Ellipse und vollständiger Tooltip. Auch Buchnamen können länger als „Access 4“ sein. Bei kompakter Darstellung ausreichend große Schrift beibehalten, zuerst Layout umbrechen. Der HUD ist eine Anzeige, kein neuer Button: mouse_filter IGNORE verwenden, sofern kein Tooltip benötigt wird.

Fortschritt bei Änderungen optional kurz interpolieren, Stufenaufstieg kurz hervorheben; keine dauerhafte Animation und reduzierte Bewegung beachten. Castle bleibt austauschbar, falls bereits stufenabhängige Festungsmodelle existieren.

## Prüfung und Herkunft

WebP-Export und transparente/deckende Alphabereiche geprüft; alle sechs Teile auf dunklem Hintergrund visuell geprüft. Die Godot-Style-Ressourcen sind vorbereitet, aber in dieser Übergabe noch nicht in einer Spielszene gerendert. Beim Einbau Nahtstellen, Nine-Slice-Ränder, lange Titel und tatsächliche Projektschrift prüfen.

Erstellt mit eingebautem image_gen.imagegen; Prompt in `sources/prompt.txt`, Originalatlas in `sources/atlas.png`. Export reproduzierbar mit `sources/export.cjs` (Sharp). `sources/` und `preview/` sind vom Godot-Import ausgeschlossen. Konzeptbilder sind keine Runtime-Assets.
