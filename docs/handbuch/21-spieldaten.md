# 21. Spieldaten für die Entwicklung

Monster Slam ist in der Testphase. Damit das Spiel besser wird, schickt es Spieldaten an
unseren eigenen Server in Deutschland. Beim ersten Start sagt ein Hinweis, dass das
passiert. Danach geht es ohne Nachfrage.

## Was gesendet wird

- **Nach jedem Lauf und jedem Bosskampf** der Spielstand des Profils: Sitzungen (wann, wie
  lange, wie viele Wellen und Antworten), Gold, Erfahrung, gelernte Fähigkeiten,
  Boss-Siege, Zauber im Vorrat und die eingestellte Schwierigkeit.
- **Der Lernstand je Wort**, als Kennung des Worts: wie oft gefragt, wie oft richtig, wie
  sicher es sitzt.
- **Der Spielverlauf**: wann welches Monster kam, ob die Antwort richtig war, wie lange sie
  gedauert hat und, bei einer falschen, wie weit sie von der Lösung entfernt war (zum
  Beispiel „ein Buchstabe falsch“).
- Dazu die Spielversion, das Betriebssystem und die installierten Vokabel-Packs.

## Was nie gesendet wird

- **Keine Namen.** Jedes Profil bekommt eine zufällige Nummer, und nur die geht mit. Der
  Profilname bleibt auf dem Rechner.
- **Nichts, was ein Kind selbst tippt**: keine Antworten, keine Sätze aus dem Bosskampf,
  keine Kommentare beim Melden, keine Namen von Testlisten.
- Profile, deren Name mit `zz-` beginnt, sendet das Spiel nie.

## Wenn das Internet fehlt

Dann wird nichts gesendet, und das Spiel merkt davon nichts. Beim nächsten Lauf mit
Internet geht der aktuelle Stand mit. Was im Spielverlauf noch fehlte, kommt dann nach.

Schaltet man in den Einstellungen das Protokoll aus (Reiter „Protokoll“), geht auch kein
Spielverlauf mehr mit. Der Spielstand wird weiter gesendet.

---

← [20. Der Bosskampf](20-bosskampf.md) · [Inhalt](README.md)
