class_name SentenceJudge
extends Node
## Der Vertrag für alle Bewertungsstufen — und die Zusicherung, dass keine davon blockiert
## (docs/adr/0004-satzbewertung-ohne-modell.md, Entscheidung 4).
##
##     Antwort ─► Stufe 0  Prüfkarte (offline, deterministisch, immer vorhanden)
##                  ├─ klarer Treffer oder bekannter Fehler ─► fertig
##                  └─ unsicher ─► Stufe 1, Aufruf 1: Urteil mit Schlüssel (optional)
##                                   ├─ richtig ─► refined (Treffer)
##                                   ├─ falsch  ─► denied, dann Aufruf 2: Erklärung
##                                   │               └─► explained (Grund oder leer)
##                                   └─ Zeitlimit / nichts ─► gave_up, Ergebnis aus Stufe 0
##
## `judge()` gibt das Ergebnis der Prüfkarte SOFORT zurück — es liegt bereit, während der
## Boss ausholt. Meldet sich Stufe 1 rechtzeitig, kommt die Verfeinerung als `refined`
## nach; meldet sie sich nicht, schlägt der Boss trotzdem zu. Kein Zustand des Kampfes
## hängt an einem Modell, die Wartezeit ist Inszenierung und keine Blockade.
##
## **Stufe 1 darf nur heben, nie senken — und sie ist das EINZIGE, was aus einem Zweifel
## einen Treffer machen kann.** Gefragt wird sie nur, wo die Karte nichts gefunden hat:
## keine bekannte Lösung, aber auch keinen bekannten Fehler. Dort steht die Güte der Karte
## seit der Messung am Antwortbogen auf 0 (SentenceCard.NO_VERDICT) — sie hat kein Urteil,
## und ohne Stufe 1 bleibt die Antwort kein Treffer.
##
## Beides zusammen ist der Grund, aus dem die Regel trägt: die falschen Antworten in diesem
## Topf sind schon abgewiesen, ein Modell kann sie also gar nicht durchwinken; anzuheben
## hat es nur, was richtig und bloß nicht hinterlegt ist.
##
## **Wo es nicht hebt, darf es erklären** (docs/adr/0005-bosskampf-mit-erklaerung.md,
## Entscheidung 2). Sein Tadel war der Fehler, um dessentwillen ADR 0004 kein Modell
## ausliefert — es lehnt richtige Antworten ab. Deshalb erklärt ein ZWEITER Aufruf, ohne
## Lösungsschlüssel und unabhängig vom ersten; findet er keinen Fehler, gibt es keine
## Erklärung, und es bleibt bei der Rückmeldung der Karte und der Musterlösung. Die
## Begründung des Urteils selbst wird nie gezeigt: sie ist mit dem Schlüssel vor Augen
## geschrieben.
##
## Stufe 1 ist NICHT Teil der Auslieferung: ohne `model_backend` existiert sie für das
## Spiel nicht. Wer sie will, startet einen lokalen Dienst (siehe LocalModelBackend).

## Stufe 0 hat geantwortet — immer, sofort, für jede Antwort.
signal judged(result: Dictionary)
## Stufe 1 hat rechtzeitig geantwortet und das Ergebnis verfeinert.
signal refined(result: Dictionary)
## Stufe 1 hat geurteilt: kein Treffer. Die Güte bleibt die der Karte (0); `sure` ist jetzt
## wahr, `stage` ist "model". Die Rückmeldung bleibt die der Karte — was falsch ist, sagt
## erst `explained`.
signal denied(result: Dictionary)
## Die Erklärung zu einem `denied`. Kommt nach jedem `denied`, sofern ein `explainer`
## eingehängt ist — auch wenn es keine Erklärung gibt: dann ist "explanation" leer und die
## Anzeige zeigt die Musterlösung. So muss niemand auf etwas warten, das nicht kommt.
signal explained(result: Dictionary)
## Stufe 1 war zu langsam oder hatte nichts beizutragen. Für die Werkbank und für eine
## Anzeige, die sagen will, woran es lag — der Aufrufer hat sein Ergebnis längst.
signal gave_up()

## Wie lange auf eine Antwort von Stufe 1 gewartet wird, je Aufruf. Etwas länger als das
## Backend: gäbe der Richter früher auf, bliebe die Anfrage offen und jede weitere fiele in
## dessen Sperre. Der Bosskampf hat keinen Zeitdruck (ADR 0005, Entscheidung 7).
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

## Laufende Nummer der Anfrage. Eine Antwort auf eine ältere Frage ist keine Antwort —
## im Kampf tippt der Spieler weiter, während das Modell noch rechnet.
var _ticket := 0
var _open := false
## Wartet gerade eine Erklärung? Getrennt von `_open`, weil das Urteil schon da ist.
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
	# Nicht gehoben: die Güte bleibt, die Rückmeldung auch. Nur `sure` sagt jetzt, dass
	# jemand geurteilt hat.
	# `_explaining` VOR dem Signal: wer auf `denied` hört, fragt `explaining()`, um zu
	# wissen, ob noch eine Erklärung kommt.
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


## Das Ergebnis mit der Erklärung. Eine Erklärung gibt es nur, wenn der Erklärer einen
## Fehler gefunden UND ihn benannt hat; dann ersetzt sie die Rückmeldung der Karte. Sonst
## ist "explanation" leer, und es bleibt bei Karte und Musterlösung.
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
