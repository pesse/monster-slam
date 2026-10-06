class_name SpacedRepetition
extends RefCounted
## Wiederholung mit Abstand (ADR 0018): wie viel ein Treffer zählt und wann eine Aufgabe
## wieder dran ist — beides aus der Confidence und der letzten Antwort, ohne eigenen Zustand.
##
## Bis 0.26 lief daneben ein SM-2-Plan mit Ease und Intervall. Er wusste nichts von der
## Confidence und sie nichts von ihm: fünf Treffer an einem Nachmittag meisterten ein Wort,
## drei an drei Tagen nicht, und das frisch gemeisterte Wort war am nächsten Tag „fällig"
## und stand in der Auswahl ganz vorn (Issue #18). Jetzt gibt es einen Lernstand, die
## Confidence, und die Fälligkeit wird aus ihr gerechnet.
##
## Zeitbasis sind Unix-Sekunden. Ein Fehler ist nach RELEARN_SECONDS wieder fällig — noch in
## derselben Sitzung. Richtige Antworten rechnen in Tagen und werden zu Beginn des lokalen
## Tages fällig (`utc_offset`): wer abends übt, hat das Wort am nächsten Nachmittag schon
## wieder, nicht erst um dieselbe Uhrzeit.

const DAY := 86400
## Abstand nach einer falschen Antwort, und der kleinste Abstand, der überhaupt zählt.
const RELEARN_SECONDS := 600

## Ein Treffer schließt diesen Anteil der Lücke zu 1 — GAIN_MIN direkt nach der letzten
## Antwort, GAIN_MAX nach einem vollen Abstand (spacing_gain). Gemessen an der
## Meisterungs-Schwelle 0.8 und dem Prior 0.3: drei Treffer an drei Tagen meistern
## (0.30 → 0.58 → 0.75 → 0.85), in einer Sitzung braucht es neun.
const GAIN_MIN := 0.10
const GAIN_MAX := 0.40

## Intervall nach einer richtigen Antwort, je Confidence: [ab Confidence, Tage]. Unter der
## ersten Stufe ein Tag. Der Deckel liegt bei 45 Tagen — Schulvokabular wird über ein
## Schuljahr geprüft, ein Wort, das erst in Monaten wiederkommt, ist aus dem Spiel verschwunden.
const INTERVALS := [[0.985, 45], [0.975, 30], [0.95, 14], [0.9, 7], [0.8, 3]]


## Wie viel ein Treffer zählt, nach dem Abstand zur letzten Antwort auf dieselbe Aufgabe.
##
## Logarithmisch zwischen RELEARN_SECONDS (GAIN_MIN) und dem vollen Abstand (GAIN_MAX):
## eine Stunde später zählt etwa ein Drittel des Wegs, am nächsten Tag fast alles. Der volle
## Abstand ist ein Tag oder das geplante Intervall, wenn es länger ist — wer ein Wort mit
## sieben Tagen Intervall schon nach einem wiederholt, lernt dabei weniger als zur Zeit.
## `elapsed` < 0 heißt: erste Antwort, kein Abstand bekannt — sie zählt voll, damit der
## erste Tag einer der Tage ist.
static func spacing_gain(elapsed: int, interval: int) -> float:
	if elapsed < 0:
		return GAIN_MAX
	var full := float(maxi(DAY, interval))
	var s := log(maxf(float(elapsed), RELEARN_SECONDS) / RELEARN_SECONDS) / log(full / RELEARN_SECONDS)
	return lerpf(GAIN_MIN, GAIN_MAX, clampf(s, 0.0, 1.0))


## Tage bis zur nächsten Wiederholung nach einer richtigen Antwort mit dieser Confidence.
static func interval_days(confidence: float) -> int:
	for step in INTERVALS:
		if confidence >= float(step[0]):
			return int(step[1])
	return 1


## Fälligkeit (unix) aus dem Lernstand einer Aufgabe; 0, wenn sie nie beantwortet wurde.
static func due_at(confidence: float, last_correct: bool, last_seen: int, utc_offset: int) -> int:
	if last_seen <= 0:
		return 0
	if not last_correct:
		return last_seen + RELEARN_SECONDS
	return day_start(last_seen, utc_offset) + interval_days(confidence) * DAY


## Beginn des lokalen Tages, in den `now` fällt (unix).
static func day_start(now: int, utc_offset: int) -> int:
	return int(floor(float(now + utc_offset) / DAY)) * DAY - utc_offset
