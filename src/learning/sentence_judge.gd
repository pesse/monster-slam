class_name SentenceJudge
extends Node
## Der Vertrag für alle Bewertungsstufen; keine davon blockiert (ADR 0004 und 0005).
##
##     Antwort ─► Stufe 0  Prüfkarte (offline, deterministisch, immer vorhanden)
##                  ├─ klarer Treffer oder bekannter Fehler ─► fertig
##                  └─ unsicher ─► Stufe 1, Aufruf 1: Urteil mit Schlüssel (optional)
##                                   ├─ richtig ─► refined (Treffer)
##                                   ├─ falsch  ─► denied, dann Aufruf 2: Erklärung
##                                   │               └─► explained (Grund oder leer)
##                                   └─ Zeitlimit / nichts ─► gave_up, Ergebnis aus Stufe 0
##
## `judge()` gibt das Ergebnis der Prüfkarte sofort zurück, Stufe 1 meldet sich über
## Signale. Stufe 1 darf nur heben, nie senken. Ohne `model_backend` gibt es sie nicht.

## Stufe 0 hat geantwortet — immer, sofort, für jede Antwort.
signal judged(result: Dictionary)
## Stufe 1 hat rechtzeitig geantwortet und das Ergebnis verfeinert.
signal refined(result: Dictionary)
## Stufe 1 hat geurteilt: kein Treffer. Güte und Rückmeldung bleiben die der Karte;
## `sure` ist wahr, `stage` ist "model".
signal denied(result: Dictionary)
## Die Erklärung zu einem `denied`. Kommt nach jedem `denied`, sofern ein `explainer`
## eingehängt ist; ohne Erklärung ist "explanation" leer.
signal explained(result: Dictionary)
## Stufe 1 war zu langsam oder hatte nichts beizutragen.
signal gave_up()

## Wartezeit auf Stufe 1 je Aufruf (s). Länger als das Backend, sonst bliebe dessen Anfrage
## offen und jede weitere fiele in seine Sperre.
const DEFAULT_TIMEOUT := LocalModelBackend.HTTP_TIMEOUT + 2.0

## func(sentence: Dictionary, answer: String, on_done: Callable) -> void
## `on_done` nimmt { "quality": float, "feedback": String }; ein leeres Dictionary heißt
## „nichts beizutragen". Ungültig = es gibt keine Stufe 1.
var model_backend: Callable = Callable()
## func(sentence: Dictionary, answer: String, on_done: Callable) -> void
## `on_done` nimmt { "mistake": bool, "explanation": String }; {} heißt „keine Erklärung".
## Ungültig = nach `denied` kommt nichts mehr.
var explainer: Callable = Callable()
var timeout: float = DEFAULT_TIMEOUT

## Laufende Nummer der Anfrage; Antworten auf ältere Anfragen werden verworfen.
var _ticket := 0
var _open := false
## Wartet gerade eine Erklärung (das Urteil ist schon da)?
var _explaining := false
var _card: Dictionary = {}
var _sentence: Dictionary = {}
var _answer := ""


## Bewertet die Antwort. Rückgabe ist das Ergebnis der Prüfkarte (Stufe 0), sofort.
func judge(sentence: Dictionary, answer: String) -> Dictionary:
	_ticket += 1
	_open = false
	_explaining = false
	var card := SentenceCard.evaluate(sentence, answer)
	_card = card
	_sentence = sentence
	_answer = answer
	judged.emit(card)
	if bool(card.get("sure", true)) or not model_backend.is_valid():
		return card
	_open = true
	var ticket := _ticket
	_arm_timeout(ticket)
	model_backend.call(sentence, answer, func(reply: Dictionary) -> void:
		_on_model(ticket, reply))
	return card


## Wartet gerade eine Anfrage auf das Urteil von Stufe 1?
func pending() -> bool:
	return _open


## Wartet gerade eine Erklärung?
func explaining() -> bool:
	return _explaining


## Vergisst eine laufende Anfrage — beim Szenenwechsel oder wenn der Spieler weitertippt.
func cancel() -> void:
	_ticket += 1
	_open = false
	_explaining = false


## Mischt das Urteil von Stufe 1 in das Ergebnis der Karte.
func _on_model(ticket: int, reply: Dictionary) -> void:
	if ticket != _ticket or not _open:
		return
	_open = false
	if reply.is_empty():
		gave_up.emit()
		return
	var lifted := clampf(float(reply.get("quality", 0.0)), 0.0, 1.0)
	var merged := _card.duplicate(true)
	merged["stage"] = "model"
	merged["sure"] = true
	if lifted > float(_card.get("quality", 0.0)):
		merged["quality"] = lifted
		var said := str(reply.get("feedback", "")).strip_edges()
		if not said.is_empty():
			merged["feedback"] = said
		refined.emit(merged)
		return
	# `_explaining` vor dem Signal setzen: wer auf `denied` hört, fragt `explaining()`.
	_explaining = explainer.is_valid()
	denied.emit(merged)
	if not _explaining or ticket != _ticket:
		return
	_arm_explain_timeout(ticket, merged)
	# Aufgeschoben: das Backend steht gerade noch im Rückruf seiner ersten Anfrage.
	(func() -> void:
		if ticket == _ticket and _explaining:
			explainer.call(_sentence, _answer, func(said: Dictionary) -> void:
				_on_explained(ticket, merged, said))).call_deferred()


func _on_explained(ticket: int, denied_result: Dictionary, reply: Dictionary) -> void:
	if ticket != _ticket or not _explaining:
		return
	_explaining = false
	explained.emit(with_explanation(denied_result, reply))


## Das Ergebnis mit der Erklärung. Nur wenn der Erklärer einen Fehler gefunden und benannt
## hat, ersetzt sie die Rückmeldung der Karte; sonst ist "explanation" leer.
static func with_explanation(result: Dictionary, reply: Dictionary) -> Dictionary:
	var out := result.duplicate(true)
	var text := str(reply.get("explanation", "")).strip_edges()
	if not bool(reply.get("mistake", false)) or text.is_empty():
		text = ""
	out["explanation"] = text
	if not text.is_empty():
		out["feedback"] = text
	return out


func _arm_explain_timeout(ticket: int, denied_result: Dictionary) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(timeout).timeout.connect(func() -> void:
		if ticket == _ticket and _explaining:
			_explaining = false
			explained.emit(with_explanation(denied_result, {})))


func _arm_timeout(ticket: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(timeout).timeout.connect(func() -> void:
		if ticket == _ticket and _open:
			_open = false
			gave_up.emit())
