# ADR 0008 — Französisch (À plus!)

Status: **angenommen** · Datum: 2026-09-30

## Kontext

Seit ADR 0007 ist die Fremdsprache ein Feld (`language`), und ein Buch einer neuen Sprache
braucht keine neue Architektur. Französisch bringt aber etwas mit, das weder Englisch
noch Latein kennt: Die Schreibweise ist Lernstoff, lässt sich aber auf der deutschen
Tastatur kaum tippen. é, è und ê gehen über Tottasten, ç, œ und ë gar nicht. Dazu tragen
Bindestrich und Apostroph Wörter (*est-ce que*, *aujourd'hui*, *l'école*), und
der Artikel trägt das Genus, das im Französischen gelernt werden muss.

Gespielt wird am Lehrbuch *À plus!* entlang, zunächst ohne Bosskampf.

## Entscheidung

1. **Schreibweise wird nachgesehen und gezeigt.** Akzente, Cédille und Trema (à â é è ê ë
   î ï ô û ù ÿ ç, dazu œ→oe, æ→ae) werden in einem zweiten, nachsichtigen Vergleich
   gefaltet. Bindestrich und Apostroph dürfen als Leerzeichen getippt werden oder
   ganz fehlen, ebenso das Komma (nachgetragen, in jeder Sprache: „yes please“).
   Auslassungspunkte („…“, „...“, „..“) fallen schon in der Normalisierung weg — sie
   markieren eine Lücke, keinen Bestandteil, und Weglassen ist vollständig. Eine so getroffene Antwort gilt voll, zählt voll für den
   Lernstand, und die richtige Schreibweise wird sofort über dem Monster
   eingeblendet (dasselbe Schild wie bei einer unvollständigen Antwort; seit ADR 0010
   statt des Schilds ein kurzes Standbild).
   Umlaute und ß werden **nicht** gefaltet: Sie sind die deutsche Seite.
2. **Exakt vor nachsichtig.** `AnswerEvaluator.evaluate(…, lenient)` vergleicht zuerst
   exakt und nur bei Bedarf gefaltet und meldet das im neuen Feld `exact`. Der Kampf
   wählt unter den Monstern: exakt und vollständig, dann nachsichtig und vollständig,
   dann unvollständig. Bei Paaren, die sich nur im Akzent unterscheiden (*ou/où*,
   *a/à*, *sur/sûr*), trifft die exakte Eingabe das richtige Monster.
3. **Stille und gezeigte Faltung sind zwei Dinge.** Die Makrons des Lateinischen bleiben
   in `_normalize` und werden weiterhin still gefaltet (ADR 0007). Die neue Faltung
   gibt es nur im nachsichtigen Vergleich, und nur der Wellenkampf fragt danach. Die
   Satzbewertung (ADR 0004) ruft `evaluate` ohne `lenient` und bleibt, wie sie ist.
4. **Der Artikel ist Pflicht.** `le`/`la`/`les`/`l'`/`un`/`une` stehen **nicht** unter den
   wegkürzbaren Anlauten. „maison" für „la maison" ist falsch, „le maison" auch.
   Das Genus steht über den Artikel im Lemma. Bei *l'* steht es **nicht** als Glosse in
   Klammern (`l'école (f.)`), denn jede Antwort ohne die Glosse wäre unvollständig. Es
   kommt als Form `fr_gender`, sobald das Buch es lernen lässt.
5. **Platzhalter des Französischen** (*qn*, *qc*, *qch*, *quelqu'un*, *quelque chose*)
   werden zum Wildcard wie *sb.*/*jn.*.
6. **Weibliche und männliche Formen werden bei der Generierung aufgelöst**, nicht in der
   Auswertung: Die Daten tragen ausgeschriebene Formen statt der Notation des Buchs
   (`ami(e)`, `petit, e`), siehe `docs/prompts/vocab_generation.md`.
7. **Formen am Buch entlang.** Neue `fr_*`-Formtypen kommen erst, wenn eine Unit sie
   lernen lässt, und nicht vorab als Konjugationstabelle. Konjugiert werden nur die
   unregelmäßigen Verben; regelmäßige (auch *-ir* wie *finir*, *-dre* wie *attendre*,
   *-er* mit Stammwechsel) bekommen keine Formen. Abgefragt wird das Präsens in allen sechs Personen (`fr_pres_1sg` … `fr_pres_3pl`)
   und Passé composé mit *je* (`fr_passe_compose`), als Aufgabe `conjugation`. Jede
   Form steht einmal mit Subjekt (die gezeigte, „ils reçoivent") und einmal ohne
   („reçoivent"), bei der 3. Person auch mit *elle/on* bzw. *elles*. Getippt reicht das
   Verb, gezeigt wird es mit Person. Reflexivpronomen gehören zur Form; bei *nous/vous*
   eines reflexiven Verbs gibt es nur die volle Form, weil „nous battons" allein wie die
   nicht-reflexive Form mit Subjekt aussähe. Mit *être* trägt das Passé composé beide
   Genera. Die Formen stammen aus der Grammatik, nicht aus dem Buch: Das Buch nennt nur
   für einen Teil der Verben die Konjugation und verweist sonst auf „wird wie … konjugiert".
8. **Jedes Buch nennt seine Ebenen selbst.** Intern bleiben es Unit und Teil, als Zahlen.
   Was dasteht, kommt aus `naming` in `assets/maps/<book>/map.json` (`BookNaming`):
   *À plus!* zeigt „Dossier 2 · Partie A" (Teile als Buchstaben), Latein „Abschnitt 2 ·
   Lektion 10" (Lektionen über das Buch durchgezählt, `parts_per_unit`), Access ohne
   Eintrag „Unit 2 · Teil 1". Dort steht auch der Titel des Buchs („À plus!"). Das gehört
   zur EXE wie die Karte, nicht in einen Pack. Überschriften über mehrere Bücher
   („Nach Unit") bleiben allgemein.
9. **Die Spur bekommt `exact`.** Eine Antwort, die nur nachsichtig traf, schreibt
   `"exact": false` und die richtige Schreibweise nach `canonical`. `full` bleibt, wie
   es war.

## Folgen

- Der nachsichtige Vergleich gilt im Wellenkampf für jede Sprache: „cafe" trifft „café"
  und „well known" trifft „well-known", jeweils mit eingeblendeter Schreibweise.
  Früher war beides falsch.
- `tests/lexeme_data_test.gd` prüft weiter mit den exakten Varianten. *ou/où* bleiben
  damit unterscheidbar.
- Der Französisch-Pack hebt seinen `min_app_version` auf die App mit dieser Auswertung,
  denn eine ältere App würde „ecole" für „l'école" ablehnen. Der `game`-Pack braucht
  keine Anhebung, weil `language` an den Definitionen seit 0.13.0 bekannt ist.

## Nicht gebaut

- Boss und Sätze für Französisch.
- Eine Sprachwahl je Profil, Aussprache und Hören.
- Eine Bildschirmtastatur für Sonderzeichen (gespielt wird meist ohne Maus).
