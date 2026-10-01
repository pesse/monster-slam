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
   Lexem hat. Das gilt in allen Sprachen. Gesammelt wird das in
   `ContentRegistry.form_requirements()`, gerechnet in
   `PlayerProgress.mastered_lexemes_in` und `mastered_lexeme_in`. Es bleibt eine Regel
   an einer Stelle, und Festung, Statistik und Karte bauen auf ihr auf. In der Wortliste
   der Statistik zieht die schwächste Form den Prozentstand mit.
2. **Unregelmäßig heißt:**
   - Englisch: Past Simple oder Past Participle nicht nach der *-ed*-Regel.
   - Französisch: die Verben mit Konjugationsformen, denn nur unregelmäßige haben welche
     (ADR 0008).
   - Latein: vorläufig die Verben, deren Perfekt nicht auf *-āvī*/*-uī* endet. Welche
     lateinischen Verben zählen, ist noch offen.

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
5. **Packs mit dem Feld heben `min_app_version` auf 0.19.0** (Access 2–4, Latein; *À plus!*
   lag schon dort). Eine ältere App kennt das Feld nicht und zählte unregelmäßige Verben
   nach den Richtungen allein.

## Folgen

- Bestehende Spieler können Stufen verlieren, in Units mit vielen unregelmäßigen Verben
  auch einen Stern. Das ist gewollt: Die Anzeige sagt jetzt, was das Kind kann. Weil
  Stufe 4 früher kommt, trifft der Verlust vor allem die oberen Prozente.
- Die Feier „Wort gemeistert“ kommt bei einem unregelmäßigen Verb mit der letzten
  fehlenden Aufgabe, auch wenn das eine Form ist.
- Das letzte Viertel einer Unit hat ein eigenes Ziel (Sterne 4 und 5, goldener Ring),
  ohne dass schon gemeisterte Wörter noch einmal geübt werden müssen.
- Ein Verb, das nachträglich `irregular` bekommt oder neue Formen, verliert seine
  Meisterung, bis die neuen Aufgaben sitzen. Deshalb kommen Formen für unregelmäßige
  Verben möglichst gleich mit dem Wort.
