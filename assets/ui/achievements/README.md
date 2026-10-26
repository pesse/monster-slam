# Monster-Slam-Erfolgs-Icons

24 Icons mit 256 × 256 Pixeln als verlustfreie RGBA-WebP-Dateien in `icons/`. Die bemalten Kacheln reichen bis zum schmalen Metallrahmen. Außerhalb der abgerundeten Ecken (Radius 25,6 px) transparent, innen deckend; geglättete Alphakante. Licht von oben links, keine Schrift oder Zahlen. Für 64 px in der Statistik und 56 px in der Erfolgseinblendung.

| Datei unter icons/ | Motiv | Rahmen / Hintergrund |
| --- | --- | --- |
| words_50.webp | Schnüffelmonster, offenes Buch und Pfotenabdrücke | Bronze / warmes Grün |
| words_100.webp | Pfeil und Bogen mit durchbohrter Buchseite | Silber / Himmelblau |
| words_500.webp | Kleiner Drache auf Bücherhort | Gold / Glutrot und Orange |
| words_1000.webp | Brüllendes freundliches Monster, wirbelnde Seiten | Kristall / Violett |
| mastered_first.webp | Keimling aus offenem Buch | Bronze / Frühlingsgrün |
| mastered_100.webp | Bücherstapel mit goldenem Lesezeichen | Gold / Tiefblau |
| unit_tier_4.webp | Burg mit vier Türmen, Fahnen und Schutzschein | Gold / Königsblau |
| book_tier_2.webp | Schatzkarte mit Burgsymbolen und Kompass | Silber / Pergament und Türkis |
| boss_first.webp | Gekreuzte Schwerter vor besiegtem Hornhelm | Silber / Dunkelrot |
| boss_gold.webp | Krone auf gekreuzten Schwertern | Gold / Purpur |
| streak_7.webp | Flamme über leerem Kalenderblatt | Bronze / Orange |
| streak_30.webp | Komet mit langem Feuerschweif | Gold / Nachtblau und Orange |
| level_5.webp | Ein Stern und Aufwärtspfeil | Bronze / Blau |
| level_10.webp | Zwei leuchtende Sterne | Silber / Türkis |
| level_20.webp | Drei Sterne mit kleiner Krone | Gold / Violett |
| chests_10.webp | Offene Schatzkiste mit Münzen und Licht | Gold / Smaragd |
| skill_first.webp | Leuchtender Blattzweig mit Funken | Bronze / Grün |
| skill_branch.webp | Mächtiger Baum mit leuchtenden Astknoten | Gold / Waldgrün |
| badges_all.webp | Fächer bunter Medaillen mit Bändern | Gold / Dunkelblau |
| wave_last_hp.webp | Herzförmiges Festungsschild am letzten Faden über Abgrund | Rubin / Schwarzrot |
| run_untouched.webp | Makelloser Schild mit abprallenden Pfeilen | Silber / Eisblau |
| boss_flawless.webp | Perfekt geschliffener funkelnder Diamant | Diamant / Cyan |
| revenge_3.webp | Drei magische Krallenblitze treffen fliehendes Monster | Rubin / Violett und Rot |
| hidden.webp | Verhüllte Truhe mit Lichtspalt und Nebel | Dunkles Eisen / Schieferblau |

Herkunft: am 26.10.2026 mit dem integrierten OpenAI-ImageGen-Werkzeug für diesen Auftrag erstellt. Stilvorlagen waren die vom Nutzer angehängten Monster-Slam-Assets Schatzkiste, Flamme, violette Schwertmedaille und Festungsturm. Zuerst entstand `unit_tier_4` als Stilanker; er diente als Bildvorlage für vier Atlanten mit je sechs quadratischen Zellen und einen Korrektur-Atlas. Die Burg verwendet den ursprünglichen Stilanker.

`sources/` enthält unveränderte PNG-Rohbilder, vollständige Prompts und Zellzuordnung in `prompts.json`, das Exportskript `build.cjs` sowie `validation.json`. Der Export mit Sharp/Lanczos verkleinert die Zellen, vereinheitlicht ausschließlich die äußere Rundung und kodiert verlustfrei. Reproduktion: `node sources/build.cjs`; bei Bedarf Sharp-Modulpfad über `ACHIEVEMENTS_SHARP` setzen.

`preview/all.png` zeigt alle 24 Icons mit Dateinamen auf #1b2233, `preview/all_gray.png` dieselben Icons in abgedunkelten Graustufen als gesperrte Vorschau. `preview/size_check.png` ergänzt eine Sichtprüfung bei 64 und 56 px. `sources/` und `preview/` enthalten jeweils eine leere `.gdignore` und werden von Godot nicht importiert.

Die Exportprüfung kontrolliert für jede Datei Maße, RGBA, VP8L-Kodierung, pixelgleichen Dekodierungsvergleich aller sichtbaren Farbwerte und sämtlicher Alphawerte sowie die vollständige Alphakontur mit deckendem Innenbereich. Unsichtbare RGB-Werte unter Alpha null dürfen durch den WebP-Encoder ersetzt werden.
