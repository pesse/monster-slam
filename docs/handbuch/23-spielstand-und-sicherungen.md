# 23. Spielstand und Sicherungen

Ein Spielstand ist viel Arbeit: jedes Wort, jedes Level, jedes Stück Gold. Das Spiel
passt deshalb dreifach darauf auf.

## Wann gespeichert wird

Gespeichert wird **nach jeder Welle**, nicht mittendrin. Ebenso nach einer geöffneten
Schatzkiste, nach einem Bosskampf und wenn du im Menü etwas änderst, etwa eine Fähigkeit
lernst. Wird eine Welle abgebrochen, das Fenster geschlossen oder stürzt der Rechner ab,
zählt die angefangene Welle nicht. Alles davor bleibt.

## Sicherungen

Nach jedem Speichern legt das Spiel eine **Sicherung** des ganzen Profils an. Es hebt die
drei neuesten auf, dazu je eine für jeden der letzten sieben Tage und je eine für jede
der letzten acht Wochen.

Jede Datei des Spielstands trägt eine **Prüfsumme**. Daran erkennt das Spiel beim Start,
ob eine Datei beschädigt ist, etwa nach einem Stromausfall. Dann holt es den Spielstand
aus der neuesten heilen Sicherung zurück und sagt Bescheid. Was nach dieser Sicherung
gespielt wurde, fehlt dann. Die beschädigten Dateien werden nicht gelöscht, sondern im
Ordner `quarantine` aufgehoben.

Gibt es keine Sicherung, speichert das Spiel für dieses Profil erst einmal nicht. So
überschreibt es nichts, was sich vielleicht noch retten lässt. Es fragt, ob es mit leerem
Stand für die beschädigten Teile weitergehen soll. „Noch nicht“ lässt alles, wie es ist.

Würde beim Speichern ein Wert sinken, der nur wachsen kann (Erfahrung, verdientes Gold,
gelernte Wörter, Boss-Siege), speichert das Spiel nicht und meldet sich. Das passiert beim
normalen Spielen nie; es ist eine Sperre gegen Fehler.

## Sichern und Laden als Datei

Die Sicherungen liegen auf demselben Rechner wie der Spielstand. Für einen neuen Rechner
oder zur Vorsicht gibt es in den Einstellungen im Reiter „Profil“ den Abschnitt
„Spielstand“:

- **„Sichern…“** legt den Spielstand dieses Profils als Datei ab, zum Beispiel auf einem
  USB-Stick.
- **„Laden…“** spielt so eine Datei in das Profil ein, das gerade spielt. Vorher zeigt das
  Spiel, was in der Datei steht (Name, Level, Gold, Datum), und fragt nach. Der bisherige
  Stand bleibt in den Sicherungen. Ersetzt wird nur, was in der Datei steckt: eine Datei
  nur mit der Erfahrung lässt die gelernten Wörter, das Gold und alles andere, wie es ist.

Wo die Sicherungen liegen, steht in [Kapitel 19](19-daten.md).

---

← [21. Spieldaten für die Entwicklung](21-spieldaten.md) · [Inhalt](README.md)
