# ADR 0018 — Meisterung mit Abstand: ein Lernstand, gewichtete Auswahl

Status: **angenommen** · Datum: 2026-10-06 · Issue #18

## Kontext

Spieler melden, dass Wort-Meisterung sehr lange dauert, und gemeisterte Wörter kommen
trotzdem gehäuft in einer Welle. Ursache waren zwei Lernstände nebeneinander:

- Die **Confidence** (Meisterung, `t − c`, XP, Punkte) stieg je Treffer um 25 % der Lücke zu
  1, egal wann. Fünf Treffer an einem Nachmittag meisterten eine Richtung, drei an drei Tagen
  nicht (0,30 → 0,71). Das ist das Gegenteil dessen, was Wiederholung mit Abstand will.
- Ein **SM-2-Plan** daneben bestimmte die Fälligkeit. Er rückte nur bei fälligen Antworten
  vor, wusste nichts von der Confidence und leitete seine Qualität aus der Standzeit des
  Monsters ab (#18). Ein an einem Nachmittag gemeistertes Wort hatte dort `reps = 1`, war
  morgen fällig und stand in der harten Reihenfolge fällig → neu → Rest **vor** jedem neuen
  Wort. Ein gemeistertes, nicht fälliges Wort dagegen kam praktisch nie.

## Entscheidung

1. **Ein Lernstand.** Die Confidence ist der einzige gespeicherte Wert; die Fälligkeit wird
   aus ihr und der letzten Antwort gerechnet (`SpacedRepetition.due_at`): nach einem Fehler
   in 10 Minuten, sonst je Confidence 1 (< 0,8), 3, 7, 14, 30, 45 Tage ab lokaler
   Mitternacht. 45 Tage sind der Deckel — Schulvokabular wird über ein Schuljahr geprüft.
   Der SM-2-Plan (`sr`) und `next_review_at` fallen beim Laden weg. Damit erledigt sich auch
   die Qualität aus der Standzeit; `response_time_ms` geht nicht mehr in den Lernstand ein.

2. **Der Zuwachs hängt am Abstand** (`SpacedRepetition.spacing_gain`): ein Treffer schließt
   10–40 % der Lücke zu 1, logarithmisch zwischen 10 Minuten und einem vollen Abstand (ein
   Tag oder das geplante Intervall, wenn länger). Die erste Antwort zählt voll. Gemessen wird
   je Aufgabe (Richtung), nicht je Wort. Drei Tage hintereinander: 0,30 → 0,58 → 0,75 → 0,85,
   gemeistert. In einer Sitzung braucht es neun Treffer — möglich, aber keine Abkürzung.
   Ein Fehler halbiert die Confidence wie bisher; ein Vergessen ohne Fehler gibt es nicht.

3. **Gewichtete Auswahl statt harter Stufen** (`WaveGenerator.ordered`): „in dieser Welle
   schon gezeigt" bleibt die oberste Stufe (Issue #24). Darunter wird ohne Zurücklegen nach
   Gewicht gezogen (Efraimidis–Spirakis): Bedarf `max(1 − c, 0,05)` × Dringlichkeit
   (verstrichener Anteil des Intervalls seit der letzten Antwort auf das **Grundwort**,
   gedeckelt bei 2); ein neues Wort wiegt 1, die neuen zusammen mindestens 30 % des
   Gesamtgewichts. Fällig/neu/Rest bleiben als Gruppen in der Spur, entscheiden aber nichts
   mehr allein. Das ist ein Auswahlgewicht, kein Schwierigkeitsmaß — `t − c` bleibt das eine.

4. **`SPELLING_FORM_PRIOR` steigt von 0,55 auf 0,6**, damit eine Form mit Schreibfalle in
   einer Sitzung weiter nach drei Treffern sitzt (ADR 0009, Nachtrag).

## Folgen

- Spieler, die über Tage üben, meistern deutlich schneller; Pauken an einem Nachmittag
  langsamer.
- Gemeisterte Wörter kommen selten (Gewicht etwa ein Fünftel bis ein Zehntel eines
  unsicheren), aber nicht nie. Ein Fehlwort liegt zwanzig Minuten später über einem neuen.
- Bestehende Confidence-Werte gelten weiter; die Fälligkeit von Altprofilen folgt sofort
  der neuen Kurve, ohne Klemmen.
- `SessionLog.FAST_ANSWER_MS` und die Reaktionszeit-Kennzahl (#10) hängen nicht mehr am
  Lernstand; ob die Standzeit dort taugt, bleibt bei #10.
- Die Werkbank `pool_lab` verstellt nur noch die Bezugszeit; eine Scheduler-Kopie gibt es
  nicht mehr.
