---
name: monster-slam-mapset
description: Erstelle oder überarbeite Monster-Slam-Übersichts- und Detailkarten als Rasterbilder mit abwechslungsreichen Reisewegen und visueller Anschlussprüfung. Nur für Monster-Slam-Kartensets verwenden.
---

# Monster-Slam-Kartensets

## Auftrag und Referenzen

- Anzahl und Reihenfolge der Übersichtsstopps sowie Anzahl und Rollen der Detailstopps kommen aus dem aktuellen Auftrag. Keine feste Standardzahl, keine Pflichtschlüssel oder obligatorische Boss-Arena. Unterschiedliche Detailkarten dürfen unterschiedliche Stationszahlen haben. Fehlt eine benötigte Angabe, kläre sie, statt sie aus Referenzbildern oder früheren Sets zu übernehmen.
- Prüfe die aktuellen Projektbilder. `assets/maps/access4/book.webp` orientiert Perspektive, Maßstab und lebendige Geländeformen; `assets/maps/access4/unit1.webp` bis `unit4.webp` orientieren den Detailstil. Freigegebene Karten des aktuellen Sets ergänzen diese Referenzen.
- Trenne die Vorlagenrollen im Bildprompt: Detailreferenzen liefern Kamera, stilisierte 3D-Spielgrafik, vereinfachte Materialien, kantige freigestellte Geländeplatte und dunkelblauen Leerraum. Auftrag und ausgewählte Übersicht liefern Geografie, Motive und Stimmung. Übernimm weder Biome, Bauwerke, Stationszahl noch breite Pflasterwege automatisch aus Stilreferenzen.
- Prüfe neue Detailkarten neben einer Stilreferenz. Fotorealistische Landschaften, natürliche Horizonte und bloße Küstenklippen ohne freigestellte Geländeplatte entsprechen nicht diesem Stil.
- Nutze die ausgewählte Übersicht als geografische Grundlage: Relief, Vegetation, Gewässer und Stimmung der Region müssen in der Detailkarte erkennbar bleiben. Biome greifen entlang von Tälern, Hängen und Wasserläufen ineinander; vermeide Farbstreifen und starre Quadranten. Inseln oder verbundenes Festland richten sich nach dem Auftrag.
- Wenn zunächst eine Übersicht oder eine einzelne Detailvorschau gewünscht ist, bearbeite nur diesen Schritt. Nutze für Folgearbeiten genau die freigegebene Variante.

## Landschaft und dynamische Reisewege

- Entwirf Gelände und Route gemeinsam. Eine breite, tiefe Geländeplatte bietet auch abseits der Route abwechslungsreiche Landschaft oder Stadtviertel. Ihre Silhouette folgt nicht bloß einem schmalen Wegstreifen.
- Plane die angeforderte Anzahl Stationen und ihre Reihenfolge vor der Generierung. Variiere Start- und Zielseite, Höhenprofil, großräumigen Verlauf und Stationslage zwischen den Karten. Entwickle die Strecke aus der Geografie; kopiere keine Standarddiagonale.
- Verbinde Orte durch eine passende Mischung aus schmalen Pfaden, Gassen, Straßenstücken, Treppen, Brücken und Gebirgspfaden. Boote, Seilrutschen, Klettersteige, Strickleitern, Tunnel oder schwebende Trittsteine sind mögliche besondere Übergänge, keine Pflichtliste. Setze sie gezielt ein und vermeide unnötige Wiederholung innerhalb einer Karte.
- Eine durchgehende Reise verlangt keinen durchgehend sichtbaren Bodenweg. Unterschiedliche Materialien, Breiten und Fortbewegungsarten sind erwünscht. Vermeide einen gleichförmigen breiten Pflasterweg und zusätzliche Leuchtlinien in Detailkarten.
- Die spielbare Reihenfolge bleibt eindeutig: keine unbeabsichtigten Abkürzungen, Sackgassen oder mehrfach benutzten Teilstücke. Dekorative Gassen und Ruinen dürfen nicht wie alternative Verbindungen zu späteren Stationen wirken. Kreuzungen auf verschiedenen Höhen sind nur geeignet, wenn der Verlauf klar lesbar ist.
- Stationen sind natürliche Orte: Lichtungen, Höfe, Dorfplätze, Dächer, Ufer oder Felsabsätze. Halte ihre nutzbaren Flächen frei und unterscheidbar; vermeide identische große Spielscheiben und zusätzliche Flächen, die wie weitere Stationen aussehen. Kleine Trittsteine und Treppenabsätze zählen nicht als Stationen. Gestalte besondere Rollen wie Sammelplatz oder Endarena nur entsprechend dem Auftrag.

## Anschlüsse und visuelle Prüfung

- Verfolge die tatsächliche Bildroute vom Start über jeden Halt zum Ziel. Ein ausführlicher Prompt oder eingezeichnete Koordinaten beweisen keine Verbindung.
- Brücken brauchen tragfähige Auflager, freie Zugänge und passende Anschlusshöhen. Treppen verbinden erreichbare Flächen; sie enden nicht an einer Wand oder im Wasser. Pfade auf Felsabsätzen brauchen unterstützendes Gelände.
- Seilrutschen benötigen Gefälle in Reiserichtung. Bootsverbindungen brauchen zwei erreichbare Anlegestellen und einen freien Wasserweg. Kletterstellen müssen an beiden Enden an die Route anschließen. Magische Übergänge dürfen physikalisch unmöglich sein, müssen aber als beabsichtigte Verbindung lesbar bleiben.
- Ein Tunneleingang darf verdeckt sein. Zufahrt, Felsmasse, Höhen und Ausgang müssen den Verlauf plausibel machen; erzwinge nicht zwei frontal sichtbare Portale.
- Zähle nach jeder Bildänderung alle tatsächlichen Stationen erneut und prüfe sämtliche Anschlüsse. Lokale Bearbeitungen können andere Stationen entfernen oder Abkürzungen hinzufügen.
- Korrigiere unklare Übergänge vor einer Empfehlung zur Übernahme. Wenn der Nutzer eine bekannte Unklarheit ausdrücklich akzeptiert, speichere die gewählte Fassung und dokumentiere die offene Stelle; erfinde keinen geprüften Weg durch Fels oder Mauern.

## Metadaten und Prüfbilder

- Speichere zur finalen Karte eine gleichnamige `*-route.json` mit `size`, geordneten `stops` und `path`. `size` und Pixelkoordinaten beziehen sich auf das tatsächlich exportierte Bild. Jeder Halt hat einen eindeutigen `key`, `x` und `y`. Schlüssel richten sich nach Auftrag bzw. Verbraucher; der Skill erzwingt kein festes Namensschema.
- `path` beschreibt die vorgesehene Reise einschließlich Bootsfahrt oder anderer Übergänge. Setze an Kurven und Wechseln ausreichend Stützpunkte; verbinde keine Halte quer durch Hindernisse. Technisch kurze Punktabstände sind kein Beweis für Begehbarkeit.
- Ergänze für neue Routen `segments`: Jeder Abschnitt hat `start` und `end` als inklusive Indizes in `path`, `mode` (`walk`, `boat`, `zipline`, `climb`, `floating_steps`) und `visibility` (`visible`, `occluded`). Aufeinanderfolgende Abschnitte teilen einen Endpunkt und decken den ganzen Pfad ab. Verdeckte Tunnelabschnitte sind zum Beispiel `walk` und `occluded`.
- Benenne ungelöste Stellen in `review_notes` als Liste von Texten. Verdeckter Verlauf und ungeklärter Anschluss sind nicht dasselbe. Eine technische Prüfung darf offene Fragen nicht als gelöst darstellen.
- Auf der Übersicht folgt die Reiseroute den angeforderten Gebieten, bei Bedarf mit Seeabschnitten. Halte müssen den tatsächlichen Hubmitten entsprechen. Keine festgelegte Kontinent- oder Hubanzahl.
- Nummerierungen, Pfeile und Routenlinien gehören in separate Prüfbilder. Das Spielbild bleibt ohne Text, Zahlen, UI und Wasserzeichen. Prüfe das Overlay zusätzlich zum unverdeckten Original.

## Technische Prüfung und Export

- Standardexport: WebP, 16:9, mindestens 1920 × 1080, unter 2 MB. PNG kann als lokale Quelle dienen. Abweichende ausdrückliche Ausgabevorgaben des Nutzers haben Vorrang.
- `assets/maps/check_map.py` benötigt Pillow. Es prüft ausschließlich Exportformat, Maße, Dateigröße und optional Metadaten: angeforderte Anzahl, eindeutige Schlüssel, gültige Koordinaten, geordnete Erreichbarkeit auf der gelieferten Polylinie und Abschnittsstruktur. Es erkennt keine Stationen im Bild und bewertet weder Weggeometrie noch Stil oder Physik.
- Aufruf für eine Karte: `python assets/maps/check_map.py <bild.webp> --route-json <route.json> --expected <Anzahl-aus-dem-Auftrag> --overlay-dir <separater-Prüfordner>`. Ohne Metadaten werden nur Exportdaten geprüft. Der Standardexport-Prüfer gilt nicht unverändert für ausdrücklich anders angeforderte Bildformate.
- Ein technisches OK bedeutet nur konsistente Daten. Berichte technische Ergebnisse und visuelle Beurteilung getrennt. Auch eine Linie durch eine Wand kann technisch gültig sein. Prüfe Stationenzahl, Reihenfolge, Anschlüsse, Gefälle und fehlende Abkürzungen immer am Bild.
- Speichere die freigegebene Übersicht und jede freigegebene Detailkarte an den passenden Projektpfaden. Prüfe Zielpfade; überschreibe keine fremden Dateien. Halte WebP, Routenmetadaten und vorhandene normalisierte `map.json`-Koordinaten synchron. Passe die tatsächlich verwendeten Verbraucher an abweichende Stationszahlen an, wenn Integration Teil des Auftrags ist; bloßes Speichern bestätigt keine Spielintegration.
