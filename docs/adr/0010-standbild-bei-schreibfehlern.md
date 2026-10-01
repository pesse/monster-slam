# ADR 0010 — Standbild bei nachsichtig gewerteten Schreibfehlern

Status: **angenommen** · Datum: 2026-10-01

## Kontext

Fehlende Akzente, Bindestriche und Apostrophe zählen als Treffer (ADR 0008). Bisher
erschien die richtige Schreibweise dann als kleines Schild über dem Monster. Im Kampf sieht
das kaum jemand: der Blick ist schon beim nächsten Monster. Zu sehen ist nur, dass es
geklappt hat. So prägt sich *ecole* ein und nicht *l'école*.

## Entscheidung

1. **Ein nachsichtiger Treffer auf eine noch nicht gemeisterte Aufgabe hält das Spiel kurz
   an.** Das Monster explodiert und gibt XP wie sonst. Nach einem Vorlauf von 150 ms,
   während dem die Explosion noch läuft, steht das Spiel. Die Kamera fährt auf die Stelle
   des Monsters zu, und ein halbdurchsichtiger weißer Schleier legt sich über das Bild.
   Darauf steht groß die richtige Form. Danach fährt die Kamera zurück. Das dauert gut
   1,4 s (`SpellingFreeze`: 220 ms hin, 900 ms Stand, 250 ms zurück).
2. **Gezeigt wird nur die richtige Form.** Die Stellen, die gefehlt haben, sind rot und
   unterstrichen. Die getippte Form erscheint nicht, damit sich kein falsches Bild
   einprägt. Welche Stellen das sind, bestimmt `AnswerEvaluator.spelling_marks()`, eine
   Ausrichtung der beiden Schreibweisen:
   - Ein gefaltetes Zeichen, eine Ligatur (*œ* gegen getipptes *oe*) und ein fehlender
     oder als Leerzeichen getippter Bindestrich oder Apostroph sind markiert.
   - Ein ganz weggelassener Teil, der erlaubt war (Artikel, Platzhalter), ist es nicht.
3. **Über jedem Akzent steht klein sein französischer Name** („accent aigu", „cédille",
   „tréma" …), so wie er im Unterricht heißt. Derselbe Akzent zweimal kurz hintereinander
   bekommt einen Namen. Passen zwei Namen nicht nebeneinander, steht der linke eine Zeile
   höher — gelesen wird von oben nach unten und von links nach rechts. Bindestriche und
   Apostrophe bleiben ohne Namen.
4. **Keine Taste beendet das Standbild.** Es soll nichts kosten außer der kurzen Pause.
   Während es steht, getippte Antworten werden aufgehoben und danach ausgewertet, wie bei
   der Meisterungsfeier. Die Antwortzeit der Monster wird um die Pause verschoben.
5. **Hat der Spieler die Aufgabe schon gemeistert, gibt es kein Standbild**, nur das
   bisherige Schild über dem Monster. Wer *l'école* sicher kann und einmal schludert,
   muss nicht angehalten werden.
6. **Auch Bindestrich und Apostroph bekommen den vollen Zoom.** Es gibt keine Abstufung
   nach Art des Fehlers.
7. **Die Feier wartet.** Bringt derselbe Treffer eine Meisterung, kommt die Feier erst nach
   dem Standbild (`MasteryCelebration.hold()`/`release()`). Sonst stünde die Feier über
   einem Wort, das noch nicht richtig dasteht.

## Folgen

- Pausiert wird über die Baum-Pause, wie bei der Feier, nicht über `Engine.time_scale`.
  Das Standbild läuft auf `process_mode = ALWAYS`, seine Tweens ignorieren die Zeitskala.
- Die Kamerafahrt (`WaveRunner.spelling_zoom`) kennt beide Ansichten. Die Perspektive
  verengt das Sichtfeld und dreht zum Ziel, die Isometrie verkleinert die Ortho-Größe und
  schiebt die Kamera hin. Bei 0 steht die Kamera exakt wie vorher.
- Schrift, Farben und Akzentnamen sind im Kampf neu und deshalb in `FxWarmup`.
- Ein roter Apostroph ist klein. Er fällt durch die Unterstreichung auf, nicht durch die Farbe.
