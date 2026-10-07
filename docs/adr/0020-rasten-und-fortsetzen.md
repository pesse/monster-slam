# ADR 0020 — Rasten und Fortsetzen eines Laufs

Status: **angenommen** · Datum: 2026-10-06

## Kontext

Ein Lauf ist alles vom Kampfstart bis zur gefallenen Festung oder bis „Zurück zum Menü“
auf Stufe 2 des Wellenabschlusses (`SessionLog`). Was dabei gewachsen ist, endet mit ihm:
die Wellennummer, der HP-Stand und die Bilanz „Dieser Lauf“. Erfahrung, Gold und
Lernstand gehören dem Profil und bleiben.

Wer Genesung und Bollwerk ausgebaut hat, kommt weit: ein besiegtes Monster heilt
mehrere HP, und die Rüstung wird jede Welle instand gesetzt. Ein Lauf hält damit sehr
lange. Wer aufhört, verliert seinen besten Lauf, also spielen manche weiter, als gut
ist. Aufhören darf nichts kosten.

Mitten in einer Welle steckt viel Zustand: Monster auf der Bahn, Spawn-Coroutinen, Pfeile
und Steine in der Luft, Zauber, Standbilder und Feiern. An der Wellengrenze ist davon
nichts mehr übrig. Ein Abbruch mit Escape zählt die angefangene Welle schon heute nicht.

## Entscheidung

1. **Gerastet wird nur an der Wellengrenze.** Auf Stufe 2 des Wellenabschlusses wird
   „⟵ Zurück zum Menü“ zu **„Rasten“** und schreibt immer einen Speicherstand, denn eine
   zweite Entscheidung muss dort niemand treffen. Mitten in der Welle gibt es keinen
   Speicherstand. Fällt die Festung, gibt es keinen, Stufe 2 bietet dann wie bisher nur
   den Rückweg an. Das gilt nur für Läufe von der Karte. Expertenmodus, Testvorbereitung
   und Bosskampf bleiben, wie sie sind (siehe „Bewusst nicht“).

2. **Ein Speicherplatz je Buch.** Ein Kind spielt Englisch und Latein nebeneinander. Mit
   nur einem Platz würde jeder Wechsel den begonnenen Lauf verwerfen. Alle Plätze eines
   Profils stehen in `user://progress/<profil>_runs.json` (Buch-Id → Speicherstand),
   geschrieben über eine temporäre Datei und Umbenennen. Je Buch und nicht je Unit: ein
   Platz je Unit ergäbe Dutzende halbe Läufe, die keiner wiederfindet. Ein neuer Lauf
   verwirft nur den Platz **seines** Buchs und fragt vorher nach, siehe Punkt 6
   (`RunSave`, `src/progression/run_save.gd`).

3. **Gespeichert wird der Ursprung, gerechnet wird der Rest.**

   | im Speicherstand | beim Fortsetzen gerechnet |
   |---|---|
   | das Level aus `RunRequest` (`MapLevel.combine`: Buch, Unit, die gewählten Orte `keys` und ihr `scope`), **fest** | welche Wörter und Aufgaben dieser Scope heute enthält, aus den installierten Inhalten |
   | die nächste Welle und die zuletzt gespielte Schwierigkeit (die Wahl auf Stufe 2 galt der Welle, die nicht mehr kommt) | Tempo und Schaden der Welle (`WaveGenerator.wave_damage_scale`) |
   | `fortress_health`, `fortress_armor` | `fortress_max_health`, `fortress_armor_max` und Heilung aus `SkillBook.bonuses()` und `FortressTier.health_bonus` wie bei jedem Laufstart |
   | `score`, `monsters_defeated`, `monsters_leaked`, `no_leak_streak`, `best_no_leak_streak`, `min_fortress_health` (`GameState.run_snapshot`) | Level, Erfahrung und Gold, die ohnehin dem Profil gehören |
   | `saved_at`, `run_started_at`, `app_version`, `format` | |

   Die Wörter der letzten Welle stehen nicht darin: dass an der Wellengrenze keins direkt
   wiederkommt, braucht nur die Testliste (`TestPlaylist`), und die rastet nicht.

   Fortgesetzt wird wie gestartet: `GameState.reset()`, `apply_skills()` mit den
   **aktuellen** Skills und der aktuellen Festungsstufe, danach HP und Rüstung aus dem
   Speicherstand, begrenzt auf das neue Maximum. Was zwischendurch gelernt wurde, wirkt
   sofort. Einen zweiten Zähler für das Maximum gibt es nicht (`GameState.restore_run`).
   `RunRequest.start_level(level, resume)` trägt den Stand in den Kampf, der ihn genau
   einmal nimmt (`take_resume`). Bisher galt „wird nicht gespeichert“ (Kopfkommentar in
   `run_request.gd`), das ändert sich mit diesem ADR.

   Der **Bereich** sitzt fest, der **Inhalt** nicht. Ein Lauf aus Unit 1 lässt sich nicht
   nach Unit 5 mitnehmen. Innerhalb seiner Unit darf er wachsen, aber nicht schrumpfen
   (Punkt 6). Ein Pack-Update, das in Unit 1 eine gemeldete Übersetzung
   korrigiert oder ein Wort ergänzt, kommt beim Fortsetzen aber an. Eine eingefrorene
   Liste von Lexem-IDs wäre eine zweite Wahrheit über die Unit neben dem Katalog und
   neben `FortressTier`, die über denselben Scope rechnet.

4. **Fortsetzen verbraucht den Speicherstand.** Er wird gelöscht, sobald die erste Welle
   des fortgesetzten Laufs beginnt, und erst an der nächsten Wellengrenze neu
   geschrieben. Eine schlecht laufende Welle lässt sich also nicht durch Neuladen
   ungeschehen machen. Lässt sich der Speicherstand nicht mehr spielen, etwa weil ein Pack
   fehlt, der Pool leer ist oder `app_version` zu alt ist, wird er mit einem kurzen
   Hinweis verworfen, nicht still.

5. **Escape mitten in der Welle fragt nach, sobald es etwas zu verlieren gibt.** Der
   Abbruch beendet den Lauf, und mit Rasten wiegt das schwerer. In einem Lauf von der
   Karte öffnet Escape ab der zweiten Welle (ein fortgesetzter Lauf steht immer dort)
   einen `ConfirmDialog` und pausiert das Spiel, auch Escape in der Pause: „Abbrechen beendet deinen Lauf (Welle 23). Die angefangene Welle zählt nicht,
   und der Lauf lässt sich nicht fortsetzen. Rasten kannst du nach dem Ende der Welle.“
   Gespielt wird meist ohne Maus. Deshalb heißt die Vorgabe **Weiterspielen**: Enter
   und ein zweites Escape schließen den Dialog. Abbrechen braucht den eigenen Knopf oder
   dessen Taste. In der ersten Welle eines frischen Laufs bricht Escape sofort ab wie
   bisher, dort geht nichts verloren, ebenso im Expertenmodus und in der
   Testvorbereitung. Die Regel „das erste Escape schließt nur das Eingabefeld“ bleibt
   davor.

6. **„Lauf fortsetzen“ stellt die Auswahl wieder her, „Spielen“ startet.** Hat ein Buch
   einen Speicherstand, zeigt die Buchkarte unten rechts „Lauf fortsetzen · Unit 4,
   Welle 23“ (im Kopf ist bei 1152 Pixel Breite kein Platz).
   Der Knopf öffnet die Gebietskarte der Unit, und dort sind die gespeicherten Orte
   (`keys`) markiert, wie es `AreaMap._initial_selection` nach einem Kampf schon tut. Die
   Gebietskarte selbst bekommt keinen eigenen Knopf: unten neben dem Schild ist bei
   1152 Pixel Breite kein Platz, und die markierten Orte mit „Fortsetzen“ sagen dasselbe.
   Gestartet wird erst mit „Spielen“:

   - **Auswahl enthält alle gespeicherten Orte:** „Spielen“ heißt „Fortsetzen“ und setzt
     den Lauf fort. Weitere Orte derselben Unit dürfen dazukommen, der Lauf wird
     **erweitert**: erst Teil 1, dann Teil 1 und 2, dann Gesamt. Das ist der Weg, den ein
     Kind durch eine Unit ohnehin geht, und ein langer Lauf soll ihn mitgehen, statt zu
     verfallen, sobald etwas Neues dazukommt. Gesamt zählt dabei als alle Teile der Unit.
     Der Hinweis am Knopf nennt, was neu dabei ist. Rastet der erweiterte Lauf, stehen die
     neuen Orte im Speicherstand und gehören ab da fest dazu (`RunSave.continues`,
     `RunSave.added`).

     Ausnutzen lässt sich das nicht: die Festungsstufe wertet ohnehin die ganze Unit
     (`FortressTier`), neue Wörter machen eine späte Welle schwerer, nicht leichter (`t - c`),
     und ein Vorlauf auf gemeisterten Wörtern bringt weder Erfahrung noch Gold.
   - **Ein gespeicherter Ort fehlt, oder die Auswahl liegt in einer anderen Unit des
     Buchs:** „Spielen“ fragt erst nach (`ConfirmDialog`): „Dies
     startet einen neuen Lauf. Dein begonnener Lauf (Unit 4, Welle 23) geht verloren.“
     Vorgabe ist **Zurück**, der neue Lauf braucht den eigenen Knopf. Erst dann wird der
     Platz verworfen.
   - **Ohne Speicherstand im Buch** startet „Spielen“ ohne Rückfrage, wie bisher.

   - **Der Boss** gehört zu keinem Lauf. Er startet ohne Rückfrage, setzt nichts fort und
     verwirft nichts, der begonnene Lauf bleibt liegen. Der Hinweis am Knopf sagt das.

   Wer mit derselben Auswahl neu anfangen will, verwirft den Lauf mit dem „✕“ neben
   „Fortsetzen“ (ebenfalls mit Rückfrage). Die Plätze anderer Bücher bleiben unberührt.
   Ein Speicherstand, der sich nicht mehr spielen lässt (Punkt 4), wird beim Öffnen seiner
   Unit verworfen, und die Karte sagt es (`ConfirmDialog.inform`).

7. **Sitzungen und Spur.** Rasten beendet die Sitzung im `SessionLog` wie bisher, mit dem
   zusätzlichen Feld `suspended: true`. Fortsetzen beginnt eine neue Sitzung mit
   `continues: <started_at des Laufs>`. Die Spurzeile `run_resume` trägt bei einem
   erweiterten Lauf `added` mit den neuen Orten. Die Felder kommen dazu, umbenannt wird nichts.
   „Heute“ zählt damit nur, was heute gespielt wurde, und die Statistik kann die Teile
   eines Laufs trotzdem zusammenführen. Für die Spur bekommt der EventBus
   `run_suspended` und `run_resumed`, `TraceLog` hängt sich nur daran.

## Bewusst nicht

- **Expertenmodus und Testvorbereitung rasten nicht.** Dort bleibt „⟵ Zurück zum Menü“,
  und der Lauf endet wie bisher. Die Testvorbereitung hat ihren Fortschritt schon in der
  Runde (`TestPlaylist`, `round_started_at` in `TestLists`): ein beendeter Lauf verliert
  keine gespielten Wörter, und eine neue Runde beginnt erst, wenn der Beutel leer ist.
  Der Expertenmodus ist frei gefilterte Übung ohne Ort und Stufe. Ein gespeicherter Lauf
  müsste dort die Filter vom Start mitnehmen, die das Profil inzwischen anders haben kann.
- **Anreize oder Grenzen für die Spieldauer** gibt es vorerst nicht: keinen Bonus für eine
  lange Pause, keinen Hinweis nach X Minuten und kein Tageslimit. Für eine Beschränkung
  der Bildschirmzeit ist es zu früh. Die Daten dafür liegen bereit, falls sie kommt:
  Pausenlänge aus `saved_at`, Tageszeit aus `started_at`/`ended_at` im `SessionLog`, ohne
  eigenen Zeitzähler.

## Folgen

- Aufhören kostet den Lauf nicht mehr, ein Abbruch mitten in der Welle aber weiterhin.
  Der Dialog aus Punkt 5 macht diesen Unterschied sichtbar.
- Ein fortgesetzter Lauf kann mit mehr HP-Maximum weitergehen, als er gerastet wurde,
  wenn zwischendurch Skills gelernt wurden. Das ist gewollt: Skills sind Profilstand.
- Ein Lauf kann mehrere Sitzungen umfassen. Wer Läufe auswertet (Bestwerte, Bilanz),
  folgt `continues`.
- Handbuch: Kapitel 7 (Abbrechen, Rückfrage), Kapitel 8 (Rasten statt „Zurück zum Menü“)
  und Kapitel 10 (HP beim Fortsetzen).
- Tests mit `zz-`-Profil: Speichern und Laden ergeben denselben Lauf, das Maximum wird
  neu gerechnet und der Stand darauf begrenzt, Fortsetzen verbraucht den Speicherstand,
  eine gefallene Festung schreibt keinen, ein unspielbarer Stand wird verworfen, ein Lauf
  lässt die Plätze anderer Bücher in Ruhe, eine Auswahl mit allen gespeicherten Orten setzt
  fort (auch erweitert, auch über Gesamt), wegnehmen oder tauschen fragt nach, der Boss
  setzt nie fort, und Expertenmodus und Testvorbereitung
  schreiben nie einen.
