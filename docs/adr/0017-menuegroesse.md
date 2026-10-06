# ADR 0017 — Menügröße: die Bezugsgröße wird aus dem Fenster gerechnet

Status: **angenommen** · Datum: 2026-10-06 · Issue #38

## Kontext

Das Spiel skaliert mit `canvas_items`/`expand` von einer festen Bezugsgröße 1152×648 aus.
Ein größeres Fenster macht damit alles größer, auch die Menüs: im Vollbild auf 1920×1080
um den Faktor 1,67. Auf einem Notebook ist das Startfenster (1152×648) zu klein und das
Vollbild zu groß. Die 3D-Welt rendert ohnehin in Fensterauflösung und darf wachsen.

## Entscheidung

1. **Die Skalierungsart bleibt, die Bezugsgröße wird gerechnet** (`UiScale`,
   `src/core/ui_scale.gd`): Fenster ÷ gewünschte Skala, je Achse mindestens 1152×648. Ein
   großes Fenster gibt mehr Platz statt größerer Schrift. Reicht das Fenster nicht, sinkt
   die Skala wie bisher, und die übrige Achse wächst wie bei `expand`. 1152×648 bleibt der
   schmalste Fall, die Layout-Tests gelten unverändert.

2. **Die gewünschte Skala ist Systemskalierung × Stufe.** Unter Windows die wirksame DPI
   ÷ 96 (150 % → 1,5), unter macOS der Retina-Faktor. „Mittel" heißt damit: so groß, wie der
   Rechner seine eigenen Fenster zeichnet. Die Stufen „Klein"/„Mittel"/„Groß" sind 0,85 / 1 /
   1,2 darauf.

3. **Gespeichert wird nur die Stufe**, geräteweit in `[general] ui_size` wie die
   Grafikstufe. Was „Mittel" in Pixeln heißt, wird bei jedem Start und jeder
   Größenänderung gerechnet.

4. **Die Bezugsgröße setzt nur `UiScale.apply`.** Ausgelöst wird sie von `UserSettings`
   beim Start und nach jedem `size_changed`. Werkbänke, die mehr Platz brauchen (`LabRoom`),
   heben die Untergrenze `UiScale.floor_size`, statt die Bezugsgröße selbst zu schreiben.
   Sonst nähme die nächste Größenänderung den Platz wieder weg.

5. **Kopflos gilt fest 1152×648.** Das kopflose Fenster ist 100×100 und gibt kein Maß.

6. **Die EXE startet maximiert** (`window/size/mode.template=2`). Editor-Läufe, Werkbänke
   und ihre Bilder bleiben im freien Fenster 1152×648, damit Bilder nicht vom Bildschirm
   abhängen.

## Folgen

- Das Kampf-HUD wird mit der Menügröße kleiner, auch relativ zu den Monstern: die 3D-Welt
  hält ihre Höhe, die Wortschilder stehen in Canvas-Einheiten. Wenn das für Kinder zu klein
  wird, bekommt `UiScale` eine Mindestskala, die der Kampf beim Betreten setzt, und keine
  eigene Einstellung.
- Vorgerenderte Bilder werden meist schärfer als vorher (kleinere Skala als im Vollbild
  bisher). Nur „Groß" auf großen Schirmen liegt darüber.
- Wechselt das Fenster auf einen Bildschirm mit anderer Skalierung, gilt die neue erst mit
  der nächsten Größenänderung.
