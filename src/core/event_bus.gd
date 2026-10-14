extends Node
## Global signal hub (autoload): systems talk through these signals instead of
## referencing each other directly.

## --- Wave / spawn lifecycle ---
signal wave_started(wave_id: String)
signal wave_totals(total: int)
signal wave_cleared(wave_id: String)
## Der Rest der Welle läuft im Zeitraffer durch. `unspawned` = noch nicht erschienen,
## `on_field` = gerade unterwegs.
signal wave_fast_resolved(unspawned: int, on_field: int)
## `task` ist die aufgelöste Aufgabe (TaskResolver), `monster` nur die Darstellung.
signal monster_spawned(monster: Dictionary, task: Dictionary)
## `task` wie oben, `damage` der angerichtete Schaden.
signal monster_reached_fortress(monster: Dictionary, task: Dictionary, damage: int)

## --- Player input & combat ---
signal answer_submitted(text: String)
## Jede abgeschickte Antwort, auch ohne passende Aufgabe. `verdict` = {matched, complete,
## exact, learnable_id, source_id, response_time_ms, canonical, candidates}, bei einer
## Falscheingabe dazu `unseen` (Ich-Sicht: auf dem Feld, nicht im Bild).
signal answer_judged(text: String, verdict: Dictionary)
## Jede Zeichenänderung in der Antwort-Eingabe.
signal typing_activity()
## Eingabe abgeschickt oder geschlossen; die Zeitlupe endet sofort.
signal typing_stopped()
## Eingabe mit Enter geöffnet; die Zeitlupe hält bis `typing_stopped`.
signal typing_started()
## Stärke der Zeitlupe: 0.0 = Normaltempo, 1.0 = voll verlangsamt.
signal slow_motion_changed(intensity: float)
signal monster_defeated(monster: Dictionary, was_correct: bool)
signal fortress_damaged(amount: int)

## --- Boss fights ---
signal boss_started(boss_id: String)
signal boss_sentence_presented(sentence: Dictionary)
signal boss_answer_evaluated(quality: float, feedback: String)
## `result` = { quality, stage, sure, hit }.
signal boss_answer_judged(sentence_id: String, text: String, result: Dictionary)
## Erklärung des Modells zur Antwort (ADR 0005).
signal boss_answer_explained(sentence_id: String, explanation: String)
signal boss_ended(boss_id: String, won: bool)
## Boss am Ende einer Unit besiegt (ADR 0006); kommt zusätzlich zu `boss_ended`.
signal boss_won(boss_id: String, unit_key: String)

## --- Schreib-Boss (ADR 0023) ---
## Eine Abgabe beim Schreib-Boss ist bewertet. `entry` hat die Felder von
## `WritingLog.FIELDS` (Boss, Abgabe-Nummer, Modell, Token, Dauer, erfüllte Kriterien,
## Wortzahl) — kein Text, kein Schlüssel.
signal writing_submitted(entry: Dictionary)

## --- Zauber (Verbrauchsgegenstände, ADR 0014) ---
## Ein Zauber hat gewirkt und ist verbraucht. Ein Zauber ohne Wirkung meldet sich nicht.
signal spell_activated(spell_id: String)

## --- Lauf (Sitzung) ---
## Ein Lauf umfasst alle Wellen bis zur gefallenen Festung oder zum Rückweg ins Menü.
signal run_started()
## `summary` = { wave_reached, difficulty_last, last_wave_won }.
signal run_ended(summary: Dictionary)
## Der Lauf wird gerastet (ADR 0020). `next_wave` ist die Welle zum Weitermachen,
## `remaining` ihre übrigen Monster (0 an der Wellengrenze). Kommt direkt vor `run_ended`.
signal run_suspended(next_wave: int, remaining: int)
## Fortsetzung eines begonnenen Laufs, direkt nach `run_started`. `run_started_at` ist der
## Beginn des ursprünglichen Laufs, `added` die auf der Karte hinzugefügten Orte.
signal run_resumed(next_wave: int, run_started_at: int, added: Array)

## --- Learning / spaced repetition ---
## `response_time_ms` ist 0 ohne gemessene Zeit (durchgelassenes Monster).
signal item_reviewed(item_id: String, correct: bool, response_time_ms: int)
## Eine Aufgabe ist zum ersten Mal gemeistert; nie ein zweites Mal für dieselbe Aufgabe.
signal task_mastered(task_id: String)
## Ein Wort sitzt zum ersten Mal in allen Richtungen (Lexeme.mastery_directions).
## Kommt direkt nach dem `task_mastered`, das es abgeschlossen hat.
signal lexeme_mastered(lexeme_id: String)
## Plakette verdient: `id` wie in Badges, `tier` 1..4 oder 0 ohne Stufe.
signal badge_earned(id: String, tier: int)
## Das Wachkatapult hat ein gemeistertes Monster abgeschossen: erledigt, aber nicht
## beantwortet (kein Lernstand, keine Erfahrung, keine Punkte).
signal monster_catapulted(task: Dictionary)
## Der Donnerschlag (ADR 0014) hat ein Monster vom Feld genommen; erledigt wie beim Katapult.
signal monster_struck(task: Dictionary)

## --- Spielstand (ADR 0024) ---
## SaveGuard hat ein Speichern verweigert; `file` bleibt unverändert.
signal save_refused(file: String, reason: String)
## Beschädigter Spielstand aus der Sicherung von `backup_at` (unix) zurückgeholt.
## `files` nennt die beschädigten Dateien (nur Endungen).
signal save_restored(files: Array, backup_at: int)
## Beschädigt und keine Sicherung: das Profil speichert nicht, bis der Spieler entscheidet.
signal save_damaged(files: Array)
