# Prüfbericht – korrigierte Revision 2

Die erste Lieferung war technisch skalierbar, traf aber den Aufbau des Konzepts nicht: separat umrahmter Titelbalken, fehlende Seitenanschlüsse, flache Innenfläche und zu schwere blaue Bedienelemente. Revision 2 korrigiert diese Abweichungen.

- Gemeinsame Außenkontur: Titelband übernimmt dieselben oberen und seitlichen Rahmenpixel wie das Panel. Die untere Titelkante ist eine feine Trennlinie.
- Zwei ausgeschnittene Metallanschlüsse verbinden Titeltrennlinie und Seiten. Positionen und Ebenenreihenfolge sind in README und Manifest dokumentiert.
- Separate kachelbare Alpha-Materialebene erhält die Flächenstruktur, ohne Textur auf den dehnbaren Rahmenkanten zu verschmieren.
- Schließen-X neu aus dem Konzept abgeleitet: schlank und silberhell. Zustände unterscheiden sich nur in RGB; Alphakanäle bytegleich.
- Werkzeugrahmen auf ca. 2 px reduziert; Slices jetzt 8 px statt 16 px.
- Zwölf Texturen auf verlustfreies WebP, Alpha und Maße geprüft. Alle horizontalen Mittelstücke von Panel/Titelband sowie vertikale Panel-Mittelstücke pixelgleich geprüft. Details in asset-checks.json.
- Vorschauen bei 1152 × 648 und 1920 × 1080 sowie direkter Kopfbereichvergleich mit dem Konzept visuell kontrolliert. Vorschau-Buch, Stern, Text und Werkzeugzeichen sind nicht in den Laufzeittexturen eingebrannt.

Die Vorschauen sind tatsächliche Sharp-Kompositionen der gelieferten Teile, keine Godot-Spielaufnahmen. Fähigkeitenbaum, Graph, Tooltip, Schriftgestaltung und Spielintegration bleiben außerhalb des Fensterpakets. Eine vollständige Nachbildung des gesamten Skill-Tree-Screens wird hier nicht behauptet. Die frühere Godot-Prüfung im README gilt für das ursprüngliche Paket.

Nur Dateien in assets/ui/windows/ bearbeitet. Keine Spielskripte, Szenen oder Theme-Ressourcen geändert. Quellen und Prompts unter sources/; bestehende .gdignore erhalten. Fontconfig meldete einen nicht beschreibbaren Cache, die Beschriftungen wurden dennoch gerendert und visuell kontrolliert.
