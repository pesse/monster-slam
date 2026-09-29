# Fensterpaket-Ergänzung – Quellen und Prompts

Erzeugung: eingebautes Imagegen, kein API-/CLI-Fallback. Nachbearbeitung und verlustfreier Export: Sharp, `extend-windows.cjs`. Alle Pfade relativ zum Paket.

Referenzen: `../skill_tree/concept/skill-tree-v5.webp`, `../main_menu/buttons/button_normal.webp`, ursprüngliches `window_panel_compact.webp`. Zusätzlich visuell verglichen mit `../../../reports/skill_tree/skill_tree_1920x1080.png` (relativ zum Paket).

## Titelband → title-generated.png

Create ONE isolated empty game window TITLE BAR texture. References 1 and 2 define exact dark blue gray and silver blue metal style. Reference 3 shows the header at top, reproduce that empty header only. Wide horizontal strip, ratio 8:1, thin 8px beveled silver-blue metal rim with 16px chamfered corners relative to 64px height; dark inset blue-gray fill, bottom metal bevel separates from content. Transparent outside chamfered corners. Straight-on orthographic UI asset. Entire long middle section absolutely uniform horizontally: no scratches, highlights, mottling or horizontal gradient, highlights only in end caps; subtle cross-sectional vertical bevel shading allowed. No text, no letters, no symbols, no icons, no X, no buttons, no ornamental features. Final target 512x64 after export; show single wide band filling canvas width.

## Schließen → close-generated.png

Create ONE isolated silver-blue metallic CLOSE X icon matching the top-right X in reference 1 and metal material in reference 2. Transparent background. Square canvas, centered symmetric X occupies exactly 75 percent width and height, ample even transparent margins. Two straight diagonal metal bars forming one solid X, moderately thick bars, crisp beveled silver faces, cool blue lower bevel, near-black dark outline to read against dark navy title bar. Flat orthographic front view. No frame, no button background, no surrounding shape, no additional marks, no text or letters other than the requested X shape. Clean recognizable silhouette at 32px game size. Balanced upper-left lighting, no cast shadow outside silhouette. Production UI icon.

## Export und abgeleitete Zustände

- `window-panel-before.webp`: unveränderte Sicherung des vorherigen kompakten Panels; ursprüngliche generierte Quelle weiterhin `window-generated.png`.
- Panel: ursprüngliche Ecken erhalten, Übergänge innerhalb der festen 32-px-Slices; gerade Kanten aus einem konstanten Querschnitt. Innenfläche vereinheitlicht, damit keine Textur gedehnt wird.
- Titel: transparente Außenränder zugeschnitten, 512 × 64, mittlere Spalten konstant; dunkle Füllung zusätzlich abgesenkt. Nur die Endkappen enthalten lokale Variation.
- X: auf 96 × 96 eingepasst, mittig auf 128 × 128; Hover RGB × 1,16 + 9, Pressed × 0,69. Alpha und Geometrie bleiben unverändert.
- Werkzeugknöpfe: aus dem kompakten Rahmen per Nine-Slice auf 88 × 88 zusammengesetzt und auf 44 × 44 reduziert. Hover × 1,22 + 5; Pressed × 0,70; Disabled × 0,52 + 3. Keine Zeichen.
- Vorschaubuch und Vorschautext werden separat zusammengesetzt; sie gehören nicht zu den Laufzeittexturen.

Reproduktion: `SHARP_MODULE` bei Bedarf auf die lokale Sharp-Installation setzen, dann `node sources/extend-windows.cjs` ausführen. `build.cjs` ist der ältere Erstexport und ersetzt die Ergänzung; für diese Version ausschließlich `extend-windows.cjs` verwenden. Node.js und Sharp werden vorausgesetzt.
