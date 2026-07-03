# Backlog: Ideen aus dem Vokabel-Prompt fürs Modell

Der ursprüngliche Entwurf des [Vokabel-Generierungs-Prompts](./vocab_generation.md)
enthielt Konzepte, die das aktuelle Datenmodell nicht abbildete. Einige sind inzwischen
umgesetzt, andere bleiben als Backlog. Bezugspunkte:
[`ARCHITECTURE.md`](../ARCHITECTURE.md), [`ADDING_CONTENT.md`](../ADDING_CONTENT.md),
`src/learning/task_resolver.gd`, `src/battle/wave_generator.gd`,
`src/learning/player_progress.gd`.

## ✅ Umgesetzt

### `notes`-Freitextfeld + `irregular`-Tag
Optionales `notes`-Feld am Eintrag (Review/Zweifelsfälle); unregelmäßige Verben über
Tag `"irregular"` statt eines Feldes. Dokumentiert in `ADDING_CONTENT.md`, im Prompt
wieder zugelassen.

### CEFR / frequency_band als confidence-Prior
Optionale Lexem-Felder `cefr` (A1..C2) und `frequency_band`
(core|high|common|mid|low|rare). `WaveGenerator._confidence_prior()` mittelt die
vorhandenen Signale zu einer Start-Confidence; `PlayerProgress.confidence/record/_ensure`
nehmen sie über `initial_confidence` auf. **`difficulty` bleibt bewusst NICHT am Lexem** —
der Prior ist nur die bessere Anfangsschätzung des Lernstands, die Schwierigkeit bleibt
Projektion der Confidence. Schwerere/seltenere Wörter starten unsicherer → langsameres
Monster + mehr Punkte. Demo-Annotation am Paar `dangerous`/`safe`.

### `confused_with`-Daten + „Confusables"-Aufgabentyp
Neuer `task_type: confusables` (`TaskResolver._resolve_confusables`): zeigt die deutsche
Bedeutung + beide englischen Kandidaten des Verwechslungspaars und akzeptiert das passende
Lemma. Enthält `def.confusables`, `mrule.confusables.de_en`, ist im Default-Wellenpool
aktiv. Demodaten: `data/lexemes/en_confusables.json` +
`data/lexeme_relations/en_confusables.json` (borrow/lend, say/tell, jeweils beide
Richtungen).

### Produktiv/rezeptiv-Zielverteilung als Vorgabe
900 produktiv / 600 rezeptiv über Tags `core`/`receptive` — im Prompt als Design-Vorgabe
verankert.

## Offen

### `confused_with`-Datenbestand ausbauen
Bisher nur zwei Demopaare. Systematisch typische Klasse-9-Fehlerquellen ergänzen
(look for/at/after, remember/remind, since/for, …). Reine Datenarbeit — die Mechanik steht.

### Boss-Sätze an geforderte Lexeme koppeln
Über die vorhandene Kategorie `sentence_lexemes`. Passt zur Philosophie
„Schwierigkeit = Projektion": ein Boss-Satz wird erst fällig, wenn seine Kern-Lexeme
gelernt sind. (Die ursprüngliche `required_lexeme_ids`-Idee, nur anders serialisiert.)
Hängt am zurückgestellten Satz-/Boss-Feature.

### Redemittel / Connectors als eigene Aufgabenform
„Redemittel für Diskussion/Meinung/Vergleich" sind für Klasse 9 zentral, werden von
`translate` aber nur schwach getroffen. Perspektivisch ein eigener Aufgabentyp
(Lückensatz / passende Wendung). Bis dahin als `type: expression`/`connector` mit Tag
sammeln. Hängt mit dem zurückgestellten Satz-/`fill_gap`-Feature zusammen.

## Bewusst verworfen
- **`difficulty` am Lexem** (1–5-Skala): widerspricht dem Architektur-Prinzip; durch
  confidence-Prior besser gelöst.
- **`is_irregular` als Feld**: als Tag `"irregular"` ausreichend.
- **`phrasal_variant`-Relation**: kein realer Nutzen; `related` + Alt-Listen decken das ab.
- **Verschachteltes `forms`-Array / `gerund`-Formtyp**: passt nicht zum flachen
  Form-Schema bzw. heißt `present_participle`.
