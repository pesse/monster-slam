# Monster-Slam-Kampfmedaillen

Alle Laufzeitbilder sind 256 × 320 Pixel große, verlustfreie RGBA-WebP-Dateien mit echtem Alphakanal. Keine Schrift oder Zahlen sind eingebrannt.

| Datei | Material / Symbol | Stoffband |
| --- | --- | --- |
| bronze.webp | Bronze, leer | Rotbraun |
| silver.webp | Silber, leer | Blau |
| gold.webp | Gold, leer | Rot |
| diamond.webp | Hellblau-weißer Diamant, leer, Randfunkeln | Violett |
| comeback.webp | Orange/Kupfer, Pfeil nach oben | Dunkelrot |
| better.webp | Türkis/Jade, Stern | Dunkeltürkis |
| revenge.webp | Violett/Amethyst, gekreuzte Schwerter | Dunkelviolett |
| catch_up.webp | Grün/Smaragd, zwei Winkel nach oben | Dunkelgrün |

Geometrie: Scheibenmittelpunkt (128, 120), Außenradius 104 px, Scheibenbereich x=24–232 / y=16–224. Helle Innenfläche mit ungefähr 78 px Radius. Zwei auseinanderlaufende Stoffbänder mit Schwalbenschwanz-Kerben reichen bis y≈310. Zahlenanker für das Spiel: (128, 120). Anzeigegröße: etwa 112 × 140 logische Pixel.

Herkunft: am 07.10.2026 mit dem integrierten OpenAI-ImageGen-Werkzeug für diesen Auftrag erstellt. Stilvorgabe waren die vom Nutzer gezeigten Monster-Slam-Assets Pokal, Meisterungsbuch und grünes Medaillon. Die erzeugte Bronzemedaille diente als Bildvorlage für die sieben Material-/Symbolvarianten. Unveränderte PNG-Rohbilder und vollständige Prompts liegen in sources/. Die Laufzeitdateien wurden mit Sharp/Lanczos auf die gemeinsame Geometrie normalisiert; Scheibe und unterer Bandbereich wurden getrennt skaliert. Die generierte Transparenz bleibt erhalten.

preview/all_badges.png zeigt alle acht nebeneinander auf dunklem Hintergrund, preview/all_badges_transparent.png dieselbe Reihe transparent. Reihenfolge entspricht der Tabelle. sources/validation.json dokumentiert Maße, Alphakanal und verlustfreie Kodierung. sources/build.cjs erzeugt Laufzeitbilder und Vorschauen erneut (Sharp-Pfad über BADGES_SHARP konfigurierbar).

sources/ und preview/ enthalten jeweils eine leere .gdignore und werden dadurch von Godot nicht importiert.
