extends Node
## Global signal hub (autoload).
##
## Systems communicate through these signals instead of referencing each other
## directly, so gameplay, UI, learning and content modules stay decoupled.
## A new system can subscribe to relevant signals without any existing system
## needing to know it exists.

## --- Wave / spawn lifecycle ---
signal wave_started(wave_id: String)
signal wave_totals(total: int)
signal wave_cleared(wave_id: String)
## Der Spieler hat den Rest der Welle „schnell aufgelöst": was noch kommt, läuft im
## Zeitraffer durch. `unspawned` = noch nicht erschienen, `on_field` = gerade unterwegs.
signal wave_fast_resolved(unspawned: int, on_field: int)
## `task` ist die aufgelöste Aufgabe (TaskResolver), damit ein Mithörer weiß, WELCHES
## Lexem gerade erscheint — `monster` ist nur die Darstellung.
signal monster_spawned(monster: Dictionary, task: Dictionary)
## Ein Monster hat die Festung erreicht. `task` wie oben, `damage` der angerichtete Schaden.
signal monster_reached_fortress(monster: Dictionary, task: Dictionary, damage: int)

## --- Player input & combat ---
signal answer_submitted(text: String)
## Eine abgeschickte Antwort ist beurteilt — RICHTIG WIE FALSCH, und auch die, die keiner
## Aufgabe zuzuordnen war. Das unterscheidet es von `item_reviewed`: das ist eine
## Lernstands-Buchung und feuert auch ohne Eingabe (durchgelassenes Monster), dieses hier
## feuert genau dann, wenn jemand Enter gedrückt hat.
## `verdict` trägt {matched, complete, exact, learnable_id, source_id, response_time_ms,
## canonical, candidates} und bei einer Falscheingabe `unseen` (Ich-Sicht: auf dem Feld,
## aber nicht im Bild). Ein Dictionary, damit Felder dazukommen können, ohne die
## Signatur zu brechen.
signal answer_judged(text: String, verdict: Dictionary)
## Jede Zeichenänderung in der Antwort-Eingabe (spannt in der Ich-Sicht den Bogen).
signal typing_activity()
## Eingabe abgeschickt/beendet — eine laufende Slow-Motion endet sofort.
signal typing_stopped()
## Die Eingabe wurde mit Enter geöffnet. Die Zeitlupe beginnt sofort und hält,
## bis typing_stopped kommt (Abschicken oder Schließen) — nicht nach Zeichen bemessen.
signal typing_started()
## Stärke der Tipp-Slow-Motion: 0.0 = Normaltempo, 1.0 = voll verlangsamt.
signal slow_motion_changed(intensity: float)
signal monster_defeated(monster: Dictionary, was_correct: bool)
signal fortress_damaged(amount: int)

## --- Boss fights ---
signal boss_started(boss_id: String)
signal boss_sentence_presented(sentence: Dictionary)
signal boss_answer_evaluated(quality: float, feedback: String)
## Eine Antwort im Bosskampf ist entschieden — mit dem, was die Spur braucht: welcher Satz,
## was getippt wurde, und wer wie geurteilt hat ({ quality, stage, sure, hit }).
signal boss_answer_judged(sentence_id: String, text: String, result: Dictionary)
## Das Modell hat erklärt, was an der Antwort nicht stimmt (ADR 0005).
signal boss_answer_explained(sentence_id: String, explanation: String)
signal boss_ended(boss_id: String, won: bool)
## Ein Boss am Ende einer Unit ist besiegt (von der Karte gestartet, ADR 0006). Kommt
## zusätzlich zu `boss_ended`, nicht statt ihm.
signal boss_won(boss_id: String, unit_key: String)

## --- Zauber (Verbrauchsgegenstände, ADR 0014) ---
## Nicht zu verwechseln mit den Skills des Fähigkeitsbaums: die sind dauerhaft, werden
## mit Skillpunkten gekauft und wirken über SkillBook auf den Lauf (kein Signal nötig).
## Ein Zauber aus dem Vorrat hat gewirkt und ist verbraucht. Ein Zauber, der nichts
## bewirkt hätte, wird nicht verbraucht und meldet sich nicht.
signal spell_activated(spell_id: String)

## --- Lauf (Sitzung) ---
## Ein neuer Lauf beginnt: Kampfszene betreten, GameState zurückgesetzt. Die Welle
## darunter ist die kleinere Einheit — ein Lauf umfasst alle Wellen bis zur gefallenen
## Festung oder zum Rückweg ins Menü.
signal run_started()
## Der Lauf ist zu Ende, über den Statistik-Screen oder per Abbruch. `summary` trägt,
## was nur der WaveRunner weiß: wave_reached, difficulty_last, last_wave_won.
signal run_ended(summary: Dictionary)
## Der Lauf wird gerastet (ADR 0020): er endet hier, und `next_wave` ist die Welle, mit
## der er auf der Karte weitergehen kann. Kommt direkt vor `run_ended`.
signal run_suspended(next_wave: int)
## Der Kampf setzt einen begonnenen Lauf fort. Kommt direkt nach `run_started`;
## `run_started_at` ist der Beginn des ursprünglichen Laufs (SessionLog `continues`),
## `added` die Orte, um die er auf der Karte erweitert wurde (RunSave.added), sonst leer.
signal run_resumed(next_wave: int, run_started_at: int, added: Array)

## --- Learning / spaced repetition ---
## `response_time_ms` ist 0, wo es keine gemessene Zeit gibt (durchgelassenes Monster) —
## dieselbe Konvention wie in PlayerProgress.record().
signal item_reviewed(item_id: String, correct: bool, response_time_ms: int)
## Eine Aufgabe ist ZUM ERSTEN MAL gemeistert (PlayerProgress.record() lieferte true).
## Nie ein zweites Mal für dieselbe Aufgabe — `mastered_at` wird nicht zurückgenommen.
signal task_mastered(task_id: String)
## Mit dieser Antwort sitzt ein Wort zum ersten Mal in allen Richtungen
## (Lexeme.mastery_directions). Kommt direkt nach dem task_mastered der
## Aufgabe, die es abgeschlossen hat.
signal lexeme_mastered(lexeme_id: String)
## Das Wachkatapult (Bollwerk) hat ein Monster mit gemeisterter Aufgabe abgeschossen. Es ist
## erledigt, aber nicht beantwortet: kein Lernstand, keine Erfahrung, keine Punkte.
signal monster_catapulted(task: Dictionary)
## Der Donnerschlag (Zauber, ADR 0014) hat ein Monster vom Feld genommen. Wie beim Katapult
## erledigt, aber nicht beantwortet — ein eigenes Signal, damit die Spur die beiden trennt.
signal monster_struck(task: Dictionary)
