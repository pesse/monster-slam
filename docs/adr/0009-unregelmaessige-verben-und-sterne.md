# ADR 0009 — Unregelmäßige Verben, Festungsschwellen und Kartensterne

Status: **angenommen** · Datum: 2026-10-01

## Kontext

Ein Wort galt als gemeistert, wenn beide Übersetzungsrichtungen sitzen (Issue #8). Formen
blieben bewusst außen vor: sie hängen an Zusatzdaten, die nur ein Teil der Lexeme hat.
Mit Französisch (ADR 0008) kamen Konjugationsaufgaben, aber nur für unregelmäßige Verben,
und damit eine Frage: Wer *recevoir* übersetzen kann, aber *ils reçoivent* nicht, kann das
Verb nicht. Dasselbe gilt für *go/went/gone* oder *mittere/mīsī*. Bei einem regelmäßigen
Verb ergibt sich die Form aus der Regel, bei einem unregelmäßigen ist sie Teil des Wortes.

Wenn die Meisterung strenger wird, rückt die Festungsstufe 4 weiter weg. Vorher lag sie
bei 85 %, und dort hängt das Wachkatapult. Die Kartensterne waren die Festungsstufe:
vier Punkte, voll ab 85 %. Für das letzte Stück einer Unit gab es danach nichts mehr zu
sehen.

## Entscheidung

1. **Ein unregelmäßiges Verb ist erst mit seinen Formen gemeistert.** Das Lexem trägt
   `irregular: true`. Dann gehören zur Meisterung neben beiden Richtungen alle
   Formaufgaben, die es zu ihm gibt: Definitionen mit `requires_form`, deren Form das
   Lexem hat. Das gilt in allen Sprachen. *Nachtrag (ADR 0012): ausgenommen Formen, die das
   Buch später lehrt als das Wort — sie stehen in einem Bonus und zählen für sich.* Gesammelt wird das in
   `ContentRegistry.form_requirements()`, gerechnet in
   `PlayerProgress.mastered_lexemes_in` und `mastered_lexeme_in`. Es bleibt eine Regel
   an einer Stelle, und Festung, Statistik und Karte bauen auf ihr auf. In der Wortliste
   der Statistik zieht die schwächste Form den Prozentstand mit.
2. **Unregelmäßig heißt:**
   - Englisch: Past Simple oder Past Participle nicht nach der *-ed*-Regel.
   - Französisch: die Verben mit Konjugationsformen, denn nur unregelmäßige haben welche
     (ADR 0008).
   - Latein: die Verben, deren Perfekt nicht nach der Regel ihrer Konjugation gebildet
     ist (a: *-āvī*, e: *-uī*, i: *-īvī*): *-s-*-Perfekt, *-uī* bei konsonantischen Verben
     (*imposuī*), *petīvī*, dazu *esse* (*sum*). Nachtrag 2026-10-01; zuvor hieß es
     „nicht auf *-āvī*/*-uī*", was die i-Konjugation mitgezählt hätte.

   Gesetzt wird das Feld beim Erzeugen der Daten. Ein eigenes Feld statt des Thementags
   `irregular`, weil Tags die Achse des Themenfilters sind, nicht die der Regeln. Ein
   Test hält beides gleich: jedes Verb mit dem Tag trägt das Feld, und jedes Lexem mit
   dem Feld ist ein Verb mit Formaufgaben.
3. **Festungsschwellen linear von 10 bis 75 %: 10/32/53/75.** Stufe 4 und das
   Wachkatapult gibt es bei drei Vierteln, ohne Zusatzbedingung. Unregelmäßige Verben
   zählen dort wie jedes andere Wort.
4. **Die Kartensterne sind der Meisterungsstand, nicht die Stufe.** Es gibt fünf Sterne
   zu je 20 % gemeisterter Wörter (`MapCanvas.STAR_PERCENT`, `stars_for`). Gerechnet
   wird aus denselben `done`/`total` wie die Stufe, es gibt keinen neuen Zähler. Bei
   100 % wird der Ring um den Ort golden und breiter. Die Füllfarbe des Ortes zeigt
   weiter die Stufe.

   **Nachtrag 2026-10-01: Ring statt Sterne.** Die fünf Sterne sind entfallen. Der Ring
   um den Ort füllt sich stetig in Gold mit dem Anteil gemeisterter Wörter — jedes Wort
   bewegt ihn, statt nur jedes fünfte. Bei 100 % wird er massiv, pulsiert und sprüht
   Funken. Die Füllfarbe zeigt nicht mehr die Stufe, sondern grob denselben Anteil:
   dunkel, ab 25 % Bronze, ab 60 % Silber, bei 100 % Gold (`MapCanvas.FILL_PERCENT`).
   Die Festungsstufe steht damit nur noch an der Festung und oben im Kopf; einen Teil
   einer Unit hat sie ohnehin nicht. Die Aussage von Punkt 4 bleibt: Die Karte zeigt den
   Meisterungsstand, nicht die Stufe, aus denselben `done`/`total`. Sterne unter einem
   Ort stehen jetzt für Bonus-Level (`node["bonus"]`, Anteil je Bonus), golden erst,
   wenn der Bonus gemeistert ist.
5. **Packs mit dem Feld heben `min_app_version` auf 0.19.0** (Access 2–4, Latein; *À plus!*
   lag schon dort). Eine ältere App kennt das Feld nicht und zählte unregelmäßige Verben
   nach den Richtungen allein.
6. **Nachtrag 2026-10-01: Formen nach der Regel starten sicher.** Regelmäßige Verben
   behalten ihre Formaufgaben, aber eine Form nach der *-ed*-Regel startet mit Confidence
   0.65, also gemeistert nach zwei Treffern (`WaveGenerator.RULE_FORM_PRIOR`). Bei einer
   Schreibfalle (verdoppelter Konsonant, *y → ied*) liegt der Start bei 0.55, also drei
   Treffer (seit ADR 0018 0.6: der Zuwachs hängt am Abstand, drei Treffer in einer
   Sitzung brauchen den höheren Start). Ein Fehler halbiert die Confidence wie bei jeder anderen Aufgabe. Anlass war
   Access 4 Unit 1: 22 von 24 Verben sind regelmäßig, die Formaufgaben dort bestanden fast
   nur aus *-ed* und verdrängten *dug* und *stood up*. Ganz herausnehmen wollten wir sie
   nicht, denn ein-, zweimal soll man sie sehen. Erkannt wird die Regel an den Formen
   selbst (`rule_form_kind`), nicht über ein Feld. Eine Form, die zu keinem Muster passt,
   behält den Prior des Lexems. Nur Englisch, siehe `RULE_FORMS`.

## Folgen

- Bestehende Spieler können Stufen verlieren, in Units mit vielen unregelmäßigen Verben
  auch Fortschritt auf der Karte. Das ist gewollt: Die Anzeige sagt jetzt, was das Kind kann. Weil
  Stufe 4 früher kommt, trifft der Verlust vor allem die oberen Prozente.
- Die Feier „Wort gemeistert“ kommt bei einem unregelmäßigen Verb mit der letzten
  fehlenden Aufgabe, auch wenn das eine Form ist.
- Das letzte Viertel einer Unit hat ein eigenes Ziel (der Ring füllt sich bis 100 %),
  ohne dass schon gemeisterte Wörter noch einmal geübt werden müssen.
- Ein Verb, das nachträglich `irregular` bekommt oder neue Formen, verliert seine
  Meisterung, bis die neuen Aufgaben sitzen. Deshalb kommen Formen für unregelmäßige
  Verben möglichst gleich mit dem Wort.
