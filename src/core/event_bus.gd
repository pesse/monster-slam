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
## `verdict` trägt {matched, complete, learnable_id, source_id, response_time_ms,
## canonical, candidates}. Ein Dictionary, damit Felder dazukommen können, ohne die
## Signatur zu brechen.
signal answer_judged(text: String, verdict: Dictionary)
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

## --- Zauber (aktive Fähigkeiten mit Abklingzeit) ---
## Nicht zu verwechseln mit den Skills des Fähigkeitsbaums: die sind dauerhaft, werden
## mit Skillpunkten gekauft und wirken über SkillBook auf den Lauf (kein Signal nötig).
signal spell_activated(spell_id: String)
signal spell_ready(spell_id: String)

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
