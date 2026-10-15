# 22. The Rambler

The Rambler ist ein Boss für ältere Spielerinnen und Spieler (ab Access 4): Hier geht
es nicht um Wörter oder Sätze, sondern um einen **ganzen Text**. Er ist ein aufgeblähter
Bücherwurm-Drache aus Papier, der in einem Turm aus Papierstapeln haust und Geschichten
endlos, abschweifend und falsch nacherzählt. Deine Aufgabe ist das Gegenteil: eine
**Summary** auf Englisch – kurz, sachlich, das Wichtige in eigenen Worten.

Du triffst ihn am Boss-Ort einer Unit auf der Gebietskarte: Markierst du den Boss, steht
neben „Spielen“ (das den Satzmeister startet) ein „📜“ für The Rambler. Im Expertenmodus
gibt es „📜 The Rambler“ in „Runde vorbereiten“ ([Kapitel 3](03-expertenmodus.md)). Beides
erscheint nur, wenn **zwei Dinge** stimmen: Es ist ein eigener API-Schlüssel eingetragen
(siehe unten), und zur Unit gibt es eine Schreibaufgabe. Fehlt eins davon, ist der Knopf
einfach nicht da. Ein Sieg zählt für die Medaille am Boss-Ort wie ein Sieg über den
Satzmeister. Es gibt **keinen Zeitdruck**.

## Der Kampf in Phasen

1. **Begegnung.** The Rambler stellt sich vor und sagt dir, was er hören will: Titel
   der Geschichte, wie viele Wörter, und die Regeln einer Summary.
2. **Lesen.** Die Geschichte steht groß in der Mitte. Lies sie in Ruhe; The Rambler
   murmelt währenddessen im Hintergrund.
3. **Schreiben.** Links steht die Geschichte schmal zum Nachlesen, in der Mitte dein
   Schreibfeld. Rechts zählt das Spiel beim Tippen die Wörter mit und zeigt, ob du im
   Zielbereich bist. Alles andere beurteilt The Rambler erst, wenn du abgibst. Mit
   „⚔ Abgeben“ oder Strg+Enter gibst du ab.
4. **Angriff.** Während dein Text bewertet wird, lädt der Angriff auf – das dauert ein paar
   Sekunden, manchmal eine halbe Minute. Danach kommt Kriterium für Kriterium: Ist es
   erfüllt, fällt einer seiner fünf Papierstapel ab, und er schrumpft. Sonst hält der
   Stapel.
5. **Überarbeiten.** Dein Text steht wieder da, die Stellen, die noch nicht stimmen, sind
   farbig. Links stehen die Hinweise dazu. Ein Klick auf eine Stelle springt im Text
   dorthin. Ändere, was du ändern willst, und gib erneut ab – das ist der nächste
   Angriff. Wie oft du überarbeitest, ist nicht begrenzt.

Fällt der letzte Stapel, ist The Rambler besiegt. **Ein gefallener Stapel kommt nicht
zurück**: Was einmal erfüllt war, bleibt erfüllt, auch wenn du danach weiterschreibst.

## Die fünf Stapel

| Stapel | fällt, wenn |
|---|---|
| Einleitung | der erste Satz Titel und Autor nennt |
| Inhalt | alle wichtigen Punkte der Geschichte vorkommen |
| Textsorte | der Text im Present Tense steht, ohne direkte Rede, ohne abgeschriebene Sätze und ohne deine Meinung |
| Sprache | keine schweren Fehler mehr im Text stehen |
| Länge | die Wortzahl im Zielbereich liegt |

**Bonus: Wortschatz.** Benutzt dein Text mindestens fünf verschiedene Wörter aus der
Unit, gibt es den Wortschatz-Bonus ✨. Rechts beim Schreiben zählt das Spiel mit, wie viele
es schon sind; gebeugte Formen zählen mit („fetches“ für „fetch“). Der Bonus zählt aber erst,
wenn auch der Stapel „Inhalt“ gefallen ist – eine Liste von Wörtern allein reicht nicht.
Für den Sieg brauchst du ihn nicht. Gezählt wird auf diesem Rechner, nicht vom Modell.

Die Hinweise nennen immer **die Regel**, nie die Lösung: „Eine Summary steht im Present
Tense“, nicht der verbesserte Satz. Verbessern sollst du selbst – The Rambler ist keine
Hausaufgabenmaschine.

## Wohin dein Text geht

Nur die Wortzahl und die Länge rechnet das Spiel selbst, auf diesem Rechner. Alles andere
– Titel und Autor im ersten Satz, die wichtigen Punkte, Present Tense, eigene Worte statt
Rede und Abgeschriebenem, keine Meinung, Sprachfehler – beurteilt ein großes Sprachmodell
von **Anthropic** im Internet.
Dafür geht bei jeder Abgabe dein Text zusammen mit der Geschichte und der Aufgabe an
Anthropic – **mit deinem eigenen API-Schlüssel**. Nicht mit: dein Profilname, deine
Spielernummer oder irgendetwas aus der Spur.

- Den Schlüssel trägt man unter „Inhalte“ im Abschnitt „Cloud-Bewertung (eigener Schlüssel)“ ein
  ([Kapitel 15](15-vokabel-packs.md)). Dabei muss man bestätigen, dass die Texte den
  Rechner verlassen; ohne diese Bestätigung wird der Schlüssel nicht gespeichert.
- Der Schlüssel wird verschlüsselt gespeichert. Lesen kann ihn nur dein Benutzerkonto auf
  diesem Rechner; eine kopierte Datei nützt niemandem.
- Jede Abgabe kostet den Inhaber des Schlüssels ein wenig Geld. Das Spiel schreibt den
  Verbrauch je Abgabe mit, aber nie den Text und nie den Schlüssel.
- Der Satzmeister ([Kapitel 20](20-bosskampf.md)) bleibt davon unberührt und läuft auf
  diesem Rechner – außer man schickt ihn mit einem eigenen Kreuz ebenfalls in die Cloud.

**Ohne Netz oder bei einem Fehler des Dienstes** gibt es kein Urteil. Dein Text bleibt
stehen, der Grund steht dabei, und die Abgabe zählt nicht – du kannst einfach noch einmal
abgeben. Nur wenn du den Kampf mit „← Zurück“ verlässt, ist der Text weg; davor fragt das
Spiel nach.

**Für Eltern und Lehrkräfte:** Das Modell irrt sich manchmal – es übersieht einen Fehler
oder hält einen Punkt für erfasst, der nur angedeutet ist. Jede Stelle, die es nennt, muss
aber wörtlich im Text des Kindes stehen; erfundene Fehler fallen so weg. The Rambler
bringt kein Gold und keine Erfahrung und ändert den Lernstand nicht.

---

← [21. Spieldaten für die Entwicklung](21-spieldaten.md) · [Inhalt](README.md) · [23. Spielstand und Sicherungen](23-spielstand-und-sicherungen.md) →
