# Projektvision

Entwickle ein Offline-Singleplayer-Lernspiel in einer isometrischen Fantasy-Welt.
Der Spieler verteidigt seine Festung gegen Monsterhorden, indem er deutsche und
englische Sprachaufgaben löst. Der Fokus liegt auf einem motivierenden Gameplay,
das evidenzbasiertes Lernen unterstützt.

## Kern-Gameplay

- Normale Gegner tragen einzelne Vokabeln.
- Der Spieler gibt die Übersetzung per Tastatur ein.
- Richtige Antworten besiegen das Monster.
- Unterschiedliche Monstertypen bewegen sich unterschiedlich schnell und erzeugen variablen Zeitdruck.
- Zeitdruck dient ausschließlich dazu, bekannte Vokabeln schnell abzurufen (Recall).

## Bosskämpfe

Bossgegner verwenden vollständige Sätze statt einzelner Wörter.

- Kein oder nur minimaler Zeitdruck.
- Der Spieler übersetzt den gesamten Satz.
- Die Qualität der Übersetzung bestimmt den verursachten Schaden.
- Ein LLM kann alternative Formulierungen akzeptieren und semantisch bewerten, anstatt nur exakte Übereinstimmungen zu prüfen.
- Nach jeder Antwort erhält der Spieler kurzes, konstruktives Feedback.

## Lernprinzipien

- Neue Inhalte werden ohne starken Zeitdruck eingeführt.
- Bereits bekannte Vokabeln erscheinen später in schnelleren Wellen.
- Fehlerhafte Wörter und Sätze werden regelmäßig wiederholt (Spaced Repetition).
- Hilfen unterstützen das Lernen, ohne die Lösung vollständig vorzugeben.

## Fähigkeiten

Fähigkeiten erleichtern das Lernen, ersetzen es aber nicht. Beispiele:

- Ersten Buchstaben anzeigen
- Zeitform oder Grammatikhinweis anzeigen
- Ein schwieriges Wort hervorheben
- Monster kurz verlangsamen oder einfrieren
- Einen Satz nach einer falschen Antwort erneut versuchen

## Technische Ziele

- Offline-first
- Godot 4.7 als Engine (Vision nannte ursprünglich 4.6; auf die aktuelle Version angehoben)
- Datengetriebene Inhalte (JSON/SQLite)
- Modulare Architektur
- KI-Agent (Claude Code) soll eigenständig neue Monster, Fähigkeiten, Vokabelpakete
  und Spielmechaniken erweitern können, ohne bestehende Systeme anzupassen.
