# ADR 0031 — Karten als Pack je Buch

Status: **angenommen** · Datum: 2026-11-08 · Issue: #34 · Löst ab: ADR 0006, Entscheidung 5

## Kontext

Buch- und Gebietskarten (`book.webp`, `unit<n>.webp`, Masken) und `map.json` lagen unter
`assets/maps/<book>/` in der EXE. Ein neues Buch kam mit seinen Lexemen über einen Pack,
hatte ohne neue EXE aber nur die schlichte Fläche. Eine Karte in der EXE passte auch nicht
mehr, sobald ein Pack Units oder Lektionen eines Buchs änderte. `map.json` trägt außerdem
Inhalt des Buchs: Benennung und Einbandfarbe (`naming`), Kampfumgebung (`themes`) und die
Punkte der Lektionen. Die EXE trug damit rund 20 MB Inhalt.

## Entscheidung

1. **In der EXE steht die Mechanik, im Pack der Inhalt.** `export_presets.cfg` schließt
   `assets/maps/*` ganz aus. Ohne Karten-Pack zeigt die Karte die schlichte Fläche mit
   `default_positions`, das Buch heißt „Unit“/„Teil“, der Kampf nimmt das Standardthema.
   `BattleTheme`s, Modelle, Bodentexturen und der Stoff der Einbände (`assets/ui/library/`)
   sind Mechanik und bleiben in der EXE; `themes` in `map.json` nennt sie nur.

2. **Je Buch ein offener Pack `maps-<book>`.** Die neue Kategorie `maps` steht an allen
   vier Stellen (ADR 0003); in der ContentRegistry als `ASSET_CATEGORIES`, weil sie Dateien
   statt Einträge trägt (`ContentRegistry.asset_dir`). Ein Eintrag liegt genau eine Ebene
   unter dem Buch und ist `.json` oder `.webp` (`PackInstaller.is_allowed_entry`). Die
   Bilder tragen weder Schrift noch Vokabeln (ADR 0006), der Pack ist deshalb offen und
   baut aus dem Hauptrepo: Root `maps` ist dessen `assets/`, gescannt wird nur
   `maps/*/map.json` und `maps/*/*.webp` — PNG-Quellen, Routen, Entwürfe und Prüfbilder
   daneben gehören in keinen Pack. Das Pack-Format bleibt v1: ein ZIP trägt Bytes, ob
   JSON oder WebP. `check_open_packs.py` lässt den Buchnamen im Pfad von Karten zu.

3. **Ein Karten-Pack begleitet den Sprach-Pack seines Buchs** (`companion_of` in
   `packs.yaml`, `companionOf` im Index). Ohne Vokabeln ist eine Karte nichts wert, und
   eine eigene Zeile je Karte verdoppelte die Liste der Inhalte. Begleit-Packs stehen im
   `index.json` unter `companions` (Schema 3), nicht unter `packs`: eine ältere App liest
   nur `packs` und zeigte sie sonst als gesperrte Zeilen. Die App holt fällige Begleiter mit
   ihrem Pack (`ContentService.install_order`); ein installierter Pack mit fälligem
   Begleiter zeigt „Update verfügbar“ und zählt im Abzeichen. Ein Begleiter eines
   gesperrten oder nie geholten Packs zählt nicht.

4. **Lesen: Pack vor Repo.** `MapLayout.source_of(book)` nimmt den Ordner aus dem zuletzt
   sortierten Pack, sonst `assets/maps/<book>/` (nur im Editor-Lauf vorhanden). Bilder aus
   `user://` lädt `Image.load_from_file` ohne Import, im Hintergrund über den
   `WorkerThreadPool`. Nach jeder Installation zählt `ContentRegistry.generation` hoch;
   `MapLayout` und `BookNaming` verwerfen daran ihre Zwischenspeicher.

5. **Die Quelle bleibt `assets/maps/`.** `map_lab` schreibt dorthin und liest mit
   `MapLayout.bundled_only` nur dort, nie aus einem installierten Pack. Eine Änderung an
   `map.json` oder einem WebP stößt über `data-changed.yml` den Pack-Build an.

## Folgen

- Die EXE wird rund 20 MB kleiner; ein Buch bekommt neue Karten ohne neue EXE.
- Nach dem Update auf diese Fassung zeigt jedes installierte Buch „Update verfügbar“, bis
  seine Karten geholt sind. Bis dahin ist es mit schlichter Fläche spielbar.
- Karten-Packs tragen `min_app_version` 0.44.0. Reihenfolge wie immer: erst die App
  veröffentlichen, dann im Content-Repo nach `main`.
- Ein Karten-Pack ist mit 2–5 MB größer als die Sprach-Packs; geladen wird er einmal.

## Nicht gebaut

- **Karten im Sprach-Pack**: der ist geschützt und baut aus dem privaten Submodule, die
  Bilder sind offen und liegen im Hauptrepo. Ein Pack hat einen Root.
- **Ein Karten-Pack für alle Bücher**: wer ein Buch hat, lädt nicht die Karten der übrigen.
