# Skalierbare Monster-Slam-Fenster

Nine-Slice-Fensterrahmen passend zu den freigegebenen Hauptmenü-Buttons. Erstellt am 29.09.2026.

## Direkt verwenden

1. `window_shell.tscn` in eine UI-Szene instanziieren. Unter `Content` die gewünschten Controls hinzufügen.
2. Den äußeren `PanelContainer` über Anchors oder einen Container auf die gewünschte Größe setzen. Der Rahmen wird in beiden Achsen über `StyleBoxTexture` skaliert: vier feste Ecken, vier nur längs gedehnte Kanten, eine gedehnte Innenfläche.
3. Für einen fertigen Statistik-Aufbau `statistics_example.tscn` öffnen und die Szene mit F6 ausführen. Das Beispiel nutzt statische Werte aus dem Screenshot, keine Spielstände. „Zurück“ beendet diese Demo.
4. Alternativ `window_theme.tres` lokal einem Fenster-Control zuweisen. Enthalten sind Stile für PanelContainer, Panel, Button, TabContainer und TabBar. Ein globaler Austausch des bestehenden Projektthemes ist nicht nötig. Buttons mindestens etwa 140 × 56 px anlegen.

## Assets und Slices

| Ressource | Textur | Slice-Ränder L/T/R/B | Innenabstand |
| --- | --- | --- | --- |
| `styles/window.tres` | `window_panel_compact.webp`, 256 × 256 | 32 / 32 / 32 / 32 px | 26 px |
| `styles/window_large.tres` | `window_panel.webp`, 512 × 512 | 64 / 64 / 64 / 64 px | 48 px |
| `styles/frame_only.tres` | kompakte Textur | 32 / 32 / 32 / 32 px | 26 px |
| `styles/tab_normal.tres` | `tab_normal.webp`, 520 × 96 | 28 / 28 / 28 / 28 px | 16 px |
| `styles/tab_highlighted.tres` | `tab_highlighted.webp`, 520 × 96 | 28 / 28 / 28 / 28 px | 16 px |

`frame_only.tres` zeichnet die Mitte nicht und kann über einer eigenen Innenfläche verwendet werden. Alle WebP-Dateien sind verlustfrei mit Alphakanal. Die generierte Rahmen-Textur besitzt transparente Außenbereiche und eine deckende Innenfläche. Die Slice-Grenzen liegen außerhalb der abgeschrägten Ecken.

Die Texturen nicht als komplettes Bild auf eine andere Seitenproportion ziehen: `StyleBoxTexture` oder `NinePatchRect` mit den angegebenen Rändern verwenden. Ecken und Rahmenstärke bleiben dann unverändert. Für `NinePatchRect` müssen eigene MarginContainer für den Inhalt angelegt werden; StyleBoxTexture kann diese Abstände selbst liefern.

Größere Fenster können beliebige Seitenverhältnisse haben. Nach unten bestehen Grenzen: geometrisch mindestens zweimal die Slice-Breite/-Höhe, praktisch mindestens 280 × 180 px für eine leere Fensterhülle. Das Statistik-Beispiel ist für mindestens 480 × 400 px ausgelegt; bei 480 × 800 px geprüft. Schrift und Icons separat zeichnen. Größere UI-Skalierung erfolgt zusätzlich über Godots UI-Skalierung oder den großen Rahmenstil; Rasterassets sind nicht unbegrenzt detailreich.

## Statistik-Beispiel

- Titel, Zurück-Aktion, goldener aktiver Tab und weitere Tabs.
- Tabs umbrechen bei geringer Breite; native TabContainer umbrechen nicht automatisch. Das Beispiel verwendet deshalb HFlowContainer und gruppierte Buttons.
- Kennzahlen ab 760 px nebeneinander, darunter untereinander.
- Inhaltsbereich vertikal scrollbar; Titel, Tabs und Fußzeile bleiben stehen.
- Monatstage umbrechen; Beschriftungen sind native Labels.
- Fortschritt/Aufgaben zeigen zusätzliche Beispielansichten; Debug-Werte lassen sich einblenden.

Der bestehende Statistik-Screen und die Spiel-Logik wurden nicht verändert. Zur Integration dessen Datenquellen mit den Labels/ProgressBars dieses Beispiels verbinden.

## Prüfung und Herkunft

In isoliertem Projekt mit Godot 4.7 geladen und ausgeführt. Fünf StyleBoxTexture-Ressourcen, drei Viewportgrößen (1280 × 900, 800 × 700, 480 × 800), Tab-Inhalte und horizontaler Überlauf geprüft. Native Godot-Renderings bei 1280 × 900 und 480 × 800 in `preview/` visuell kontrolliert. Eine Umgebungswarnung zum Windows-Zertifikatsspeicher beeinflusst die lokalen UI-Prüfungen nicht.

Fenstertextur mit dem eingebauten Imagegen-Tool aus der vorhandenen Button-Referenz abgeleitet, kein API-/CLI-Fallback. Finaler Prompt: `sources/prompt.txt`. Quelle: `sources/window-generated.png`. Export über Sharp mit `sources/build.cjs` (Modulpfad über `SHARP_MODULE` konfigurierbar). Quellen und Vorschauprojekt sind mit `.gdignore` vom Spielimport ausgeschlossen.
