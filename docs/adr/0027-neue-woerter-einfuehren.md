# ADR 0027 — Neue Wörter einführen: Lösung auf dem Schild, Standbild beim Durchlass

Status: **angenommen** · Datum: 2026-10-16

## Kontext

Die erste Runde einer neuen Unit frustriert: Fast jede Aufgabe ist unbekannt, aber jede
kommt als Abrufaufgabe. Das Kind kann nur raten, die Monster laufen durch, und die Lösung
steht erst nach der Welle in der Auflösung, wenn der Moment vorbei ist. Die Vision
verlangt dagegen, neue Inhalte ohne starken Druck einzuführen.

## Entscheidung

1. **Lösung auf dem Schild.** Eine Aufgabe ohne Lernstand trägt das Abzeichen „neu“ an
   der Ecke des Schilds und unter dem Wort die Lösung (`WaveGenerator.needs_help`). Eine Übersetzung nur, wenn auch die
   Gegenrichtung nie dran war: wer eine Richtung kennt, kennt beide Seiten. Eine Form
   (`requires_form`, etwa Past Participle oder Genitiv) nie: sie folgt meist aus dem Wort,
   und sie zählt nicht als Einführung.
2. **Abtippen ist kein Abruf.** Was mit sichtbarer Lösung getippt wird, kommt nicht in den
   Lernstand und bringt keine Plakette; Punkte und Erfahrung wie bei einer gemeisterten
   Aufgabe. Das Tempo bleibt das der neuen Aufgabe (Zeit zum Lesen), `t − c` das einzige Maß.
3. **Erster Abruf kurz danach.** `RETEST_AFTER` Spawns nach dem Abtippen kommt dieselbe
   Aufgabe ohne Lösung und geht jeder anderen Wahl vor, auch über die Wellengrenze. Sie ist
   die erste echte Antwort und zählt wie jede andere. Ohne sie bliebe die Aufgabe ohne
   Lernstand und zeigte die Lösung beim nächsten Lauf wieder.
4. **Höchstens `INTRODUCTIONS_PER_WAVE` Einführungen je Welle**, aber nur, solange der Pool
   in dieser Welle noch ungezeigte Aufgaben ohne Lösung hat; dann kommen erst die, danach
   wieder neue. Hat eine Unit nur neue Wörter, greift die Grenze nicht. Wörter aus anderen
   Units werden nie zum Auffüllen geholt: das Level spielt seine Unit.
5. **Standbild beim Durchlass.** Trifft ein Monster die Festung, steht das Spiel wie bei
   einem Schreibfehler (ADR 0010): klein die Aufgabe, groß die erste Lösung, ohne
   Markierung. Die Auflösung nach der Welle zeigt sie noch einmal. Kein Standbild beim
   Vorspulen und nicht, wenn die Festung dabei fällt.
6. **Ein Durchlass halbiert weiter, auch vor dem ersten Treffer.** Ein sanfterer Faktor für
   nie richtig beantwortete Aufgaben ändert die Zeit bis zur Meisterung kaum (drei Tage bei
   jedem Start zwischen 7 und 44 %), und ein kleineres `c` macht das nächste Monster
   langsamer und wertvoller. Spürbar ist der Durchlass selbst; den fangen 1 und 5 ab.
7. **Kein neuer Zustand.** Was im Lauf eingeführt ist, hält `Introductions` nur im
   Speicher; „neu“ ist abgeleitet (kein Eintrag im Lernstand).

## Folgen

- Spur: `help` an `spawn` und `answer` (auch im Statistik-Kanal), `retest` im Auswahlgrund.
- Nach Rasten oder Abbruch vor der Wiederholung steht die Lösung beim nächsten Mal wieder da.
- Eine Testliste (TestPlaylist) behält ihre Reihenfolge; eine fällige Wiederholung geht
  ihr trotzdem vor.
- Jeder Durchlass hält das Spiel gut 1,5 s an. Wellen mit vielen Durchlässen werden länger.
