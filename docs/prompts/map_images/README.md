# Prompts: Kartenbilder

Die Bilder für Buchkarte und Gebietskarte (ADR 0006) entstehen mit einem Bild-KI-Tool. Je
Buch gibt es eine eigene Datei mit eigenem **Thema**. Ein Thema ist eine Welt mit Stimmung —
Landschaft, Jahreszeit, Wetter, Licht —, nicht bloß eine Farbe:

| Buch | Datei | Thema |
|---|---|---|
| Access 2 | [`access2.md`](access2.md) | Frühling im Waldland — hell, freundlich, blühend |
| Access 3 | [`access3.md`](access3.md) | Düsterer Spätherbst — Nebel, kahle Bäume, Laub, Laternen |
| Access 4 | [`access4.md`](access4.md) | Wüste — Dünen, Canyons, Oasen, Sandstein, flirrende Hitze |

Alle Karten eines Buchs, Buchkarte wie Gebietskarten, tragen sein Thema. Zwischen den Büchern
soll man den Unterschied auf den ersten Blick sehen.

Die Prompts dort sind **vollständig**: einen Codeblock ganz kopieren, fertig. Grundstil und
Buchstil stecken schon drin. Die Punkte, an denen die Orte liegen, setzt man danach in der
Werkbank `scenes/dev/map_lab.tscn`.

## Der Stil: ein Spielbrett, keine Malerei

Das Spiel zeigt Low-Poly-Modelle von KayKit und Quaternius; die Festung ist aus den Kacheln
von „KayKit Medieval Hexagon" gebaut (`assets/models/CREDITS.md`). Eine Karte muss dazu
passen und **wie eine Karte lesbar** sein. Deshalb:

- **Ein Brett aus Sechseck-Kacheln**, als Ganzes sichtbar, schwebend auf dunklem Grund —
  kein Landschaftsbild mit Horizont und Himmel. Die Ränder des Bretts machen es zur Karte.
- **Low-Poly, flach schattiert**, klare Flächenfarben: Bäume als Kegel und Kugeln, Häuser
  als einfache Blöcke mit farbigem Dach. Keine Pinselstriche, keine Fototexturen.
- **Schräg von oben** (isometrisch, etwa 50°), ohne Fluchtpunkt-Perspektive.
- **Der Hintergrund ist das Dunkelblau der Oberfläche (#161B29).** Dann gehen Bildrand und
  Rand der Karte ineinander über, und die Kopfleiste steht auf ruhigem Grund.
- **Das Licht gehört zum Thema**, nicht zum Grundstil: ein düsteres Buch hat düsteres
  Licht. Die Marker müssen trotzdem lesbar bleiben — nie so dunkel, dass die Halte im
  Schatten verschwinden.
- **Freie, flache Kacheln an jedem Halt**: dort sitzt der runde Marker des Spiels.
- **Kein Text, keine Zahlen, keine Figuren.** Die Motive kommen nur aus den allgemeinen
  Themen einer Unit, nie aus ihren Vokabeln — die Karten liegen im öffentlichen Repo.

Der Grundstil, der in jedem Prompt steckt:

> Stylized low-poly 3D diorama in the style of the KayKit Medieval Hexagon asset pack: a
> game board made of hexagonal terrain tiles with chunky, flat-shaded, slightly rounded
> low-poly models — trees as simple cones and blobs, small houses as blocks with coloured
> roofs, faceted rocks. Clean flat colours, soft ambient occlusion,
> no textures, no painterly brushwork. Isometric camera from about 50 degrees above, the
> whole board visible with its hexagonal outline and a thin layer of earth and stone
> beneath the tiles, floating on a plain flat dark navy background (#161B29), no sky, no
> horizon. It reads like a board-game map. No text, no letters, no numbers, no UI, no
> people. 16:9.

Negativ-Prompt, wo das Tool einen kennt:

> painting, painterly, concept art, matte painting, realistic, photorealistic, detailed
> textures, sky, clouds, horizon, mountains in the distance, text, letters, labels, logo,
> watermark, frame, border, compass, people, characters, cluttered

**Tipps je Tool**

- Midjourney: `--ar 16:9 --style raw --no text, letters, sky, painting`.
- Kann das Tool ein **Stilreferenzbild**, einen Screenshot aus dem Kampf mitgeben (Festung
  und Monster). Dann trifft es Formen und Farben deutlich besser als mit Worten allein.
- Wird es doch wieder ein Gemälde: „low poly", „flat shaded" und „board game tiles" nach
  vorn ziehen und das Bild einmal ohne Stadtdetails erzeugen lassen.

## Ablage

```
assets/maps/<book>/book.png        Buchkarte
assets/maps/<book>/unit<n>.png     Gebietskarte der Unit n
assets/maps/<book>/map.json        Punkte (schreibt die Werkbank)
```

- **Format:** 16:9, mindestens 1920×1080, PNG oder WebP. Unter 2 MB je Bild: die Karten
  liegen in der EXE.
- **Nach dem Ablegen:** `tools/godot.sh --import`, dann in der Werkbank Buch und Karte
  wählen, die Punkte der Reihe nach setzen und speichern.
- **Fehlt ein Bild oder ein Punkt,** zeigt das Spiel eine schlichte Fläche und legt die Orte
  selbst aus. Man kann also Karte für Karte nachliefern.

## Aufbau der beiden Kartenarten

- **Buchkarte:** das ganze Brett des Buchs, so viele **deutlich getrennte Regionen**, wie das
  Buch Units hat, verbunden durch einen Weg aus hellen Kacheln, der links beginnt und rechts
  endet. Jede Region hat eine freie Kachelgruppe für ihren Marker.
- **Gebietskarte:** eine Region aus der Nähe, im Stil und in den Farben ihres Buchs. Ein Weg
  aus hellen Kacheln führt durch **sechs freie Halte**: vier kleine, einen größeren
  Sammelplatz und am Ende eine **Boss-Arena** auf einem erhöhten Plateau. Der Weg beginnt
  links unten, die Arena liegt rechts oben.

## Neue Bücher und Units

- **Neues Buch:** eine neue Datei `<book>.md` mit eigenem Thema — Landschaft, Jahreszeit,
  Wetter, Licht (zum Beispiel „verschneiter Winter", „Vulkaninseln", „Sumpf"). Es soll
  sich von den anderen Büchern auf den ersten Blick unterscheiden.
- **Neue Unit:** die Themen aus den `tags` ihrer Lexeme ablesen (nur die Themen, keine
  Wörter) und in einen Ort im Stil des Buchs übersetzen. Die Buchkarte bekommt eine Region
  mehr und ist neu zu erzeugen.
