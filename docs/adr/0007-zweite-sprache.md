# ADR 0007 — Eine zweite Fremdsprache: Latein

Status: **Entwurf** · Datum: 2026-09-28 · Issue: #31

## Kontext

Bücher sind seit ADR 0006 reine Daten: Buchauswahl, Karte, Festungsstufe und `RunRequest`
kennen nur `book` und `unit`. Dass die Fremdsprache Englisch ist, steckte trotzdem an drei
Stellen fest: in den Feldnamen `lemma_en`/`lemma_en_alt`, in den Richtungen
`de_to_en`/`en_to_de` und in der Meisterungsregel. Ein Lateinbuch soll gespielt werden
wie ein Access-Band — Bedeutung in beiden Richtungen und die Formen, die das Buch
mitlernen lässt —, zunächst ohne Bosskampf.

## Entscheidung

1. **Sprache als neues Feld, nichts umbenannt.** Lexem und task_definition tragen
   `language`; ohne Feld sind sie englisch. Die fremde Seite steht in `lemma_<language>`,
   gelesen nur über `Lexeme.foreign`/`foreign_alt` (`src/learning/lexeme.gd`).
2. **Richtungen tragen die Sprache** (`de_to_la`, `la_to_de`). Ein Wort ist gemeistert, wenn
   beide Richtungen EINER Sprache sitzen; die Sprache kommt aus der Richtung
   (`Lexeme.language_of_direction`), die Zählung bleibt ohne Katalog.
3. **Eine Definition gilt nur für Lexeme ihrer Sprache** — geprüft in
   `WaveGenerator._instances`, der einen Stelle für Wave-Pool und Statistik.
4. **Formen als eigene Aufgabenart `forms`** über `requires_form` und `lexeme_forms`
   (`la_genitive`, `la_gender`, `la_perfect`, `la_ppp`). Das Genus wird als Buchstabe
   hinterlegt; der Resolver nimmt auch das Wort dazu an. Im Reveal der Übersetzung stehen
   die Formen als Lexikonform.
5. **Makrons werden nie verlangt.** `AnswerEvaluator._normalize` faltet sie auf beiden
   Seiten; die Daten tragen sie wie das Buch.
6. **Gemeinsames Regal, ein Fach je Sprache.** Englisch steht oben, jede weitere Sprache
   in einem Fach darunter (`BookSelect.shelf_rows`); das Cover nennt die Sprache
   (`ContentRegistry.book_language`). Eine Sprachwahl je Profil gibt es nicht.

## Folgen

- Der `game`-Pack hebt `min_app_version` auf die Version mit Latein: eine ältere App kennt
  `language` an den Definitionen nicht und stellte die lateinischen Übersetzungen mit
  englischen Wörtern. Der Latein-Pack hebt seinen eigenen.
- Ein Buch ohne Sätze zeigt den Boss gesperrt (`AreaMap.has_boss_sentences`).
- Die Buch-Id muss über alle Sprachen eindeutig sein — Scope, `BossRecord` und
  `assets/maps/<book>/` sind nur nach ihr benannt.

## Nicht gebaut

- Boss und Sätze für Latein (`SentenceSelector`, `StageOnePrompts`, `GrammarRules` sind
  englisch).
- Deklinations- und Konjugationstabellen über die Stammformen hinaus.
- Eine Sprachwahl je Profil.
