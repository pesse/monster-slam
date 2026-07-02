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
signal monster_defeated(monster: Dictionary, was_correct: bool)
signal fortress_damaged(amount: int)

## --- Boss fights ---
signal boss_started(boss_id: String)
signal boss_sentence_presented(sentence: Dictionary)
signal boss_answer_evaluated(quality: float, feedback: String)

## --- Skills ---
signal skill_activated(skill_id: String)
signal skill_ready(skill_id: String)

## --- Learning / spaced repetition ---
signal item_reviewed(item_id: String, correct: bool)
