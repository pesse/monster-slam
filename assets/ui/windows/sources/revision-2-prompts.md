# Revision 2 – Konzeptgetreue Fensterstruktur

Referenz für beide Imagegen-Aufrufe: `../skill_tree/concept/skill-tree-v5.webp`, relativ zum Fensterpaket. Eingebautes Imagegen, kein CLI-/API-Fallback.

## shell-v2-generated.png

Precise editing of this approved game UI concept: deliver only the EMPTY WINDOW SHELL, preserving its exact proportions, dark navy blue-gray material, thin silver-blue outer metal frame, chamfered outer corners and recessed header with a VERY THIN 2 pixel bottom divider, including small beveled metal joint plates where divider joins left/right vertical outer frame. Remove ALL content: all text, book, star, close X, all nodes, circles, graph connections, compass, tooltip, tools, buttons and symbols. Remove outside scenic background, transparent outside window only. Keep all inside window opaque dark navy with very subtle cloudy material texture matching original. HEADER IS NOT A BUTTON: no thick bottom frame, no chamfered lower corners across header, no separate complete frame around header. Header blends structurally into one common outer frame. Only its hairline metallic bottom divider and subtle recessed surface distinguish header from body. Empty header height ~64 relative to full 648px canvas. Body clean dark blue subtle texture, no shapes or symbols whatsoever. Straight-on flat orthographic asset, maintain original 16:9 aspect ratio. Thin outer frame 6-8 logical pixels, chamfers 16 logical pixels. Preserve original layout and understated lighting.

## close-v2-generated.png

Extract/recreate the exact SMALL SILVER CLOSE X from the top right of this reference as a single standalone transparent icon. It must have the same slender diagonal strokes and pale almost-white silver face, cool lavender-blue lower bevel, near black fine outline. NOT the broad heavy blue X often used as game buttons. Slender stroke width about 14 percent of total X width, beveled straight ends, symmetrical centered union of two diagonals. Front facing, no perspective. X visible size 96x96 centered on eventual 128x128 canvas; preserve 12.5 percent clear margins. Only one X, no button or enclosing frame, no text, no other marks. Transparent outside silhouette. Tiny dark bevel under silver white metal, no big glow, no cast shadow. Match reference top right icon rather than invent new styling.

## Reproduzierbarer Export

`node sources/rebuild-v2.cjs`, mit installiertem Sharp; optional Modul über `SHARP_MODULE` auswählen. `extend-windows.cjs` ruft denselben Export auf.

Aus der generierten leeren Hülle werden Ecken, konstante Kantenprofile und Anschlussplatten exportiert. Platten erhalten eine enge Alphamaske. Die Titeloberkante verwendet dieselben Pixel wie das Panel; die Trennkante ist ein vierzeiliges Profil mit zwei dunklen Begrenzungszeilen. Material wird separat aus einer Innenflächenprobe exportiert und durch Spiegelung nahtlos kachelbar gemacht. Panel-/Titelmittelstücke bleiben exakt konstant. Toolrahmen werden aus dem Panel mit 1/4-Randstärke abgeleitet. Die X-Zustände werden aus demselben beschnittenen Motiv durch reine RGB-Änderungen abgeleitet.

Vorherige Prompts und Quellen bleiben historische Referenzen. `preview-v1.png` zeigt den verworfenen ersten Aufbau. Aktueller Vergleich: `preview/concept-header-comparison.png` (oben Originalkonzept, unten tatsächliche Asset-Komposition).
