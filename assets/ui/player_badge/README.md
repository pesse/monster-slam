# Player-Badge – Übergabe an den Coding-Agenten

## Auftrag und verbindliche Gestaltung

Den bisherigen Spieler-Badge in Hauptmenü und Bibliothek durch das freigegebene Medaillon-Konzept ersetzen. Referenz: `../main_menu/concept/player-medallion-v6.png`. Medaillon mit Avatar rechts, Name und Gold links; Profilwechsel als Pfeil-Icon ganz links. Blau-silbernes Metall und dunkle Flächen wie im übrigen Menü. XP als blauer Außenring, Level auf unterer Plakette. **In Statistik und Skill-Tree keinen Player-Badge anzeigen.**

Die generative Rahmenextraktion ist eine stilgetreue Rekonstruktion und nicht pixelidentisch mit dem Konzept. Der beigefügte Godot-Aufbau ist eine lauffähige Integrationsvorlage; Spielzustand und Navigation sind absichtlich nicht angebunden.

## Dateien

- `frame.webp`: unbeschrifteter transparenter Rahmen, 1536 × 1024 px; Goldmünze ist Bestandteil des Rahmens.
- `level_overlay.webp`: exakt ausgerichteter Vordergrund-Ausschnitt, 250 × 200 px; verdeckt Ring/Avatar hinter der Level-Plakette.
- `player_badge.tscn` und `player_badge.gd`: skalierbare Godot-4-Beispielkomponente mit dynamischen Beschriftungen, XP-Ring, Mouseover/Fokus, Tooltip und Profilwechsel-Signal.
- Wiederverwendete Icons: `res://assets/ui/main_menu/icons/profile.webp` und `switch_profile.webp`.
- `layout.json`: Koordinaten und Datenvertrag.
- `preview/badge-render.png`: tatsächlicher Godot-Render mit Level 99 und 999.999 Gold.
- `sources/`: Original, Generierungsauftrag und reproduzierbarer WebP-Export. Quellen und Vorschauen sind vom Godot-Import ausgeschlossen.

## Wie das Spiel die Teile benutzt

`scenes/ui/profile_badge.tscn` mit `src/ui/profile_badge.gd` (nicht die Vorlage
`player_badge.tscn`). Gezeichnet wird auf ein Fünftel der Leinwand (277 × 136 in der
Bezugsgröße 1152 × 648). Die Bilder dafür liegen **vorab verkleinert** unter `menu/`, so
dass sie bei 1920 × 1080 Pixel für Pixel stehen: `frame.webp` und `level_overlay.webp` auf
ein Drittel, dazu Avatar und Wechsel-Icon aus `../main_menu/icons/`. Zur Laufzeit von
1536 px auf ein Fünftel gezeichnet, ließ der Rahmen an den feinen Kanten Fragmente stehen.
Neu erzeugen mit `src/dev/shrink_image.gd`, wenn sich ein Bild oder die Größe ändert.

## Umsetzungsschritte

1. Bestehende Profil-/Menülogik untersuchen und die Komponente in Hauptmenü und Bibliothek instanziieren. An der rechten oberen Ecke verankern; ausreichend Abstand zum Fensterrand lassen. Die transparente Textur hat Außenabstand, daher sichtbare Silhouette statt Canvasrand bei Positionierung beachten.
2. `set_profile(display_name, current_level, current_gold, current_xp, required_xp)` mit den bestehenden aktiven Profildaten aufrufen. Bei Profilwechsel, Goldänderung und XP-/Leveländerung aktualisieren. Keine Demo-Zahlen fest im Spiel hinterlegen.
3. `profile_switch_requested` an die vorhandene Profilwahl anschließen. Der Klick auf das Pfeil-Icon und Enter/Controller-Bestätigen auf fokussiertem Badge lösen dasselbe Signal aus. Sichtbaren Fokus beibehalten. Für produktive Barrierefreiheit Pfeilfläche als separaten Button mit zugänglichem Namen „Profil wechseln“ umsetzen; die Vorlage zeichnet sie noch selbst.
4. Projektschrift statt `ThemeDB.fallback_font` einsetzen. Namen bei Überlänge mit Ellipse und vollständigem Tooltip anzeigen. Platz für zwei Levelziffern sowie sechs Goldziffern plus Tausendertrennzeichen reservieren. Gold rechtsbündig, Level zentriert, tabellarische Ziffern verwenden. 99 bzw. 999.999 sind Breitentests, keine neu einzuführenden Spielgrenzen. Keine dauernde Schriftverkleinerung bei Zahlenwechsel.
5. XP-Verhältnis aus tatsächlichen Leveldaten berechnen, auf 0–1 begrenzen, Division durch null vermeiden. Level-Cap nach bestehender Spiellogik behandeln. XP-Tooltip in den vorhandenen Skill-Tree-Tooltip-Stil überführen; Vorlage verwendet zunächst den Godot-Standardtooltip. Tooltip an Bildschirmrändern begrenzen.
6. Node selbst proportional skalieren oder die Designkoordinaten verwenden; Rahmen nicht unabhängig in X/Y strecken. Bei Größenänderung neu zeichnen. Im Header für echten Pointer-Passthrough die transparenten Außenflächen aus dem Hit-Test nehmen bzw. separate interaktive Controls verwenden. Die Referenz hat noch ein rechteckiges Control.
7. Ring im finalen UI sauber auf die ringförmige Vertiefung maskieren: die Vorlage zeichnet einen geometrischen Kreis, die generierte Vertiefung ist leicht unregelmäßig. Level-Overlay bleibt darüber. Keine fertigen XP-Werte in Texturen einbrennen.

## Bewegung und Zustände

Keine permanente Bewegung. Bei XP-Gewinn Ring kurz zum Zielwert interpolieren; Levelaufstieg mit kurzem zurückhaltendem Lichtimpuls. Bei Goldänderung Zahl kurz hervorheben. Die Münze ist in diesem Paket fest im Rahmen: kein unabhängiges Schwingen ohne spätere Freistellung. Reduzierte Bewegung respektieren. Diese Animationen sind noch nicht in der Vorlage implementiert.

Hover/Fokus des Profilwechsels sichtbar, im finalen Button zusätzlich Pressed-Zustand vorsehen. Gold-/XP-Änderungen dürfen die Breite des Badges nicht verschieben.

## Prüfen vor Integration

- Level 4 und 99; Gold 0, 1.250, 888.888, 999.999.
- XP 0 %, 41,5 %, 100 % und bestehender Maximallevel-Fall.
- Lange Profilnamen, schmale Auflösungen, UI-Skalierung und tatsächliche Projektschrift.
- Profilwechsel per Maus und Tastatur/Controller; Rückkehrfokus und Profilaktualisierung.
- Hauptmenü und Bibliothek zeigen denselben Badge; Statistik und Skill-Tree keinen.

Bereits geprüft: echte Alpha-Transparenz, verlustfreier Export, Godot-4.7-Import, Laden der Szene und tatsächliches Rendern mit Level 99 / 999.999 Gold. Godot meldete nur einen umgebungsbedingten Zertifikatsspeicherfehler. Noch keine Integration in die Hauptspielszenen, keine End-to-End-Prüfung gegen echte Profildaten.
