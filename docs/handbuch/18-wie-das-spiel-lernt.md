# 18. Wie das Spiel lernt

*Für Spielerinnen und Spieler ebenso wie für Eltern und Lehrkräfte.*

Das Herz des Spiels: Es merkt sich für jede Aufgabe, wie sicher sie sitzt, und entscheidet
daraus, **wann** sie wiederkommt und **wann** sie als gemeistert gilt. Die Regel dahinter
ist alt und gut belegt: Wer ein Wort an mehreren Tagen abruft, behält es; wer es an einem
Nachmittag zehnmal tippt, hat es nach einer Woche oft wieder vergessen.

## Der Lernstand einer Aufgabe

Jede Aufgabe hat ihren eigenen **Lernstand** zwischen 0 und 100 %. „Hund → dog“ ist dabei
eine andere Aufgabe als „dog → Hund“, eine Verbform wieder eine andere.

- Ein Wort, das du noch nie hattest, startet je nach Schwierigkeit bei etwa 10 bis 50 %:
  häufige, leichte Wörter höher, seltene niedriger. Ein mittleres Wort startet bei 30 %.
- **Richtig beantwortet** steigt der Lernstand. Wie stark, hängt vom Abstand ab (nächster
  Abschnitt).
- **Entwischt dir das Monster**, halbiert sich der Lernstand. Eine falsche Eingabe allein
  zählt nicht, nur ein Monster, das bis zur Festung kommt.
- Ab **80 %** ist die Aufgabe **gemeistert**. Ein **Wort** ist gemeistert, wenn beide
  Richtungen gemeistert sind, ein unregelmäßiges Verb erst mit seinen Formen.

## Abstand zählt mehr als Menge

Eine richtige Antwort schließt einen Teil der **Lücke bis 100 %**. Wie groß dieser Teil
ist, hängt davon ab, wie lange die letzte Antwort auf dieselbe Aufgabe her ist:

| Abstand zur letzten Antwort | so viel der Lücke schließt ein Treffer |
|---|---|
| allererste Antwort | 40 % |
| unter 10 Minuten | 10 % |
| 30 Minuten | 17 % |
| 1 Stunde | 21 % |
| 3 Stunden | 27 % |
| 8 Stunden | 33 % |
| ab 1 Tag | 40 % |

*Rechenbeispiel:* Steht eine Aufgabe auf 60 %, fehlen 40 Punkte bis 100 %. Ein Treffer am
nächsten Tag schließt 40 % davon, also 16 Punkte: 60 → 76 %. Derselbe Treffer zehn Minuten
später schließt nur 10 %, also 4 Punkte: 60 → 64 %.

**Beispiele** — dasselbe mittlere Wort (Start 30 %), immer richtig beantwortet:

| Wer | Wann geübt | Lernstand nach jedem Treffer | gemeistert? |
|---|---|---|---|
| Lina | Mo, Di, Mi je einmal | 58 → 75 → **85 %** | ✅ am Mittwoch |
| Ben | Mo abends, Di früh, Mi | 58 → 73 → **84 %** | ✅ am Mittwoch |
| Tom | alles am Montag, alle 15 Minuten | 58 → 63 → 68 → 72 → 75 → 78 → **81 %** | ✅ nach 7 Treffern |
| Mia | ein leichtes Wort (Start 48 %), Mo und Di | 69 → **81 %** | ✅ am Dienstag |

Tom kommt auch ans Ziel, braucht aber mehr als doppelt so viele Treffer wie Lina, und sein
Wort sitzt trotzdem schlechter. Wer gleich hintereinander übt, wiederholt also nicht
umsonst, es zählt nur weniger.

Wie lange der volle Abstand ist, hängt am Plan: Ist ein gemeistertes Wort erst in sieben
Tagen wieder dran und kommt schon nach einem Tag, zählt der Treffer etwas weniger als die
vollen 40 %.

## Wann eine Aufgabe wiederkommt

Nach jeder Antwort steht fest, ab wann die Aufgabe wieder **fällig** ist. Gezählt wird ab
Mitternacht: Wer abends übt, hat das Wort am nächsten Tag schon wieder.

| Lernstand nach der Antwort | wieder fällig |
|---|---|
| Monster ist entwischt | nach 10 Minuten |
| unter 80 % | am nächsten Tag |
| 80 – 89 % (gemeistert) | nach 3 Tagen |
| 90 – 94 % | nach 7 Tagen |
| 95 – 97,4 % | nach 14 Tagen |
| 97,5 – 98,4 % | nach 30 Tagen |
| ab 98,5 % | nach 45 Tagen (länger nie) |

**Beispiel — Linas Wort geht weiter**, jedes Mal pünktlich und richtig:

| Wann | Lernstand | nächste Wiederholung |
|---|---|---|
| Mittwoch (gemeistert) | 85 % | 3 Tage später |
| Samstag | 91 % | 7 Tage später |
| eine Woche danach | 94 % | 7 Tage später |
| eine Woche danach | 96 % | 14 Tage später |
| zwei Wochen danach | 98 % | 30 Tage später |
| einen Monat danach | 99 % | 45 Tage später |

So ist ein Wort über ein Schuljahr immer wieder dabei, aber immer seltener. Länger als
45 Tage verschwindet keines.

**Beispiel — ein Fehler:** Linas Wort steht bei 85 %, dann entwischt ihr das Monster.

| Wann | was passiert | Lernstand |
|---|---|---|
| Montag 16:00 | Monster entwischt | 85 → 42 % (nicht mehr gemeistert) |
| Montag 16:20 | wieder dran, richtig | 51 % |
| Dienstag | richtig | 70 % |
| Mittwoch | richtig | 82 % — wieder gemeistert |

Eine zweite Feier gibt es dafür nicht ([Kapitel 5](05-kampf.md)), in der Lernkurve der Statistik bleibt
das Wort die ganze Zeit gezählt.

## Welches Wort als Nächstes kommt

Für jedes neue Monster sucht das Spiel eine Aufgabe aus. Zuerst kommen alle Wörter, die in
dieser Welle noch nicht dran waren; erst wenn alle durch sind, wiederholt sich eins. Unter
den übrigen wird **gelost**, aber nicht gleich: Jede Aufgabe hat ein **Gewicht**, und ein
doppeltes Gewicht heißt doppelt so oft zuerst dran.

Das Gewicht ist **Bedarf × Dringlichkeit**: Bedarf ist, was bis 100 % fehlt; Dringlichkeit,
wie weit die Wartezeit bis zur nächsten Wiederholung schon um ist (bei 1 ist sie gerade
fällig, mehr als 2 wird es nicht).

| Aufgabe | Gewicht | im Vergleich zu einem neuen Wort |
|---|---|---|
| neues Wort, noch nie gesehen | 1 | — |
| vor 20 Minuten entwischt (jetzt 42 %) | 1,2 | etwas öfter |
| unsicher (50 %), lange überfällig | 1 | gleich oft |
| unsicher (50 %), heute fällig | 0,5 | halb so oft |
| gemeistert (85 %), heute fällig | 0,15 | etwa ein Siebtel |
| sehr sicher (95 %), fällig | 0,05 | etwa ein Zwanzigstel |
| eben gerade beantwortet | fast 0 | so gut wie nie |

Dazu drei Regeln:

- **Gemeisterte Wörter kommen selten, aber nicht nie.** Auch mit 99 % bleibt ein kleines
  Gewicht, damit ein Wort ab und zu auftaucht.
- **Neue Wörter gehen nicht unter.** Gibt es in der Auswahl noch neue Wörter, tragen sie
  zusammen mindestens 30 % des Gewichts, so viele Wiederholungen auch anstehen. Etwa jedes
  dritte Monster bringt dann ein neues Wort.
- **Die andere Richtung wartet.** Kam gerade „Hund → dog“, gilt auch „dog → Hund“ als eben
  beantwortet — sonst wäre die Antwort geschenkt.

## Weiteres

- **Neue und schwere Wörter kommen langsam**, bekannte schneller. Der Zeitdruck soll
  das schnelle Abrufen von Bekanntem trainieren, nicht Neues unter Stress abfragen.
- **Tippfehler-Frust wird klein gehalten:** Artikel, „the“, „to“, Klammerteile und
  Groß-/Kleinschreibung müssen nicht exakt stimmen. Eine falsche Eingabe wird keinem Wort
  angerechnet.
- **Ein Wort zählt erst, wenn es in beide Richtungen sitzt**, ein unregelmäßiges Verb
  (*go – went – gone*, *recevoir*) erst mit seinen Formen. Die Balken im Reiter
  „Fortschritt“ sind deshalb die Zahl, nach der man vor einer Vokabelarbeit fragt.
- **Die Festung ist bei drei Vierteln fertig, der Ring erst bei allem.** Stufe 4 mit dem
  Wachkatapult gibt es ab 75 % (mit dem Schnellen Erbauer ab 70 %); der Ring um den Ort auf der Karte füllt sich bis 100 %,
  und erst dann leuchtet er.
- **Belohnung für Genauigkeit statt für Masse:** die Güte der Schatzkiste hängt nur davon
  ab, wie genau eine Welle war, nicht davon, wie lang sie war.
- **Eine Niederlage kostet den Lauf, nicht das Erspielte.** Gold, Erfahrung und
  Lernstand bleiben.
- Die Einstellung **„Grund-Geschwindigkeit“** ist der richtige Hebel, wenn ein Kind
  grundsätzlich zu wenig Zeit hat. Die Schwierigkeit ist dafür da, sich zu steigern.

---

← [17. Hinweise am Mauszeiger](17-hinweise.md) · [Inhalt](README.md) · [19. Wo die Daten liegen](19-daten.md) →
