# Silber-Gold-Rahmen

Passend zu den Monster-Slam-UI-Elementen: silberne, blau schattierte Metallkanten und genau eine goldene Raute je Ecke (vier insgesamt). Innenfläche und Außenbereich sind transparent. Kein Icon, keine eingebaute Hintergrundfläche.

## Dateien

- `frame.webp`: 192 × 192 px, verlustfreies WebP mit Alpha, als 9-Slice-Textur.
- `frame@2x.webp`: 384 × 384 px, 64 px Slice-Ränder.
- `frame@4x.webp`: 768 × 768 px, 128 px Slice-Ränder.
- `parts/`: vier einzelne Ecken und vier Kanten, jeweils in 1×, 2× und 4×.
- `frame.tres`: vorbereitete Godot-StyleBoxTexture für die Basisauflösung.
- `preview/sizes.webp`: Zusammensetzung in fünf unterschiedlichen Formaten.
- `sources/generated.png`: Original aus dem eingebauten Imagegen-Werkzeug.

## Größen ohne verzogene Ecken

Alle vier Slice-Ränder der Basistextur sind **32 px**. Ecken unverändert lassen; obere und untere Kante nur horizontal, linke und rechte nur vertikal strecken. Mitte nicht zeichnen. Mindestgröße bei 1×: **64 × 64 px**; praktisch sind mindestens 96 × 96 px sinnvoll. Breite und Höhe können unabhängig wachsen. Die Vorschau verwendet überall dieselben 32-px-Eckstücke und dieselbe Rahmenstärke.

WebP ist ein Rasterformat: mathematisch verlustfreie, beliebige Vergrößerung des gesamten Motivs ist damit nicht möglich. Die 9-Slice-Anordnung erlaubt beliebige Panelgrößen, ohne Eckdetails oder Rahmenstärke zu vergrößern. Für höhere Pixeldichte die 2×/4×-Dateien bei gleicher logischer Anzeigegröße verwenden. Nicht die komplette Textur auf das Zielrechteck strecken.

Für Godot `frame.tres` als Panel-Style laden. Alternativ NinePatchRect mit allen `patch_margin_* = 32`, `draw_center = false` und Stretch für beide Achsen verwenden. Eine gewünschte dunkelblaue Fläche separat dahinter zeichnen. Hochauflösende Varianten benötigen entsprechend 64/128 Texturpixel als Slice-Ränder und eine passende Skalierung auf die logische Größe. Keine Projektdateien außerhalb dieses Asset-Sets wurden angepasst.

Die WebP-Dateien sind verlustfrei gespeichert; Alpha und sichtbare RGB-Werte wurden nach erneutem Dekodieren mit den vorbereiteten PNG-Daten verglichen. Die Größenkompositionen wurden visuell geprüft. Die Godot-Ressource wurde nicht in einer laufenden Engine getestet.

## Erstellung

Bildgestaltung mit dem eingebauten Imagegen-Werkzeug; anschließend ausschließlich Zuschnitt, Größenexport, Slice-Aufteilung und Vorschau-Komposition mit Sharp. `sources/build.cjs` regeneriert die Exporte aus `sources/generated.png` (Node.js und Sharp benötigt). Der Generierungsauftrag steht in `sources/prompt.txt`.
