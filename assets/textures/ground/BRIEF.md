# Auftrag: Bodentexturen für das Schlachtfeld

Dieser Ordner nimmt **graue, nahtlos kachelnde Detailtexturen** für den Boden des
Kampfes auf. Das Spiel legt sie von oben auf den Boden und nimmt sie automatisch, sobald
die Datei hier liegt — sonst ist nichts zu tun. Bitte nur die PNGs aus der Liste unten (und die
`CREDITS.md`) hier ablegen; Entwürfe, Vorschauen und Mosaike woanders, denn jede Bilddatei
in diesem Ordner wird ins Spiel importiert.

## Wofür

Ein Lernspiel für Kinder. Burg, Monster, Bäume und Felsen sind Low-Poly-Modelle (flache
Facetten, klare Farben, wie KayKit). Der **Boden** ist dagegen ein glatt schattiertes
Hügelgelände, dessen Farbe weich zwischen den Tönen des Themas wechselt (Wiese, Wüste,
Schnee …). Ohne Textur sieht er aus wie glatter Kunststoff. Die Textur gibt ihm
**Material** — Gras, Sand, Erde, Schnee — und darf dafür **realistisch** sein: der
Kontrast zu den kantigen Modellen ist gewollt, ein stilisierter Boden sah daneben flach
und künstlich aus.

**Die Textur ist grau und bestimmt nur die Helligkeit.** Das Spiel rechnet
`Farbe × (Grauwert × 2)`: 50 % Grau (128) lässt die Farbe des Themas stehen, heller hebt,
dunkler senkt. Dieselbe Textur liegt also in mehreren Themen mit verschiedenen Farben.

Gesehen wird der Boden auf zwei Arten:

- **Draufsicht** (meistens): orthografisch von schräg oben, 30° über dem Horizont. Eine
  Kachel (8 × 8 m) ist dort nur etwa **160 Pixel breit** und 80 hoch. Alles unter etwa
  30 Pixeln in der Textur verschwindet oder flimmert.
- **Ich-Sicht**: aus 1,6 m Augenhöhe über den Boden, bis zu einem Nebel. Hier sieht man die
  Textur aus der Nähe — sie soll dort glaubhaft aussehen, nicht verwaschen.

## Technische Vorgaben (für alle)

| | |
| --- | --- |
| Format | PNG, **1024 × 1024**, 8 Bit Graustufen (oder RGB mit R = G = B) |
| Maßstab | eine Kachel = **8 × 8 m** Boden, also 128 Pixel je Meter |
| Kacheln | **nahtlos in beide Richtungen**; im 3 × 3-Mosaik keine Naht, kein Rand, keine Kante. Die letzte Zeile/Spalte schließt an die erste an — sie ist nicht deren Kopie (sonst steht an der Naht ein doppelter Pixelstreifen) |
| Helligkeit | **Mittelwert 128 (± 6)**; fast alles zwischen 90 und 170; selten unter 60 oder über 200 |
| Beleuchtung | **entleuchtet** wie eine PBR-Albedo-Map (Aufnahme bei bedecktem Himmel, Licht herausgerechnet): keine Schlagschatten, keine Glanzlichter, keine Sonnenrichtung. Das Spiel beleuchtet selbst. Leichte Dunkelung in Ritzen und Fugen (Ambient Occlusion) ist gut, aber sanft. Bleibt Relief sichtbar (Rippeln, Blattränder), dann nur angedeutet und **immer von oben links** — alle Texturen gleich |
| Blickwinkel | genau senkrecht von oben, keine Perspektive, kein Horizont |
| Formgröße | natürliche Details auf allen Größen, aber eine **tragende Struktur von 30–150 Pixeln** (0,25–1,2 m): Büschel, Schollen, Rippeln, Laubhaufen. Nur Feinkorn allein wird aus der Ferne zu flachem Grau. Feines Detail kontrastarm halten, sonst grieselt es |
| Stil | **realistisch**, wie eine gute fotogrammetrische Bodentextur aus einem aktuellen Spiel — aber erzeugt, nicht aus einem fremden Foto übernommen (siehe „Herkunft") |
| Gleichmäßigkeit | über die ganze Fläche gleich dicht; **kein Einzelstück, das auffällt** (ein großer Stein, ein dunkler Fleck, eine Spur): es wiederholt sich im Bild sieben Mal und wäre sofort als Muster zu sehen. Das gilt auch für einzeln erkennbare Dinge wie ein Blatt mit klarer Form: lieber viele kleinere, die zu einer Fleckung verschmelzen, als wenige, die man an derselben Stelle wiederfindet |

**Verboten:** Farbe; Schrift, Buchstaben, Ziffern, Zeichen, Symbole, Logos, Wasserzeichen;
Gegenstände und Lebewesen (Blumen, Pilze, Tiere, Fußspuren, Wege, Zäune); alles, was
hochsteht und einen Schatten werfen müsste — Bäume, Felsen und Grasbüschel stellt das Spiel
als eigene 3D-Modelle hin.

## Die Texturen

### `grass.png`

Kurzer, dichter Rasen von oben: unregelmäßige Büschel und Polster als weiche, etwas
hellere und dunklere Flecken, dazwischen hier und da eine kleine, flache Lücke Erde.
Richtungslos (kein Mähmuster). Die Büschel und Lücken müssen aus der Ferne als ruhige
Fleckung stehen bleiben — echtes Gras von oben ist sonst nur Rauschen. Themen: Wiese,
Gebirge, Alm, Savanne.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, short dense grass seen from directly above, soft irregular clumps in slightly
> lighter and darker gray, a few small flat patches of bare soil, no direction, flat even
> lighting, no shadows, no highlights, low contrast, average mid-gray, clumps readable at
> 30–150 px, fine detail low in contrast, no objects, no flowers, no text.

### `forest_floor.png`

Waldboden: flach liegendes Laub, Moospolster, kurze Zweigstücke, etwas Erde. Die Blätter
zahlreich und eher klein (20–60 Pixel), so dass sie zu einer Fleckung aus hellerem Laub
und dunklerem Moos verschmelzen; kein einzelnes Blatt, das man im Mosaik wiederfindet.
Themen: Wald, Urwald.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, forest floor with flat fallen leaves, soft moss cushions, a few short twigs lying
> flat and bits of soil, leaves 40–100 px, realistic detail, flat even lighting, no
> cast shadows, low contrast, average mid-gray, no high-contrast grain, no mushrooms, no objects,
> no text.

### `sand.png`

Wüstensand mit Windrippeln: sanft geschwungene, ungefähr parallele Rippeln, Abstand
60–100 Pixel, die Richtung schwankt leicht, damit das Mosaik nicht wie Wellblech wirkt.
Vereinzelt winzige flache Kiesel. Sehr ruhig. Thema: Wüste.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, desert sand with soft wind ripples, gently curving roughly parallel ripples spaced
> 60–100 px with slowly varying direction, a few tiny flat pebbles, very calm, flat even
> overcast lighting, no cast shadows, low contrast, average mid-gray, no high-contrast grain, no footprints,
> no objects, no text.

### `dry_earth.png`

Trockene, rissige Lehmerde: unregelmäßige Schollen von 80–200 Pixeln, getrennt von dünnen
Rissen, die nur etwas dunkler sind (um 95, **nicht schwarz**); die Schollen leicht
unterschiedlich hell; dazwischen wenige flache Steinchen. Themen: Canyon, Mittelmeer.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, dry cracked clay earth, irregular plates 80–200 px separated by thin cracks that are
> only slightly darker (not black), plates vary slightly in brightness, a few small flat
> stones, flat even lighting, no cast shadows, low contrast, average mid-gray, no high-
> contrast grain, no objects, no text.

### `snow.png`

Vom Wind geformte Schneedecke: weiche Verwehungen und flache Windgangeln, kaum Kontrast —
**enger als die anderen, fast alles zwischen 110 und 150**. Keine Spuren, kein Eis mit
Spiegelung. Themen: Eis, Tundra, Winterwald.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, wind-shaped snow cover with soft drifts and shallow wind ridges, very low contrast
> (values mostly 110–150), realistic snow grain kept low in contrast, flat even overcast lighting, no cast shadows, no
> sparkle, no footprints, no ice reflections, no objects, no text.

### `gravel.png`

Steinwüste des australischen Outbacks (Gibber-Ebene): eine dichte, flache Decke aus
abgerundeten Kieseln von 15–60 Pixeln, eng aneinander, dazwischen etwas feiner Staub. Die
Steine leicht unterschiedlich hell, ohne einzelnen großen Brocken; in Gruppen etwas
dichter oder lockerer, damit eine ruhige Fleckung von 60–150 Pixeln entsteht. Das Spiel
färbt sie rot. Themen: Outback, Farm, Sandsteinplateau.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, gibber plain: dense flat layer of small rounded pebbles 15–60 px packed
> closely with a little fine dust between, pebbles vary slightly in brightness, loose soft
> clusters forming a calm mottling, no large single stones, flat even lighting, no cast
> shadows, low contrast, average mid-gray, no objects, no text.

### `eucalyptus_litter.png`

Boden eines Eukalyptuswalds: lange, schmale Blätter (sichelförmig, 40–90 Pixel lang, nur
8–15 breit) und abgeschälte Rindenstreifen, die flach und kreuz und quer liegen, dazwischen
trockene Erde. Heller und trockener als `forest_floor`, kein Moos. Die Blätter so zahlreich,
dass sie zu einer Fleckung verschmelzen. Themen: Busch an der Küste, Feuchtgebiet.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, dry eucalyptus forest floor, many long narrow sickle-shaped leaves and
> curled strips of shed bark lying flat in all directions, patches of dry soil between, no
> moss, leaves merge into a calm mottling, flat even lighting, no cast shadows, low contrast,
> average mid-gray, no objects, no text.

### `marsh.png`

Feuchtwiese am Billabong: flach liegendes, nasses Seggengras in weichen Polstern, dazwischen
glatte, etwas dunklere Flecken Schlamm (60–150 Pixel). Kein offenes Wasser, keine
Spiegelung, keine Pfützen mit hellem Rand. Thema: Feuchtgebiet.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, wet marsh meadow, flattened sedge grass in soft cushions with smooth
> slightly darker patches of mud 60–150 px between, no open water, no reflections, no
> puddles, flat even overcast lighting, no cast shadows, low contrast, average mid-gray, no
> objects, no text.

### `flagstone.png`

Römisches Pflaster eines Forums: rechteckige und leicht unregelmäßige Steinplatten
(60–160 Pixel, also 0,5–1,2 m), in versetzten Reihen verlegt, Kanten abgerundet und
abgetreten, die Oberfläche fein porös wie Travertin. Die Fugen schmal (4–8 Pixel) und nur
sanft dunkler, mit etwas Staub darin, nicht schwarz. Die Platten leicht unterschiedlich
hell, damit eine ruhige Fleckung entsteht; keine einzelne Platte mit Riss oder Fleck, die
auffällt, keine Inschrift, kein Muster aus farbigen Steinen. Das Spiel färbt sie warm
beige. Themen: Forum, Markt, Hafen, Himmelsruinen.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, ancient roman forum pavement, worn rectangular travertine flagstones
> 0.5–1.2 m laid in staggered rows, rounded worn edges, finely porous surface, narrow soft
> joints only slightly darker with a little dust, stones vary slightly in brightness, no
> single standout crack or stain, no inscriptions, no mosaic, flat even overcast lighting,
> no cast shadows, low contrast, average mid-gray, no objects, no text.

### `autumn_leaves.png`

Herbstlaub im Mischwald: eine geschlossene Decke aus flach liegenden, breiten Blättern
(Ahorn, Buche, Eiche; 25–70 Pixel), dicht übereinander, dazwischen kaum Erde. Die Blätter
unterschiedlich hell, damit sie zu Laubhaufen von 80–150 Pixeln verschmelzen; **kein
einzelnes großes Blatt**, das man im Muster wiederfindet (das war der Fehler der ersten
`forest_floor`). Das Spiel färbt sie orange-rot. Themen: Herbstwald, Weinberg.

> Seamless tileable photorealistic ground texture, delit albedo map, grayscale, top-down
> orthographic view, autumn forest floor fully covered with flat lying broad fallen leaves
> of maple, beech and oak 25–70 px, densely overlapping, very little soil visible, leaves
> vary in brightness and merge into soft leaf piles 80–150 px, no single large standout
> leaf, flat even overcast lighting, no cast shadows, low contrast, average mid-gray, no
> objects, no text.

## Stand

**Neu bestellt 2026-09-28: alle fünf realistisch** (Vorgaben oben). Die erste, handgemalte
Fassung erfüllte den damaligen Auftrag — Helligkeit, Nähte und Format waren einwandfrei
und bleiben der Maßstab —, wirkte auf dem inzwischen glatten Boden aber zu flächig. Sie
bleibt im Spiel, bis die neue Datei sie ersetzt (gleicher Dateiname, einfach
überschreiben).

| Datei | Stand |
| --- | --- |
| `grass.png` | neu bestellt (realistisch) |
| `forest_floor.png` | neu bestellt (realistisch) — erste Fassung: große Einzelblätter wiederholten sich sichtbar |
| `sand.png` | neu bestellt (realistisch) |
| `dry_earth.png` | neu bestellt (realistisch) |
| `snow.png` | neu bestellt (realistisch) |
| `gravel.png` | erstellt (realistisch), 2026-09-29 |
| `eucalyptus_litter.png` | erstellt (realistisch), 2026-09-29 |
| `marsh.png` | erstellt (realistisch), 2026-09-29 |
| `flagstone.png` | erstellt (realistisch), 2026-09-29 |
| `autumn_leaves.png` | erstellt (realistisch), 2026-09-29 |

Neue Texturen werden hier als eigener Abschnitt unter „Die Texturen" bestellt und in
diese Tabelle eingetragen.

## Selbstprüfung vor der Abgabe

1. **Mosaik:** 3 × 3 nebeneinandergelegt — keine Naht, kein Kachelgitter, kein Stück, das
   sich auffällig wiederholt.
2. **Ferne:** auf 160 × 160 Pixel verkleinert — noch als Material erkennbar (Rasen,
   Rippeln, Schollen), aber ruhig, kein Grieseln.
3. **Helligkeit:** Mittelwert der ganzen Datei 122–134; kein Bereich reines Schwarz oder
   Weiß.
4. **Nur Grau**, 1024 × 1024, Dateiname genau wie oben.

## Herkunft

In `CREDITS.md` (hier im Ordner) je Datei eine Zeile: womit erzeugt (Werkzeug/Modell),
Datum, und dass keine fremde Vorlage oder Foto übernommen wurde. Das Repository ist
öffentlich; Bilder mit unklarer Lizenz können nicht hinein.

## Was danach passiert (nicht Teil des Auftrags)

Das Thema einer Unit nennt die Textur in `assets/battle_themes/<thema>.tres`
(`ground_texture`, Stärke `ground_texture_strength`); der Shader liegt in
`assets/shaders/battle_ground.gdshader`. Abgestimmt wird im Spiel, am gerenderten Bild.
