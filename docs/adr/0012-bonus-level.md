# ADR 0012 — Bonus-Level für Formen älterer Wörter

Status: **angenommen** · Datum: 2026-10-01 · ersetzt ADR 0011 Punkt 3, ergänzt ADR 0009

## Kontext

Seit ADR 0011 trägt eine Form die Lektion, die sie lehrt, und diese Lektion holt das
Lexem mit allen seinen Aufgaben als Wiederholung in den Pool. In Lektion 11 sind das die
Perfekte aller Verben aus Lektion 1–10, samt ihrer Übersetzungen: gut dreimal so viele
Aufgaben wie eigene Wörter. Eine neue Lektion fühlt sich dann an wie eine alte. Im
Kleinen gilt das schon für Lektion 3 und die 1. Person.

Das wird nicht der einzige Fall bleiben. Immer wieder führt ein Buch etwas Neues ein, das
alte Vokabeln mitschleppt. Vorziehen lässt sich das nicht: In Lektion 5 gibt es noch kein
Perfekt. Weglassen soll man es auch nicht, denn das Ziel einer Unit sind 100 %, nicht die
Festungsstufe.

## Entscheidung

1. **Ein Bonus besteht aus Formen, die später gelehrt werden als ihr Wort.** Eine Form
   gehört in einen Bonus, wenn ihre Lektion (`unit`/`part` an der Form, ADR 0011 Punkt 1)
   später liegt als die ihres Lexems. Das gilt auch innerhalb einer Unit. Der Bonus
   gehört zu der Unit, in der die Form gelehrt wird. Eine Form ohne eigene Lektion landet
   nie in einem Bonus.
2. **Ein Bonus je Lernthema, nichts wird zusammengelegt.** Ein Lernthema ist die lehrende
   Lektion zusammen mit der Formart (`form_type`). Lehrt eine Lektion zwei Formarten,
   gibt es zwei Boni; wird eine Formart über zwei Lektionen verteilt gelehrt, ebenfalls.
   Der Bonus wird aus den Daten abgeleitet, nicht gespeichert und nicht von Hand gepflegt.
   Heute ergibt das zwei Boni in Latein: die 1. Person aus Lektion 3 (Abschnitt 1, 20
   Formen) und das Perfekt aus Lektion 11 (Abschnitt 2, 68 Formen, auch die der Verben
   aus Lektion 7–10). Englisch und Französisch tragen keine Lektion an ihren Formen und
   haben keinen Bonus.
3. **Die lehrende Lektion holt keine Wiederholung mehr** (ersetzt ADR 0011 Punkt 3).
   `lexemes_for_run` bringt nur die eigenen Wörter der Lektion. Lektion 11 übt das
   Perfekt an den eigenen Verben, die älteren Verben üben es im Bonus. ADR 0011 Punkt 2
   bleibt: Eine Form gilt ab ihrer Lektion als eingeführt.
4. **Ein Bonus-Lauf fragt nur die Formaufgaben des Bonus ab**, nicht die Übersetzungen.
   Der Lauf „Gesamt“ einer Unit und jeder Lauf, dessen Scope die ganze Unit umfasst,
   spielen ihre Boni mit. Auf der Gebietskarte lassen sich Teile und Boni mehrfach
   wählen, „Gesamt“ und Boss nicht. Ein Lauf über einzelne Teile bringt keine
   Bonus-Formen mit. Eingeführt (ADR 0011 Punkt 2, Reveal) sind sie dort trotzdem; als
   Aufgabe kommen sie nur, wo ihr Bonus mitspielt (`ContentRegistry.form_task_in_scope`).
   Im Bonus-Lauf gilt als eingeführt, was bis zu seiner Lektion gelehrt ist.
5. **Ein Bonus zählt nicht zur Festung.** Die Festungsstufe gilt immer für die Unit, auch
   im Bonus-Lauf, und misst die Wörter ohne Bonus. Ergänzt ADR 0009 Punkt 1 und ADR 0011
   Punkt 4: Eine Bonus-Form gehört bei keinem Verb zur Meisterung des Wortes, auch bei
   einem unregelmäßigen nicht.
6. **Jeder Bonus hat eine eigene Zählung:** gemeisterte von allen Formaufgaben des
   Bonus, gerechnet an einer Stelle aus `PlayerProgress`, ohne eigenen Speicher.
7. **Karte:**
   - Ring von Unit und „Gesamt“: der Anteil gemeisterter Wörter ohne Bonus, wie bisher.
   - Jeder Bonus bekommt einen eigenen Ort auf der Gebietskarte, sein Ring zeigt nur seine
     Aufgaben.
   - Der Unit-Ort zeigt je Bonus einen Stern (`node["bonus"]`). Er ist immer zu sehen, grau,
     und leuchtet golden, wenn der Bonus gemeistert ist.
   - `map.json` legt je Bonus nur den Punkt und einen Titel fest, der beim Hovern sagt,
     was der Bonus enthält (etwa „Perfekt der Verben aus L1–L10“). Ein Test
     (`tests/map_screens_test.gd`) meldet einen abgeleiteten Bonus ohne Punkt und einen
     Punkt ohne Bonus. Sonst zählte ein Bonus mit, der sich nirgends spielen lässt. Ohne
     Punkt heißt der Bonus „Bonus · <Lektion>“, und die Karte legt ihn selbst aus.
8. **Statistik:** Unter jeder Unit steht je Bonus eine eigene Zeile mit gemeisterten von
   allen Aufgaben. Die Wortzählung der Unit bleibt davon unberührt.

## Folgen

- Lektion 3 und Lektion 11 sind wieder so groß wie ihre eigenen Wörter.
- Unregelmäßige Verben werden für die Festung leichter: In Abschnitt 2 brauchen 6 Verben
  aus Lektion 7–10 ihr Perfekt nicht mehr, in Abschnitt 1 brauchen 2 Verben aus Lektion
  1–2 ihre 1. Person nicht mehr. Bewusst so: Wer 100 % will, braucht den Bonus trotzdem;
  darauf sollen später Achievements aufbauen.
- Ein Spielstand kann nach der Umstellung eine höhere Festungsstufe zeigen. Das ist
  harmlos, weil nichts gespeichert ist, sondern gerechnet wird.
- Eine neue Formart mit eigener Lektion ergibt von selbst einen Bonus. Damit er spielbar
  ist, braucht er einen Punkt in `map.json`, den der Test einfordert.
- Bekommt Latein Sätze und einen Boss, muss die Satzerzeugung festlegen, ob sie
  Bonus-Formen verwendet. Wenn ja, wird der Bonus für den Boss faktisch Pflicht.

## Nicht gebaut

- Achievements für 100 % einer Unit samt Boni.
- Boss und Sätze für Latein.
