# Skalierbare Monster-Slam-Fenster

Nine-Slice-Fensterrahmen passend zu den freigegebenen Hauptmenü-Buttons. Erstellt am 29.09.2026.

## Ergänzung für den Fähigkeitenbaum – korrigierte Revision 2

Die erste Lieferung hatte einen separat umrahmten Titelbalken und eine flache Füllung. Revision 2 bildet den gemeinsamen Fensterrahmen, die feine Titeltrennkante und die seitlichen Anschlussplatten des Konzepts nach. Alle Laufzeittexturen sind verlustfreie WebP mit Alpha, ohne Beschriftung; einzige Symbol-Ausnahme ist das gewünschte separate Schließen-X.

| Datei / Zustände | Leinwand | Slice L/T/R/B | Verwendung |
| --- | --- | --- | --- |
| `window_panel_compact.webp` | 256 × 256 | 32 / 32 / 32 / 32 | ca. 8 px Rand, 16 px Abschrägung, Innenabstand 26 px |
| `title_bar.webp` | 512 × 64 | 32 / 8 / 32 / 8 | Nur waagerecht dehnen; Höhe 64, empfohlen 800–1100 px breit |
| `title_joint_left.webp`, `title_joint_right.webp` | je 24 × 24 | keine | Feste Metallanschlüsse zwischen Titeltrennkante und Seiten |
| `window_surface.webp` | 512 × 512 | keine | Separate kachelbare Materialebene mit Alpha 190/255 |
| `close.webp`, `close_hover.webp`, `close_pressed.webp` | je 128 × 128 | keine | Sichtbar ca. 96 × 96, ganze Textur im Spiel 32–40 px |
| `tool_button_normal.webp`, `tool_button_hover.webp`, `tool_button_pressed.webp`, `tool_button_disabled.webp` | je 44 × 44 | 8 / 8 / 8 / 8 | Rand ca. 2 px; Innenabstand 7 px; Zeichen liefert das Spiel |

Aufbau bei Fensterbreite W, alle Positionen relativ zur Fensteroberkante:

1. Kompaktes Panel als Nine-Slice zeichnen, 32 px pro Seite.
2. `window_surface.webp` mit 512-px-Kacheln wiederholen, nicht als Nine-Slice dehnen. Auf die innere Fläche beschneiden: 9 px Einzug, innere Ecken 11 px abgeschrägt. Die Alphaebene liegt über der deckenden Panel-Füllung.
3. `title_bar.webp` bei (0, 0) auf W × 64 legen. Es überdeckt oben denselben Außenrahmen und wird nicht eingerückt. Die feine Trennkante liegt bei y=62; keine unteren abgeschrägten Titelband-Ecken.
4. Optional dieselbe Materialtextur auf der Titelinnenfläche mit zusätzlicher Deckkraft 0,48 zeichnen; nur x=10..W−10, y=10..59, obere Ecken beschneiden. Metallische Kanten bleiben frei von Flächentextur.
5. Linke Anschlussplatte bei (0, 51), rechte bei (W−24, 51), jeweils 24 × 24 unverändert. Sie reichen bis y=75 unter die Trennkante und werden über Titelband und Rahmen gelegt.
6. Icons, Titel, Punkte und X darüber zeichnen. Inhalt ab y=80 beginnen lassen. Der bestehende Panel-Innenabstand 26 px reserviert das Titelband nicht automatisch.

Im Titelband links 24 px, oben/unten 12 px freihalten. Links 40 × 40 px für das Icon, danach 12 px bis zum Titel. Rechts eine 40 × 40-px-Box für das X, 12 px Abstand zum rechten Rand; Punkte links daneben mit mindestens 20 px Abstand. Etwa 230 px für die rechte Gruppe reservieren, bei langen Punktetexten mehr. Eine 32-px-X-Textur in der 40-px-Box zentrieren.

Alle Maße sind logische Pixel bei 1152 × 648. Die Vorschau bei 1920 × 1080 skaliert die UI insgesamt um 5/3. Die feste Titelhöhe bezieht sich auf die Basisauflösung.

X: schlankes helles Silber, Hover heller, Pressed dunkler; gleicher Alphakanal und gleiche Position. Werkzeugrahmen: Normal, heller Hover, dunkler Pressed, nochmals dunkler Disabled; keine eingebrannten Zeichen. Gerade Panel-/Titelmittelstücke sind pixelgleich, sodass STRETCH und TILE keine Glanzflecken verziehen. Die Materialebene wird unabhängig gekachelt. Das große `window_panel.webp` und die Tabs bleiben unverändert; die neue Kanten-Garantie gilt für den kompakten Rahmen und das Titelband.

Vorschauen: `preview/skill-tree-window-1152x648.png`, `preview/skill-tree-window-1920x1080.png`, `preview/close-states.png`. `preview/concept-header-comparison.png` zeigt oben das freigegebene Konzept und darunter die tatsächliche Asset-Komposition. Buch, Titel, Punkte und Werkzeugzeichen sind nur Vorschau-Overlays; die vier Werkzeugrahmen zeigen Normal. Der Stern stammt aus dem vorhandenen Skill-Tree-Paket.

Quellen und exakte Prompts: `sources/revision-2-prompts.md`, `sources/shell-v2-generated.png`, `sources/close-v2-generated.png`. Erzeugt mit dem eingebauten Imagegen-Tool, Export mit Sharp: `node sources/rebuild-v2.cjs` oder `node sources/extend-windows.cjs`. Bei Bedarf `SHARP_MODULE` setzen. Frühere Quellen bleiben historische Referenzen. Den ursprünglichen `sources/build.cjs` nicht zum Export dieser Ergänzung verwenden.

Prüfbericht: `preview/extension-check.md`; maschinenlesbar: `preview/asset-checks.json`. Spielcode, Szenen und Theme-Ressourcen wurden nicht verändert.
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

## Prüfung und Herkunft des ursprünglichen Pakets

In isoliertem Projekt mit Godot 4.7 geladen und ausgeführt. Fünf StyleBoxTexture-Ressourcen, drei Viewportgrößen (1280 × 900, 800 × 700, 480 × 800), Tab-Inhalte und horizontaler Überlauf geprüft. Native Godot-Renderings bei 1280 × 900 und 480 × 800 in `preview/` visuell kontrolliert. Eine Umgebungswarnung zum Windows-Zertifikatsspeicher beeinflusst die lokalen UI-Prüfungen nicht.

Fenstertextur mit dem eingebauten Imagegen-Tool aus der vorhandenen Button-Referenz abgeleitet, kein API-/CLI-Fallback. Finaler Prompt: `sources/prompt.txt`. Quelle: `sources/window-generated.png`. Export über Sharp mit `sources/build.cjs` (Modulpfad über `SHARP_MODULE` konfigurierbar). Quellen und Vorschauprojekt sind mit `.gdignore` vom Spielimport ausgeschlossen.
