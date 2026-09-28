---
name: monster-slam-mapset
description: Erstelle oder überarbeite Monster-Slam-Gebiets- und Detailkarten als Rasterbilder und prüfe die sechs Wegpunktflächen. Nur für Monster-Slam-Kartensets verwenden.
---

# Monster-Slam-Kartensets

## Bildsprache und Geografie

- Lies die aktuellen Referenzbilder im Projekt. Für Übersichtskarten dient `assets/maps/access4/book.webp` als Orientierung für Perspektive, Maßstab und lebendige Geländeformen; für Detailkarten dienen `assets/maps/access4/unit1.webp` bis `unit4.webp` als Orientierung für isometrische Geländeplatte, dunkelblauen Hintergrund, Weg, Geländeausdehnung und Detaildichte. Übernimm keine fremden Biome oder Bauwerke ungefragt.
- Prüfe vorhandene Zielbilder gegen diese Referenzen und den aktuellen Auftrag. Eine vorhandene Übersichtskarte ist nicht automatisch die richtige Stilvorlage für neue Detailkarten. Wenn der Auftrag eine Überarbeitung oder Ersetzung umfasst, richte Übersicht und Details als zusammengehöriges Set aus.
- Nutze die Übersichtskarte als geografische Grundlage für die Detailkarten: Ordne jede Unit einer erkennbaren Landschaftsregion zu und übertrage deren Relief, Vegetation und Gewässer. Bei einer Abfolge entlang eines Höhenzugs müssen spätere Units die dort sichtbaren raueren oder kargeren Bedingungen zeigen; Motive tieferer Regionen wandern nicht ohne geografischen Grund bis in die Hochlagen.
- Leite die Landschaft aus Relief, Wind, Niederschlag und Wasserläufen ab. Biome dürfen vor- und zurückgreifen, besonders entlang von Flüssen und Höhenzügen. Vermeide saubere Farbstreifen, Quadranten und regelmäßig angeordnete Biome. Entscheide Insel oder Festland nach dem Auftrag und der vom Nutzer gewählten Vorschau.
- Gestalte Detailkarten als breite, tiefe Geländeplatten wie in den Referenzen. Das Gelände soll einen großen Teil des Bildes einnehmen und auch abseits des Hauptwegs abwechslungsreiche Täler, Höhen, Gewässer oder Orte zeigen. Die Brettsilhouette darf nicht bloß dem Weg als schmaler diagonaler Streifen folgen. Der Weg bleibt trotzdem klar lesbar.
- Halte Spielbilder im 16:9-Format mit mindestens 1920 × 1080 Pixeln. Exportiere WebP unter 2 MB; PNG kann lokal als bearbeitbare Quelle dienen; im Repo und Spiel liegen die WebP-Dateien. Kein Text, keine Zahlen, kein UI und keine Wasserzeichen in den Spielbildern.
- Wenn der Nutzer zuerst eine Übersichtsvorschau sehen möchte, warte mit den Detailkarten auf seine Entscheidung. Verwende danach genau die ausgewählte Variante.

## Routenplanung für Detailkarten

- Plane vor der Bildgenerierung die sechs großen Flächen und den verbindenden Hauptweg als geordnete Route. Verändere innerhalb eines Sets die großräumige Wegform und die Lage der Flächen, statt nur kleine Kurven in dieselbe Diagonale einzubauen. Geeignete Formen sind zum Beispiel ein Bogen um ein Gewässer, eine S-Kurve durch ein Tal, eine Haarnadel entlang zweier Ufer oder Serpentinen an einem Hang. Wähle die Form passend zur Geografie, nicht nach einem starren Muster.
- Halte den Weg vom Start über die Flächen 1 bis 5 zur Endarena 6 eindeutig und ohne Abzweigung, Abkürzung, Kreuzung oder mehrfach benutztes Teilstück. Variiere innerhalb eines Sets auch die Start- und Zielseite: Ein Weg kann zum Beispiel oben links, oben rechts oder unten rechts beginnen. Lege die Endarena passend zur Kartenfolge und Geografie fest; verwende nicht automatisch für jede Unit unten links als Start und oben rechts als Ziel.
- Forme Relief, Brücken, Ufer und Orte so, dass die geplante Route natürlich wirkt. Prüfe den tatsächlich erzeugten Bildweg visuell; ein Prompt mit Koordinaten garantiert weder die Reihenfolge noch eine eindeutige Verbindung.
- Erstelle zu jeder Detailkarte eine `unitN-route.json` mit Bildgröße, benannten Halten und dichtem Pfad. Prüfe ihren Overlay-Verlauf visuell auf dem tatsächlich exportierten Spielbild.

## Routenmetadaten und visuelle Halte

- Speichere pro Detailkarte `unitN-route.json` im einheitlichen, mehrzeilig eingerückten JSON-Format: `{"size":[1920,1080],"stops":[{"key":"t1","x":100,"y":200},...,{"key":"boss","x":1500,"y":180}],"path":[[100,200],...]}`. Die sechs Schlüssel stehen immer in der Reihenfolge `t1`, `t2`, `t3`, `t4`, `all`, `boss`; Koordinaten sind Pixel des tatsächlich geladenen Spielbilds. `path` folgt genau dieser Reihenfolge und erreicht die Mitte jedes Halts.
- Nur der sechste Halt ist eine Boss-Arena mit Wänden oder monumentaler Einfassung. Der Start ist ein kleiner, einfacher Halt. `all` ist eine offene, deutlich größere Fläche als `t1` bis `t4`; er darf nicht wie eine zweite Arena wirken. Prüfe diese Unterschiede am fertigen Bild statt nur am Prompt.
- Lege auf Kurven, Brücken und Treppen genügend Stützpunkte, in der Regel alle 80–120 Pixel. Verbinde keine zwei Halte mit einer Geraden, wenn der sichtbare Weg dazwischen abbiegt. Das Overlay muss über den hellen Weg laufen.
- Gib jeder Buchkarte eine `book-route.json` mit `size`, `stops` und `path`. Die Halte heißen `unit1` bis zur tatsächlich vorhandenen letzten Unit. Zeichne im Buchbild genau einen sichtbaren, durchgehenden Weg durch die zugehörigen Regionen und gleiche die Metadaten an die wirklichen Hubmitten an.
- Halte WebP und JSON synchron. Nach jeder Bildänderung WebP neu exportieren und dieselbe Größe sowie Stopppositionen erneut prüfen. Vorhandene `map.json`-Koordinaten in normalisierten Werten auf die endgültigen Buch- und Detailbilder abstimmen.

## Zählregel vor jeder Übernahme

Jede Detailkarte braucht **genau sechs große, gut sichtbare Flächen auf dem durchgehenden Hauptweg, einschließlich der Endarena**. Die Endarena ist Punkt 6. Nebenplätze, Steinkreise, Tempelhöfe oder andere Flächen abseits des Wegs zählen nicht. Kleine normale Wegplatten zählen ebenfalls nicht.

1. Verfolge den Weg vom Start bis zur Endarena und nummeriere die sechs Flächen gedanklich oder in einem separaten Prüfbild. Prüfe, dass der Weg jede Fläche tatsächlich erreicht.
2. Führe `assets/maps/count_waypoints.py` vom Projektstamm aus auf jeder fertigen Detailkarte aus, am besten mit `--overlay-dir` für ein nummeriertes Prüfbild. Das Skript verlangt Pillow und NumPy und gibt bei einer anderen Anzahl als sechs einen Fehlercode zurück.
3. Übergib die passende `unitN-route.json` mit `--route-json`. Das Skript prüft Größe, Schlüssel, Halte auf der Route und Punktabstände; prüfe zusätzlich das Overlay visuell, besonders Brücken, Treppen und Kurven. Eine bloße Zahl aus dem Generatorprompt ist kein Nachweis.
4. Zähle nach jeder Bildänderung erneut und prüfe das Overlay, auch bei einer gezielten Korrektur: Bildbearbeitungen können weitere Halteflächen unbeabsichtigt verändern. Wenn Zahl oder Weganbindung nicht stimmen, korrigiere die betroffenen Flächen und prüfe nochmals. Übernimm erst das geprüfte Bild.

## Ablage

Nutze die vom Nutzer genannte Reihenfolge und Anzahl von Units, zum Beispiel `accessN/book.webp` und `accessN/unit1.webp` bis zur letzten vorhandenen Unit. Leite die Anzahl nicht aus älteren Sets ab. Prüfe die Zielpfade vor dem Kopieren. Überschreibe vorhandene, nicht zu dieser Bearbeitung gehörende Dateien nur auf ausdrücklichen Wunsch. Kontrolliere nach dem Speichern Format und endgültigen Zählerstand aller Detailkarten.
