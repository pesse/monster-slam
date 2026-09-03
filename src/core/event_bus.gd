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
signal monster_spawned(monster: Dictionary)
signal monster_reached_fortress(monster: Dictionary)

## --- Player input & combat ---
signal answer_submitted(text: String)
## Jede Zeichenänderung in der Antwort-Eingabe (treibt die Tipp-Slow-Motion).
signal typing_activity()
## Eingabe abgeschickt/beendet — eine laufende Slow-Motion endet sofort.
signal typing_stopped()
## Stärke der Tipp-Slow-Motion: 0.0 = Normaltempo, 1.0 = voll verlangsamt.
signal slow_motion_changed(intensity: float)
signal monster_defeated(monster: Dictionary, was_correct: bool)
signal fortress_damaged(amount: int)

## --- Boss fights ---
signal boss_started(boss_id: String)
signal boss_sentence_presented(sentence: Dictionary)
signal boss_answer_evaluated(quality: float, feedback: String)

## --- Skills ---
signal skill_activated(skill_id: String)
signal skill_ready(skill_id: String)

## --- Lauf (Sitzung) ---
## Ein neuer Lauf beginnt: Kampfszene betreten, GameState zurückgesetzt. Die Welle
## darunter ist die kleinere Einheit — ein Lauf umfasst alle Wellen bis zur gefallenen
## Festung oder zum Rückweg ins Menü.
signal run_started()
## Der Lauf ist zu Ende, über den Statistik-Screen oder per Abbruch. `summary` trägt,
## was nur der WaveRunner weiß: wave_reached, difficulty_last, last_wave_won.
signal run_ended(summary: Dictionary)

## --- Learning / spaced repetition ---
## `response_time_ms` ist 0, wo es keine gemessene Zeit gibt (durchgelassenes Monster) —
## dieselbe Konvention wie in PlayerProgress.record().
signal item_reviewed(item_id: String, correct: bool, response_time_ms: int)
