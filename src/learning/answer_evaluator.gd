class_name AnswerEvaluator
extends RefCounted
## Evaluates player answers.
##
## Two modes, matching the game design:
##  - evaluate_vocab():  exact/normalized match for single-word recall (fast, offline).
##  - evaluate_sentence(): semantic quality score for boss sentences.
##
## The sentence evaluator is deliberately behind a pluggable interface. The
## default implementation is a simple offline heuristic (token overlap). A
## local LLM backend can be plugged in later by replacing `sentence_backend`
## WITHOUT changing any caller — see docs/ARCHITECTURE.md.

## Optional callable: func(prompt, reference, answer) -> { "quality": float, "feedback": String }
var sentence_backend: Callable = Callable()


## Returns true if `answer` matches any accepted answer (case/whitespace-insensitive).
## Nimmt direkt die Liste gültiger Antworten (z. B. task.accepted_answers).
func evaluate_answers(accepted: Array, answer: String) -> bool:
	var normalized := _normalize(answer)
	for a in accepted:
		if _normalize(str(a)) == normalized:
			return true
	return false


## Kompatibilitäts-Helfer: prüft gegen entry["answers"].
func evaluate_vocab(entry: Dictionary, answer: String) -> bool:
	return evaluate_answers(entry.get("answers", []), answer)


## Returns { "quality": 0.0..1.0, "feedback": String }.
func evaluate_sentence(prompt: String, reference: String, answer: String) -> Dictionary:
	if sentence_backend.is_valid():
		return sentence_backend.call(prompt, reference, answer)
	return _heuristic_sentence(reference, answer)


func _heuristic_sentence(reference: String, answer: String) -> Dictionary:
	var ref_tokens := _tokens(reference)
	var ans_tokens := _tokens(answer)
	if ref_tokens.is_empty():
		return {"quality": 0.0, "feedback": "Keine Referenz hinterlegt."}
	var hits := 0
	for t in ref_tokens:
		if t in ans_tokens:
			hits += 1
	var quality := float(hits) / float(ref_tokens.size())
	var feedback := "Gut getroffen!" if quality >= 0.8 else "Fast — achte auf die fehlenden Wörter."
	if quality < 0.4:
		feedback = "Versuch es nochmal, viele Kernbegriffe fehlen."
	return {"quality": quality, "feedback": feedback}


func _normalize(s: String) -> String:
	return s.strip_edges().to_lower()


func _tokens(s: String) -> PackedStringArray:
	return _normalize(s).replace(".", " ").replace(",", " ").split(" ", false)
