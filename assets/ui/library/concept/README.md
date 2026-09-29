# Bibliothek – Alternativentwurf

Aktueller Entwurf: `library-v6.webp`. Bücher frontal auf einem seitlich durchblätterbaren Lesepult. Vier vorhandene Inhalte: Access 2 (blau), Access 3 (rot), Access 4 (grün), Latein (violett). Jedes Cover zeigt Titel, Fach und seine eigene Übersichtskarte. Die tatsächlichen `assets/maps/<buch>/book.webp` wurden als Bildreferenzen verwendet; bei Spielintegration die Originaltexturen direkt auf die Cover legen.

Nur bei Hover oder Tastatur-/Controller-Fokus erscheint auf dem jeweiligen Buch die Statistik: gemeisterte Wörter mit Fortschrittsbalken und besiegte Bosse. Gleichzeitig schimmert der Rand goldfarben und das Buch kommt etwas nach vorne. Beim Verlassen verschwinden Statistiken und Hervorhebung wieder; der Platz bleibt reserviert, damit das Coverlayout nicht springt. Im Entwurf zeigt Access 4 die gelieferten Werte 0 / 586 Wörter und 0 / 4 Bosse. Keine Statistiken auf den übrigen Büchern.

Klick beziehungsweise Enter/Bestätigen öffnet das Buch sofort. Kein zusätzlicher Öffnen-Button und kein Auswahltext. Seitliche Pfeile, Scrollen/Ziehen und Tastaturbedienung erlauben weitere Bücher. Nur die Bücherreihe bewegt sich beim Blättern, der Raum bleibt stehen. Bei vielen Büchern sind Fachregister und Suche eine spätere Erweiterung.

`library.webp` bleibt als alter, überholter Entwurf erhalten. Die aktuelle Übergangsvorschau nutzt v6: fünf Plätze auf einer durchgehenden Regalfläche ohne Buchstützen; das hervorgehobene Buch steht vorne und überdeckt seine beiden Nachbarn teilweise. Das fünfte Buch ist ausdrücklich ein Platzhalter für künftige Inhalte.

## Übergänge

`transition-preview.html` im Browser öffnen. Die Vorschau nutzt die bestehenden Intro-/Hauptmenü-Bilder sowie den neuen Bibliotheksentwurf.

- „Weiter“: Profilauswahl → Hauptmenü.
- „Lernen“: Hauptmenü → Bibliothek.
- Beide Vorwärtsschritte: aktuelle Ansicht von x=0 nach x=−Viewportbreite; Zielansicht gleichzeitig von x=+Viewportbreite nach x=0.
- Zurück jeweils umgekehrt.
- Beim direkten Öffnen eines Buchs kommt auch die nächste Ansicht von rechts herein; der Bibliotheks-Screen gleitet nach links hinaus.
- Dauer: 360 ms, sanftes Abbremsen, kein Überschwingen und kein Zoom.
- Eingabe während des Wechsels sperren; nach Abschluss Fokus in den neuen Screen setzen. Im Spiel die gewählte Profil-/Buch-ID beibehalten.
- Reduzierte Bewegung: direkter Wechsel ohne Animation. Die HTML-Vorschau respektiert die entsprechende Betriebssystem-/Browser-Einstellung.

Die Vorschau ist ein Bewegungsentwurf mit statischen Bildern, keine Spielintegration. Der vorhandene Hauptmenüentwurf zeigt weiterhin „Spielen“; die Vorschauleiste demonstriert den gewünschten „Lernen“-Übergang. Neues Layout und endgültige Bezeichnung im Hauptmenü bei Integration angleichen.

Erstellt mit dem eingebauten Imagegen-Tool. Perspektive und fünf Plätze: prompt-v5.txt. Größenanpassung: prompt-v4.txt. Bisherige Bearbeitungsprompts: `prompt-v3.txt`; ursprünglicher Prompt: `prompt.txt`. Verlustfrei als WebP konvertiert. Das Konzeptverzeichnis ist vom Godot-Import ausgeschlossen. Die HTML-Vorschau demonstriert die Screenwechsel anhand statischer Bilder; Buch-Hover, Blättern und Öffnen sind hier beschrieben, aber noch nicht als Spielinteraktionen implementiert.




Spieler-Badge (v6): gemeinsame Komponente wie im Hauptmenü, gleiche Position und Gestaltung; Sam, Level 4, 166 / 400 XP mit Goldbalken und Profil wechseln. Bei Implementierung dieselbe Badge-Szene wiederverwenden. Prompt: prompt-v6.txt.
