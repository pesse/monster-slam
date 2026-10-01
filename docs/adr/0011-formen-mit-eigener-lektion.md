# ADR 0011 — Formen mit eigener Lektion

Status: **angenommen** · Datum: 2026-10-01

## Kontext

Eine Form hing bisher an ihrem Lexem und galt damit in dessen Lektion. Das Lateinbuch
lehrt aber nicht alles mit der Vokabel. Die 1. Person Singular steht erst ab Lektion 3
neben den Verben, das Perfekt erst ab Lektion 11. Mit Lektion 11 schickt das Buch eine
Tabelle in der Begleitgrammatik, in der die Perfekte aller Verben aus Lektion 1–10 stehen.
Ohne eigene Lektion an der Form käme das Perfekt von *clāmāre* schon im ersten Kampf
dran, und in Lektion 11 gar nicht. Ein zweites Lexem *clāmāre* in Lektion 11 wäre eine
Dublette mit zwei Fortschrittsständen.

## Entscheidung

1. **Eine Form trägt optional `unit` und `part`:** die Lektion, in der das Buch sie lehrt.
   Ohne Feld gilt wie bisher die Lektion des Lexems.
2. **Eine Form gilt ab ihrer Lektion als eingeführt** (`ContentRegistry.form_in_scope`),
   in ihr und in jeder späteren, wie im Buch, das ab Lektion 3 bzw. 11 jede Vokabel mit
   diesen Stammformen führt. Das gilt für die Aufgabe und für die Lexikonform im Reveal
   (`TaskResolver.scope`, gesetzt vom `WaveGenerator`). In Lektion 1 gibt es also weder
   Perfekt noch 1. Person, in Lektion 11 beides. Eine Unit zählt bis zu ihrem Ende, das
   Buch alles.
3. **Nur die lehrende Lektion holt das Lexem als Wiederholung in den Pool**
   (`ContentRegistry.form_taught_in`, `lexemes_for_run`), mit allen seinen Aufgaben
   dort, auch den
   Übersetzungen. Gemeisterte, nicht fällige Aufgaben stehen in der Auswahl hinten.
   Wie stark die Wiederholung die neuen Wörter verdrängt, hängt an der Auswahlreihenfolge
   (#18).
4. **Gezählt wird das Wort weiter in seiner eigenen Unit.** Festung, Karte, Statistik und
   Sätze nehmen `lexemes_scoped`, nicht `lexemes_for_run`. Bei einem unregelmäßigen Verb
   zählt eine Form aus einer anderen Unit nicht zur Meisterung
   (`_index_form_requirements`), sonst ließe sich Unit 1 nur in Unit 2 meistern.
5. **Neue Form `la_present_1sg`** (1. Person Singular Präsens), im Reveal vor dem
   Genitiv bzw. Perfekt: „clāmō · Perf. clāmāvī".

## Folgen

- Der Latein-Pack hebt `min_app_version`: eine ältere App kennt `unit` an Formen nicht
  und fragte das Perfekt schon in Lektion 1 ab.
- In der Wiederholungslektion kommen alle bis dahin eingeführten Formen dran: Lektion 11
  fragt bei einem Verb aus Lektion 1 Perfekt und 1. Person, das Reveal zeigt beide.
- Spätere Lektionen holen die Wiederholung nicht erneut; ihre eigenen Verben bringen die
  Formen ohnehin mit.
- Lektion 11 hat damit gut dreimal so viele Aufgaben wie eigene Wörter.

## Nicht gebaut

- Perfekte, die nicht auf *-v-*, *-u-* oder *-s-* gebildet werden. Das Buch führt sie
  später ein; dann bekommen sie die Lektion, die sie lehrt.
