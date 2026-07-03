# Prompt: Basis-Vokabelset Klasse 9 generieren

Prompt für einen Content-Generierungs-Agenten, der ein großes Englisch-Basisvokabular
für „Monster Slam" erzeugt. **An das reale Datenmodell angepasst** (ContentRegistry /
TaskResolver, siehe [`ADDING_CONTENT.md`](../ADDING_CONTENT.md) und
[`ARCHITECTURE.md`](../ARCHITECTURE.md)).

Wichtigste Abweichungen vom ursprünglichen Entwurf, die hier bereits korrigiert sind:
ID-Schema `lex.en.*`/`form.*`/`rel.*`/`sen.*`; **keine `difficulty` am Lexem** (CEFR/
`frequency_band` sind optionale Metadaten und dienen als Confidence-Prior); Formen als
**flache Zeilen** mit `present_participle` statt `gerund`; Relationen mit `id` +
`review_status`, ohne `phrasal_variant` (`confused_with` erzeugt Confusables-Aufgaben);
Sätze im realen `sentences`-Schema plus separate `sentence_lexemes`-Verknüpfung (kein
`required_lexeme_ids`). Welche dieser Ideen bereits im Modell umgesetzt sind, steht im
[Backlog](./vocab_generation_backlog.md).

---

## Prompt

````text
Du bist ein Agent zur Erstellung eines großen, sauberen Basis-Vokabelsets für das
Englisch-Lernspiel „Monster Slam" (Godot 4.7). Die Ausgabe muss exakt zum
bestehenden Datenmodell passen (ContentRegistry / TaskResolver, siehe
docs/ADDING_CONTENT.md und docs/ARCHITECTURE.md).

Ziel: Ein strukturiertes Grundvokabular für deutsche Gymnasium-Schüler der 9. Klasse
Englisch, Niveau A2+/B1 — systematisch generiert, angereichert, dedupliziert und für
das Spiel-Datenmodell vorbereitet.

Grundregeln des Datenmodells (unbedingt einhalten):
- Jedes Objekt hat eine eindeutige `id` im Schema `kategorie.name`.
- Sprachdaten (lexemes/forms/relations), Aufgaben-Regeln (task_definitions) und
  Darstellung sind getrennt. Aufgaben werden NICHT pro Wort angelegt: der
  WaveGenerator kombiniert die bestehenden task_definitions zur Laufzeit mit
  passenden Lexemen. Ein neues Wort abzufragen heißt: nur ein Lexem anlegen.
- Am Lexem gibt es KEINE `difficulty`. Schwierigkeit lebt auf der task_definition;
  der Lernstand kommt aus PlayerProgress.confidence. Erzeuge daher keine
  task_definitions und keine per-Wort-Schwierigkeit.
- `tags` sind das einzige Wellen-Filterkriterium. Konvention: die Wortart als Tag
  mitführen ("noun"/"verb"/"adjective"/"phrase") plus "basics" für den Kernwortschatz,
  dann semantische Themen-Tags.

--------------------------------------------------------------------------------
1. Zielniveau und Themenrahmen
--------------------------------------------------------------------------------
Klasse 9 Gymnasium Englisch, Schwerpunkte:
- Alltag, Familie, Schule, Freizeit
- Reisen, Orientierung, Verkehr
- Medien, Internet, Social Media
- Umwelt, Klima, Nachhaltigkeit
- Gesellschaft, Regeln, Konflikte, Meinung
- Kultur, Länder, Geschichte, Migration
- Gesundheit, Körper, Gefühle
- Jobs, Praktikum, Bewerbung, Zukunftspläne
- Literatur, Film, Textanalyse
- Redemittel für Diskussion, Meinung, Begründung, Vergleich

Zielgröße: mind. 1500 Lexeme; davon ca. 900 produktiv wichtig (Tag "core"),
ca. 600 rezeptiv/erweiternd (Tag "receptive"). Keine seltenen Spezialwörter ohne
Nutzen für Klasse 9.

--------------------------------------------------------------------------------
2. Lexeme  ->  data/lexemes/en_klasse9.json  (Array)
--------------------------------------------------------------------------------
Format je Eintrag:

{
  "id": "lex.en.dangerous",
  "type": "adjective",
  "lemma_de": "gefährlich",
  "lemma_en": "dangerous",
  "lemma_en_alt": [],
  "lemma_de_alt": [],
  "cefr": "B1",
  "frequency_band": "common",
  "tags": ["adjective", "core", "safety", "environment"],
  "notes": ""
}

Regeln:
- `id`: "lex.en.<slug>", stabil und sprechend, Slug aus dem englischen Lemma.
- `type`: bevorzugt aus dem dokumentierten Set noun | verb | adjective | phrase.
  Andere Kategorien (adverb, phrasal_verb, connector, expression) sind erlaubt,
  erhalten aber NUR translate-Aufgaben (keine opposite/synonym/conjugation) —
  wenn du sie nutzt, markiere das in import_report.md als offene Design-Frage.
- `lemma_en_alt` / `lemma_de_alt`: optionale Arrays für gleichwertige
  Übersetzungen/Varianten (z. B. go -> gehen/laufen, colour/color). Alle gelten
  bei translate als richtig. Ist die Variante ein eigenständiges Lernwort mit
  eigenen Aufgaben, lege stattdessen ein zweites Lexem an.
- `tags`: Wortart-Tag + "core" ODER "receptive" + semantische Themen-Tags.
  (Produktiv/rezeptiv wird über diese Tags abgebildet, nicht über ein eigenes Feld.)
- `cefr` (A1..C2) und `frequency_band` (core|high|common|mid|low|rare): optionale,
  deskriptive Metadaten. Sie setzen KEINE difficulty, dienen aber als Prior für die
  Start-Confidence (schwerere/seltenere Wörter starten unsicherer -> langsameres
  Monster + mehr Punkte). Wenn bekannt, immer angeben.
- `notes`: optionaler Freitext für Review/Zweifelsfälle (z. B. BE/AE-Hinweis).
- KEIN difficulty-Feld am Lexem (Schwierigkeit lebt auf der task_definition).
  KEIN productive/is_irregular-Feld. Produktiv/rezeptiv über Tags "core"/"receptive",
  unregelmäßige Verben über Tag "irregular".

--------------------------------------------------------------------------------
3. Verben anreichern  ->  data/lexeme_forms/en_klasse9.json  (Array)
--------------------------------------------------------------------------------
FLACHE Einzelzeilen, eine pro Form, jede mit eigener `id` — KEIN verschachteltes
"forms"-Array:

{ "id": "form.go.base",  "lexeme_id": "lex.en.go", "language": "en", "form_type": "base",              "value": "go" }
{ "id": "form.go.3sg",   "lexeme_id": "lex.en.go", "language": "en", "form_type": "3sg_present",       "value": "goes" }
{ "id": "form.go.past",  "lexeme_id": "lex.en.go", "language": "en", "form_type": "past_simple",       "value": "went" }
{ "id": "form.go.pp",    "lexeme_id": "lex.en.go", "language": "en", "form_type": "past_participle",    "value": "gone" }
{ "id": "form.go.ing",   "lexeme_id": "lex.en.go", "language": "en", "form_type": "present_participle", "value": "going" }

Regeln:
- Erlaubte form_type: base | 3sg_present | past_simple | past_participle |
  present_participle. Es gibt KEIN "gerund" — die -ing-Form ist "present_participle".
- `id`: "form.<slug>.<kurz>" (base/3sg/past/pp/ing), eindeutig.
- Für alle produktiven Verben mindestens base, 3sg_present, past_simple,
  past_participle, present_participle liefern.

--------------------------------------------------------------------------------
4. Relationen  ->  data/lexeme_relations/en_klasse9.json  (Array)
--------------------------------------------------------------------------------
{
  "id": "rel.dangerous.safe",
  "from_lexeme_id": "lex.en.dangerous",
  "to_lexeme_id": "lex.en.safe",
  "relation_type": "opposite",
  "confidence": 0.95,
  "review_status": "approved"
}

Regeln:
- Erlaubte relation_type: opposite | synonym | confused_with | related.
  Es gibt KEIN "phrasal_variant".
- `id` Pflicht ("rel.<from-slug>.<to-slug>"), `review_status` Pflicht
  (approved | draft | rejected).
- `opposite` und `synonym` erzeugen Aufgaben NUR für Lexeme vom type "adjective" —
  nur zwischen Adjektiven anlegen, wenn sie als Aufgabe genutzt werden sollen.
- `confused_with` erzeugt "confusables"-Aufgaben (Verwechslungspaare, ALLE Wortarten):
  typische Fehler wie borrow/lend, say/tell, look for/look at/look after. Damit die
  Bedeutungen unterscheidbar bleiben, muss `lemma_de` der beteiligten Lexeme die
  Nuance tragen (z. B. "sich leihen (von jmd.)" vs. "verleihen (jmd. geben)").
- `related` ist erlaubter Datenbestand ohne Aufgabe.
- Relationen werden nur über `from_lexeme_id` nachgeschlagen. Für beidseitige
  Nutzbarkeit jede Relation in BEIDEN Richtungen anlegen (from<->to getauscht,
  je eigene id).
- confidence < 0.8 => review_status "draft". Keine erfundenen Relationen.

--------------------------------------------------------------------------------
5. + 6. Sätze (Beispiel- UND Boss-Sätze)  ->  data/sentences/en_klasse9.json (Array)
--------------------------------------------------------------------------------
Hinweis: Das Satz-/Boss-Feature ist im Spiel derzeit ZURÜCKGESTELLT. Die Daten
werden aber schon im finalen Schema vorbereitet. Es gibt KEINE getrennte
"example_sentences"- oder "boss_sentences"-Kategorie — beides fällt unter `sentences`.

Schema je Satz:

{
  "id": "sen.forest_dangerous_key",
  "source_language": "de",
  "target_language": "en",
  "source_text": "Obwohl der Wald gefährlich war, suchten wir weiter nach dem Schlüssel.",
  "reference_translation": "Although the forest was dangerous, we kept looking for the key.",
  "difficulty": 3,
  "grammar_tags": ["although_clause", "past_simple", "phrasal_verb"],
  "is_generated": true,
  "review_status": "draft"
}

Erzeuge:
- Für jedes produktive (Tag "core") Lexem mindestens einen kurzen, natürlichen
  Beispielsatz (difficulty 1–2, einfache Grammatik).
- Zusätzlich ca. 300 anspruchsvollere Satzpaare für freie Übersetzung (difficulty 2–4).

Regeln:
- `id` Pflicht ("sen.<slug>"), `is_generated: true`, `review_status`
  (draft | approved | rejected) Pflicht. Generierte Sätze default "draft".
- `source_language`/`target_language`: "de"/"en".
- Deutsch und Englisch müssen semantisch übereinstimmen; kurz und natürlich.

Satz<->Lexem-Verknüpfung  ->  data/sentence_lexemes/en_klasse9.json  (Array)
(ersetzt das nicht existierende Feld "required_lexeme_ids"):

{ "id": "slx.forest_dangerous_key.forest", "sentence_id": "sen.forest_dangerous_key", "lexeme_id": "lex.en.forest" }
{ "id": "slx.forest_dangerous_key.dangerous", "sentence_id": "sen.forest_dangerous_key", "lexeme_id": "lex.en.dangerous" }
...

- Verknüpfe jeden Satz mit den enthaltenen Kern-Lexemen. Alle referenzierten
  lexeme_id/sentence_id müssen existieren.

--------------------------------------------------------------------------------
7. Qualitätsprüfung
--------------------------------------------------------------------------------
- Keine doppelten Lexeme mit gleicher Bedeutung.
- Keine britisch/amerikanisch widersprüchlichen Schreibweisen ohne Hinweis
  (Varianten über lemma_en_alt, z. B. colour/color).
- Keine C1/C2-Wörter im Kern ("core").
- Keine falschen Gegenteile; keine unnatürlichen Beispielsätze.
- Alle IDs eindeutig und im Schema kategorie.name; keine doppelten IDs innerhalb
  einer Kategorie.
- Alle produktiven Verben haben die fünf Formen.
- Alle Relations-/Satz-Verknüpfungsziele (from/to/lexeme_id/sentence_id) existieren.
- opposite/synonym nur zwischen Adjektiven; jede genutzte Relation in beiden
  Richtungen.

--------------------------------------------------------------------------------
8. Ausgabe (Dateien in die Registry-Ordner)
--------------------------------------------------------------------------------
- data/lexemes/en_klasse9.json
- data/lexeme_forms/en_klasse9.json
- data/lexeme_relations/en_klasse9.json
- data/sentences/en_klasse9.json
- data/sentence_lexemes/en_klasse9.json
- import_report.md

import_report.md enthält:
- Anzahl Lexeme gesamt
- Anzahl core vs. receptive (aus den Tags)
- CEFR-/Frequenzband-Verteilung (die Felder stehen am Lexem; hier zusammengefasst)
- Anzahl pro Wortart (type)
- Anzahl Relationen je Typ
- Anzahl Beispiel-/Boss-Sätze und Satz-Lexem-Verknüpfungen
- bekannte Unsicherheiten
- Review-Empfehlungen (alle Einträge mit review_status "draft" bzw. confidence < 0.8)

Wichtig:
- Das LLM darf Inhalte vorschlagen, aber alle unsicheren Einträge markieren:
  review_status "draft" oder confidence < 0.8.
- Erfinde keine Lehrbuch-spezifischen Vokabeln. Ziel ist ein breites, schulnahes
  Basis-Set für Klasse 9 Gymnasium Englisch.
- Jede JSON-Datei ist ein Array von Objekten und muss gültiges JSON sein
  (die Registry loggt Fehler in die Godot-Konsole).
````
