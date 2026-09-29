# Monster-Slam – Hauptmenü-Assets

Aus dem freigegebenen Menüentwurf abgeleitet, 29.09.2026.
Freistellung, Entfernen der Beschriftungen und goldener Highlight-Zustand mit dem eingebauten Imagegen-Tool; kein API-/CLI-Fallback. Die generativen Extraktionen sind stilgetreue Rekonstruktionen, keine pixelidentischen Ausschnitte des ursprünglichen Entwurfs.

## Dateien

| Datei | Größe | Verwendung |
| --- | --- | --- |
| `logo.webp` | 1216 × 593 | Logo mit Transparenz |
| `buttons/button_normal.webp` | 1040 × 192 | Leere dunkelblaue Button-Fläche |
| `buttons/button_highlighted.webp` | 1040 × 192 | Goldener Hover-/Fokus-/Auswahlzustand |
| `panels/profile_panel.webp` | 1016 × 253 | Leere Profilplakette mit unterem rechten Tab |
| `icons/*.webp` | je 256 × 256 | play, skills, statistics, content, settings, expert, profile, switch_profile |

Alle zwölf Laufzeitbilder sind verlustfreie RGBA-WebP-Dateien mit echter Transparenz. Details stehen in `manifest.json`. Die Quelldateien und verwendeten Prompts liegen unter `sources/`; diese werden durch `.gdignore` vom Godot-Import ausgeschlossen. `preview/` enthält eine Kontaktübersicht auf heller und dunkler Fläche.

## Verwendung in Godot

- Normale und hervorgehobene Button-Textur sind über denselben Quellausschnitt ausgerichtet. Gleiche Control-Abmessungen beibehalten; kein erneutes Trimmen pro Zustand. Empfohlene Anzeige etwa 520 × 96 px.
- `TextureButton.texture_normal` und `texture_hover` entsprechend zuweisen. Für die aktive „Spielen“-Aktion kann die goldene Variante dauerhaft verwendet werden. Tastatur-/Controller-Fokus ebenfalls sichtbar markieren. Ein eigener Pressed-/Disabled-Zustand ist nicht Bestandteil dieses Sets.
- Beschriftungen als echte `Label`-Nodes darüberlegen: SPIELEN, FÄHIGKEITEN, STATISTIK, INHALTE, EINSTELLUNGEN. Die Textur ist absichtlich unbeschriftet; dadurch bleiben Lokalisierung und Skalierung möglich.
- Icons typischerweise mit 40–64 px darstellen. Links etwa 40 px Innenabstand am Button lassen, Text ab etwa 130 px setzen (bezogen auf die empfohlene Anzeigegröße).
- Logo und Profilplakette proportional skalieren. Die Plakette hat eine asymmetrische Unterkante und ist kein generisches NinePatch. XP-Balken, Spielername, Level und Profilwechsel werden separat mit UI-Nodes gerendert.
- Texturen mit linearer Filterung und verlustfreier Import-Kompression verwenden. Hintergrund bleibt eine Szene aus den vorhandenen Spielmodellen; dieses Set enthält keine Hintergrundillustration.

## Reproduzierbarer Export

`export-assets.cjs` konvertiert die lokalen PNG-Quellen mit Sharp, schneidet das Icon-Atlas in Einzelbilder und vereinheitlicht die Button-Leinwände. `SHARP_MODULE` kann auf eine lokale Sharp-Installation zeigen. Ein anschließender Export nutzt ausschließlich `sources/` und benötigt keinen erneuten Bildgenerierungsaufruf.

Geprüft: WebP-Dekodierung, Alphakanal mit transparenten und deckenden Pixeln für jedes Asset, identische Button-Abmessungen sowie visuelle Kontaktübersicht. Noch nicht in eine Godot-Szene eingebaut.
