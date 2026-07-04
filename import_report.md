# Import-Report — `data/lexemes/en_klasse9.json`

**Stand: Phase 1 + Phase 2 abgeschlossen.** Lexeme, Verbformen, Relationen, Sätze und
Satz-Verknüpfungen liegen vor. Alle Dateien geladen + Godot-Headless-Start ohne
Registry-Fehler/Duplikat-Warnungen geprüft (`--headless --quit-after`); alle
Querverweise (Form→Lexem, Relation-Endpunkte inkl. Adjektiv-Regel, Satz↔Lexem)
maschinell validiert (0 Warnungen).

## Kennzahlen

| Metrik | Wert |
|---|---|
| Lexeme gesamt | **2007** |
| davon `core` (produktiv) | 1222 |
| davon `receptive` | 785 |
| Roh generiert (16 Themen-Batches) | 2206 |
| Beim Merge dedupliziert/verworfen | 199 |
| Unregelmäßige Verben (Tag `irregular`) | 105 |

Ziel „mind. 1500 Lexeme (ca. 900 core / 600 receptive)" ist übererfüllt; das Set ist
bewusst etwas größer angelegt, damit beim späteren Review gekürzt statt nachgeliefert
werden kann.

## Verteilung nach Wortart (`type`)

| type | Anzahl |
|---|---|
| noun | 1104 |
| verb | 354 |
| adjective | 217 |
| phrase | 192 |
| connector | 68 |
| adverb | 47 |
| expression | 25 |

## CEFR-Verteilung

| CEFR | Anzahl |
|---|---|
| A1 | 377 |
| A2 | 722 |
| B1 | 836 |
| B2 | 70 |
| C1 | 2 |

Kein A/B-Wort im Kern verstößt gegen die Regel „kein C1/C2 mit `core`" (0 Verstöße,
maschinell geprüft). Die 2 C1- und alle B2-Einträge sind `receptive`.

## Frequenzband-Verteilung

| frequency_band | Anzahl |
|---|---|
| core | 946 |
| common | 375 |
| high | 298 |
| mid | 271 |
| low | 108 |
| rare | 9 |

## Themenabdeckung (semantische Tags, Auszug)

Die 10 Themenrahmen der Vorgabe sind alle vertreten. Häufigste semantische Tags:
`time` (72), `school` (67), `technology` (60), `text_analysis` (60), `discussion` (57),
`internet` (56), `food` (53), `travel` (48), `environment` (47), `body` (44),
`wellbeing` (43), `home` (41), `sport` (41), `health` (40), `linking` (40),
`relationships` (39), `society` (39), `narrative` (39), `nature` (38), `family` (37),
`climate` (37), `communication` (36), `argument` (36), `sustainability` (35),
`work` (35), `countries` (31) …

Konvention eingehalten: `tags[0]` = Wortart, `tags[1]` = `core`|`receptive`, danach
1–3 semantische Themen-Tags; unregelmäßige Verben zusätzlich `irregular`.

## Deduplizierung

199 Einträge wurden beim Zusammenführen der 16 Batches verworfen. Regel: **erstes
Vorkommen gewinnt**, spätere Dubletten fallen weg. Kriterien:

- **Gleiche `id`** (gleiches englisches Lemma → gleicher Slug) über Themengrenzen —
  der Großteil (z. B. `lex.en.play`, `lex.en.protect`, `lex.en.appointment` tauchten in
  mehreren Themen auf).
- **Gleiches Lemma-Paar** (`lemma_en` + `lemma_de`) mit abweichender ID — z. B.
  `music` = „die Musik" (in Schule als `music_subject`, in Freizeit als `music`).
- **Ausschluss der 19 Basiswörter** aus `en_basics.json` / `en_confusables.json`
  (house, dog, cat, forest, key, run, go, eat, quick, slow, big, large, small,
  dangerous, safe, borrow, lend, say, tell) — nicht neu angelegt, um Duplikat-IDs in
  der `ContentRegistry` zu vermeiden.

**Bewusst erhaltene Homonyme** (gleiches `lemma_en`, verschiedene Bedeutung → eigene ID):
`report_news` / `report_abuse` (berichten vs. melden), `flood` / `flood_verb`
(Nomen vs. Verb), `draw` / `draw_tie` (zeichnen vs. Unentschieden), `music_subject`,
`history_subject`, `argument_quarrel` u. a.

## Bekannte Unsicherheiten & Review-Empfehlungen

1. **Nicht-Standard-Wortarten (offene Design-Frage).** 140 Einträge nutzen `type`
   außerhalb des dokumentierten Sets `noun|verb|adjective|phrase`:
   `connector` (68), `adverb` (47), `expression` (25). Laut Vorgabe erhalten diese
   **nur `translate`-Aufgaben** (keine opposite/synonym/conjugation) — das ist mit den
   bestehenden `task_definitions` (`allowed_types: ["*"]` bei translate) automatisch
   abgedeckt. **Zu entscheiden:** ob diese Typen so bleiben oder auf `phrase`
   normalisiert werden sollen (z. B. alle `connector`/`expression` → `phrase`).
   Betroffen v. a. Batch 13 (Redemittel) und 16 (Funktionswörter).

2. **`notes` gesetzt bei 131 Einträgen** — überwiegend BE/AE-Hinweise und
   Bedeutungsnuancen. Kein eigenes `review_status` am Lexem (das Schema kennt keins);
   `notes` dient hier als Review-Marker. Empfehlung: diese 131 Einträge in einem
   Durchgang gegenlesen.

3. **`core`/`receptive`-Quote (ca. 61 % core).** Etwas über der anvisierten
   ~60/40-Verteilung. Falls der produktive Kern kleiner sein soll, lassen sich
   receptive-lastige Themen (Textanalyse, Geschichte, Fachpolitik) leicht umtaggen —
   rein Tag-Änderung, keine Datenumstrukturierung.

4. **Adjektiv-Gegenteile für spätere `opposite`-Aufgaben** sind bewusst paarweise
   angelegt (happy/sad, cheap/expensive, clean/dirty, …), aber **noch nicht als
   Relationen** verknüpft — das ist Teil von Phase 2 (`lexeme_relations`).

---

# Phase 2 — Formen, Relationen, Sätze

## `data/lexeme_forms/en_klasse9.json`

**1770 Formen** für **alle 354 Verben** (je 5: base, 3sg_present, past_simple,
past_participle, present_participle). Rechtschreibregeln (e-Tilgung, y→ies,
Konsonantenverdopplung), unregelmäßige Formen (buy→bought, think→thought,
wake up→woke up/woken up) und Phrasal Verbs (nur erstes Wort gebeugt, Partikel behalten)
sind berücksichtigt. Britische Schreibung konsistent (travel→travelled/travelling).
Keine Kollision mit `en_verbs.json` (go/run/eat), da diese Basiswörter ausgeschlossen sind.
Alle `lexeme_id` maschinell gegen die Lexem-Liste geprüft.

## `data/lexeme_relations/en_klasse9.json`

**262 Relationen** (jede in beiden Richtungen):

| relation_type | Anzahl | Aufgabe |
|---|---|---|
| opposite | 132 | nur Adjektive (`def.opposite`) |
| synonym | 54 | nur Adjektive (`def.synonym`) |
| confused_with | 76 | alle Wortarten (`def.confusables`) |

- `opposite`/`synonym` wurden maschinell auf **Adjektiv↔Adjektiv** geprüft (Verstöße
  würden verworfen; es gab keine).
- **ID-Schema:** `rel.<from>.<to>`; trägt ein Paar zwei Relationstypen (z. B. `few/little`
  als `synonym` *und* `confused_with`), wird der zweite eindeutig als
  `rel.<from>.<to>.<relation_type>` benannt (verhindert Duplikat-IDs in der Registry).
- **32 Relationen (= 16 Paare) sind `review_status: draft`** (confidence < 0.8) — meist,
  weil die deutschen Glossen die Nuance für die `confusables`-Aufgabe noch nicht klar
  trennen. Review empfohlen für: `ill/sick`, `economics/economy`, `each/every`,
  `few/little`, `carry/wear`, `history_subject/story`, `right/true`,
  `reliable/responsible`, `busy/free`, `content/happy`, `different/various`,
  `committed/loyal`, `committed/motivated`, `ancient/historical`,
  `beautiful/picturesque`, `bilingual/multilingual`. Bei Verwechslungspaaren mit
  gleichem `lemma_de` sollte die `lemma_de` eines Partners nachgeschärft werden
  (die Aufgabe zeigt die deutsche Bedeutung + beide EN-Kandidaten).

## `data/sentences/en_klasse9.json`

**1522 Sätze** (`is_generated: true`, alle `review_status: draft`):

| difficulty | Anzahl | Zweck |
|---|---|---|
| 1 | 951 | einfacher Beispielsatz je core-Lexem |
| 2 | 322 | Beispielsatz / leichte freie Übersetzung |
| 3 | 139 | anspruchsvollere freie Übersetzung |
| 4 | 110 | komplexe freie Übersetzung |

- Je core-Lexem (1222) genau ein kurzer Satz (`sen.<lexem-slug>`, difficulty 1–2).
- + 300 anspruchsvollere Satzpaare (`sen.hga_/hgb_/hgc_…`, difficulty 2–4) mit
  variierter Grammatik (Relativsätze, if/unless, Passiv, although/because, present
  perfect, indirekte Rede, Vergleiche).
- **Hinweis:** Das Satz-/Boss-Feature ist im Spiel weiterhin **zurückgestellt** — die
  Daten sind fürs finale Schema vorbereitet, aber noch nicht spielbar.

## `data/sentence_lexemes/en_klasse9.json`

**1816 Satz↔Lexem-Verknüpfungen**; 1521 der 1522 Sätze haben ≥1 Verknüpfung
(ein anspruchsvoller Satz ohne passendes gelistetes Lexem blieb ohne Link). Alle
`sentence_id`/`lexeme_id` maschinell auf Existenz geprüft; ungültige Verweise würden
verworfen (es gab keine).

## Bekannte Unsicherheiten (Phase 2)

- Alle generierten Sätze sind `draft` und semantisch, aber nicht redaktionell
  gegengelesen — Empfehlung: Stichprobe pro Batch.
- Die 16 Draft-Relationspaare (s. o.) vor Aktivierung der `confusables`-Aufgaben prüfen.
- Einzelne `opposite`-Paare sind kontextabhängig (z. B. `hungry/full` = hungrig/satt) —
  im Schul-Kontext vertretbar, aber Review-würdig.
