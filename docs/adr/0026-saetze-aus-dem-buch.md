# ADR 0026 — Sätze aus dem Buch: die 3. Spalte als Übersetzungsaufgabe

Status: **angenommen** · Datum: 2026-10-16 · ergänzt ADR 0012 und 0013

## Kontext

Das Vokabelverzeichnis der Access-Bände hat drei Spalten. Die dritte trägt Beispielsätze,
mit „~“ für das Stichwort, oft gebeugt oder nur für einen Teil einer Wendung. Dazu kommen
Kästen, Gegenüberstellungen „English:/German:“ und Hinweise. Manche Lehrkräfte fragen genau
diese Sätze ab. Bisher kam von der dritten Spalte nichts ins Spiel. Die Sätze des Bosses
sind eigene Sätze zur Grammatik der Unit (ADR 0004), keine aus dem Buch.

Mit einer Lücke lässt sich die dritte Spalte nicht abbilden: Bei rund einem Drittel der
Sätze ergibt „~“ durch das Stichwort ersetzt einen falschen Satz, und viele Sätze haben
gar kein „~“.

## Entscheidung

1. **Ein Lexem trägt seine Buchsätze unter `examples`**:
   `[{ key, de, <sprache>, <sprache>_alt }]`.
   - `<sprache>` ist der Satz aus dem Buch, ausgeschrieben.
   - `<sprache>_alt` sind die anderen Fassungen, die gelten.
   - `de` ist die deutsche Aufgabe.
   - `key` ist je Lexem fest und Teil des Fortschritts-Keys `example:<lexem>:<key>`.

   Erzeugt wird nach einer nicht öffentlichen Generierungsvorgabe.
2. **Aufgabe `example` (`requires_example`)**:
   - Der deutsche Satz steht auf dem Schild, getippt wird der ganze Satz.
   - Bewertet wird wie jede Vokabel mit `AnswerEvaluator`: ein Treffer gegen die Liste,
     ohne Modell, ohne Nähe.
   - Jede Fassung enthält das Stichwort, ein anderes Wort dafür gilt nicht.
   - Kurz- und Langformen stehen als eigene Fassungen in den Daten.
3. **Ein Bonus je Unit, Thema `examples`, Teil 0**, abgeleitet aus den Daten wie ADR 0012:
   - Er zählt seine Aufgaben für sich und nicht zur Festung.
   - Er hat einen Punkt `bonus/0/examples` in `map.json`.
   - Anders als dort spielt ihn kein Scope von selbst mit, auch kein Buch-Scope und nicht
     der leere (`explicit` am Bonus): Ein Satz dauert ein Vielfaches einer Vokabel und
     würde jede normale Welle bremsen. Die Aufgaben kommen nur, wo der Bonus im Scope steht.
   - „Gesamt“ nimmt ihn über einen Schalter neben „Spielen“ dazu, an als Standard
     (`RunRequest.level_scope`). Der Schalter steht weder im Level noch im begonnenen Lauf
     (RunSave), Umschalten macht also keinen Lauf ungültig.
4. **Der Zauber „reveal_alts“ zeigt beim Buchsatz das Stichwort** („Wort: …“), nicht die
   Lösung. Nach der Welle zeigt die Auflösung den Buchsatz, ohne die übrigen Fassungen.
5. **Tippzeit.** Eine Antwort über `LONG_ANSWER_CHARS` Zeichen (kürzeste angenommene
   Fassung) bekommt mehr Zeit:
   - Ihr Monster wird im Verhältnis der Länge langsamer, höchstens bis `MIN_TYPING_PACE`.
   - Der nächste Spawn wartet die Tippzeit ab (`TYPING_CHARS_PER_SECOND`).

   Das ist kein zweites Maß der Schwierigkeit: Punkte und Erfahrung bleiben bei `t - c`.
   Es gilt für jede lange Antwort, nicht nur für Buchsätze.

## Folgen

- Die Aufgabendefinition steht im Pack `game`. Eine ältere App kennt `requires_example`
  nicht, würde aus jedem Lexem eine unauflösbare Aufgabe machen und bei jedem Spawn
  warnen. `game` und der Pack mit den Sätzen heben deshalb `min_app_version`.
- Was die dritte Spalte sonst trägt, bleibt draußen: Bildunterschriften, Hinweise zu
  Aussprache und Betonung, Verweise auf Französisch und Latein, Wortfamilien. Außerdem
  fehlen Kastensätze ohne passendes Lexem (Sammelnamen, „so do I“).
- Die Eingabezeile ist einzeilig und rollt bei langen Sätzen seitlich weiter.

## Nicht gebaut

- Ein Wort-Bonus für die neuen Wörter und Wendungen der dritten Spalte (ADR 0013).
- Wortfamilien als Relation mit eigener Aufgabe.
