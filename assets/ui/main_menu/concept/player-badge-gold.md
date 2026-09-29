# Spieler-Badge mit Gold

Neuer Komponentenentwurf: `player-badge-gold.webp`.

Obere Zeile: Avatar/Name links, Münzsymbol und aktueller Goldbestand rechts. Zweite Zeile: Level, XP-Balken und XP-Zahlen. Profilwechsel im unteren rechten Tab. 1.250 Gold ist nur der Beispielwert des Entwurfs; aktuellen Goldbestand aus dem aktiven Profil dynamisch binden. XP ebenfalls dynamisch, Beispiel 166/400 = 41,5 %. Lange Namen kürzen, Platz für Gold reservieren; große Goldzahlen lokalisiert formatieren und bei Bedarf Breite anpassen.

Gemeinsamer Badge für Hauptmenü und Bibliothek. In Statistik und Skill-Tree ausdrücklich nicht anzeigen. Ältere Gesamtansichten zeigen noch den vorherigen Badge; dieser Komponentenentwurf ersetzt dort dessen Anordnung.

Vorhandene Komponenten verwenden: `../panels/profile_panel.webp`, `../icons/profile.webp`, `../icons/switch_profile.webp`, `../../statistics/icons/gold_coins.webp`. Text und XP-Balken nativ rendern. Konzeptbild ist keine Laufzeittextur. Layout etwa 560 × 132 px, bei Bedarf proportional größer; Profilwechsel als eigener klickbarer Bereich mit Fokuszustand.

Erzeugt mit eingebautem image_gen.imagegen, Referenzen: approved-concept.png und profile_panel.webp. Prompt: einzelner großer Spieler-Badge im bisherigen abgeschrägten Stahl-/Marineblau-Stil; violetter Avatar, Sam links und Münzstapel mit 1.250 Gold rechts in Zeile 1; Level 4, XP-Balken mit 41,5 % und 166 / 400 XP in Zeile 2; Profil wechseln im unteren rechten Tab. Dunkler Hintergrund, keine weiteren UI-Elemente, kein Debug-Text.
