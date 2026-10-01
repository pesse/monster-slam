# ADR 0010 — Standbild bei Schreibfehlern und unvollständigen Antworten

Status: **angenommen** · Datum: 2026-10-01

## Kontext

Fehlende Akzente, Bindestriche und Apostrophe zählen als Treffer (ADR 0008). Bisher
erschien die richtige Schreibweise dann als kleines Schild über dem Monster. Im Kampf sieht
das kaum jemand: der Blick ist schon beim nächsten Monster. Zu sehen ist nur, dass es
geklappt hat. So prägt sich *ecole* ein und nicht *l'école*.

Dasselbe gilt für eine unvollständige Antwort: wer „meinung zu" für *die Meinung (zu
etwas)* tippt, trifft und sieht die volle Form nur als Schild, das schon wegfliegt.

## Entscheidung

1. **Ein nachsichtiger oder unvollständiger Treffer hält das Spiel kurz an.** Das Monster explodiert und gibt XP wie sonst. Nach einem Vorlauf von 150 ms,
   während dem die Explosion noch läuft, steht das Spiel. Die Kamera fährt auf die Stelle
   des Monsters zu, und ein halbdurchsichtiger weißer Schleier legt sich über das Bild.
   Darauf steht groß die richtige Form. Danach fährt die Kamera zurück. Das dauert gut
   1,4 s (`SpellingFreeze`: 220 ms hin, 900 ms Stand, 250 ms zurück).
2. **Gezeigt wird nur die richtige Form.** Die getippte Form erscheint nicht, damit sich
   kein falsches Bild einprägt. Markiert wird, was nicht stimmte, unterstrichen und in
   zwei Farben. Beides bestimmt eine Ausrichtung der beiden Schreibweisen
   (`AnswerEvaluator._align`):
   - **Rot** (`spelling_marks()`, Theme-Typ `SpellingMark`): ein gefaltetes Zeichen, eine
     Ligatur (*œ* gegen getipptes *oe*) und ein fehlender oder als Leerzeichen getippter
     Bindestrich oder Apostroph.
   - **Blau** (`missing_marks()`, Theme-Typ `SpellingMissing`): ein weggelassener Teil,
     der die Antwort unvollständig machte — eine Klammergruppe samt Klammern (*(zu
     etwas)*) oder ein Platzhalter (*sb.*, *etwas*). Ein Bereich fehlt, wenn keinem
     seiner Zeichen etwas Getipptes gegenübersteht; „meinung zu" lässt also nur *etwas*
     blau.
   - **Nicht markiert** ist, was nicht zur Vollständigkeit zählt: ein weggelassener
     Artikel, *the* oder *to* vorn, Auslassungspunkte.
3. **Über jedem Akzent steht klein sein französischer Name** („accent aigu", „cédille",
   „tréma" …), so wie er im Unterricht heißt. Derselbe Akzent zweimal kurz hintereinander
   bekommt einen Namen. Passen zwei Namen nicht nebeneinander, steht der linke eine Zeile
   höher — gelesen wird von oben nach unten und von links nach rechts. Bindestriche und
   Apostrophe bleiben ohne Namen.
4. **Keine Taste beendet das Standbild.** Es soll nichts kosten außer der kurzen Pause.
   Während es steht, getippte Antworten werden aufgehoben und danach ausgewertet, wie bei
   der Meisterungsfeier. Die Antwortzeit der Monster wird um die Pause verschoben.
5. **Das Schild über dem Monster gibt es nicht mehr.** Jeder Treffer, der nicht exakt
   und vollständig war, bekommt das Standbild — auch bei einer schon gemeisterten
   Aufgabe. Eine erste Fassung ließ es dort beim Schild; zwei Arten, dieselbe Sache zu
   zeigen, sind eine zu viel, und wer schludert, soll die Form ruhig noch einmal sehen.
6. **Jede Art bekommt den vollen Zoom**, auch Bindestrich, Apostroph und eine fehlende
   Klammergruppe. Es gibt keine Abstufung nach Art des Fehlers.
7. **Die Feier wartet.** Bringt derselbe Treffer eine Meisterung, kommt die Feier erst nach
   dem Standbild (`MasteryCelebration.hold()`/`release()`). Sonst stünde die Feier über
   einem Wort, das noch nicht richtig dasteht.

## Folgen

- Pausiert wird über die Baum-Pause, wie bei der Feier, nicht über `Engine.time_scale`.
  Das Standbild läuft auf `process_mode = ALWAYS`, seine Tweens ignorieren die Zeitskala.
- Die Kamerafahrt (`WaveRunner.spelling_zoom`) kennt beide Ansichten. Die Perspektive
  verengt das Sichtfeld und dreht zum Ziel, die Isometrie verkleinert die Ortho-Größe und
  schiebt die Kamera hin. Bei 0 steht die Kamera exakt wie vorher.
- Schrift, beide Farben und Akzentnamen sind im Kampf neu und deshalb in `FxWarmup`
  (`SpellingFreeze.warm_up`); das Schild und sein Vorwärmen (`form_label`) sind weg.
- Ein roter Apostroph ist klein. Er fällt durch die Unterstreichung auf, nicht durch die Farbe.
