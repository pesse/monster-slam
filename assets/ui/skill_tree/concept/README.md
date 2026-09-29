# Skill-Tree – Fensterentwurf

**Status: Vom Nutzer freigegeben am 29.09.2026.** Verbindlicher visueller Stand: `skill-tree-v5.webp`. Die folgenden Interaktionsregeln gehören zur Freigabe. **Wo „Entscheidungen zur Umsetzung“ (unten) etwas anderes sagt, gilt der Abschnitt dort.**

Aktuell: skill-tree-v5.webp. Fast bildschirmfüllend, etwa 12–20 px Außenrand bei 1672 × 941 px. Schmaler Rahmen, kompakte Kopfzeile mit Skillpunkten und Schließen, ohne Profil-Badge. Baum über volle Breite, keine rechte Seitenleiste und kein Kaufbutton.

## Öffnen und Bedienung

Als Fenster wie Statistik öffnen; kein seitliches Wischen. Kurze Einblendung. X/Escape schließt, Fokus geht zum aufrufenden Menüpunkt zurück. Hintergrund blockiert Eingaben.

Mausrad über dem Baum zoomt um die Mausposition. Plus/Minus und Einpassen bleiben verfügbar. Ziehen auf leerer Fläche verschiebt den Baum. Eine Drag-Schwelle verhindert Käufe beim Verschieben.

Mouseover oder Tastaturfokus zeigt einen kleinen Tooltip am Knoten: Name, Zweig, Beschreibung, Status, Kosten und Voraussetzungen. Tooltip bleibt beim Zoom lesbar, klappt an Fensterrändern um, verdeckt den Knoten nicht und fängt keine Klicks ab. Beim Verlassen oder Ziehen ausblenden.

## Direkte Klickaktion

- Kaufbare Fähigkeit: Klick kauft. Tooltip „Klicken zum Kaufen“.
- Erlernte Fähigkeit: Klick setzt zurück. Tooltip „Klicken zum Zurücksetzen“.
- Gesperrte oder nicht bezahlbare Fähigkeit: keine Kaufaktion; Ursache im Tooltip nennen.
- Enter/Controller-Bestätigen führt dieselbe Aktion aus.
- Beim Klick Voraussetzungen, Punktestand und bestehende Rücksetzregeln erneut prüfen. Atomar speichern, Mehrfachauslösung verhindern; Knoten, Verbindungen, Punktestand und Tooltip aktualisieren.
- Keine neue pauschale Rückerstattungs-/Kaskadenregel festgelegt. Bestehende Spiellogik zu Folgeskills und Erstattung übernehmen und im Tooltip anzeigen.

## Darstellung

Erlernt: gefülltes Medaillon mit Häkchen. Kaufbar: klare Kontur/Icon. Gesperrt: gedämpft mit Schloss. Hover/Fokus: goldener Ring zusätzlich zum Zustand.

Beispiel Leichte Stiefel: Beschreibung aus data/skills/scout.json „Du läufst in der Ich-Sicht 25 % schneller.“, Kosten 1 Skillpunkt, Voraussetzung Späherblick. Andere Werte und Verknüpfungen bei Umsetzung aus aktuellen Spieldaten lesen, nicht aus dem generierten Bild.

## Entscheidungen zur Umsetzung (29.09.2026)

Diese Punkte stehen über dem Bild und den Abschnitten oben.

- **Rückfrage bleibt.** Lernen und Verlernen fragen weiter über `ConfirmDialog` nach. Es gibt keine direkte Klickaktion. Verlernen kostet Gold und nimmt die Äste darüber mit (`SkillTree.forget_set`).
- **Begriffe: Lernen/Verlernen**, nicht Kaufen/Zurücksetzen. Tooltip „Klicken zum Lernen“ bzw. „Klicken zum Verlernen“.
- **Alles umlernen** (`reset.webp`) sitzt in der Werkzeugleiste unten rechts, neben −/+/Einpassen.
- **Medaillons:** Die Ringfarbe kommt vom Baum (`color`), nicht vom Zustand. Grundlage ist das silberne `available.webp`, eingefärbt mit der Baumfarbe:
  - Kaufbar: Ring hell, Icon, Kostenplakette.
  - Zu teuer (`TOO_EXPENSIVE`): Ring gedämpft wie gesperrt, aber ohne Schloss, Icon gedämpft, Kostenplakette.
  - Gesperrt: Ring gedämpft, Schloss statt Icon.
  - Gelernt: Ring hell, Mitte leicht in Baumfarbe getönt, Icon, Häkchen. Die Tönung ist ein gezeichneter Kreis innerhalb des Rings, keine weitere Icon-Datei.
  - `learned.webp` (grün) und `locked.webp` (grau) werden dafür nicht gebraucht.
- **Hint-Karte:** Der neue Rahmen gilt für **alle** Hint-Karten im Spiel (`HintCard`). Es bleibt bei `Hints`, eine eigene Tooltip-Szene gibt es nicht. Die Karte folgt wie bisher der Maus und wird nie am Knoten ausgerichtet. Der Pfeil zeigt auf den Mauszeiger und wechselt die Seite, wenn die Karte am Bildrand umklappt.
- **Debug-Build:** Die Kopfzeile zeigt wie bisher „∞ Skillpunkte (Debug)“. Das Konzeptbild weicht hier ab.
- **Reduzierte Bewegung:** vorerst gestrichen, eine solche Einstellung gibt es nicht.

## Dateien

skill-tree-v5.webp: freigegebener Entwurf. Frühere Varianten sind gelöscht.


Mit eingebautem Imagegen erstellt; Bearbeitungsprompts in prompt-v3.txt. Verlustfreie WebP-Dateien. Noch keine Spielintegration und keine interaktive Kaufimplementierung. Konzeptverzeichnis ist durch .gdignore vom Godot-Import ausgeschlossen. Wiederverwendbare Fenster-Styles liegen unter assets/ui/windows/.


Kopfzeile: Stern und 995 Skillpunkte rechtsbündig vor dem Schließen-X. 995 ist der Konzept-Beispielwert; im Spiel aktuellen Punktestand dynamisch anzeigen. Mit eingebautem Imagegen bearbeitet; Prompt: prompt-v5.txt im Konzeptordner.
