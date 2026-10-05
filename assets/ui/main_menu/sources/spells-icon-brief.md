# Bestellung: Icon „Zauber“ (ADR 0014)

Der Knopf „Zauber“ im Hauptmenü, der Knopf in der Knopfreihe der kompakten Plakette und die
Titelleiste des Ladens (`scenes/ui/spell_shop.tscn`) zeigen vorläufig `icons/content.webp`
(die Truhe von „Inhalte“). Zwei gleiche Symbole übereinander im Menü sind verwechselbar.

Gebraucht wird `icons/spells.webp`, 256 × 256, RGBA, im Stil der übrigen acht Icons
(silbern, kantig, Low-Poly-Facetten wie im Atlas `icons.png`). Lesbar ab 24 px, denn so
klein steht es an der Plakette.

Motiv: ein **bauchiges Zauberfläschchen mit Korken**, silbern, im Bauch ein kleiner
leuchtender Funke. Gold oder Farbe nur im Funken. Keine Schrift, kein Buch (das ist
„Fähigkeiten“), keine Truhe (das ist „Inhalte“).

Prompt im Stil von `prompts.json`:

> Use case: background-extraction. Using the sculpted icon style of the attached approved
> Monster Slam menu icon atlas, create ONE isolated icon: a SILVER ROUND-BELLIED MAGIC POTION
> FLASK with a cork stopper, beveled low-poly physical game pictogram, same silver-blue steel
> material, bevels and lighting as the book, chart and chest icons, a small glowing warm
> spark inside the flask as the only color accent. Centered, occupying no more than 60% of a
> square canvas, genuinely transparent background and holes. No plaque, no text, no extra
> elements.

Danach `export-assets.cjs` ergänzen, die drei `ext_resource` auf `spells.webp` umstellen
(`profile_menu.tscn`, `profile_badge.tscn`, `spell_shop.tscn`) und `manifest.json` nachtragen.
