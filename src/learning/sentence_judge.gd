class_name SentenceJudge
extends Node
## Der Vertrag für alle Bewertungsstufen — und die Zusicherung, dass keine davon blockiert
## (docs/adr/0004-satzbewertung-ohne-modell.md, Entscheidung 4).
##
##     Antwort ─► Stufe 0  Prüfkarte (offline, deterministisch, immer vorhanden)
##                  ├─ klarer Treffer oder bekannter Fehler ─► fertig
##                  └─ unsicher ─► Stufe 1  lokaler Dienst über HTTP (optional)
##                                   └─ Zeitlimit überschritten ─► Ergebnis aus Stufe 0
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
## hat es nur, was richtig und bloß nicht hinterlegt ist. Sein Tadel wäre dagegen genau der
## Fehler, um dessentwillen das ADR kein Modell ausliefert — es lehnt richtige Antworten ab.
## Deshalb bleibt auch die Rückmeldung der Karte stehen, wo das Modell nicht anhebt.
##
## Stufe 1 ist NICHT Teil der Auslieferung: ohne `model_backend` existiert sie für das
## Spiel nicht. Wer sie will, startet einen lokalen Dienst (siehe LocalModelBackend).

## Stufe 0 hat geantwortet — immer, sofort, für jede Antwort.
signal judged(result: Dictionary)
## Stufe 1 hat rechtzeitig geantwortet und das Ergebnis verfeinert.
signal refined(result: Dictionary)
## Stufe 1 war zu langsam oder hatte nichts beizutragen. Für die Werkbank und für eine
## Anzeige, die sagen will, woran es lag — der Aufrufer hat sein Ergebnis längst.
signal gave_up()

## Wie lange auf Stufe 1 gewartet wird. Vier Sekunden sind die Zeit, die der Boss zum
## Ausholen hat; was länger braucht, ist im Kampf ohnehin zu spät.
const DEFAULT_TIMEOUT := 4.0

## func(sentence: Dictionary, answer: String, on_done: Callable) -> void
## `on_done` nimmt { "quality": float, "feedback": String }; ein leeres Dictionary heißt
## „nichts beizutragen". Ungültig = es gibt keine Stufe 1.
var model_backend: Callable = Callable()
var timeout: float = DEFAULT_TIMEOUT

## Laufende Nummer der Anfrage. Eine Antwort auf eine ältere Frage ist keine Antwort —
## im Kampf tippt der Spieler weiter, während das Modell noch rechnet.
var _ticket := 0
var _open := false
var _card: Dictionary = {}


## Bewertet die Antwort. Rückgabe ist das Ergebnis der Prüfkarte (Stufe 0), sofort.
func judge(sentence: Dictionary, answer: String) -> Dictionary:
	_ticket += 1
	_open = false
	var card := SentenceCard.evaluate(sentence, answer)
	_card = card
	judged.emit(card)
	if bool(card.get("sure", true)) or not model_backend.is_valid():
		return card
	_open = true
	var ticket := _ticket
	_arm_timeout(ticket)
	model_backend.call(sentence, answer, func(reply: Dictionary) -> void:
		_on_model(ticket, reply))
	return card


## Wartet gerade eine Anfrage auf Stufe 1?
func pending() -> bool:
	return _open


## Vergisst eine laufende Anfrage — beim Szenenwechsel oder wenn der Spieler weitertippt.
func cancel() -> void:
	_ticket += 1
	_open = false


## Mischt die Antwort von Stufe 1 in das Ergebnis der Karte.
func _on_model(ticket: int, reply: Dictionary) -> void:
	if ticket != _ticket or not _open:
		return
	_open = false
	var lifted := clampf(float(reply.get("quality", 0.0)), 0.0, 1.0)
	if reply.is_empty() or lifted <= float(_card.get("quality", 0.0)):
		gave_up.emit()
		return
	var merged := _card.duplicate(true)
	merged["quality"] = lifted
	merged["stage"] = "model"
	merged["sure"] = true
	var said := str(reply.get("feedback", "")).strip_edges()
	if not said.is_empty():
		merged["feedback"] = said
	refined.emit(merged)


func _arm_timeout(ticket: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(timeout).timeout.connect(func() -> void:
		if ticket == _ticket and _open:
			_open = false
			gave_up.emit())
