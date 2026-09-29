# Tooltip-Transparenzkorrektur

Ziel: vorhandene Goldkontur erhalten, navy/schwarze Füllung und Schatten vollständig transparent machen. Originale: `tooltip-before-alpha/`. Finale deterministische Alpha-/Matte-Korrektur: `tooltip-alpha.cjs`. Kein Spielcode und keine Theme-Ressource verändert.

Mit eingebautem Imagegen wurden zwei Freistellungen geprüft, aber wegen Konturveränderung verworfen. Die Dateien dienen nur als Quellenprotokoll, nicht als Runtime-Input.

Prompt für `tooltip-transparent-generated.png` (Referenz `../frame.webp` vor Änderung):

Edit this exact tooltip frame: REMOVE ALL navy blue/black fill, all dark backing, dark outline and shadows everywhere, including the entire interior and exterior corners. Those regions must be truly alpha=0 transparent, not dark translucent. Retain ONLY the thin gold/yellow metallic chamfered rectangular contour in its original position, same geometry and thickness, same square aspect ratio. No new objects, no redesign, no shadow, no glow halo, no dark rim. Entire huge inner area is an empty transparent hole. Transparent outside gold contour too. Keep original gold highlights and antialiased gold edge only. This is a transparent gold outline overlay for use on WHITE backgrounds, so no black/blue pixels or matte can remain. No text.

Prompt für `pointer-transparent-generated.png` (Referenz `../pointer_up.webp` vor Änderung):

Edit this exact tooltip pointer: retain ONLY its two fine gold diagonal strokes forming an upward chevron roof shape. Remove ALL dark navy blue and black filled triangular interior, backing, shadow, dark outline. True alpha=0 transparency in all interior and exterior empty space, no dark translucent pixels. Keep exact geometry, proportions, thin gold material and location, no bottom horizontal line, no redesign, no new shape. It will be overlaid on a WHITE background so absolutely no dark matte. Transparent background.

Reproduktion: `node sources/tooltip-alpha.cjs` (Sharp erforderlich, optional `SHARP_MODULE`). Das Skript liest die gesicherten Originale, schreibt fünf WebP-Dateien, aktualisiert Manifest-Prüfsummen und erstellt die Vorschau. Das Tooltip-Paket hat einen eigenständigen Export; der Skill-Tree-Export verändert es nicht.
