# ADR 0006 — Buchzentrierte Karte statt Runden-Setup

Status: **angenommen** · Datum: 2026-09-25 · Issue: #28 · Ändert: ADR 0005, Entscheidung 6
(der Boss steht jetzt am Ende jeder Unit) · Ergänzt: ADR 0001 (der Grundwortschatz-Pack
entfällt)

## Kontext

Bis 0.10 führte „▶ Spielen" in „Runde vorbereiten": Bücher, Units und Teile ankreuzen,
Aufgaben- und Wortarten wählen, Tags filtern — dann eine endlose Wellenrunde. Der Boss war
ein zweiter Knopf daneben, ohne Bezug zu einer Unit. Die Landkarte zeigte Festungsstufen,
ein Klick darauf füllte aber nur den Filter.

Das ist mächtig und für ein Kind der falsche Einstieg: die erste Entscheidung ist eine
Filterkombination statt „wo will ich hin". Dazu kam der frei verteilte Grundwortschatz
(`language-basic`, rund 2000 selbst erzeugte Lexeme ohne Buchbezug): qualitativ schwach,
und er machte „leerer Scope" zu „alles, auch ohne Buch".

## Entscheidung

### 1. Der Weg ins Spiel führt über das Buch

**▶ Spielen → Buchauswahl → Buchkarte → Gebietskarte → Kampf.**

- Die **Buchauswahl** zeigt je Buch eine Karte mit Stand (gemeisterte Wörter, schwächste
  Festung, besiegte Bosse).
- Die **Buchkarte** ist ein Bild mit einem Ort je Unit — die Units sind die Gebiete.
- Die **Gebietskarte** ist ein Bild mit den Leveln der Unit: T1 … T4 (die vier Teile, die
  `ContentRegistry` ohnehin schon berechnet), **Gesamt** (die ganze Unit) und der **Boss**.
  Hat eine Unit weniger Teile, gibt es weniger T-Level; bei nur einem entfällt Gesamt.

„Runde vorbereiten" bleibt unverändert als **Expertenmodus** — ein kleiner Knopf unter
dem Menü, nicht mehr der Hauptweg.

### 2. Nichts wird gesperrt, nichts wird als Abschluss gespeichert

Alle Level sind frei wählbar. Wie weit ein Level ist, wird aus der Meisterung **gerechnet**
— dieselbe Zählung und dieselben Schwellen (10/35/60/85 %) wie die Festungsstufe
(`FortressTier.part_tiers` neben `unit_tiers`; Gesamt ist genau `unit_tiers`). Ein
gespeichertes „Level geschafft" wäre ein zweiter Zähler neben dem Lernstand.

Ein Level ist ein Lauf wie bisher: die Wellen laufen endlos, bis man aufhört oder die
Festung fällt. „Zurück" führt auf die Gebietskarte, wo die Stufen schon nachgezogen sind.

### 3. Boss-Siege sind ein Ursprungswert

Ein Sieg über den Boss einer Unit lässt sich aus nichts anderem ableiten, also wird er
gespeichert: je Sieg ein Eintrag `{unit, won_at}` in `user://progress/<profil>_bosses.json`
(`BossRecord`). Gezählt wird beim Lesen; 1/3/5 Siege ergeben Bronze, Silber, Gold, und
der Boss auf der Karte wird golden. Gold, Erfahrung und Lernstand bleiben unberührt (ADR
0005, Entscheidung 6). Ein Boss aus dem Expertenmodus hat keinen Bereich, der einer Unit
gehört, und zählt nicht. Die Spur bekommt den Sieg über ein eigenes Signal `boss_won`.

### 4. Kampf und Boss lesen ihren Bereich aus `RunRequest`

`RunRequest` hält statisch, was der nächste Lauf spielt: ein Level der Karte oder — ohne
Level — die gespeicherte Auswahl des Expertenmodus. `WaveRunner`, `SentenceSelector` und
die Festungsstufe lesen dort und nicht mehr in `UserSettings`; sonst spielte ein Level mit
Filtern, die jemand irgendwann im Expertenmodus gesetzt hat. Ein Level spielt alle
Aufgaben- und Wortarten seines Bereichs und filtert nicht nach Themen.

### 5. Kartenbilder liegen in der EXE, nicht im Pack

`assets/maps/<book>/book.png`, `unit<n>.png` und `map.json` (Punkte in Anteilen des Bildes).
Bild und Punkte gehören zusammen; ein Pack trägt nur JSON und hätte eine neue Kategorie an
vier Stellen gebraucht. Die Bilder entstehen mit einem Bild-KI-Tool aus
`docs/prompts/map_images/`, die Punkte setzt die Werkbank `scenes/dev/map_lab.tscn`.
Der Stil folgt den Modellen des Kampfes: ein Low-Poly-Spielbrett aus Sechseck-Kacheln auf
dem Dunkelblau der Oberfläche, keine gemalte Landschaft — die erste, gemalte Fassung sah
weder nach Karte noch nach dem Spiel aus. Jedes Buch hat ein eigenes Thema (Landschaft,
Jahreszeit, Stimmung) und eine eigene Prompt-Datei.
Fehlt ein Bild oder ein Punkt, zeigt die Karte eine schlichte Fläche und legt die Orte
selbst aus — eine Unit aus einem Content-Update ist so spielbar, bevor ihr Bild existiert.

### 6. Der Grundwortschatz entfällt

`language-basic` ist aus `packs.yaml` und dem Content-Repo entfernt. Die App deinstalliert
einen installierten Pack, den das Verzeichnis nicht mehr führt (`PackInstaller.retired`,
nach jedem erfolgreichen Abruf); ein leeres Verzeichnis zieht nichts zurück.

## Folgen

- Das Spiel braucht ein Buch mit Zugangscode, um spielbar zu sein. Ohne Code bleibt nur der
  offene `game`-Pack, und „▶ Spielen" ist gesperrt, bis Vokabeln da sind.
- Lernstände zu Grundwortschatz-Lexemen bleiben in `progress/*.json` liegen; gezählt werden
  sie nicht mehr, weil es die Lexeme nicht mehr gibt.
- Die Tag-Auswahl im Expertenmodus schrumpft auf die Themen der Bücher.
- Die Aufgabe `confusables` findet ohne Grundwortschatz keine Paare mehr; sie bleibt
  definiert und kommt wieder, sobald ein Buch `confused_with`-Relationen trägt.
- `UnitPath` (der gezeichnete Serpentinenpfad der alten Landkarte) entfällt; `MapCanvas`
  zeichnet beide Karten.

## Nicht gebaut

- **Ein eigener Boss je Unit**: es bleibt der eine Satzmeister, gefüttert mit den Sätzen der
  Unit. Ein Feld am Buch oder an der Unit, das einen anderen Boss nennt, kommt, wenn es
  einen zweiten gibt.
- **Eine feste Wellenzahl je Level** und ein gespeicherter Level-Abschluss.
- **Die Bilder selbst** — sie kommen nach und nach; bis dahin gilt der Platzhalter.
